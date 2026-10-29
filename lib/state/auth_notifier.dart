import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_exceptions.dart';
import '../core/auth_api.dart';
import '../core/config.dart';
import '../models/app_user.dart';
import '../models/permissions.dart';

/// Сессия пользователя: токены, профиль, сроки.
///
/// Токены и профиль лежат в localStorage, чтобы пережить перезагрузку.
/// Роль из профиля используется только для построения интерфейса;
/// разрешает или запрещает операцию сервер.
class AuthNotifier extends ChangeNotifier {
  static const _kAccess = 'auth_access_token';
  static const _kRefresh = 'auth_refresh_token';
  static const _kUser = 'auth_user';
  static const _kStarted = 'auth_session_started';

  static const inactivityReason =
      'Сеанс завершён: не было действий в течение 3 минут.';
  static const sessionLimitReason =
      'Сеанс завершён: истекло наибольшее время работы.';
  static const expiredReason = 'Срок действия входа истёк. Войдите снова.';

  final SharedPreferences _prefs;
  final AuthApi _api;

  AuthNotifier(this._prefs, this._api);

  AppUser? _user;
  String? _accessToken;
  Timer? _sessionTimer;
  Future<bool>? _refreshing;

  /// Почему пользователь вышел из системы — показывается на экране входа.
  String? logoutReason;

  AppUser? get user => _user;
  String? get accessToken => _accessToken;
  bool get isAuthenticated => _user != null;

  bool can(Permission permission) => roleCan(_user?.role, permission);

  /// Восстановление сессии при запуске, до построения виджетов.
  /// Действительность токена проверит первый запрос: при 401 токен
  /// обновится, а если не выйдет — пользователь выйдет из системы.
  Future<void> restore() async {
    final access = _prefs.getString(_kAccess);
    final userJson = _prefs.getString(_kUser);
    if (access == null || userJson == null) return;
    try {
      _user = AppUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      _accessToken = access;
      _startSessionTimer();
    } catch (_) {
      await _clear();
    }
  }

  Future<void> login(String username, String password) async {
    final result = await _api.login(username, password);
    await _save(result);
    await _prefs.setString(_kStarted, DateTime.now().toIso8601String());
    logoutReason = null;
    _startSessionTimer();
    notifyListeners();
  }

  Future<void> register({
    required String username,
    required String password,
    required String email,
    required String fullName,
  }) async {
    await _api.register(
      username: username,
      password: password,
      email: email,
      fullName: fullName,
    );
    await login(username, password);
  }

  /// Обновление пары токенов. Одновременные запросы с кодом 401
  /// дожидаются одного обновления, а не запускают несколько.
  Future<bool> refreshTokens() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<bool> _refresh() async {
    final refreshToken = _prefs.getString(_kRefresh);
    if (refreshToken == null) return false;
    try {
      await _save(await _api.refresh(refreshToken));
      return true;
    } on ApiException {
      return false;
    }
  }

  Future<void> logout({String? reason}) async {
    if (_user == null && _accessToken == null) return;
    final refreshToken = _prefs.getString(_kRefresh);
    _user = null;
    _accessToken = null;
    logoutReason = reason;
    _sessionTimer?.cancel();
    await _clear();
    notifyListeners();
    if (refreshToken != null) unawaited(_api.logout(refreshToken));
  }

  Future<void> _save(LoginResult result) async {
    _accessToken = result.accessToken;
    _user = result.user;
    await _prefs.setString(_kAccess, result.accessToken);
    await _prefs.setString(_kRefresh, result.refreshToken);
    await _prefs.setString(_kUser, jsonEncode(result.user.toJson()));
  }

  Future<void> _clear() async {
    for (final key in [_kAccess, _kRefresh, _kUser, _kStarted]) {
      await _prefs.remove(key);
    }
  }

  /// Ограничение общей длительности сессии независимо от активности.
  void _startSessionTimer() {
    _sessionTimer?.cancel();
    final started =
        DateTime.tryParse(_prefs.getString(_kStarted) ?? '') ?? DateTime.now();
    final left = sessionMaxDuration - DateTime.now().difference(started);
    _sessionTimer = Timer(
      left.isNegative ? Duration.zero : left,
      () => logout(reason: sessionLimitReason),
    );
  }
}
