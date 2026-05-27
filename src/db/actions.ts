import { database } from './index';
import { Account, Transaction, Category, Budget } from './models';
import { Q } from '@nozbe/watermelondb';

// ==========================================
// CENTRALIZED FINANCIAL LOGIC (WATERMELONDB)
// ==========================================

/**
 * Registra una nueva transacción y actualiza el balance de la cuenta automáticamente.
 * Todo ocurre dentro de un solo Batch (database.write) para garantizar consistencia.
 */
export async function createTransaction(data: {
  amount: number;
  type: 'INCOME' | 'EXPENSE' | 'TRANSFER';
  accountId: string;
  categoryId?: string;
  description: string;
}) {
  await database.write(async () => {
    // 1. Obtener la cuenta afectada
    const account = await database.get<Account>('accounts').find(data.accountId);
    
    // 2. Calcular el nuevo balance
    let newBalance = account.balance;
    if (data.type === 'EXPENSE') newBalance -= data.amount;
    if (data.type === 'INCOME') newBalance += data.amount;

    // 3. Crear el registro de la transacción y actualizar cuenta en lote
    await database.batch(
      // Actualizar la cuenta
      account.prepareUpdate((acc) => {
        acc.balance = newBalance;
      }),
      // Crear la transacción
      database.get<Transaction>('transactions').prepareCreate((tx) => {
        tx.amount = data.amount;
        tx.type = data.type;
        tx.accountId = data.accountId;
        tx.categoryId = data.categoryId || '';
        tx.description = data.description;
        tx.date = Date.now();
        tx.isRecurring = false;
      })
    );
  });
}

/**
 * Crea datos iniciales (Cuentas y Categorías por defecto) si la BD está vacía.
 */
export async function seedInitialData() {
  const accountsCount = await database.get('accounts').query().fetchCount();
  
  if (accountsCount === 0) {
    await database.write(async () => {
      await database.get<Account>('accounts').create((acc) => {
        acc.name = 'Efectivo Principal';
        acc.type = 'CASH';
        acc.balance = 0;
        acc.currency = 'DOP';
        acc.color = '#00D4AA';
      });
      await database.get<Account>('accounts').create((acc) => {
        acc.name = 'Cuenta Bancaria';
        acc.type = 'BANK';
        acc.balance = 50000;
        acc.currency = 'DOP';
        acc.color = '#1a1a2e';
      });
      await database.get<Category>('categories').create((cat) => {
        cat.name = 'Comida';
        cat.icon = 'Utensils';
        cat.color = '#FF6B6B';
        cat.type = 'EXPENSE';
        cat.isDefault = true;
      });
      // Crear Presupuesto Inicial (Ejemplo)
      await database.get<Budget>('budgets').create((b) => {
        b.name = 'Presupuesto General';
        b.amount = 30000;
        b.period = 'MONTHLY';
        b.rollover = true;
        b.status = 'ACTIVE';
      });
    });
  }
}

/**
 * Calcula las métricas avanzadas de un presupuesto usando las transacciones en SQLite.
 * Se separa de la UI para no saturar los componentes.
 */
export async function getBudgetAnalytics(budgetId: string) {
  const budget = await database.get<Budget>('budgets').find(budgetId);
  
  // Por ahora, traemos todas las transacciones de GASTO (EXPENSE) del mes actual
  // Para optimización real, usaríamos startOfMonth y endOfMonth en la query SQLite.
  const dateObj = new Date();
  const startOfMonth = new Date(dateObj.getFullYear(), dateObj.getMonth(), 1).getTime();
  
  const expenses = await database.get<Transaction>('transactions').query(
    Q.where('type', 'EXPENSE'),
    Q.where('date', Q.gte(startOfMonth))
  ).fetch();

  const totalSpent = expenses.reduce((sum, tx) => sum + tx.amount, 0);
  const remaining = budget.amount - totalSpent;
  const percentage = Math.min((totalSpent / budget.amount) * 100, 100);

  // Días en el mes
  const daysInMonth = new Date(dateObj.getFullYear(), dateObj.getMonth() + 1, 0).getDate();
  const currentDay = dateObj.getDate();
  const daysLeft = daysInMonth - currentDay;
  
  const dailyAverageAllowed = remaining > 0 ? remaining / daysLeft : 0;
  
  return {
    limit: budget.amount,
    spent: totalSpent,
    remaining,
    percentage,
    dailyAverageAllowed,
    daysLeft
  };
}
