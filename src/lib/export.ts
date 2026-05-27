import * as FileSystem from 'expo-file-system';
import * as Sharing from 'expo-sharing';
import { database } from '@/db';
import { Transaction } from '@/db/models';
import { format } from 'date-fns';

export async function exportTransactionsToCSV() {
  try {
    // 1. Obtener todas las transacciones localmente
    const transactions = await database.get<Transaction>('transactions').query().fetch();
    
    // 2. Construir la cabecera del CSV
    let csvContent = 'ID,Fecha,Descripcion,Monto,Tipo,Categoria\n';

    // 3. Generar las filas (optimizando la carga)
    transactions.forEach(tx => {
      const dateStr = format(new Date(tx.date), 'yyyy-MM-dd HH:mm:ss');
      // Escapamos comas y saltos de línea básicos
      const desc = tx.description ? `"${tx.description.replace(/"/g, '""')}"` : '""';
      const cat = tx.categoryId || 'General';
      
      csvContent += `${tx.id},${dateStr},${desc},${tx.amount},${tx.type},${cat}\n`;
    });

    // 4. Escribir archivo temporal
    const dateStamp = format(new Date(), 'yyyyMMdd');
    const fileName = `PlusBalance_Export_${dateStamp}.csv`;
    const fileUri = FileSystem.documentDirectory + fileName;
    
    await FileSystem.writeAsStringAsync(fileUri, csvContent, {
      encoding: FileSystem.EncodingType.UTF8,
    });

    // 5. Compartir usando UI nativa
    const isAvailable = await Sharing.isAvailableAsync();
    if (isAvailable) {
      await Sharing.shareAsync(fileUri, {
        mimeType: 'text/csv',
        dialogTitle: 'Exportar Movimientos +Balance',
        UTI: 'public.comma-separated-values-text' // Para iOS
      });
    } else {
      console.warn("La función de compartir no está disponible en este dispositivo.");
    }
  } catch (error) {
    console.error("Error exportando a CSV:", error);
    throw error;
  }
}
