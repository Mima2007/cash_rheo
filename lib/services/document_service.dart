import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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


  /// B2C — generiše PDF lokalno i otvara share sheet (mail, WhatsApp, itd.)
  static Future<void> shareViaMail(Uint8List imageBytes, String userEmail) async {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) throw Exception('Ne mogu da pročitam sliku');

    final w = decoded.width.toDouble();
    final h = decoded.height.toDouble();
    final scale = 595.0 / w;
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

    // Sačuvaj u privremeni folder
    final tempDir = await getTemporaryDirectory();
    final fileName = 'dokument_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(pdfBytes);

    // Otvori share sheet
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Skenirani dokument',
      text: 'Dokument skeniran u Cash Rheo aplikaciji',
    );
  }

  /// Legacy compat

  /// Obradi skeniranu sliku — približno kao Google Auto filter
  /// Osvetli belu pozadinu + povećaj kontrast teksta
  static Uint8List _enhanceDocument(Uint8List imageBytes) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return imageBytes;

    // Povećaj osvetljenje i kontrast
    var processed = img.adjustColor(
      decoded,
      brightness: 1.15,
      contrast: 1.25,
      saturation: 0.7,
    );

    // Blago izoštri
    processed = img.gaussianBlur(processed, radius: 0);

    return Uint8List.fromList(img.encodeJpg(processed, quality: 88));
  }
}
