import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

class DocumentService {
  /// Upload scanned image directly as PDF to Supabase — no server needed
  static Future<String> uploadDirect(Uint8List imageBytes) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Niste prijavljeni');

    // Get image dimensions
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) throw Exception('Ne mogu da pročitam sliku');

    // Create PDF with image filling the page
    final w = decoded.width.toDouble();
    final h = decoded.height.toDouble();

    // Scale to A4-ish proportions (72 DPI points)
    final scale = 595.0 / w; // A4 width in points
    final pageW = 595.0;
    final pageH = h * scale;

    final pdf = pw.Document();
    final image = pw.MemoryImage(imageBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(pageW, pageH, marginAll: 0),
        build: (context) => pw.Center(
          child: pw.Image(image, width: pageW, height: pageH, fit: pw.BoxFit.fill),
        ),
      ),
    );

    final pdfBytes = await pdf.save();
    final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}.pdf';

    await _supabase.storage.from('documents').uploadBinary(
      fileName, Uint8List.fromList(pdfBytes),
      fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
    );

    final pdfUrl = _supabase.storage.from('documents').getPublicUrl(fileName);

    await _supabase.from('documents').insert({
      'user_id': userId,
      'company_id': 'aa8a914b-9b47-4f99-985a-aedcc4991ed1',
      'doc_type': 'scan',
      'file_url': pdfUrl,
      'created_at': DateTime.now().toIso8601String(),
    });

    return pdfUrl;
  }

  /// Legacy compat
  static Future<String> scanAndUpload(Uint8List imageBytes) => uploadDirect(imageBytes);
}
