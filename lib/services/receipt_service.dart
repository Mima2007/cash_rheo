import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'pdf_service.dart';

final supabase = Supabase.instance.client;

class ReceiptService {
  static Future<void> saveReceipts(List<Map<String, dynamic>> receipts) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Niste prijavljeni');

    for (final receipt in receipts) {
      final isPhoto = receipt['_isPhoto'] == true;

      if (isPhoto) {
        final bytes = receipt['_photoBytes'] as Uint8List;
        final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await supabase.storage.from('receipts').uploadBinary(fileName, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
        final imageUrl = supabase.storage.from('receipts').getPublicUrl(fileName);

        await supabase.from('receipts').insert({
          'user_id': userId,
          'qr_url': '',
          'status': 'photo',
          'total_amount': 0,
          'pfr_number': '',
          'pfr_time': DateTime.now().toIso8601String(),
          'vendor_name': '',
          'vendor_pib': '',
          'is_manual': true,
          'image_url': imageUrl,
          'json_raw': {},
        });
      } else {
        final qrUrl = receipt['_qrUrl'] as String? ?? '';
        final invoiceResult = receipt['invoiceResult'] as Map<String, dynamic>? ?? {};
        final invoiceRequest = receipt['invoiceRequest'] as Map<String, dynamic>? ?? {};
        final journal = receipt['journal'] as String? ?? '';
        final isValid = receipt['isValid'] as bool? ?? false;

        final pfrNumber = invoiceResult['invoiceNumber'] ?? '';
        final totalAmount = invoiceResult['totalAmount'] ?? invoiceRequest['totalAmount'] ?? 0;
        final pfrTime = invoiceResult['sdcDateTime'] ?? DateTime.now().toIso8601String();

        final lines = journal.split('\n');
        final vendorName = lines.length > 2 ? lines[1].trim() : '';
        final vendorPib = lines.isNotEmpty ? lines[0].replaceAll(RegExp(r'[^0-9]'), '') : '';

        // Generiši PDF i uploaduj
        String pdfUrl = '';
        try {
          pdfUrl = await PdfService.generateAndUpload(receipt);
        } catch (e) {
          print("PDF GRESKA: $e"); rethrow;
        }

        final insertedReceipt = await supabase.from('receipts').insert({
          'user_id': userId,
          'qr_url': qrUrl,
          'status': isValid ? 'valid' : 'invalid',
          'total_amount': totalAmount is num ? totalAmount : num.tryParse(totalAmount.toString()) ?? 0,
          'pfr_number': pfrNumber,
          'pfr_time': pfrTime,
          'vendor_name': vendorName,
          'vendor_pib': vendorPib,
          'is_manual': false,
          'image_url': pdfUrl,
          'json_raw': receipt,
        }).select().single();

        final items = invoiceRequest['items'] as List<dynamic>? ?? invoiceResult['items'] as List<dynamic>? ?? [];
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            await supabase.from('receipt_items').insert({
              'receipt_id': insertedReceipt['id'],
              'item_name': item['name'] ?? '',
              'quantity': item['quantity'] ?? 0,
              'unit_price': item['unitPrice'] ?? item['price'] ?? 0,
              'total_price': item['totalAmount'] ?? item['total'] ?? 0,
            });
          }
        }
      }
    }
  }
}
