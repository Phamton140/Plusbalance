import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/app_database.dart';

class PdfService {
  static Future<void> generateAndPrintTransactionsReport({
    required List<Transaction> transactions,
    required List<Account> accounts,
    required List<Category> categories,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    double totalIncomes = 0;
    double totalExpenses = 0;

    for (var tx in transactions) {
      if (tx.type == 'income') totalIncomes += tx.amount;
      if (tx.type == 'expense') totalExpenses += tx.amount;
    }

    final balance = totalIncomes - totalExpenses;

    final DateFormat dateFormatter = DateFormat('dd/MM/yyyy');
    final DateFormat dateTimeFormatter = DateFormat('dd/MM/yyyy HH:mm');
    final String periodText = (startDate != null && endDate != null)
        ? 'Periodo: ${dateFormatter.format(startDate)} - ${dateFormatter.format(endDate)}'
        : 'Periodo: Histórico Completo';

    String accountName(String id) {
      final a = accounts.firstWhere(
        (a) => a.id == id,
        orElse: () => Account(
          id: '',
          name: 'N/A',
          type: '',
          balance: 0,
          color: '',
          isArchived: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          currency: 'USD',
        ),
      );
      return a.name;
    }

    String categoryName(String? id) {
      if (id == null) return 'Sin categoría';
      final c = categories.firstWhere(
        (c) => c.id == id,
        orElse: () => Category(
          id: '',
          name: 'Sin categoría',
          color: '#9E9E9E',
          icon: '57680',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      return c.name;
    }

    String typeText(String t) => switch (t) {
          'income' => 'Ingreso',
          'expense' => 'Gasto',
          'transfer' => 'Transferencia',
          _ => t,
        };

    final sortedTx = [...transactions]
      ..sort((a, b) => b.date.compareTo(a.date));

    final List<List<dynamic>> tableData = sortedTx.map((tx) {
      return [
        dateFormatter.format(tx.date),
        typeText(tx.type),
        accountName(tx.accountId),
        categoryName(tx.categoryId),
        tx.description ?? '-',
        '\$${tx.amount.toStringAsFixed(2)}',
      ];
    }).toList();

    final activeAccounts = accounts.where((a) => !a.isArchived).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        header: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('+Balance',
                      style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800)),
                  pw.Text('Estado de Cuenta',
                      style: const pw.TextStyle(
                          fontSize: 16, color: PdfColors.grey700)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                  'Generado: ${dateTimeFormatter.format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              pw.Text(periodText,
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
              pw.Divider(),
              pw.SizedBox(height: 8),
            ],
          );
        },
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
          );
        },
        build: (context) {
          return [
            // Resumen financiero
            pw.Text('Resumen Financiero',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryBox('Ingresos', totalIncomes, PdfColors.green700),
                _buildSummaryBox('Gastos', totalExpenses, PdfColors.red700),
                _buildSummaryBox('Balance', balance, PdfColors.blue700),
              ],
            ),
            pw.SizedBox(height: 24),

            // Saldo por cuenta (estilo estado de cuenta)
            pw.Text('Saldo Actual por Cuenta',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            if (activeAccounts.isEmpty)
              pw.Text('No hay cuentas registradas.',
                  style: const pw.TextStyle(color: PdfColors.grey600))
            else
              pw.TableHelper.fromTextArray(
                headers: const ['Cuenta', 'Tipo', 'Institución', 'Saldo'],
                data: activeAccounts.map((a) {
                  return [
                    a.name,
                    a.type.toUpperCase(),
                    a.institutionName ?? '-',
                    '\$${a.balance.toStringAsFixed(2)}',
                  ];
                }).toList(),
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellHeight: 26,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerRight,
                },
                cellStyle: const pw.TextStyle(fontSize: 10),
              ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Patrimonio Total',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  pw.Text(
                      '\$${activeAccounts.fold<double>(0, (sum, a) => sum + a.balance).toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                          color: PdfColors.blue800)),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Detalle de transacciones
            pw.Text('Detalle de Transacciones',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            if (tableData.isEmpty)
              pw.Center(
                child: pw.Text('No hay transacciones en este periodo',
                    style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey600)),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: const ['Fecha', 'Tipo', 'Cuenta', 'Categoría', 'Descripción', 'Monto'],
                data: tableData,
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellHeight: 28,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerLeft,
                  5: pw.Alignment.centerRight,
                },
                cellStyle: const pw.TextStyle(fontSize: 9),
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
                ),
              ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'EstadoDeCuenta_PlusBalance_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static pw.Widget _buildSummaryBox(String title, double amount, PdfColor color) {
    return pw.Container(
      width: 160,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: color, width: 1.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('\$${amount.toStringAsFixed(2)}',
              style: pw.TextStyle(
                  fontSize: 16, color: color, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
