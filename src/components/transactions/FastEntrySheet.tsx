import React, { useCallback, useMemo, useRef, useEffect } from 'react';
import { View, Text, TextInput, TouchableOpacity, StyleSheet, Keyboard } from 'react-native';
import BottomSheet, { BottomSheetBackdrop, BottomSheetTextInput, BottomSheetView } from '@gorhom/bottom-sheet';
import { useUIStore } from '@/store/useUIStore';
import { hapticFeedback } from '@/lib/haptics';
import { BlurView } from 'expo-blur';
import { Utensils, Car, ShoppingCart, Coffee, CreditCard, ChevronDown } from 'lucide-react-native';
import { createTransaction } from '@/db/actions';
import { database } from '@/db';
import { Account } from '@/db/models';

const quickCategories = [
  { id: '1', name: 'Comida', icon: Utensils, color: '#FF6B6B' },
  { id: '2', name: 'Transporte', icon: Car, color: '#4ECDC4' },
  { id: '3', name: 'Super', icon: ShoppingCart, color: '#A855F7' },
  { id: '4', name: 'Café', icon: Coffee, color: '#F59E0B' },
];

export function FastEntrySheet() {
  const { isFastEntryOpen, closeFastEntry } = useUIStore();
  const bottomSheetRef = useRef<BottomSheet>(null);
  const amountInputRef = useRef<any>(null);
  const [amount, setAmount] = React.useState('');
  const [desc, setDesc] = React.useState('');
  const [type, setType] = React.useState<'EXPENSE' | 'INCOME'>('EXPENSE');

  const snapPoints = useMemo(() => ['60%', '85%'], []);

  useEffect(() => {
    if (isFastEntryOpen) {
      bottomSheetRef.current?.expand();
      setTimeout(() => amountInputRef.current?.focus(), 100);
    } else {
      bottomSheetRef.current?.close();
      Keyboard.dismiss();
    }
  }, [isFastEntryOpen]);

  const handleSheetChanges = useCallback((index: number) => {
    if (index === -1) {
      closeFastEntry();
      Keyboard.dismiss();
    }
  }, [closeFastEntry]);

  const renderBackdrop = useCallback(
    (props: any) => (
      <BottomSheetBackdrop
        {...props}
        disappearsOnIndex={-1}
        appearsOnIndex={0}
        opacity={0.7}
      />
    ),
    []
  );

  const handleSave = async () => {
    const numericAmount = parseFloat(amount);
    if (isNaN(numericAmount) || numericAmount <= 0) {
      hapticFeedback.error();
      return;
    }

    // Buscamos la cuenta principal (por simplicidad, la de mayor saldo o efectivo)
    const accounts = await database.get<Account>('accounts').query().fetch();
    const accountId = accounts[0]?.id;

    if (!accountId) {
      hapticFeedback.error();
      return;
    }

    try {
      await createTransaction({
        amount: numericAmount,
        type: type,
        accountId: accountId,
        description: desc || 'Registro rápido',
      });
      hapticFeedback.success();
      setAmount('');
      setDesc('');
      closeFastEntry();
    } catch (e) {
      console.error(e);
      hapticFeedback.error();
    }
  };

  return (
    <BottomSheet
      ref={bottomSheetRef}
      index={-1}
      snapPoints={snapPoints}
      onChange={handleSheetChanges}
      backdropComponent={renderBackdrop}
      enablePanDownToClose
      backgroundStyle={styles.sheetBackground}
      handleIndicatorStyle={styles.indicator}
    >
      <BottomSheetView style={styles.contentContainer}>
        {/* Header */}
        <View className="flex-row items-center justify-between mb-6 px-6">
          <View className="flex-row items-center bg-white/10 rounded-full px-3 py-1.5">
            <Text className="text-white text-sm font-medium mr-1">Gasto</Text>
            <ChevronDown size={14} color="white" />
          </View>
          <Text className="text-white/50 text-sm">Hoy</Text>
        </View>

        {/* Monto (Amount) */}
        <View className="items-center justify-center mb-8 px-6">
          <View className="flex-row items-baseline">
            <Text className="text-secondary text-2xl font-bold mr-1">$</Text>
            <BottomSheetTextInput
              ref={amountInputRef}
              style={styles.amountInput}
              keyboardType="decimal-pad"
              placeholder="0.00"
              placeholderTextColor="rgba(255,255,255,0.2)"
              maxLength={10}
              selectionColor="#00D4AA"
              value={amount}
              onChangeText={setAmount}
            />
          </View>
          <BottomSheetTextInput
            placeholder="¿En qué gastaste?"
            placeholderTextColor="rgba(255,255,255,0.4)"
            style={styles.descInput}
            returnKeyType="done"
            value={desc}
            onChangeText={setDesc}
          />
        </View>

        {/* Categorías Rápidas */}
        <View className="px-6 mb-8">
          <Text className="text-white/50 text-xs font-medium mb-3 uppercase tracking-wider">Categorías Frecuentes</Text>
          <View className="flex-row justify-between">
            {quickCategories.map((cat) => (
              <TouchableOpacity
                key={cat.id}
                activeOpacity={0.7}
                onPress={() => hapticFeedback.light()}
                className="items-center"
              >
                <View className="w-14 h-14 rounded-2xl items-center justify-center mb-1" style={{ backgroundColor: `${cat.color}20` }}>
                  <cat.icon size={24} color={cat.color} />
                </View>
                <Text className="text-white/70 text-xs">{cat.name}</Text>
              </TouchableOpacity>
            ))}
          </View>
        </View>

        {/* Método de Pago */}
        <View className="px-6 mb-8">
          <TouchableOpacity activeOpacity={0.8} onPress={() => hapticFeedback.light()} className="flex-row items-center bg-white/5 p-4 rounded-2xl border border-white/10">
            <View className="w-10 h-10 rounded-full bg-primary/20 items-center justify-center mr-3">
              <CreditCard size={20} color="#6C63FF" />
            </View>
            <View className="flex-1">
              <Text className="text-white/50 text-xs mb-0.5">Pagado con</Text>
              <Text className="text-white font-semibold">Visa Platinum •••• 4521</Text>
            </View>
            <ChevronDown size={20} color="rgba(255,255,255,0.3)" />
          </TouchableOpacity>
        </View>

        {/* Save Button */}
        <View className="px-6 pb-8 mt-auto">
          <TouchableOpacity
            activeOpacity={0.8}
            onPress={handleSave}
            className="w-full bg-secondary py-4 rounded-2xl items-center shadow-lg shadow-secondary/30"
          >
            <Text className="text-background font-black text-lg">Guardar Registro</Text>
          </TouchableOpacity>
        </View>
      </BottomSheetView>
    </BottomSheet>
  );
}

const styles = StyleSheet.create({
  sheetBackground: {
    backgroundColor: '#1a1548', // card dark background
    borderTopLeftRadius: 32,
    borderTopRightRadius: 32,
  },
  indicator: {
    backgroundColor: 'rgba(255,255,255,0.2)',
    width: 48,
    height: 5,
  },
  contentContainer: {
    flex: 1,
    paddingTop: 12,
  },
  amountInput: {
    fontSize: 56,
    fontWeight: '900',
    color: '#ffffff',
    textAlign: 'center',
    height: 80,
  },
  descInput: {
    fontSize: 16,
    color: '#ffffff',
    textAlign: 'center',
    height: 40,
    marginTop: 8,
    width: '100%',
  }
});
