// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'services_dao.dart';

// ignore_for_file: type=lint
mixin _$ServicesDaoMixin on DatabaseAccessor<AppDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $ServicesTable get services => attachedDatabase.services;
  ServicesDaoManager get managers => ServicesDaoManager(this);
}

class ServicesDaoManager {
  final _$ServicesDaoMixin _db;
  ServicesDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$ServicesTableTableManager get services =>
      $$ServicesTableTableManager(_db.attachedDatabase, _db.services);
}
