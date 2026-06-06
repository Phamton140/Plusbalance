import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../app_database.dart';
import '../tables.dart';

part 'goals_dao.g.dart';

@DriftAccessor(tables: [Goals, Categories, Transactions, Accounts])
class GoalsDao extends DatabaseAccessor<AppDatabase> with _$GoalsDaoMixin {
  GoalsDao(super.db);

  Stream<List<Goal>> watchActiveGoals() {
    return (select(goals)..where((g) => g.status.equals('active'))).watch();
  }

  Future<int> createGoal(Insertable<Goal> goal) {
    return into(goals).insert(goal);
  }

  Future<bool> updateGoalAmount(String goalId, double addAmount) async {
    final goal = await (select(goals)..where((g) => g.id.equals(goalId))).getSingle();
    return update(goals).replace(
      goal.copyWith(currentAmount: goal.currentAmount + addAmount)
    );
  }

  Future<bool> updateGoal(Insertable<Goal> goal) {
    return update(goals).replace(goal);
  }

  /// Realiza un abono a una meta: registra una transacción tipo "expense"
  /// en la categoría por defecto de metas, debita el monto de la cuenta
  /// seleccionada y suma al progreso de la meta, todo en una sola
  /// transacción de base de datos.
  ///
  /// Lanza [StateError] si la cuenta no tiene saldo suficiente.
  Future<void> addFundsToGoal({
    required String goalId,
    required String accountId,
    required double amount,
  }) async {
    await db.transaction(() async {
      final account = await (select(accounts)
            ..where((a) => a.id.equals(accountId)))
          .getSingle();

      if (account.balance < amount) {
        throw StateError('Saldo insuficiente en ${account.name}');
      }

      final goal = await (select(goals)..where((g) => g.id.equals(goalId)))
          .getSingle();

      // 1. Insertar transacción de gasto vinculada a la categoría por defecto
      await into(transactions).insert(
        TransactionsCompanion.insert(
          id: const Uuid().v4(),
          amount: amount,
          date: DateTime.now(),
          type: 'expense',
          accountId: accountId,
          categoryId: const Value(goalDefaultCategoryId),
          description: Value('Abono a meta: ${goal.name}'),
          sourceType: const Value('goal'),
        ),
      );

      // 2. Debitar el saldo de la cuenta
      await (update(accounts)..where((a) => a.id.equals(accountId))).write(
        AccountsCompanion(balance: Value(account.balance - amount)),
      );

      // 3. Sumar al progreso de la meta
      await update(goals).replace(
        goal.copyWith(currentAmount: goal.currentAmount + amount),
      );
    });
  }

  /// Revierte un abono a meta: devuelve el monto a la cuenta, resta del
  /// progreso de la meta y elimina la transacción vinculada. Lanza
  /// [StateError] si la cuenta no tiene saldo suficiente.
  Future<void> reverseGoalContribution({
    required String transactionId,
  }) async {
    await db.transaction(() async {
      final tx = await (select(transactions)
            ..where((t) => t.id.equals(transactionId)))
          .getSingleOrNull();
      if (tx == null) {
        throw StateError('Este abono ya no existe.');
      }
      final account = await (select(accounts)
            ..where((a) => a.id.equals(tx.accountId)))
          .getSingle();
      final goalName = (tx.description ?? '')
          .replaceFirst('Abono a meta: ', '');
      final goal = await (select(goals)
            ..where((g) => g.name.equals(goalName)))
            .getSingleOrNull();

      // Devolver al saldo y restar del progreso.
      await (update(accounts)..where((a) => a.id.equals(account.id))).write(
        AccountsCompanion(balance: Value(account.balance + tx.amount)),
      );
      if (goal != null) {
        final newAmount = (goal.currentAmount - tx.amount).clamp(0.0, double.infinity);
        await update(goals).replace(goal.copyWith(currentAmount: newAmount));
      }
      // Borrar la transacción.
      await (delete(transactions)..where((t) => t.id.equals(tx.id))).go();
    });
  }
}
