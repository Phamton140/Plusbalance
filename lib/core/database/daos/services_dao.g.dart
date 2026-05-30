// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'services_dao.dart';

// ignore_for_file: type=lint
mixin _$ServicesDaoMixin on DatabaseAccessor<AppDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $CategoriesTable get categories => attachedDatabase.categories;
  $ServicesTable get services => attachedDatabase.services;
  ServicesDaoManager get managers => ServicesDaoManager(this);
}

class ServicesDaoManager {
  final _$ServicesDaoMixin _db;
  ServicesDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$ServicesTableTableManager get services =>
      $$ServicesTableTableManager(_db.attachedDatabase, _db.services);
}
