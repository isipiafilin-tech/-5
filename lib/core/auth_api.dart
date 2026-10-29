import 'package:dio/dio.dart';

import '../models/app_user.dart';
import 'api_exceptions.dart';
import 'config.dart';

class LoginResult {
  final String accessToken;
  final String refreshToken;
  final AppUser user;

  const LoginResult(this.accessToken, this.refreshToken, this.user);

  factory LoginResult.fromJson(Map<String, dynamic> json) => LoginResult(
    json['accessToken'] as String? ?? '',
    json['refreshToken'] as String? ?? '',
    AppUser.fromJson(json['user'] as Map<String, dynamic>? ?? const {}),
  );
}

/// Запросы раздела 2 контракта. Отдельный Dio без интерсептора токена:
/// ответ 401 на вход или обновление не должен запускать повторное
/// обновление, иначе получится бесконечный цикл.
class AuthApi {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  Future<Map<String, dynamic>> _post(String path, Object data) =>
      guard(() async {
        final response = await _dio.post(path, data: data);
        final status = response.statusCode ?? 0;
        if (status >= 400) throw mapHttpError(status, response.data);
        return response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : const {};
      });

  /// Пароль передаётся как есть: хеширует его сервер.
  Future<LoginResult> login(String username, String password) async =>
      LoginResult.fromJson(
        await _post('/auth/login', {
          'username': username,
          'password': password,
        }),
      );

  Future<AppUser> register({
    required String username,
    required String password,
    required String email,
    required String fullName,
  }) async => AppUser.fromJson(
    await _post('/auth/register', {
      'username': username,
      'password': password,
      'email': email,
      'fullName': fullName,
    }),
  );

  Future<LoginResult> refresh(String refreshToken) async =>
      LoginResult.fromJson(
        await _post('/auth/refresh', {'refreshToken': refreshToken}),
      );

  Future<void> logout(String refreshToken) async {
    try {
      await _post('/auth/logout', {'refreshToken': refreshToken});
    } on ApiException {
      // Сервер недоступен — локальная сессия всё равно уже завершена.
    }
  }
}
