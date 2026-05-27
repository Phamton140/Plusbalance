import React from 'react';
import { View, Text, Dimensions, TouchableOpacity } from 'react-native';
import Animated, {
  useAnimatedScrollHandler,
  useSharedValue,
  useAnimatedStyle,
  interpolate,
  Extrapolation,
} from 'react-native-reanimated';
import { Wallet, CreditCard, Landmark, Coins } from 'lucide-react-native';
import withObservables from '@nozbe/with-observables';
import { database } from '@/db';
import { Account } from '@/db/models';

const { width } = Dimensions.get('window');
const CARD_WIDTH = width * 0.85;
const SPACING = 16;

const typeIcons: Record<string, any> = {
  BANK: Landmark,
  CREDIT_CARD: CreditCard,
  CASH: Coins,
  WALLET: Wallet,
};

// Componente Interno que recibe cuentas reales desde SQLite
function AccountsCarouselComponent({ accounts }: { accounts: Account[] }) {
  const scrollX = useSharedValue(0);

  const scrollHandler = useAnimatedScrollHandler({
    onScroll: (event) => {
      scrollX.value = event.contentOffset.x;
    },
  });

  if (!accounts || accounts.length === 0) return null;

  return (
    <View className="mb-6">
      <View className="flex-row items-center justify-between px-6 mb-4">
        <Text className="text-white font-bold text-lg">Cuentas Locales</Text>
        <TouchableOpacity>
          <Text className="text-secondary font-medium">Añadir</Text>
        </TouchableOpacity>
      </View>

      <Animated.ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        snapToInterval={CARD_WIDTH + SPACING}
        decelerationRate="fast"
        onScroll={scrollHandler}
        scrollEventThrottle={16}
        contentContainerStyle={{ paddingHorizontal: (width - CARD_WIDTH) / 2 }}
      >
        {accounts.map((account, index) => {
          const IconComponent = typeIcons[account.type] || Wallet;
          const inputRange = [
            (index - 1) * (CARD_WIDTH + SPACING),
            index * (CARD_WIDTH + SPACING),
            (index + 1) * (CARD_WIDTH + SPACING),
          ];

          const animatedStyle = useAnimatedStyle(() => {
            const scale = interpolate(scrollX.value, inputRange, [0.9, 1, 0.9], Extrapolation.CLAMP);
            const opacity = interpolate(scrollX.value, inputRange, [0.7, 1, 0.7], Extrapolation.CLAMP);
            return {
              transform: [{ scale }],
              opacity,
            };
          });

          return (
            <Animated.View
              key={account.id}
              style={[{ width: CARD_WIDTH, marginRight: SPACING }, animatedStyle]}
            >
              <View
                className="rounded-3xl p-6 overflow-hidden h-48 justify-between shadow-2xl"
                style={{ backgroundColor: account.color || '#1a1a2e' }}
              >
                {/* Decoration */}
                <View className="absolute -right-8 -top-8 w-32 h-32 rounded-full bg-white/10" style={{ opacity: 0.5 }} />
                <View className="absolute -left-12 -bottom-12 w-40 h-40 rounded-full bg-black/10" style={{ opacity: 0.5 }} />

                <View className="flex-row justify-between items-start">
                  <View>
                    <Text className="text-white/60 text-xs uppercase tracking-wider mb-1">{account.type.replace('_', ' ')}</Text>
                    <Text className="text-white font-bold text-base">{account.name}</Text>
                  </View>
                  <View className="w-10 h-10 rounded-full bg-white/20 items-center justify-center">
                    <IconComponent color="white" size={20} />
                  </View>
                </View>

                <View className="mt-auto">
                  <Text className="text-white/60 text-sm mb-1">
                    {account.type === 'CREDIT_CARD' ? 'Balance Utilizado' : 'Balance Disponible'}
                  </Text>
                  <View className="flex-row items-baseline">
                    <Text className="text-white/80 text-xl font-medium mr-1">{account.currency === 'USD' ? '$' : 'RD$'}</Text>
                    <Text className="text-white text-3xl font-black tracking-tight">
                      {account.balance.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                    </Text>
                  </View>
                </View>
              </View>
            </Animated.View>
          );
        })}
      </Animated.ScrollView>
    </View>
  );
}

// Envuelve el componente para que observe los cambios de la tabla 'accounts'
export const AccountsCarousel = withObservables([], () => ({
  accounts: database.get<Account>('accounts').query(),
}))(AccountsCarouselComponent);
