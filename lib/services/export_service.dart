import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart'; // Import printing package
import '../models/expense_models.dart';

class ExpenseExportService {
  static Future<void> exportPdf({
    required List<SettlementTransfer> settlements,
    required List<FamilyUnit> units,
    required List<ExpenseEntry> expenses,
    required String currencySymbol,
  }) async {
    final pdfDoc = pw.Document();

    pdfDoc.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            // Title Header
            pw.Header(
              level: 0,
              child: pw.Text("Expense Splitter Report",
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 10),

            // Section 1: Units & Members
            pw.Text("Registered Units & Members",
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            ...units.map((unit) {
              final memberString = unit.members.isEmpty
                  ? "No individual members"
                  : unit.members.join(', ');
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text("• ${unit.name}: $memberString",
                    style: const pw.TextStyle(fontSize: 12)),
              );
            }),
            pw.SizedBox(height: 16),

            // Section 2: Detailed Expenses
            pw.Text("Expenses Breakdown",
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            ...expenses.map((expense) {
              final payersText = expense.payers.map((p) {
                final matchedUnit = units.firstWhere(
                  (u) => u.id == p.familyId,
                  orElse: () =>
                      FamilyUnit(id: '', name: 'Unknown', members: []),
                );
                return "${matchedUnit.name} ($currencySymbol${p.amountPaid.toStringAsFixed(2)})";
              }).join(', ');

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: const PdfColor(0.8, 0.8, 0.8)),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(expense.title,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 13)),
                    pw.SizedBox(height: 2),
                    pw.Text(
                        "Total Amount: $currencySymbol${expense.amount.toStringAsFixed(2)}",
                        style: const pw.TextStyle(fontSize: 11)),
                    pw.Text("Paid by: $payersText",
                        style: const pw.TextStyle(fontSize: 11)),
                    pw.Text(
                        "Split among: ${expense.participatingMemberNames.join(', ')}",
                        style: const pw.TextStyle(fontSize: 11)),
                  ],
                ),
              );
            }),
            pw.SizedBox(height: 16),

            // Section 3: Final Settlements
            pw.Text("Final Settlements",
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            ...settlements.map((s) {
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(
                    "${s.from} owes ${s.to}: $currencySymbol${s.amount.toStringAsFixed(2)}",
                    style: const pw.TextStyle(fontSize: 12)),
              );
            }),
          ];
        },
      ),
    );

    // Use Printing share/layout functionality to display native print/share sheet on mobile
    await Printing.sharePdf(
      bytes: await pdfDoc.save(),
      filename: 'expense_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static Future<void> exportDocument({
    required List<SettlementTransfer> settlements,
  }) async {
    // Document export logic if applicable
  }
}
