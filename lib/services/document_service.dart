import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

class DocumentService {
  static const _baseUrl = 'https://cash-rheo.vercel.app';

  /// Full auto: send photo → get clean PDF back → upload to Supabase
  static Future<String> scanAndUpload(Uint8List imageBytes) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Niste prijavljeni');

    // Compress for upload (max 2048px, quality 85)
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) throw Exception('Ne mogu da procitam sliku');

    img.Image sized = decoded;
    final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
    if (longest > 2048) {
      if (decoded.width > decoded.height) {
        sized = img.copyResize(decoded, width: 2048);
      } else {
        sized = img.copyResize(decoded, height: 2048);
      }
    }

    final compressed = img.encodeJpg(sized, quality: 85);
    final base64Image = base64Encode(compressed);

    // Send to Vercel — returns PDF directly
    final response = await http.post(
      Uri.parse('$_baseUrl/api/process-document'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'image': base64Image}),
    ).timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      final errorMsg = response.headers['content-type']?.contains('json') == true
          ? json.decode(response.body)['error'] ?? 'Greska'
          : 'Server greska: ${response.statusCode}';
      throw Exception(errorMsg);
    }

    final pdfBytes = response.bodyBytes;
    final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}.pdf';

    await _supabase.storage.from('documents').uploadBinary(
      fileName, pdfBytes,
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
}
