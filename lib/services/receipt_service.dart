import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'pdf_service.dart';

final supabase = Supabase.instance.client;

class ReceiptService {
  static const String _defaultCompanyId = 'aa8a914b-9b47-4f99-985a-aedcc4991ed1';

  static double _parseNum(String s) {
    // "35.606,48" -> 35606.48  ili  "182,00" -> 182.0
    return double.tryParse(s.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;
  }

  static List<Map<String, dynamic>> _parseItems(String journal) {
    final items = <Map<String, dynamic>>[];
    final lines = journal.split('\n').map((l) => l.trim()).toList();

    // Nadji liniju zaglavlja "Назив  Цена  Кол.  Укупно"
    int headerIdx = -1;
    for (int i = 0; i < lines.length; i++) {
      final l = lines[i];
      if ((l.contains('Назив') || l.contains('naziv') || l.contains('Name')) &&
          (l.contains('Цена') || l.contains('cena') || l.contains('Price'))) {
        headerIdx = i;
        break;
      }
    }
    if (headerIdx == -1) return items;

    // Citaj od sledece linije posle headera
    int i = headerIdx + 1;
    while (i < lines.length) {
      final line = lines[i];

      // Stop na separatoru ili praznoj totalnoj liniji
      if (line.startsWith('---') || line.startsWith('===') ||
          line.contains('Укупан') || line.contains('Ukupan') ||
          line.contains('Укупно') || line.isEmpty) {
        break;
      }

      // Sledeci red treba da su brojevi (cena  kolicina  ukupno)
      if (i + 1 < lines.length) {
        final nextLine = lines[i + 1];
        // Regex: 3 broja odvojena razmakom
        final numRegex = RegExp(
          r'(\d[\d.,]*)\s+(\d[\d.,]*)\s+(\d[\d.,]*)$'
        );
        final match = numRegex.firstMatch(nextLine);
        if (match != null) {
          final itemName = line.replaceAll(RegExp(r'\s*\([А-ЯA-Z]\)\s*$'), '').trim();
          final unitPrice = _parseNum(match.group(1)!);
          final quantity  = _parseNum(match.group(2)!);
          final totalPrice = _parseNum(match.group(3)!);
          items.add({
            'item_name': itemName,
            'quantity': quantity,
            'unit_price': unitPrice,
            'total_price': totalPrice,
          });
          i += 2; // preskoči oba reda
          continue;
        }
      }
      i++;
    }
    return items;
  }

  static Future<String?> _findCompanyId(String pib) async {
    if (pib.isEmpty) return null;
    try {
      final result = await supabase
          .from('companies')
          .select('id')
          .eq('pib', pib)
          .maybeSingle();
      return result?['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveReceipts(List<Map<String, dynamic>> receipts) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Niste prijavljeni');

    for (final receipt in receipts) {
      final isPhoto = receipt['_isPhoto'] == true;

      if (isPhoto) {
        final bytes = receipt['_photoBytes'] as Uint8List;
        final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await supabase.storage.from('receipts').uploadBinary(
          fileName, bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
        final imageUrl = supabase.storage.from('receipts').getPublicUrl(fileName);
        await supabase.from('receipts').insert({
          'user_id': userId,
          'company_id': _defaultCompanyId,
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
        final pfrTime = invoiceResult['sdcTime'] ?? DateTime.now().toIso8601String();

        final vendorPib = invoiceRequest['taxId'] as String? ?? '';
        final vendorName = invoiceRequest['businessName'] as String? ?? '';

        final companyId = await _findCompanyId(vendorPib) ?? _defaultCompanyId;

        String pdfUrl = '';
        try {
          pdfUrl = await PdfService.generateAndUpload(receipt);
        } catch (e) {
          print("PDF GRESKA: $e");
        }

        final insertedReceipt = await supabase.from('receipts').insert({
          'user_id': userId,
          'company_id': companyId,
          'qr_url': qrUrl,
          'status': isValid ? 'valid' : 'invalid',
          'total_amount': totalAmount is num
              ? totalAmount
              : num.tryParse(totalAmount.toString()) ?? 0,
          'pfr_number': pfrNumber,
          'pfr_time': pfrTime,
          'vendor_name': vendorName,
          'vendor_pib': vendorPib,
          'is_manual': false,
          'image_url': pdfUrl,
          'json_raw': receipt,
        }).select().single();

        final items = _parseItems(journal);
        for (final item in items) {
          await supabase.from('receipt_items').insert({
            'receipt_id': insertedReceipt['id'],
            ...item,
          });
        }
      }
    }
  }
}
