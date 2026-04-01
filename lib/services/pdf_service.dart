import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
final supabase = Supabase.instance.client;
class PdfService {
  static Future<String> generateAndUpload(Map<String, dynamic> receipt) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('KORAK 1: userId null');
    final journal = receipt['journal'] as String? ?? '';
    final invoiceResult = receipt['invoiceResult'] as Map<String, dynamic>? ?? {};
    final pfrNumber = invoiceResult['invoiceNumber'] ?? 'racun';
    final qrUrl = receipt['_qrUrl'] as String? ?? '';
    late Uint8List pdfBytes;
    try {
      final response = await http.post(
        Uri.parse('https://cash-rheo.vercel.app/api/generate-pdf'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'journal': journal, 'qrUrl': qrUrl}),
      );
      if (response.statusCode != 200) {
        throw Exception('Vercel greska ${response.statusCode}: ${response.body}');
      }
      pdfBytes = response.bodyBytes;
    } catch (e) {
      throw Exception('KORAK 2 PDF generisanje: $e');
    }
    try {
      final fileName = '$userId/$pfrNumber.pdf';
      await supabase.storage.from('receipts').uploadBinary(
        fileName,
        pdfBytes,
        fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
      );
      return supabase.storage.from('receipts').getPublicUrl(fileName);
    } catch (e) {
      throw Exception('KORAK 3 upload: $e');
    }
  }
}
