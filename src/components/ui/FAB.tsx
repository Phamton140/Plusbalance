import React from 'react';
import { TouchableOpacity, StyleSheet } from 'react-native';
import { Plus } from 'lucide-react-native';
import Animated, { useAnimatedStyle, withSpring } from 'react-native-reanimated';
import { hapticFeedback } from '@/lib/haptics';
import { useUIStore } from '@/store/useUIStore';

const AnimatedTouchable = Animated.createAnimatedComponent(TouchableOpacity);

export function FAB() {
  const { openFastEntry, isFastEntryOpen } = useUIStore();

  const animatedStyle = useAnimatedStyle(() => {
    return {
      transform: [
        { scale: withSpring(isFastEntryOpen ? 0.8 : 1, { damping: 15, stiffness: 300 }) },
        { rotate: withSpring(isFastEntryOpen ? '45deg' : '0deg', { damping: 15, stiffness: 300 }) }
      ],
      opacity: withSpring(isFastEntryOpen ? 0 : 1),
    };
  });

  const handlePress = () => {
    hapticFeedback.medium();
    openFastEntry();
  };

  return (
    <AnimatedTouchable
      activeOpacity={0.8}
      onPress={handlePress}
      style={[styles.fab, animatedStyle]}
      className="bg-primary shadow-lg shadow-primary/50"
      pointerEvents={isFastEntryOpen ? 'none' : 'auto'}
    >
      <Plus color="white" size={28} strokeWidth={2.5} />
    </AnimatedTouchable>
  );
}

const styles = StyleSheet.create({
  fab: {
    position: 'absolute',
    bottom: 32,
    right: 24,
    width: 64,
    height: 64,
    borderRadius: 32,
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 50,
    elevation: 8,
  },
});
