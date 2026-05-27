import React, { useEffect } from 'react';
import { View, StyleSheet, Dimensions } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withSpring,
  interpolateColor,
} from 'react-native-reanimated';

interface BudgetProgressBarProps {
  percentage: number;
  height?: number;
}

export function BudgetProgressBar({ percentage, height = 8 }: BudgetProgressBarProps) {
  const animatedWidth = useSharedValue(0);

  useEffect(() => {
    // Evita valores sobre 100% en la barra visual, pero permite interpolación
    const visualPercent = Math.min(percentage, 100);
    animatedWidth.value = withSpring(visualPercent, {
      damping: 20,
      stiffness: 90,
      mass: 1,
    });
  }, [percentage]);

  const animatedStyle = useAnimatedStyle(() => {
    // Colores elegantes sin ser alarmistas: Verde -> Naranja sutil -> Rojo/Rosado advertencia
    const backgroundColor = interpolateColor(
      animatedWidth.value,
      [0, 70, 90, 100],
      ['#00D4AA', '#00D4AA', '#F59E0B', '#FF6B6B']
    );

    return {
      width: `${animatedWidth.value}%`,
      backgroundColor,
    };
  });

  return (
    <View style={[styles.track, { height }]}>
      <Animated.View style={[styles.fill, animatedStyle]} />
      
      {/* Sutil Glow si está cerca del límite */}
      {percentage > 85 && (
        <Animated.View 
          style={[
            styles.glow, 
            animatedStyle, 
            { opacity: 0.3, width: `${Math.min(percentage, 100)}%` }
          ]} 
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  track: {
    width: '100%',
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderRadius: 999,
    overflow: 'hidden',
    position: 'relative',
  },
  fill: {
    height: '100%',
    borderRadius: 999,
  },
  glow: {
    position: 'absolute',
    top: 0,
    left: 0,
    height: '100%',
    borderRadius: 999,
    transform: [{ scaleY: 2 }],
  }
});
