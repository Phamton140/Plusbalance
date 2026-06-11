import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/app_database.dart';

class PdfService {
  static const _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
  ];

  static String _formatFechaLarga(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} de ${_meses[d.month - 1]} de ${d.year} a las $hh:$mm';
  }

  static Future<void> generateAndPrintTransactionsReport({
    required List<Transaction> transactions,
    required List<Account> accounts,
    required List<Category> categories,
    DateTime? startDate,
    DateTime? endDate,
    String? userName,
  }) async {
    final pdf = pw.Document();

    // Cargar imagen del icono
    pw.ImageProvider? logoImage;
    try {
      final iconBytes = await rootBundle.load('assets/app_icon.png');
      logoImage = pw.MemoryImage(iconBytes.buffer.asUint8List());
    } catch (_) {
      logoImage = null;
    }

    // Cargamos las fuentes. Si no hay red, caemos a las fuentes por defecto
    // del paquete `pdf` (Helvetica/Times) para no romper la generación.
    pw.Font? fontRegular;
    pw.Font? fontBold;
    try {
      fontRegular = await PdfGoogleFonts.robotoRegular();
      fontBold = await PdfGoogleFonts.robotoBold();
    } catch (_) {
      fontRegular = null;
      fontBold = null;
    }

    double totalIngresos = 0;
    double totalGastos = 0;

    for (var tx in transactions) {
      if (tx.type == 'income') totalIngresos += tx.amount;
      if (tx.type == 'expense') totalGastos += tx.amount;
    }

    final balanceNeto = totalIngresos - totalGastos;

    final DateFormat dateFormatter = DateFormat('dd/MM/yyyy');
    final DateFormat dateTimeFormatter = DateFormat('dd/MM/yyyy HH:mm');
    final String periodText = (startDate != null && endDate != null)
        ? 'Periodo: del ${dateTimeFormatter.format(startDate)} al ${dateTimeFormatter.format(endDate)}'
        : 'Periodo: Histórico completo';

    String nombreCuenta(String id) {
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

    String nombreCategoria(String? id) {
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

    String tipoTexto(String t) => switch (t) {
          'income' => 'Ingreso',
          'expense' => 'Gasto',
          'transfer' => 'Transferencia',
          _ => t,
        };

    final sortedTx = [...transactions]
      ..sort((a, b) => b.date.compareTo(a.date));

    final List<List<dynamic>> datosTabla = sortedTx.map((tx) {
      return [
        dateTimeFormatter.format(tx.date),
        tipoTexto(tx.type),
        nombreCuenta(tx.accountId),
        nombreCategoria(tx.categoryId),
        tx.description ?? '-',
        '\$${tx.amount.toStringAsFixed(2)}',
      ];
    }).toList();

    final cuentasActivas = accounts.where((a) => !a.isArchived).toList();
    final patrimonioTotal = cuentasActivas.fold<double>(0, (sum, a) => sum + a.balance);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: (fontRegular != null && fontBold != null)
            ? pw.ThemeData.withFont(base: fontRegular, bold: fontBold)
            : null,
        header: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Logo de la app con icono e imagen
              pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoImage != null)
                    pw.Container(
                      width: 40,
                      height: 40,
                      child: pw.Image(logoImage, fit: pw.BoxFit.cover),
                    )
                  else
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: const PdfColor.fromInt(0xFF6C63FF),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Text('+', style: pw.TextStyle(
                        color: const PdfColor.fromInt(0xFF00D4AA),
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      )),
                    ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    '+Balance',
                    style: pw.TextStyle(
                      color: const PdfColor.fromInt(0xFF6C63FF),
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Estado de Cuenta',
                      style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey800)),
                  if (userName != null && userName.isNotEmpty)
                    pw.Text('Usuario: $userName',
                        style: const pw.TextStyle(
                            fontSize: 11, color: PdfColors.grey700)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text('Generado el ${_formatFechaLarga(DateTime.now())}',
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
            child: pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
          );
        },
        build: (context) {
          return [
            // Resumen financiero
            _seccionTitulo('Resumen Financiero'),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _cajaResumen('Ingresos', totalIngresos,
                    const PdfColor.fromInt(0xFF00D4AA)),
                _cajaResumen('Gastos', totalGastos,
                    const PdfColor.fromInt(0xFFFF6B6B)),
                _cajaResumen('Balance Neto', balanceNeto,
                    balanceNeto >= 0
                        ? const PdfColor.fromInt(0xFF4D96FF)
                        : const PdfColor.fromInt(0xFFFF6B6B)),
              ],
            ),
            pw.SizedBox(height: 24),

            // Saldo por cuenta
            _seccionTitulo('Saldo Actual por Cuenta'),
            pw.SizedBox(height: 8),
            if (cuentasActivas.isEmpty)
              pw.Text('No hay cuentas registradas.',
                  style: const pw.TextStyle(color: PdfColors.grey600))
            else
              pw.TableHelper.fromTextArray(
                headers: const ['Cuenta', 'Tipo', 'Institución', 'Saldo'],
                data: cuentasActivas.map((a) {
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
                  pw.Text('\$${patrimonioTotal.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                          color: const PdfColor.fromInt(0xFF6C63FF))),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Detalle de transacciones
            _seccionTitulo('Detalle de Transacciones'),
            pw.SizedBox(height: 8),
            if (datosTabla.isEmpty)
              pw.Center(
                child: pw.Text('No hay transacciones en este periodo',
                    style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey600)),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: const [
                  'Fecha', 'Tipo', 'Cuenta', 'Categoría', 'Descripción', 'Monto'
                ],
                data: datosTabla,
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

  static pw.Widget _seccionTitulo(String texto) {
    return pw.Text(texto,
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold));
  }

  static pw.Widget _cajaResumen(String titulo, double monto, PdfColor color) {
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
          pw.Text(titulo,
              style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('\$${monto.toStringAsFixed(2)}',
              style: pw.TextStyle(
                  fontSize: 16,
                  color: color,
                  fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
