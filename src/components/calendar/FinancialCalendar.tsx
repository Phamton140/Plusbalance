import React, { useState } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Calendar, LocaleConfig } from 'react-native-calendars';
import withObservables from '@nozbe/with-observables';
import { database } from '@/db';
import { Transaction } from '@/db/models';
import { format } from 'date-fns';
import { es } from 'date-fns/locale';

LocaleConfig.locales['es'] = {
  monthNames: ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'],
  monthNamesShort: ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'],
  dayNames: ['Domingo','Lunes','Martes','Miércoles','Jueves','Viernes','Sábado'],
  dayNamesShort: ['Dom','Lun','Mar','Mié','Jue','Vie','Sáb'],
  today: 'Hoy'
};
LocaleConfig.defaultLocale = 'es';

function FinancialCalendarComponent({ transactions }: { transactions: Transaction[] }) {
  const [selectedDate, setSelectedDate] = useState(format(new Date(), 'yyyy-MM-dd'));

  // Pre-calcular marcas para el calendario en base a transacciones
  const markedDates = React.useMemo(() => {
    const marks: Record<string, any> = {};
    
    transactions.forEach(tx => {
      const dateStr = format(new Date(tx.date), 'yyyy-MM-dd');
      if (!marks[dateStr]) {
        marks[dateStr] = { dots: [] };
      }
      
      const dotColor = tx.type === 'INCOME' ? '#00D4AA' : '#FF6B6B';
      
      // Limitar a 3 puntitos para no saturar
      if (marks[dateStr].dots.length < 3) {
        marks[dateStr].dots.push({ key: tx.id, color: dotColor });
      }
    });

    if (marks[selectedDate]) {
      marks[selectedDate] = { ...marks[selectedDate], selected: true, selectedColor: '#1a1a2e' };
    } else {
      marks[selectedDate] = { selected: true, selectedColor: '#1a1a2e' };
    }

    return marks;
  }, [transactions, selectedDate]);

  return (
    <View className="flex-1 bg-background">
      <Calendar
        markingType={'multi-dot'}
        markedDates={markedDates}
        onDayPress={day => {
          setSelectedDate(day.dateString);
        }}
        theme={{
          calendarBackground: 'transparent',
          textSectionTitleColor: 'rgba(255,255,255,0.4)',
          selectedDayBackgroundColor: '#6C63FF',
          selectedDayTextColor: '#ffffff',
          todayTextColor: '#00D4AA',
          dayTextColor: '#ffffff',
          textDisabledColor: 'rgba(255,255,255,0.1)',
          dotColor: '#00D4AA',
          selectedDotColor: '#ffffff',
          arrowColor: '#ffffff',
          monthTextColor: '#ffffff',
          indicatorColor: '#ffffff',
        }}
      />
      
      {/* Resumen del Día Seleccionado */}
      <View className="px-6 py-4 mt-4 bg-white/5 mx-6 rounded-3xl border border-white/10">
        <Text className="text-white/40 mb-2">Resumen de: {format(new Date(selectedDate), 'dd MMM yyyy', { locale: es })}</Text>
        
        <View className="flex-row justify-between mb-2">
          <Text className="text-white font-medium">Ingresos:</Text>
          <Text className="text-success font-bold">
            + RD$ {
              transactions
                .filter(t => format(new Date(t.date), 'yyyy-MM-dd') === selectedDate && t.type === 'INCOME')
                .reduce((s, t) => s + t.amount, 0).toLocaleString('en-US')
            }
          </Text>
        </View>

        <View className="flex-row justify-between">
          <Text className="text-white font-medium">Gastos:</Text>
          <Text className="text-danger font-bold">
            - RD$ {
              transactions
                .filter(t => format(new Date(t.date), 'yyyy-MM-dd') === selectedDate && t.type === 'EXPENSE')
                .reduce((s, t) => s + t.amount, 0).toLocaleString('en-US')
            }
          </Text>
        </View>
      </View>
    </View>
  );
}

const enhance = withObservables([], () => ({
  transactions: database.collections.get<Transaction>('transactions').query()
}));

export const FinancialCalendar = enhance(FinancialCalendarComponent);
