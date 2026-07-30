import 'dart:io';
import 'package:pdf/pdf.dart' as pdf_color;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/expense_models.dart';

class ExpenseExportService {
  static Future<void> exportPdf({
    required List<SettlementTransfer> settlements,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Payment Split & Settlement Report",
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                "Expense Splitter App",
                style: pw.TextStyle(
                  fontSize: 12,
                  color: pdf_color.PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                "Final Settlement (Payers to Payers Only):",
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              ...settlements.map(
                (s) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Text(
                    "• ${s.from} pays ${s.to} : ₹${s.amount.toStringAsFixed(2)}",
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'payment_splits_report.pdf',
    );
  }

  static Future<void> exportDocument({
    required List<SettlementTransfer> settlements,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln("=== EXPENSE SPLITTER REPORT ===");
    buffer.writeln("Final Settlements (Payers to Payers Only):\n");
    for (var s in settlements) {
      buffer.writeln(
        "${s.from} pays ${s.to} : ₹${s.amount.toStringAsFixed(2)}",
      );
    }

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/payment_splits_report.txt");
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles([
      XFile(file.path),
    ], text: "Here is your expense settlement document.");
  }
}
