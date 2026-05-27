import { Model } from '@nozbe/watermelondb'
import { field, date, relation, children } from '@nozbe/watermelondb/decorators'

export class User extends Model {
  static table = 'users'
  @field('name') name!: string
  @field('email') email!: string
  @field('base_currency') baseCurrency!: string
  @field('theme') theme!: string
  @field('dashboard_layout') dashboardLayout!: string
  @date('created_at') createdAt!: number
  @date('updated_at') updatedAt!: number
}

export class Category extends Model {
  static table = 'categories'
  @field('name') name!: string
  @field('icon') icon!: string
  @field('color') color!: string
  @field('type') type!: string // EXPENSE | INCOME
  @field('is_default') isDefault!: boolean
  @date('deleted_at') deletedAt?: number
  @date('created_at') createdAt!: number
  @date('updated_at') updatedAt!: number
  
  // Relations
  @children('transactions') transactions!: any
}

export class Tag extends Model {
  static table = 'tags'
  @field('name') name!: string
  @field('color') color!: string
  @date('deleted_at') deletedAt?: number
  @date('created_at') createdAt!: number
  @date('updated_at') updatedAt!: number
}

export class Account extends Model {
  static table = 'accounts'
  @field('name') name!: string
  @field('type') type!: string
  @field('balance') balance!: number
  @field('currency') currency!: string
  @field('color') color!: string
  @field('credit_limit') creditLimit?: number
  @field('cut_date') cutDate?: number
  @field('payment_date') paymentDate?: number
  @date('deleted_at') deletedAt?: number
  @date('created_at') createdAt!: number
  @date('updated_at') updatedAt!: number

  @children('transactions') transactions!: any
}

export class Transaction extends Model {
  static table = 'transactions'
  @field('description') description!: string
  @field('amount') amount!: number
  @field('type') type!: string
  @date('date') date!: number
  @field('category_id') categoryId!: string
  @field('account_id') accountId!: string
  @field('destination_account_id') destinationAccountId?: string
  @field('is_recurring') isRecurring!: boolean
  @field('notes') notes?: string
  @date('deleted_at') deletedAt?: number
  @date('created_at') createdAt!: number
  @date('updated_at') updatedAt!: number

  @relation('categories', 'category_id') category!: any
  @relation('accounts', 'account_id') account!: any
}

export class Budget extends Model {
  static table = 'budgets'
  @field('name') name!: string
  @field('amount') amount!: number
  @field('period') period!: string
  @field('category_id') categoryId?: string
  @field('rollover') rollover!: boolean
  @field('status') status!: string
  @date('deleted_at') deletedAt?: number
  @date('created_at') createdAt!: number
  @date('updated_at') updatedAt!: number

  @relation('categories', 'category_id') category!: any
}
