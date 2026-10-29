import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_exceptions.dart';
import 'config.dart';

/// Паузы между повторами чтения при сетевом сбое: всего не более трёх попыток.
const defaultRetryDelays = [Duration(milliseconds: 500), Duration(seconds: 1)];

/// [token] — текущий токен доступа; [refreshTokens] обновляет пару токенов
/// и сообщает, удалось ли; [onAuthFailed] завершает сессию, если обновить
/// токен не получилось.
Dio buildDio({
  String? Function()? token,
  Future<bool> Function()? refreshTokens,
  Future<void> Function()? onAuthFailed,
  List<Duration> retryDelays = defaultRetryDelays,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
      // Не бросать исключение на кодах 4xx — разберём их сами
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        // Все запросы к защищённым адресам уходят с токеном.
        final value = token?.call();
        if (value != null) {
          options.headers['Authorization'] = 'Bearer $value';
        }
        // Учебные параметры __delay и __fail из адреса страницы
        // передаются серверу, чтобы проверить загрузку и ошибки.
        for (final key in const ['__delay', '__fail']) {
          final param = Uri.base.queryParameters[key];
          if (param != null) options.queryParameters[key] = param;
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        final status = response.statusCode ?? 0;
        _log(response.requestOptions, '$status');
        if (status >= 400) {
          // Коды 4xx отправляем по ветке ошибок с уже разобранным исключением.
          return handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
              error: mapHttpError(status, response.data),
            ),
            true,
          );
        }
        return handler.next(response);
      },
      onError: (error, handler) async {
        final options = error.requestOptions;
        final status = error.response?.statusCode;
        if (status == null || status >= 500) {
          _log(options, status?.toString() ?? error.type.name);
        }

        // 401: токен истёк — обновляем и повторяем запрос незаметно для
        // пользователя. Адреса /auth/ не трогаем, а повтор делаем один раз:
        // неудачное обновление ведёт к выходу, а не к бесконечному циклу.
        if (status == 401 &&
            refreshTokens != null &&
            !options.path.contains('/auth/')) {
          if (options.extra['authRetried'] != true && await refreshTokens()) {
            options.extra['authRetried'] = true;
            try {
              return handler.resolve(await dio.fetch(options));
            } on DioException catch (e) {
              return handler.next(e);
            }
          }
          await onAuthFailed?.call();
          return handler.next(error);
        }

        // Повтор только для чтения и только при сетевом сбое:
        // повторять создание записи нельзя.
        final attempt = options.extra['attempt'] as int? ?? 1;
        if (_isNetworkFailure(error) &&
            options.method == 'GET' &&
            attempt <= retryDelays.length) {
          await Future.delayed(retryDelays[attempt - 1]);
          options.extra['attempt'] = attempt + 1;
          try {
            return handler.resolve(await dio.fetch(options));
          } on DioException catch (e) {
            return handler.next(e);
          }
        }
        return handler.next(error);
      },
    ),
  );

  return dio;
}

bool _isNetworkFailure(DioException e) => switch (e.type) {
  DioExceptionType.connectionError ||
  DioExceptionType.connectionTimeout ||
  DioExceptionType.receiveTimeout => true,
  _ => false,
};

void _log(RequestOptions options, String result) {
  if (kDebugMode) {
    debugPrint('[API] ${options.method} ${options.uri} → $result');
  }
}
