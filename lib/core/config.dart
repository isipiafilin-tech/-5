/// Адрес сервера задаётся при сборке:
/// flutter run -d chrome --web-port=5555 --dart-define=API_BASE_URL=http://192.168.1.10:8080/api
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080/api',
);

/// Выход по неактивности: через 3 минуты без действий,
/// предупреждение — за 30 секунд.
const inactivityTimeout = Duration(
  seconds: int.fromEnvironment('INACTIVITY_SECONDS', defaultValue: 180),
);
const inactivityWarning = Duration(seconds: 30);

/// Наибольшая длительность сессии независимо от активности.
const sessionMaxDuration = Duration(
  minutes: int.fromEnvironment('SESSION_MAX_MINUTES', defaultValue: 480),
);
