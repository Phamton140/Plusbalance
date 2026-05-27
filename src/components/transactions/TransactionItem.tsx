import React from 'react';
import { View, Text, TouchableOpacity, Dimensions } from 'react-native';
import { BlurView } from 'expo-blur';
import { Swipeable } from 'react-native-gesture-handler';
import { Utensils, Edit3, Trash2 } from 'lucide-react-native';
import withObservables from '@nozbe/with-observables';
import { Transaction } from '@/db/models';
import { format } from 'date-fns';
import { es } from 'date-fns/locale';

const { width } = Dimensions.get('window');

function RightActions() {
  return (
    <View className="flex-row items-center h-full">
      <TouchableOpacity className="w-16 h-full bg-warning items-center justify-center">
        <Edit3 color="white" size={20} />
      </TouchableOpacity>
      <TouchableOpacity className="w-16 h-full bg-danger items-center justify-center">
        <Trash2 color="white" size={20} />
      </TouchableOpacity>
    </View>
  );
}

function TransactionItemComponent({ transaction, category }: { transaction: Transaction, category?: any }) {
  const isIncome = transaction.type === 'INCOME';
  
  return (
    <Swipeable renderRightActions={RightActions} overshootRight={false}>
      <TouchableOpacity 
        activeOpacity={0.8}
        className="w-full bg-background px-6 py-4 flex-row items-center justify-between border-b border-white/5"
      >
        <View className="flex-row items-center flex-1">
          {/* Icon */}
          <View className="w-12 h-12 rounded-2xl items-center justify-center mr-4" style={{ backgroundColor: category?.color ? `${category.color}20` : '#6C63FF20' }}>
            <Utensils color={category?.color || '#6C63FF'} size={24} />
          </View>
          
          {/* Details */}
          <View className="flex-1 mr-4">
            <Text className="text-white font-bold text-base mb-1" numberOfLines={1}>
              {transaction.description}
            </Text>
            <View className="flex-row items-center">
              <Text className="text-white/50 text-xs mr-2">{category?.name || 'General'}</Text>
              <View className="bg-white/10 rounded px-1.5 py-0.5">
                <Text className="text-white/40 text-[10px]">#viaje</Text>
              </View>
            </View>
          </View>
        </View>

        {/* Amount & Date */}
        <View className="items-end">
          <Text className={`font-black text-lg mb-1 ${isIncome ? 'text-success' : 'text-white'}`}>
            {isIncome ? '+' : '-'}${transaction.amount.toLocaleString('en-US', { minimumFractionDigits: 2 })}
          </Text>
          <Text className="text-white/40 text-xs">
            {format(new Date(transaction.date), "dd MMM HH:mm", { locale: es })}
          </Text>
        </View>
      </TouchableOpacity>
    </Swipeable>
  );
}

const enhance = withObservables(['transaction'], ({ transaction }: { transaction: Transaction }) => ({
  transaction,
  category: transaction.category,
}));

export const TransactionItem = enhance(TransactionItemComponent);
