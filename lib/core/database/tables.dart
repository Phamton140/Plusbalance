import 'package:drift/drift.dart';

// Mixin for auditing
mixin AuditMixin on Table {
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Accounts extends Table with AuditMixin {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // cash, bank, credit, wallet
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  TextColumn get color => text().withDefault(const Constant('#6C63FF'))();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  TextColumn get institutionName => text().nullable()();
  RealColumn get creditLimit => real().nullable()();
  IntColumn get cutDay => integer().nullable()();
  IntColumn get paymentDay => integer().nullable()();
  RealColumn get interestRate => real().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  // --- Recurrencia de recarga (opcional) ---
  // Frecuencia con la que se acredita dinero a la cuenta
  // (ej. salario, mesada, renta). null o 'none' = sin recurrencia.
  // Valores: 'none', 'weekly', 'biweekly', 'monthly'.
  TextColumn get rechargeFrequency => text().nullable()();
  // Próxima fecha esperada de la recarga. Si se omite se calcula
  // automáticamente a partir de la frecuencia.
  DateTimeColumn get rechargeNextDate => dateTime().nullable()();
  // Monto esperado (opcional, sólo informativo).
  RealColumn get rechargeAmount => real().nullable()();
  // Etiqueta o concepto (opcional, ej. "Salario", "Mesada").
  TextColumn get rechargeLabel => text().nullable()();

  // --- Segunda recarga (usada sólo cuando frequency = 'biweekly') ---
  // Fecha de la segunda acreditación del mes.
  DateTimeColumn get rechargeNextDate2 => dateTime().nullable()();
  // Monto esperado de la segunda recarga (opcional, sólo informativo).
  RealColumn get rechargeAmount2 => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table with AuditMixin {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get color => text().withDefault(const Constant('#6C63FF'))();
  TextColumn get icon => text().withDefault(const Constant('57680'))(); // category icon

  @override
  Set<Column> get primaryKey => {id};
}

class Services extends Table with AuditMixin {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get amount => real()();
  TextColumn get type => text().withDefault(const Constant('expense'))(); // income, expense
  TextColumn get label => text().withDefault(const Constant('none'))(); // want, need, none
  TextColumn get frequency => text()(); // once, weekly, monthly, yearly
  DateTimeColumn get nextDate => dateTime()();
  TextColumn get accountId => text().nullable().references(Accounts, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  IntColumn get reminderDaysBefore => integer().withDefault(const Constant(3))();
  BoolColumn get autoGenerateTransaction => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get icon => text().withDefault(const Constant('57680'))(); // default icon code
  TextColumn get color => text().withDefault(const Constant('#6C63FF'))();
  TextColumn get status => text().withDefault(const Constant('active'))(); // active, late

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_tx_date', columns: {#date})
@TableIndex(name: 'idx_tx_account', columns: {#accountId})
@TableIndex(name: 'idx_tx_service', columns: {#serviceId})
@TableIndex(name: 'idx_tx_type', columns: {#type})
@TableIndex(name: 'idx_tx_group', columns: {#transferGroupId})
class Transactions extends Table with AuditMixin {
  TextColumn get id => text()();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get description => text().nullable()();
  TextColumn get type => text()(); // income, expense, transfer
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get serviceId => text().nullable().references(Services, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get transactionNumber => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  RealColumn get exchangeRate => real().withDefault(const Constant(1.0))();
  IntColumn get attachmentCount => integer().withDefault(const Constant(0))();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();

  /// Identificador compartido por las dos transacciones que forman una
  /// transferencia (una en cuenta origen, una en cuenta destino).
  /// Es null para gastos, ingresos, pagos de servicios y abonos a metas.
  TextColumn get transferGroupId => text().nullable()();

  /// Origen lógico de la transacción. Útil para revertir efectos
  /// colaterales (avance de fechas en servicios / recargas) y para
  /// agrupar mejor en el historial.
  /// Valores: 'manual', 'service', 'recharge', 'goal', 'transfer'.
  TextColumn get sourceType => text().withDefault(const Constant('manual'))();

  @override
  Set<Column> get primaryKey => {id};
}

class Goals extends Table with AuditMixin {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get targetAmount => real()();
  RealColumn get currentAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get icon => text().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  TextColumn get color => text().withDefault(const Constant('#00D4AA'))();
  TextColumn get status => text().withDefault(const Constant('active'))();

  @override
  Set<Column> get primaryKey => {id};
}

class Tags extends Table with AuditMixin {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get color => text().withDefault(const Constant('#6C63FF'))();

  @override
  Set<Column> get primaryKey => {id};
}

class TransactionTags extends Table {
  TextColumn get transactionId => text().references(Transactions, #id)();
  TextColumn get tagId => text().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {transactionId, tagId};
}

class Attachments extends Table with AuditMixin {
  TextColumn get id => text()();
  TextColumn get transactionId => text().references(Transactions, #id)();
  TextColumn get filePath => text()();
  TextColumn get type => text()(); // image, pdf, receipt

  @override
  Set<Column> get primaryKey => {id};
}

class Settings extends Table with AuditMixin {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
