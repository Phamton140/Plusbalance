import React from 'react';
import { View, Text, TouchableOpacity } from 'react-native';
import { Target, TrendingUp } from 'lucide-react-native';

export function GoalsWidget() {
  const goalPercentage = 65; // Mock data for now
  
  return (
    <View className="w-full bg-white/5 border border-white/10 rounded-3xl p-5 mb-4">
      <View className="flex-row justify-between items-center mb-4">
        <View className="flex-row items-center">
          <View className="w-10 h-10 rounded-xl bg-primary/20 items-center justify-center mr-3">
            <Target color="#6C63FF" size={20} />
          </View>
          <Text className="text-white font-bold text-base">Metas Financieras</Text>
        </View>
        <TouchableOpacity>
          <Text className="text-secondary text-sm font-medium">Gestionar</Text>
        </TouchableOpacity>
      </View>

      <View className="flex-row items-center bg-background/50 rounded-2xl p-4">
        <View className="relative w-16 h-16 items-center justify-center mr-4">
          <View className="absolute inset-0 rounded-full border-4 border-white/10" />
          {/* Mock progress ring */}
          <View 
            className="absolute inset-0 rounded-full border-4 border-primary"
            style={{ borderLeftColor: 'transparent', borderBottomColor: 'transparent', transform: [{ rotate: '45deg' }] }}
          />
          <Text className="text-white font-bold">{goalPercentage}%</Text>
        </View>
        
        <View className="flex-1">
          <Text className="text-white font-bold mb-1">Fondo de Emergencia</Text>
          <Text className="text-white/40 text-xs mb-2">RD$ 65,000 de RD$ 100,000</Text>
          
          <View className="flex-row items-center bg-success/10 self-start px-2 py-1 rounded-md">
            <TrendingUp color="#10B981" size={12} className="mr-1" />
            <Text className="text-success text-[10px] font-bold">+RD$ 5,000 este mes</Text>
          </View>
        </View>
      </View>
    </View>
  );
}
