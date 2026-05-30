import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/daos/transactions_dao.dart';
import '../database/daos/settings_dao.dart';
import '../database/daos/categories_dao.dart';
import '../database/daos/services_dao.dart';
import '../database/daos/goals_dao.dart';
import '../database/daos/accounts_dao.dart';

/// Proveedor global de la base de datos (Singleton)
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Proveedor del DAO de Transacciones
final transactionsDaoProvider = Provider<TransactionsDao>((ref) {
  final db = ref.watch(databaseProvider);
  return TransactionsDao(db);
});

/// Proveedor del DAO de Cuentas
final accountsDaoProvider = Provider<AccountsDao>((ref) {
  final db = ref.watch(databaseProvider);
  return AccountsDao(db);
});

final servicesDaoProvider = Provider<ServicesDao>((ref) {
  return ServicesDao(ref.watch(databaseProvider));
});

final goalsDaoProvider = Provider<GoalsDao>((ref) {
  return GoalsDao(ref.watch(databaseProvider));
});

final settingsDaoProvider = Provider<SettingsDao>((ref) {
  return SettingsDao(ref.watch(databaseProvider));
});

final categoriesDaoProvider = Provider<CategoriesDao>((ref) {
  return CategoriesDao(ref.watch(databaseProvider));
});

final activeAccountsProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(accountsDaoProvider).watchActiveAccounts();
});

final allCategoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoriesDaoProvider).watchAllCategories();
});
