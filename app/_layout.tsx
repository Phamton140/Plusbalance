import { Slot } from "expo-router";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { FAB } from "@/components/ui/FAB";
import { FastEntrySheet } from "@/components/transactions/FastEntrySheet";
import "../src/global.css";

export default function RootLayout() {
  return (
    <GestureHandlerRootView style={{ flex: 1, backgroundColor: '#0f0c29' }}>
      <Slot />
      <FAB />
      <FastEntrySheet />
    </GestureHandlerRootView>
  );
}
