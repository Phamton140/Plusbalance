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

const String efectivoDefaultAccountId = 'efectivo-default';
const String efectivoDefaultColor = '#9E9E9E';

const String alcanciaDefaultAccountId = 'alcancia-default';
const String alcanciaDefaultColor = '#E91E63';

const String transferenciaDefaultCategoryId = 'default-cat-transferencia';
const String transferenciaDefaultCategoryName = 'Transferencia';
const String transferenciaDefaultColor = '#FB8C00';

const List<String> defaultCategoryIds = [
  'default-cat-hogar',
  'default-cat-alimentos',
  'default-cat-salud',
  'default-cat-gym',
  'default-cat-transporte',
  'default-cat-viajes',
  'default-cat-compras',
  'default-cat-comunicacion',
  'default-cat-entretenimiento',
  goalDefaultCategoryId,
  transferenciaDefaultCategoryId,
];

class _DefaultCategory {
  final String id;
  final String name;
  final IconData icon;
  final String color;
  const _DefaultCategory(this.id, this.name, this.icon, this.color);
}

const List<_DefaultCategory> _defaultCategories = [
  _DefaultCategory('default-cat-hogar', 'Hogar', Icons.home, '#9D4EDD'),
  _DefaultCategory('default-cat-alimentos', 'Alimentos', Icons.restaurant, '#66BB6A'),
  _DefaultCategory('default-cat-salud', 'Salud', Icons.medical_services, '#4D96FF'),
  _DefaultCategory('default-cat-gym', 'Gym', Icons.fitness_center, '#FF6B9D'),
  _DefaultCategory('default-cat-transporte', 'Transporte', Icons.directions_bus, '#FF6B6B'),
  _DefaultCategory('default-cat-viajes', 'Viajes', Icons.flight, '#00BCD4'),
  _DefaultCategory('default-cat-compras', 'Compras', Icons.shopping_cart, '#5E35B1'),
  _DefaultCategory('default-cat-comunicacion', 'Comunicacion', Icons.phone, '#03A9F4'),
  _DefaultCategory('default-cat-entretenimiento', 'Entretenimiento', Icons.theater_comedy, '#FF5722'),
  _DefaultCategory(goalDefaultCategoryId, goalDefaultCategoryName, Icons.savings, goalDefaultCategoryColor),
  _DefaultCategory(transferenciaDefaultCategoryId, transferenciaDefaultCategoryName, Icons.sync_alt, transferenciaDefaultColor),
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
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await into(accounts).insert(AccountsCompanion.insert(
          id: efectivoDefaultAccountId,
          name: 'Efectivo',
          institutionName: const Value('Efectivo'),
          type: 'cash',
          color: const Value(efectivoDefaultColor),
        ));
        await into(accounts).insert(AccountsCompanion.insert(
          id: alcanciaDefaultAccountId,
          name: 'Alcancía',
          institutionName: const Value('Alcancía'),
          type: 'wallet',
          color: const Value(alcanciaDefaultColor),
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
        if (from < 7) {
          await _ensureDefaultCategories();
          await (update(accounts)
                ..where((a) => a.id.equals(efectivoDefaultAccountId)))
              .write(const AccountsCompanion(
            institutionName: Value('Efectivo'),
          ));
        }
        if (from < 8) {
          await _ensureDefaultCategories();
          // La cuenta efectivo siempre gris.
          await (update(accounts)
                ..where((a) => a.id.equals(efectivoDefaultAccountId)))
              .write(const AccountsCompanion(color: Value(efectivoDefaultColor)));
          // Reservar los colores de metas y transferencias para que ninguna
          // categoría de usuario pueda tomarlos; corregir también los colores
          // de categorías por defecto que quedaron duplicados.
          await (update(categories)
                ..where((c) => c.id.equals('default-cat-alimentos')))
              .write(const CategoriesCompanion(color: Value('#66BB6A')));
          await (update(categories)
                ..where((c) => c.id.equals('default-cat-compras')))
              .write(const CategoriesCompanion(color: Value('#5E35B1')));
          await (update(categories)
                ..where((c) => c.id.equals(transferenciaDefaultCategoryId)))
              .write(const CategoriesCompanion(color: Value(transferenciaDefaultColor)));
        }
        if (from < 9) {
          // Columnas para soportar el "revertir" del historial.
          await m.addColumn(transactions, transactions.transferGroupId);
          await m.addColumn(transactions, transactions.sourceType);
          // Transferencias existentes: agrupar pares por monto, tipo y
          // proximidad temporal para poder revertirlas correctamente. Esto
          // es una migración best-effort: si hay ambigüedad (dos
          // transferencias del mismo monto en la misma fecha), la primera
          // mitad se empareja con la segunda mitad.
          final allTransfers = await (select(transactions)
                ..where((t) => t.type.equals('transfer')))
              .get();
          // Emparejamos por (amount, fecha con segundos de tolerancia).
          final used = <String>{};
          for (final origin in allTransfers) {
            if (used.contains(origin.id)) continue;
            // Buscar contraparte: mismo monto, distinta cuenta, fecha
            // dentro de 60s, no usada.
            final matches = allTransfers.where((t) {
              if (used.contains(t.id)) return false;
              if (t.id == origin.id) return false;
              if (t.amount != origin.amount) return false;
              if (t.accountId == origin.accountId) return false;
              final diff = t.date.difference(origin.date).inSeconds.abs();
              return diff <= 60;
            }).toList();
            if (matches.isNotEmpty) {
              final groupId = 'tg-${origin.id}';
              final pair = matches.first;
              used.add(origin.id);
              used.add(pair.id);
              await (update(transactions)
                    ..where((t) => t.id.equals(origin.id)))
                  .write(TransactionsCompanion(
                transferGroupId: Value(groupId),
                sourceType: const Value('transfer'),
              ));
              await (update(transactions)
                    ..where((t) => t.id.equals(pair.id)))
                  .write(TransactionsCompanion(
                transferGroupId: Value(groupId),
                sourceType: const Value('transfer'),
              ));
            }
          }
          // Las transacciones que no tengan transferGroupId (incluyendo
          // gastos, ingresos, pagos de servicios y abonos a metas) reciben
          // sourceType a partir del heurístico: si tienen serviceId es
          // 'service', si la categoría es Metas es 'goal', si no 'manual'.
          final withServiceId = await (select(transactions)
                ..where((t) => t.serviceId.isNotNull()))
              .get();
          for (final tx in withServiceId) {
            await (update(transactions)..where((t) => t.id.equals(tx.id)))
                .write(const TransactionsCompanion(sourceType: Value('service')));
          }
          final goalTxs = await (select(transactions)
                ..where((t) => t.categoryId.equals(goalDefaultCategoryId)))
              .get();
          for (final tx in goalTxs) {
            if (withServiceId.any((s) => s.id == tx.id)) continue;
            await (update(transactions)..where((t) => t.id.equals(tx.id)))
                .write(const TransactionsCompanion(sourceType: Value('goal')));
          }
        }
        if (from < 10) {
          // Add endDate to Services for recurrence end date
          await m.addColumn(services, services.endDate);
          // Add alcanciaId to Goals
          await m.addColumn(goals, goals.alcanciaId);
          // Create alcancia default account if not exists
          final alcanciaExists = await (select(accounts)..where((a) => a.id.equals(alcanciaDefaultAccountId))).getSingleOrNull();
          if (alcanciaExists == null) {
            await into(accounts).insert(AccountsCompanion.insert(
              id: alcanciaDefaultAccountId,
              name: 'Alcancía',
              institutionName: const Value('Alcancía'),
              type: 'wallet',
              color: const Value(alcanciaDefaultColor),
            ));
          }
          // Add new default categories
          await _ensureDefaultCategories();
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
