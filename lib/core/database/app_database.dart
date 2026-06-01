import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Categories,
  Accounts,
  Services,
  Transactions,
  Goals,
  Tags,
  TransactionTags,
  Attachments,
  Settings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await into(accounts).insert(AccountsCompanion.insert(
          id: 'efectivo-default',
          name: 'Efectivo',
          type: 'cash',
          color: const Value('#9E9E9E'),
        ));
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(categories);
          await m.addColumn(services, services.categoryId);
          await m.addColumn(transactions, transactions.categoryId);
        }
      },
      beforeOpen: (details) async {
        // Enforce foreign keys
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));

    // No Android workaround needed for API 34+


    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    return NativeDatabase.createInBackground(file);
  });
}
