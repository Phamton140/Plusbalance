import React, { useEffect, useState } from 'react';
import { View, Text, TouchableOpacity } from 'react-native';
import { Activity } from 'lucide-react-native';
import { BudgetProgressBar } from '../budgets/BudgetProgressBar';
import withObservables from '@nozbe/with-observables';
import { database } from '@/db';
import { Budget, Transaction } from '@/db/models';
import { getBudgetAnalytics } from '@/db/actions';
import { map } from 'rxjs/operators';

// Propiedades que llegan gracias al observable
interface Props {
  budget: Budget;
  transactions: Transaction[]; // Solo se usa para forzar re-render cuando hay nuevas transacciones
}

function BudgetWidgetComponent({ budget, transactions }: Props) {
  const [analytics, setAnalytics] = useState<any>(null);

  useEffect(() => {
    if (budget) {
      getBudgetAnalytics(budget.id).then(setAnalytics).catch(console.error);
    }
  }, [budget, transactions]); // Recalcular si entra una transacción nueva

  if (!budget || !analytics) return (
    <View className="w-[48%] bg-white/5 border border-white/10 rounded-3xl p-5 mb-4 justify-center items-center">
      <Activity color="#6C63FF" size={20} className="mb-2" />
      <Text className="text-white/40 text-xs text-center">Cargando presupuesto...</Text>
    </View>
  );

  return (
    <TouchableOpacity activeOpacity={0.8} className="w-[48%] bg-white/5 border border-white/10 rounded-3xl p-5 mb-4 shadow-lg shadow-black/20">
      <View className="flex-row justify-between items-start mb-4">
        <View className="w-10 h-10 rounded-full bg-primary/20 items-center justify-center">
          <Activity color="#6C63FF" size={20} />
        </View>
        <Text className="text-white/40 text-xs font-mono">{analytics.percentage.toFixed(0)}%</Text>
      </View>
      
      <Text className="text-white/60 text-sm mb-1">{budget.name}</Text>
      
      <View className="flex-row items-baseline mb-3">
        <Text className="text-white font-bold text-lg">RD$ {analytics.remaining.toLocaleString('en-US', { minimumFractionDigits: 0 })}</Text>
        <Text className="text-white/40 text-xs ml-1">libres</Text>
      </View>

      <BudgetProgressBar percentage={analytics.percentage} />

      <Text className="text-white/40 text-[10px] mt-3">
        Promedio seguro: RD$ {analytics.dailyAverageAllowed.toLocaleString('en-US', { minimumFractionDigits: 0 })}/día
      </Text>
    </TouchableOpacity>
  );
}

// 1. Buscamos el primer presupuesto activo (o el principal)
// 2. Observamos TODAS las transacciones para que el widget se actualice reactivamente
const enhance = withObservables([], () => ({
  budget: database.collections.get<Budget>('budgets').query().observe().pipe(
    map(budgets => budgets[0])
  ),
  transactions: database.collections.get<Transaction>('transactions').query()
}));

export const BudgetWidget = enhance(BudgetWidgetComponent);
