import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
final supabase = Supabase.instance.client;
class PdfService {
  static Future<String> generateAndUpload(Map<String, dynamic> receipt) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('PDF KORAK 1 FAIL: userId null');
    final journal = receipt['journal'] as String? ?? '';
    final invoiceResult = receipt['invoiceResult'] as Map<String, dynamic>? ?? {};
    final pfrNumber = invoiceResult['invoiceNumber'] ?? 'racun';
    final qrUrl = receipt['_qrUrl'] as String? ?? '';
    final fontData = await rootBundle.load('assets/fonts/RobotoMono-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);
    late List<int> bytes;
    try {
      final lineCount = journal.split('\n').length;
      final pageHeight = (lineCount * 10 + (qrUrl.isNotEmpty ? 70 : 0) + 20) * PdfPageFormat.mm / 10;
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, pageHeight, marginAll: 5 * PdfPageFormat.mm),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(journal, style: pw.TextStyle(font: ttf, fontSize: 8)),
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
      bytes = await pdf.save();
    } catch (e) {
      throw Exception('PDF KORAK 3 FAIL: generisanje $e');
    }
    try {
      final fileName = '$userId/$pfrNumber.pdf';
      await supabase.storage.from('receipts').uploadBinary(
        fileName,
        Uint8List.fromList(bytes),
        fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
      );
      final publicUrl = supabase.storage.from('receipts').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      throw Exception('PDF KORAK 4 FAIL: upload $e');
    }
  }
}
