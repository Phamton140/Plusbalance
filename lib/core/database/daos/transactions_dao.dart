import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables.dart';

part 'transactions_dao.g.dart';

@DriftAccessor(tables: [Transactions, Accounts, Services])
class TransactionsDao extends DatabaseAccessor<AppDatabase> with _$TransactionsDaoMixin {
  TransactionsDao(super.db);

  /// Obtener todas las transacciones paginadas para alto rendimiento (100k+)
  Future<List<Transaction>> getTransactionsPaginated(int limit, int offset) {
    return (select(transactions)
          ..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)
          ])
          ..limit(limit, offset: offset))
        .get();
  }

  /// Stream reactivo de transacciones recientes para el Dashboard
  Stream<List<Transaction>> watchRecentTransactions({int limit = 10}) {
    return (select(transactions)
          ..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)
          ])
          ..limit(limit))
        .watch();
  }

  Stream<List<Transaction>> watchTransactionsByType(String type, {int limit = 50}) {
    return (select(transactions)
          ..where((t) => t.type.equals(type))
          ..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)
          ])
          ..limit(limit))
        .watch();
  }

  /// Insertar un gasto/ingreso y actualizar el balance de la cuenta en una misma transacción
  Future<void> createTransaction(Insertable<Transaction> transaction, String accountId, double amount, bool isIncome) {
    return db.transaction(() async {
      // 1. Insertar transacción
      await into(transactions).insert(transaction);

      // 2. Obtener cuenta actual
      final account = await (select(accounts)..where((a) => a.id.equals(accountId))).getSingle();

      // 3. Actualizar balance
      final newBalance = isIncome ? account.balance + amount : account.balance - amount;
      await (update(accounts)..where((a) => a.id.equals(accountId))).write(
        AccountsCompanion(balance: Value(newBalance)),
      );
    });
  }

  /// Eliminar transacción y revertir saldo de la cuenta
  Future<void> deleteTransactionAndRevertBalance(Transaction tx) {
    return db.transaction(() async {
      // 1. Eliminar transacción
      await (delete(transactions)..where((t) => t.id.equals(tx.id))).go();

      // 2. Obtener cuenta actual
      final account = await (select(accounts)..where((a) => a.id.equals(tx.accountId))).getSingle();

      // 3. Revertir saldo (Si era gasto, sumamos; si era ingreso, restamos)
      final isIncome = tx.type == 'income';
      final revertedBalance = isIncome ? account.balance - tx.amount : account.balance + tx.amount;
      
      await (update(accounts)..where((a) => a.id.equals(tx.accountId))).write(
        AccountsCompanion(balance: Value(revertedBalance)),
      );
    });
  }
}
