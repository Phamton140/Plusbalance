import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/app_database.dart';

class PdfService {
  static Future<void> generateAndPrintTransactionsReport({
    required List<Transaction> transactions,
    required List<Account> accounts,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();

    double totalIncomes = 0;
    double totalExpenses = 0;

    for (var tx in transactions) {
      if (tx.type == 'income') totalIncomes += tx.amount;
      if (tx.type == 'expense') totalExpenses += tx.amount;
    }

    final balance = totalIncomes - totalExpenses;

    final DateFormat formatter = DateFormat('dd/MM/yyyy');
    final String periodText = (startDate != null && endDate != null)
        ? 'Periodo: ${formatter.format(startDate)} - ${formatter.format(endDate)}'
        : 'Periodo: Histórico Completo';

    // Build table data
    final List<List<dynamic>> tableData = transactions.map((tx) {
      final account = accounts.firstWhere((a) => a.id == tx.accountId, orElse: () => Account(id: '', name: 'N/A', type: '', balance: 0, color: '', isArchived: false, createdAt: DateTime.now(), updatedAt: DateTime.now(), currency: 'USD'));
      final dateText = formatter.format(tx.date);
      final desc = tx.description ?? '-';
      final typeText = tx.type == 'income' ? 'Ingreso' : (tx.type == 'expense' ? 'Gasto' : 'Transferencia');
      final amountText = '\$${tx.amount.toStringAsFixed(2)}';
      
      return [
        dateText,
        desc,
        account.name,
        typeText,
        amountText,
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('+Balance', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  pw.Text('Reporte de Transacciones', style: const pw.TextStyle(fontSize: 16, color: PdfColors.grey700)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text(periodText, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
              pw.Divider(),
              pw.SizedBox(height: 16),
            ]
          );
        },
        build: (context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryBox('Ingresos Totales', totalIncomes, PdfColors.green700),
                _buildSummaryBox('Gastos Totales', totalExpenses, PdfColors.red700),
                _buildSummaryBox('Balance Neto', balance, PdfColors.blue700),
              ]
            ),
            pw.SizedBox(height: 32),
            pw.TableHelper.fromTextArray(
              headers: ['Fecha', 'Descripción', 'Cuenta', 'Tipo', 'Monto'],
              data: tableData,
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
              },
              cellStyle: const pw.TextStyle(fontSize: 10),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))
              ),
            ),
          ];
        },
      )
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Reporte_PlusBalance_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static pw.Widget _buildSummaryBox(String title, double amount, PdfColor color) {
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: color, width: 1.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('\$${amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, color: color, fontWeight: pw.FontWeight.bold)),
        ]
      )
    );
  }
}
