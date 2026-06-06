import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show Icons, IconData;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'tables.dart';

part 'app_database.g.dart';

const String goalDefaultCategoryId = 'goal-default-category';
const String goalDefaultCategoryName = 'Ahorro / Metas';
const String goalDefaultCategoryColor = '#00D4AA';

class _DefaultCategory {
  final String id;
  final String name;
  final IconData icon;
  final String color;
  const _DefaultCategory(this.id, this.name, this.icon, this.color);
}

const List<_DefaultCategory> _defaultCategories = [
  _DefaultCategory('default-cat-hogar', 'Hogar', Icons.home, '#9D4EDD'),
  _DefaultCategory('default-cat-alimentos', 'Alimentos', Icons.restaurant, '#00D4AA'),
  _DefaultCategory('default-cat-salud', 'Salud', Icons.medical_services, '#4D96FF'),
  _DefaultCategory('default-cat-gym', 'Gym', Icons.fitness_center, '#FF6B9D'),
  _DefaultCategory('default-cat-transporte', 'Transporte', Icons.directions_bus, '#FF6B6B'),
  _DefaultCategory('default-cat-viajes', 'Viajes', Icons.flight, '#00BCD4'),
  _DefaultCategory('default-cat-compras', 'Compras', Icons.shopping_cart, '#6C63FF'),
  _DefaultCategory(goalDefaultCategoryId, goalDefaultCategoryName, Icons.savings, goalDefaultCategoryColor),
];

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
  int get schemaVersion => 6;

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
        await _ensureDefaultCategories();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(categories);
          await m.addColumn(services, services.categoryId);
          await m.addColumn(transactions, transactions.categoryId);
        }
        if (from < 3) {
          await m.addColumn(services, services.status);
        }
        if (from < 4) {
          await _ensureDefaultCategories();
        }
        if (from < 5) {
          await m.addColumn(accounts, accounts.rechargeFrequency);
          await m.addColumn(accounts, accounts.rechargeNextDate);
          await m.addColumn(accounts, accounts.rechargeAmount);
          await m.addColumn(accounts, accounts.rechargeLabel);
        }
        if (from < 6) {
          await m.addColumn(accounts, accounts.rechargeNextDate2);
          await m.addColumn(accounts, accounts.rechargeAmount2);
        }
      },
      beforeOpen: (details) async {
        // Enforce foreign keys
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _ensureDefaultCategories() async {
    for (final c in _defaultCategories) {
      final existing = await (select(categories)
            ..where((cat) => cat.id.equals(c.id)))
          .getSingleOrNull();
      if (existing != null) continue;
      await into(categories).insert(
        CategoriesCompanion.insert(
          id: c.id,
          name: c.name,
          color: Value(c.color),
          icon: Value(c.icon.codePoint.toString()),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
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
