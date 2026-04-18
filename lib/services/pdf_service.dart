import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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

  static Future<Uint8List> generatePdfBytes(Map<String, dynamic> receipt) async {
    final journal = receipt['journal'] as String? ?? '';
    final qrUrl = receipt['_qrUrl'] as String? ?? '';
    final response = await http.post(
      Uri.parse('https://cash-rheo.vercel.app/api/generate-pdf'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'journal': journal, 'qrUrl': qrUrl}),
    );
    if (response.statusCode != 200) {
      throw Exception('PDF greska ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  static Future<void> shareViaMail(List<Map<String, dynamic>> receipts, String userEmail) async {
    final dir = await getTemporaryDirectory();
    final files = <XFile>[];
    for (int i = 0; i < receipts.length; i++) {
      final receipt = receipts[i];
      final isPhoto = receipt['_isPhoto'] == true;
      if (isPhoto) {
        final bytes = receipt['_photoBytes'] as Uint8List;
        final file = File('${dir.path}/racun_${i + 1}.jpg');
        await file.writeAsBytes(bytes);
        files.add(XFile(file.path));
      } else {
        final pdfBytes = await generatePdfBytes(receipt);
        final invoiceResult = receipt['invoiceResult'] as Map<String, dynamic>? ?? {};
        final pfrNumber = invoiceResult['invoiceNumber'] ?? 'racun_${i + 1}';
        final file = File('${dir.path}/$pfrNumber.pdf');
        await file.writeAsBytes(pdfBytes);
        files.add(XFile(file.path));
      }
    }
    await SharePlus.instance.share(
      ShareParams(
        files: files,
        subject: 'Cash Rheo - ${receipts.length} racuna',
        text: 'Poslato iz Cash Rheo aplikacije',
        
      ),
    );
  }
}
