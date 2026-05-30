import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables.dart';

part 'accounts_dao.g.dart';

@DriftAccessor(tables: [Accounts])
class AccountsDao extends DatabaseAccessor<AppDatabase> with _$AccountsDaoMixin {
  AccountsDao(super.db);

  /// Obtiene un Stream reactivo de todas las cuentas no archivadas.
  /// Ideal para el Dashboard (carrusel de cuentas).
  Stream<List<Account>> watchActiveAccounts() {
    return (select(accounts)..where((a) => a.isArchived.equals(false))).watch();
  }

  /// Crea una nueva cuenta financiera
  Future<void> createAccount(Insertable<Account> account) {
    return into(accounts).insert(account);
  }

  Future<void> deleteAccount(String accountId) {
    return (delete(accounts)..where((a) => a.id.equals(accountId))).go();
  }

  /// Actualiza una cuenta existente
  Future<bool> updateAccount(Insertable<Account> account) {
    return update(accounts).replace(account);
  }

  /// Archiva una cuenta para que no aparezca en el flujo principal
  Future<int> archiveAccount(String accountId) {
    return (update(accounts)..where((a) => a.id.equals(accountId))).write(
      const AccountsCompanion(isArchived: Value(true)),
    );
  }

  /// Obtiene el balance total sumando todas las cuentas activas
  Stream<double> watchTotalBalance() {
    final balanceSum = accounts.balance.sum();
    final query = selectOnly(accounts)
      ..addColumns([balanceSum])
      ..where(accounts.isArchived.equals(false));

    return query.map((row) => row.read(balanceSum) ?? 0.0).watchSingle();
  }
}
