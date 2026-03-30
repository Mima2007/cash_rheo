import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class PdfService {
  static Future<String> generateAndUpload(Map<String, dynamic> receipt) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Niste prijavljeni');

    final journal = receipt['journal'] as String? ?? '';
    final invoiceResult = receipt['invoiceResult'] as Map<String, dynamic>? ?? {};
    final pfrNumber = invoiceResult['invoiceNumber'] ?? 'racun';
    final qrUrl = receipt['_qrUrl'] as String? ?? '';

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 5 * PdfPageFormat.mm),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(journal, style: pw.TextStyle(font: pw.Font.courier(), fontSize: 8)),
              if (qrUrl.isNotEmpty) ...[
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qrUrl,
                    width: 55 * PdfPageFormat.mm,
                    height: 55 * PdfPageFormat.mm,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final fileName = '$userId/$pfrNumber.pdf';

    await supabase.storage.from('receipts').uploadBinary(
      fileName,
      Uint8List.fromList(bytes),
      fileOptions: const FileOptions(contentType: 'application/pdf'),
    );

    final publicUrl = supabase.storage.from('receipts').getPublicUrl(fileName);
    return publicUrl;
  }
}
