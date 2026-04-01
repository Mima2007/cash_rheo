import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image/image.dart' as img;

final supabase = Supabase.instance.client;

class DocumentService {
  static Future<String> scanAndUpload(Uint8List imageBytes) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Niste prijavljeni');

    // Smanji sliku na max 1200px
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) throw Exception('Ne mogu da procitam sliku');
    
    img.Image resized;
    if (decoded.width > 1200 || decoded.height > 1200) {
      resized = img.copyResize(decoded, width: decoded.width > decoded.height ? 1200 : -1, height: decoded.height >= decoded.width ? 1200 : -1);
    } else {
      resized = decoded;
    }
    
    final compressed = img.encodeJpg(resized, quality: 75);
    final base64Image = base64Encode(compressed);

    final response = await http.post(
      Uri.parse('https://cash-rheo.vercel.app/api/scan-document'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'image': 'data:image/jpeg;base64,$base64Image',
        'width': resized.width,
        'height': resized.height,
      }),
    ).timeout(const Duration(seconds: 40));

    if (response.statusCode != 200) {
      throw Exception('Greska: ${response.statusCode}');
    }

    final pdfBytes = response.bodyBytes;
    final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}.pdf';

    await supabase.storage.from('documents').uploadBinary(
      fileName, pdfBytes,
      fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
    );

    final pdfUrl = supabase.storage.from('documents').getPublicUrl(fileName);

    await supabase.from('documents').insert({
      'user_id': userId,
      'company_id': 'aa8a914b-9b47-4f99-985a-aedcc4991ed1',
      'doc_type': 'scan',
      'file_url': pdfUrl,
      'created_at': DateTime.now().toIso8601String(),
    });

    return pdfUrl;
  }
}
