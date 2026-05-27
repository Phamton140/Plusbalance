import React from 'react';
import { View, Text, TouchableOpacity, ScrollView } from 'react-native';
import { ArrowUpRight, ArrowDownRight, Activity, Calendar } from 'lucide-react-native';
import { AccountsCarousel } from './AccountsCarousel';
import { BudgetWidget } from './BudgetWidget';
import { GoalsWidget } from '../goals/GoalsWidget';
import withObservables from '@nozbe/with-observables';
import { database } from '@/db';
import { Account } from '@/db/models';
import { useRouter } from 'expo-router';

function DashboardHeaderComponent({ accounts }: { accounts: Account[] }) {
  // Cálculo reactivo del balance total
  const totalBalance = accounts?.reduce((sum, acc) => sum + (acc.balance || 0), 0) || 0;

  return (
    <View className="px-6 pt-12 pb-6">
      <Text className="text-white/60 text-base mb-1">Buenas tardes, Carlos</Text>
      <Text className="text-white text-4xl font-black mb-6">
        RD$ {totalBalance.toLocaleString('en-US', { minimumFractionDigits: 2 })}
      </Text>
      
      <View className="flex-row gap-4">
        <View className="flex-1 bg-white/5 border border-white/10 rounded-2xl p-4">
          <View className="flex-row items-center mb-2">
            <View className="w-6 h-6 rounded-full bg-success/20 items-center justify-center mr-2">
              <ArrowDownRight color="#10B981" size={14} />
            </View>
            <Text className="text-white/60 text-xs font-medium uppercase tracking-wider">Ingresos Mes</Text>
          </View>
          <Text className="text-white font-bold text-lg">--</Text>
        </View>

        <View className="flex-1 bg-white/5 border border-white/10 rounded-2xl p-4">
          <View className="flex-row items-center mb-2">
            <View className="w-6 h-6 rounded-full bg-danger/20 items-center justify-center mr-2">
              <ArrowUpRight color="#FF6B6B" size={14} />
            </View>
            <Text className="text-white/60 text-xs font-medium uppercase tracking-wider">Gastos Mes</Text>
          </View>
          <Text className="text-white font-bold text-lg">--</Text>
        </View>
      </View>
    </View>
  );
}

const DashboardHeader = withObservables([], () => ({
  accounts: database.get<Account>('accounts').query(),
}))(DashboardHeaderComponent);

export function DashboardGrid() {
  const router = useRouter();

  return (
    <ScrollView className="flex-1" showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 100 }}>
      {/* Header Reactivo con Balances */}
      <DashboardHeader />

      {/* Carrusel de Cuentas Reactivo */}
      <AccountsCarousel />

      {/* Grid de Widgets Secundarios */}
      <View className="px-6 flex-row flex-wrap justify-between">
        
        {/* Presupuesto Reactivo */}
        <BudgetWidget />

        <TouchableOpacity activeOpacity={0.8} className="w-[48%] bg-white/5 border border-white/10 rounded-3xl p-5 mb-4">
          <View className="w-10 h-10 rounded-full bg-warning/20 items-center justify-center mb-4">
            <Calendar color="#F59E0B" size={20} />
          </View>
          <Text className="text-white/60 text-sm mb-1">Próximos Pagos</Text>
          <Text className="text-white font-bold text-lg">En desarrollo</Text>
        </TouchableOpacity>
        
        {/* Metas Financieras */}
        <GoalsWidget />

      {/* Transacciones Recientes (Mock Header) */}
      <View className="px-6 pb-24 w-full">
        <View className="w-full bg-white/5 border border-white/10 rounded-3xl p-5 mt-2">
          <View className="flex-row justify-between items-center mb-4">
            <Text className="text-white font-bold text-base">Últimos Movimientos</Text>
            <TouchableOpacity onPress={() => router.push('/transactions')}>
              <Text className="text-secondary text-sm font-medium">Ver todo</Text>
            </TouchableOpacity>
          </View>
          
          <Text className="text-white/40 text-center text-xs py-4">
            Las transacciones recientes aparecerán aquí
          </Text>
        </View>
      </View>
      </View>
    </ScrollView>
  );
}
