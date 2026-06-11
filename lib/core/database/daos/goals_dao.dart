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

  Future<bool> updateGoal(Insertable<Goal> goal) {
    return update(goals).replace(goal);
  }

  Future<Account> getAlcanciaAccount() async {
    final result = await (select(accounts)..where((a) => a.id.equals(alcanciaDefaultAccountId)))
        .getSingleOrNull();
    if (result == null) {
      throw StateError('Cuenta Alcancía no encontrada. Verifica que exista en la base de datos.');
    }
    return result;
  }

  Stream<Account> watchAlcanciaBalance() {
    return (select(accounts)..where((a) => a.id.equals(alcanciaDefaultAccountId)))
        .watchSingle();
  }

  Future<double> getAlcanciaBalance() async {
    final alcancia = await getAlcanciaAccount();
    return alcancia.balance;
  }

  Stream<List<Goal>> watchCompletableGoals() {
    return watchActiveGoals().asyncMap((goals) async {
      final balance = await getAlcanciaBalance();
      return goals.where((g) => g.targetAmount <= balance).toList();
    });
  }

  Future<bool> isGoalCompletable(String goalId) async {
    final goal = await (select(goals)..where((g) => g.id.equals(goalId))).getSingleOrNull();
    if (goal == null) return false;
    final balance = await getAlcanciaBalance();
    return balance >= goal.targetAmount;
  }

  Future<void> addFundsToAlcancia({
    required String fromAccountId,
    required double amount,
  }) async {
    await db.transaction(() async {
      final fromAccount = await (select(accounts)
            ..where((a) => a.id.equals(fromAccountId)))
          .getSingleOrNull();

      if (fromAccount == null) {
        throw StateError('Cuenta de origen no encontrada');
      }

      if (fromAccount.balance < amount) {
        throw StateError('Saldo insuficiente en ${fromAccount.name}');
      }

      final alcancia = await getAlcanciaAccount();

      await into(transactions).insert(
        TransactionsCompanion.insert(
          id: const Uuid().v4(),
          amount: amount,
          date: DateTime.now(),
          type: 'transfer',
          accountId: fromAccountId,
          categoryId: const Value(transferenciaDefaultCategoryId),
          description: const Value('Transferencia a Alcancía'),
          sourceType: const Value('transfer'),
        ),
      );

      await (update(accounts)..where((a) => a.id.equals(fromAccountId))).write(
        AccountsCompanion(balance: Value(fromAccount.balance - amount)),
      );

      await (update(accounts)..where((a) => a.id.equals(alcanciaDefaultAccountId))).write(
        AccountsCompanion(balance: Value(alcancia.balance + amount)),
      );
    });
  }

  Future<void> completeGoal({
    required String goalId,
  }) async {
    await db.transaction(() async {
      final goal = await (select(goals)..where((g) => g.id.equals(goalId)))
          .getSingleOrNull();

      if (goal == null) {
        throw StateError('Meta no encontrada');
      }

      if (goal.status != 'active') {
        throw StateError('Esta meta ya no está activa');
      }

      final alcancia = await getAlcanciaAccount();
      if (alcancia.balance < goal.targetAmount) {
        throw StateError('Saldo insuficiente en Alcancía');
      }

      await into(transactions).insert(
        TransactionsCompanion.insert(
          id: const Uuid().v4(),
          amount: goal.targetAmount,
          date: DateTime.now(),
          type: 'expense',
          accountId: alcanciaDefaultAccountId,
          categoryId: const Value(goalDefaultCategoryId),
          description: Value(goal.name),
          sourceType: const Value('goal'),
        ),
      );

      await (update(accounts)..where((a) => a.id.equals(alcanciaDefaultAccountId))).write(
        AccountsCompanion(balance: Value(alcancia.balance - goal.targetAmount)),
      );

      await update(goals).replace(
        goal.copyWith(
          currentAmount: goal.targetAmount,
          status: 'completed',
          updatedAt: DateTime.now(),
        ),
      );
    });
  }

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

      await (update(accounts)..where((a) => a.id.equals(account.id))).write(
        AccountsCompanion(balance: Value(account.balance + tx.amount)),
      );

      final goalName = tx.description ?? '';
      final isGoalCompletion = tx.sourceType == 'goal' || goalName.startsWith('Meta completada:');
      if (isGoalCompletion) {
        final actualGoalName = goalName.startsWith('Meta completada:')
            ? goalName.replaceFirst('Meta completada: ', '')
            : goalName;
        final goal = await (select(goals)..where((g) => g.name.equals(actualGoalName))).getSingleOrNull();
        if (goal != null) {
          await update(goals).replace(
            goal.copyWith(
              status: 'active',
              updatedAt: DateTime.now(),
            ),
          );
        }
      }

      await (delete(transactions)..where((t) => t.id.equals(tx.id))).go();
    });
  }
}