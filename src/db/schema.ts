import { appSchema, tableSchema } from '@nozbe/watermelondb'

export const schema = appSchema({
  version: 1,
  tables: [
    tableSchema({
      name: 'users',
      columns: [
        { name: 'name', type: 'string' },
        { name: 'email', type: 'string', isOptional: true },
        { name: 'base_currency', type: 'string' },
        { name: 'theme', type: 'string' },
        { name: 'dashboard_layout', type: 'string', isOptional: true },
        { name: 'created_at', type: 'number' },
        { name: 'updated_at', type: 'number' },
      ],
    }),
    tableSchema({
      name: 'categories',
      columns: [
        { name: 'name', type: 'string' },
        { name: 'icon', type: 'string' },
        { name: 'color', type: 'string' },
        { name: 'type', type: 'string' }, // EXPENSE | INCOME
        { name: 'is_default', type: 'boolean' },
        { name: 'deleted_at', type: 'number', isOptional: true },
        { name: 'created_at', type: 'number' },
        { name: 'updated_at', type: 'number' },
      ],
    }),
    tableSchema({
      name: 'tags',
      columns: [
        { name: 'name', type: 'string' },
        { name: 'color', type: 'string' },
        { name: 'deleted_at', type: 'number', isOptional: true },
        { name: 'created_at', type: 'number' },
        { name: 'updated_at', type: 'number' },
      ],
    }),
    tableSchema({
      name: 'accounts', // Replaces 'cards', supports multiple types
      columns: [
        { name: 'name', type: 'string' },
        { name: 'type', type: 'string' }, // CASH, BANK, CREDIT_CARD, WALLET, INVESTMENT
        { name: 'balance', type: 'number' },
        { name: 'currency', type: 'string' },
        { name: 'color', type: 'string' },
        { name: 'credit_limit', type: 'number', isOptional: true },
        { name: 'cut_date', type: 'number', isOptional: true },
        { name: 'payment_date', type: 'number', isOptional: true },
        { name: 'deleted_at', type: 'number', isOptional: true },
        { name: 'created_at', type: 'number' },
        { name: 'updated_at', type: 'number' },
      ],
    }),
    tableSchema({
      name: 'transactions',
      columns: [
        { name: 'description', type: 'string' },
        { name: 'amount', type: 'number' },
        { name: 'type', type: 'string', isIndexed: true }, // INCOME | EXPENSE | TRANSFER
        { name: 'date', type: 'number', isIndexed: true },
        { name: 'category_id', type: 'string', isIndexed: true },
        { name: 'account_id', type: 'string', isIndexed: true },
        { name: 'destination_account_id', type: 'string', isOptional: true, isIndexed: true },
        { name: 'is_recurring', type: 'boolean' },
        { name: 'notes', type: 'string', isOptional: true }, // Encrypted field candidate
        { name: 'deleted_at', type: 'number', isOptional: true },
        { name: 'created_at', type: 'number' },
        { name: 'updated_at', type: 'number' },
      ],
    }),
    tableSchema({
      name: 'transaction_tags',
      columns: [
        { name: 'transaction_id', type: 'string', isIndexed: true },
        { name: 'tag_id', type: 'string', isIndexed: true },
      ],
    }),
    tableSchema({
      name: 'budgets',
      columns: [
        { name: 'name', type: 'string' },
        { name: 'amount', type: 'number' },
        { name: 'period', type: 'string' }, // MONTHLY, WEEKLY, CUSTOM
        { name: 'category_id', type: 'string', isOptional: true, isIndexed: true },
        { name: 'rollover', type: 'boolean' },
        { name: 'status', type: 'string' }, // ACTIVE, PAUSED
        { name: 'deleted_at', type: 'number', isOptional: true },
        { name: 'created_at', type: 'number' },
        { name: 'updated_at', type: 'number' },
      ],
    }),
  ],
})
