import 'app_user.dart';

/// Операции приложения, доступ к которым зависит от роли.
enum Permission {
  viewCatalog('Просмотр каталога, авторов, жанров, издательств'),
  ownLoans('Просмотр своих выдач и продление срока'),
  manageCatalog('Создание, изменение и удаление книг и справочников'),
  manageReaders('Работа с читателями'),
  manageLoans('Оформление и закрытие выдач'),
  viewDeleted('Просмотр удалённых записей'),
  restore('Восстановление записей'),
  hardDelete('Физическое удаление'),
  manageUsers('Управление пользователями и ролями'),
  viewStats('Просмотр статистики');

  const Permission(this.label);

  final String label;
}

/// Права ролей. Роли различаются набором функций, а не объёмом одного
/// и того же: у каждой есть экран, недоступный остальным
/// («Мои выдачи», «Выдачи», «Пользователи» и «Статистика»).
///
/// Это проверка для интерфейса. Настоящая защита — на сервере, который
/// берёт роль из подписанного токена.
const rolePermissions = <Role, Set<Permission>>{
  Role.reader: {Permission.viewCatalog, Permission.ownLoans},
  Role.librarian: {
    Permission.viewCatalog,
    Permission.manageCatalog,
    Permission.manageReaders,
    Permission.manageLoans,
  },
  Role.admin: {
    Permission.viewCatalog,
    Permission.manageCatalog,
    Permission.manageReaders,
    Permission.viewDeleted,
    Permission.restore,
    Permission.hardDelete,
    Permission.manageUsers,
    Permission.viewStats,
  },
};

bool roleCan(Role? role, Permission permission) =>
    role != null && (rolePermissions[role]?.contains(permission) ?? false);
