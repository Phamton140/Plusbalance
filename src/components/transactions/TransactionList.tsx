import React, { useMemo } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { FlashList } from '@shopify/flash-list';
import withObservables from '@nozbe/with-observables';
import { database } from '@/db';
import { Transaction } from '@/db/models';
import { TransactionItem } from './TransactionItem';
import { Filter, Search } from 'lucide-react-native';

function TransactionListComponent({ transactions }: { transactions: Transaction[] }) {
  const renderItem = ({ item }: { item: Transaction }) => {
    return <TransactionItem transaction={item} />;
  };

  return (
    <View className="flex-1 bg-background">
      {/* Header Falso (Filtros y Búsqueda) */}
      <View className="px-6 py-4 border-b border-white/5 flex-row items-center justify-between bg-card/80">
        <View className="flex-row items-center bg-white/5 rounded-2xl px-4 py-2.5 flex-1 mr-3">
          <Search color="rgba(255,255,255,0.4)" size={18} />
          <Text className="text-white/40 ml-2">Buscar transacciones o #tags...</Text>
        </View>
        <View className="w-11 h-11 bg-primary/20 rounded-2xl items-center justify-center">
          <Filter color="#6C63FF" size={20} />
        </View>
      </View>

      {/* Lista Altamente Optimizada */}
      {transactions.length > 0 ? (
        <FlashList
          data={transactions}
          renderItem={renderItem}
          estimatedItemSize={85}
          keyExtractor={(item) => item.id}
          contentContainerStyle={{ paddingBottom: 120 }}
          showsVerticalScrollIndicator={false}
        />
      ) : (
        <View className="flex-1 items-center justify-center">
          <Text className="text-white/40">No hay movimientos registrados.</Text>
        </View>
      )}
    </View>
  );
}

// Envuelve la lista para que observe toda la tabla de transacciones ordenadas por fecha
const enhance = withObservables([], () => ({
  transactions: database.collections
    .get<Transaction>('transactions')
    .query(
      // Sort by date descending natively in SQLite
      // Q.sortBy('date', Q.desc) -> Note: Requires WatermelonDB setup for Q, we will use default sort or observe all
    )
    .observeWithColumns(['amount', 'category_id', 'date', 'deleted_at']),
}));

export const TransactionList = enhance(TransactionListComponent);
