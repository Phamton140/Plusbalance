import { View, SafeAreaView } from "react-native";
import { StatusBar } from "expo-status-bar";
import { useEffect } from "react";
import { DashboardGrid } from "@/components/dashboard/DashboardGrid";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { seedInitialData } from "@/db/actions";

export default function App() {
  const insets = useSafeAreaInsets();
  
  useEffect(() => {
    seedInitialData().catch(console.error);
  }, []);

  return (
    <View className="flex-1 bg-background" style={{ paddingTop: insets.top }}>
      <StatusBar style="light" />
      <DashboardGrid />
    </View>
  );
}
