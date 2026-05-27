import { Database } from '@nozbe/watermelondb'
import SQLiteAdapter from '@nozbe/watermelondb/adapters/sqlite'

import { schema } from './schema'
import { User, Account, Transaction, Category, Tag, Budget } from './models'

// 1. Adapter (SQLite)
// En Expo / React Native, Watermelon usa el adaptador JSI SQLite nativo de forma predeterminada
const adapter = new SQLiteAdapter({
  schema,
  // Opcional: configuraciones de migraciones o sincronización
  jsi: true, // Habilita el adaptador JSI ultra rápido (requiere custom dev client)
  onSetUpError: error => {
    console.error('Error inicializando base de datos local:', error)
  }
})

// 2. Base de Datos
export const database = new Database({
  adapter,
  modelClasses: [
    User,
    Category,
    Tag,
    Account,
    Transaction,
    Budget,
  ],
})
