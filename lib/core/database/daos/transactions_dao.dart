import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
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

  /// Aplica el pago de un servicio por adelantado o al día de hoy:
  /// crea la transacción de gasto en la cuenta indicada, debita el saldo
  /// y avanza `nextDate` del servicio al siguiente ciclo según la
  /// frecuencia. Lanza [StateError] si la cuenta no tiene saldo
  /// suficiente o si el servicio no tiene cuenta asociada.
  Future<void> applyServicePayment(Service service) {
    return db.transaction(() async {
      if (service.accountId == null) {
        throw StateError('Este servicio no tiene una cuenta asociada.');
      }
      final account = await (select(accounts)
            ..where((a) => a.id.equals(service.accountId!)))
          .getSingle();
      if (service.type == 'expense' && account.balance < service.amount) {
        throw StateError(
            'Saldo insuficiente en la cuenta ${account.name}.');
      }

      // 1. Insertar transacción de gasto (o ingreso si el servicio es income)
      final isIncome = service.type == 'income';
      final txType = isIncome ? 'income' : 'expense';
      await into(transactions).insert(
        TransactionsCompanion.insert(
          id: const Uuid().v4(),
          amount: service.amount,
          date: DateTime.now(),
          description: Value<String?>(
              'Pago aplicado: ${service.name}${service.label != null && service.label != 'none' ? ' (${service.label})' : ''}'),
          type: txType,
          accountId: service.accountId!,
          categoryId: Value<String?>(service.categoryId),
          serviceId: Value<String?>(service.id),
        ),
      );

      // 2. Actualizar balance de la cuenta
      final newBalance =
          isIncome ? account.balance + service.amount : account.balance - service.amount;
      await (update(accounts)..where((a) => a.id.equals(account.id))).write(
        AccountsCompanion(balance: Value(newBalance)),
      );

      // 3. Avanzar nextDate al siguiente ciclo
      final next = _nextOccurrence(service.nextDate, service.frequency);
      await (update(services)..where((s) => s.id.equals(service.id))).write(
        ServicesCompanion(
          nextDate: Value(next),
          status: const Value('active'),
        ),
      );
    });
  }

  /// Registra la recepción de una recarga esperada en una cuenta.
  /// Crea una transacción de ingreso por [amount] y avanza
  /// `rechargeNextDate` (o `rechargeNextDate2` si [installment]==2)
  /// al siguiente ciclo según `rechargeFrequency`.
  Future<void> applyAccountRecharge({
    required Account account,
    required double amount,
    required int installment,
  }) {
    return db.transaction(() async {
      // 1. Insertar transacción de ingreso
      await into(transactions).insert(
        TransactionsCompanion.insert(
          id: const Uuid().v4(),
          amount: amount,
          date: DateTime.now(),
          description: Value<String?>(
              'Recarga aplicada: ${account.rechargeLabel ?? account.name}'),
          type: 'income',
          accountId: account.id,
        ),
      );

      // 2. Sumar al balance
      final newBalance = account.balance + amount;
      await (update(accounts)..where((a) => a.id.equals(account.id))).write(
        AccountsCompanion(balance: Value(newBalance)),
      );

      // 3. Avanzar la fecha correspondiente
      final freq = account.rechargeFrequency ?? 'none';
      if (freq == 'none') return;
      final current = installment == 2
          ? account.rechargeNextDate2
          : account.rechargeNextDate;
      if (current == null) return;
      final next = _nextOccurrence(current, _mapRechargeFreq(freq));
      if (installment == 2) {
        await (update(accounts)..where((a) => a.id.equals(account.id))).write(
          AccountsCompanion(rechargeNextDate2: Value(next)),
        );
      } else {
        await (update(accounts)..where((a) => a.id.equals(account.id))).write(
          AccountsCompanion(rechargeNextDate: Value(next)),
        );
      }
    });
  }
}

DateTime _nextOccurrence(DateTime from, String frequency) {
  switch (frequency) {
    case 'weekly':
      return DateTime(from.year, from.month, from.day + 7);
    case 'biweekly':
      return DateTime(from.year, from.month, from.day + 14);
    case 'monthly':
      return DateTime(from.year, from.month + 1, from.day);
    case 'yearly':
      return DateTime(from.year + 1, from.month, from.day);
    default:
      // 'once' o desconocido: desactivar empujando 1 año al futuro
      return DateTime(from.year + 1, from.month, from.day);
  }
}

String _mapRechargeFreq(String f) {
  switch (f) {
    case 'weekly':
      return 'weekly';
    case 'biweekly':
      return 'biweekly';
    case 'monthly':
      return 'monthly';
    default:
      return 'monthly';
  }
}
