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

  /// Revierte completamente una transacción desde el historial.
  ///
  /// Comportamiento por tipo:
  /// - 'expense' (manual o 'goal'): devuelve el monto a la cuenta y borra.
  /// - 'income' (manual): descuenta el monto de la cuenta y borra.
  /// - 'service'/'expense': devuelve el monto, retrocede `nextDate` un
  ///   ciclo y borra.
  /// - 'service'/'income': descuenta el monto, retrocede `nextDate` un
  ///   ciclo y borra.
  /// - 'recharge'/'income': descuenta el monto, retrocede
  ///   `rechargeNextDate` (o `rechargeNextDate2`) un ciclo y borra.
  /// - 'transfer': identifica la contraparte por `transferGroupId`,
  ///   devuelve al origen, descuenta del destino, y borra ambas.
  ///
  /// Lanza [StateError] si la transacción ya no existe o si revertirla
  /// dejaría un balance negativo en alguna cuenta.
  Future<void> reverseTransaction(Transaction tx) {
    return db.transaction(() async {
      // Releer la tx dentro de la transacción para evitar race conditions.
      final fresh = await (select(transactions)..where((t) => t.id.equals(tx.id)))
          .getSingleOrNull();
      if (fresh == null) {
        throw StateError('Esta transacción ya no existe.');
      }

      final source = fresh.sourceType ?? 'manual';

      if (fresh.type == 'transfer') {
        await _reverseTransfer(fresh);
        return;
      }

      // Para 'expense' sumamos al balance, para 'income' restamos.
      final isExpense = fresh.type == 'expense';
      final account = await (select(accounts)
            ..where((a) => a.id.equals(fresh.accountId)))
          .getSingle();
      if (!isExpense) {
        if (account.balance < fresh.amount) {
          throw StateError(
              'No se puede revertir: la cuenta "${account.name}" no tiene saldo suficiente para devolver el ingreso. Saldo actual: \$${account.balance.toStringAsFixed(2)}, monto a restar: \$${fresh.amount.toStringAsFixed(2)}.');
        }
      }
      final newBalance = isExpense
          ? account.balance + fresh.amount
          : account.balance - fresh.amount;
      await (update(accounts)..where((a) => a.id.equals(account.id)))
          .write(AccountsCompanion(balance: Value(newBalance)));

      // Rollback de fechas para pagos de servicio y recargas.
      if (source == 'service' && fresh.serviceId != null) {
        final svc = await (select(services)
              ..where((s) => s.id.equals(fresh.serviceId!)))
            .getSingleOrNull();
        if (svc != null) {
          final prev = _previousOccurrence(svc.nextDate, svc.frequency);
          await (update(services)..where((s) => s.id.equals(svc.id)))
              .write(ServicesCompanion(
            nextDate: Value(prev),
            status: const Value('active'),
          ));
        }
      } else if (source == 'recharge') {
        // Determinar installment 1 o 2 a partir de la descripción o
        // comparando con rechargeNextDate / rechargeNextDate2.
        final isInstallment2 = fresh.description != null &&
            fresh.description!.contains('(2da)');
        final fieldCurrent = isInstallment2
            ? account.rechargeNextDate2
            : account.rechargeNextDate;
        if (account.rechargeFrequency != null &&
            account.rechargeFrequency != 'none' &&
            fieldCurrent != null) {
          final prev = _previousOccurrence(
              fieldCurrent, _mapRechargeFreq(account.rechargeFrequency!));
          if (isInstallment2) {
            await (update(accounts)..where((a) => a.id.equals(account.id)))
                .write(AccountsCompanion(rechargeNextDate2: Value(prev)));
          } else {
            await (update(accounts)..where((a) => a.id.equals(account.id)))
                .write(AccountsCompanion(rechargeNextDate: Value(prev)));
          }
        }
      }

      // Borrar la transacción.
      await (delete(transactions)..where((t) => t.id.equals(fresh.id))).go();
    });
  }

  /// Revierte una transferencia: ambas transacciones (origen y destino)
  /// agrupadas por `transferGroupId`. Devuelve al origen, descuenta del
  /// destino, borra las dos.
  Future<void> _reverseTransfer(Transaction fresh) async {
    final groupId = fresh.transferGroupId;
    if (groupId == null) {
      // Migración antigua: pareja heurística por monto/fecha no es
      // 100% segura. Pedimos al usuario que use la contraparte.
      throw StateError(
          'Esta transferencia es anterior a la versión que soporta reversa individual. Elimínala manualmente desde ambas cuentas.');
    }
    final pair = await (select(transactions)
          ..where((t) =>
              t.transferGroupId.equals(groupId) & t.id.equals(fresh.id).not()))
        .get();
    if (pair.isEmpty) {
      throw StateError('No se encontró la transacción de contrapartida.');
    }
    final counterpart = pair.first;

    final origin = await (select(accounts)
          ..where((a) => a.id.equals(fresh.accountId)))
        .getSingle();
    final destination = await (select(accounts)
          ..where((a) => a.id.equals(counterpart.accountId)))
        .getSingle();

    // Saldo destino debe poder devolver lo recibido.
    if (destination.balance < fresh.amount) {
      throw StateError(
          'No se puede revertir: la cuenta destino "${destination.name}" no tiene saldo suficiente. Saldo actual: \$${destination.balance.toStringAsFixed(2)}, monto a devolver: \$${fresh.amount.toStringAsFixed(2)}.');
    }

    // Devolver al origen.
    await (update(accounts)..where((a) => a.id.equals(origin.id))).write(
      AccountsCompanion(
          balance: Value(origin.balance + fresh.amount)),
    );
    // Descontar del destino.
    await (update(accounts)..where((a) => a.id.equals(destination.id))).write(
      AccountsCompanion(
          balance: Value(destination.balance - fresh.amount)),
    );
    // Borrar ambas.
    await (delete(transactions)
          ..where((t) => t.transferGroupId.equals(groupId)))
        .go();
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
          sourceType: const Value('service'),
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
      final label = account.rechargeLabel ?? account.name;
      final desc = installment == 2
          ? 'Recarga aplicada (2da): $label'
          : 'Recarga aplicada (1ra): $label';
      await into(transactions).insert(
        TransactionsCompanion.insert(
          id: const Uuid().v4(),
          amount: amount,
          date: DateTime.now(),
          description: Value<String?>(desc),
          type: 'income',
          accountId: account.id,
          sourceType: const Value('recharge'),
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

DateTime _previousOccurrence(DateTime from, String frequency) {
  switch (frequency) {
    case 'weekly':
      return DateTime(from.year, from.month, from.day - 7);
    case 'biweekly':
      return DateTime(from.year, from.month, from.day - 14);
    case 'monthly':
      // Restar un mes: si el día no existe en el mes anterior, se
      // hace clamp al último día de ese mes (DateTime constructor lo
      // hace automáticamente).
      return DateTime(from.year, from.month - 1, from.day);
    case 'yearly':
      return DateTime(from.year - 1, from.month, from.day);
    default:
      // 'once' o desconocido: retroceder 1 año.
      return DateTime(from.year - 1, from.month, from.day);
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
