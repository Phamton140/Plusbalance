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
    return (select(accounts)..where((a) => a.id.equals(alcanciaDefaultAccountId)))
        .getSingle();
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
    return watchActiveGoals().map((goals) {
      return goals.where((g) => g.targetAmount <= g.currentAmount).toList();
    });
  }

  Future<bool> isGoalCompletable(String goalId) async {
    final goal = await (select(goals)..where((g) => g.id.equals(goalId))).getSingle();
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
          .getSingle();

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
          .getSingle();

      if (goal.status != 'active') {
        throw StateError('Esta meta ya no está activa');
      }

      final balance = await getAlcanciaBalance();
      if (balance < goal.targetAmount) {
        throw StateError('Saldo insuficiente en Alcancía');
      }

      final alcancia = await getAlcanciaAccount();

      await into(transactions).insert(
        TransactionsCompanion.insert(
          id: const Uuid().v4(),
          amount: goal.targetAmount,
          date: DateTime.now(),
          type: 'expense',
          accountId: alcanciaDefaultAccountId,
          categoryId: const Value(goalDefaultCategoryId),
          description: Value('Meta completada: ${goal.name}'),
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

      await (delete(transactions)..where((t) => t.id.equals(tx.id))).go();
    });
  }
}