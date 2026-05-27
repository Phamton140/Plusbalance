import { View, Text, TouchableOpacity } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { TransactionList } from '@/components/transactions/TransactionList';
import { ChevronLeft } from 'lucide-react-native';
import { useRouter } from 'expo-router';

export default function TransactionsScreen() {
  const insets = useSafeAreaInsets();
  const router = useRouter();

  return (
    <View className="flex-1 bg-background" style={{ paddingTop: insets.top }}>
      <StatusBar style="light" />
      
      {/* Header Fijo */}
      <View className="px-6 py-4 flex-row items-center bg-background z-10 border-b border-white/5">
        <TouchableOpacity 
          onPress={() => router.back()}
          className="w-10 h-10 rounded-full bg-white/5 items-center justify-center mr-4"
        >
          <ChevronLeft color="white" size={24} />
        </TouchableOpacity>
        <Text className="text-white text-xl font-bold">Movimientos</Text>
      </View>

      {/* Lista Reactiva y Virtualizada */}
      <TransactionList />
    </View>
  );
}
