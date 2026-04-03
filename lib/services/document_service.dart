import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

class DocCorners {
  Offset topLeft, topRight, bottomLeft, bottomRight;
  double confidence;

  DocCorners({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
    this.confidence = 0.0,
  });

  factory DocCorners.fullImage(double w, double h) {
    final mx = w * 0.05;
    final my = h * 0.05;
    return DocCorners(
      topLeft: Offset(mx, my),
      topRight: Offset(w - mx, my),
      bottomLeft: Offset(mx, h - my),
      bottomRight: Offset(w - mx, h - my),
    );
  }
}

enum DocFilter { original, blackWhite, highContrast, sharp }

class DocumentService {
  static const _baseUrl = 'https://cash-rheo.vercel.app';

  /// Detect document edges via Gemini AI
  static Future<DocCorners> detectEdges(Uint8List imageBytes) async {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return DocCorners.fullImage(1000, 1400);

    // Resize for faster AI processing (max 1024 longest side)
    final longestSide = math.max(decoded.width, decoded.height).toDouble();
    final scale = math.min(1.0, 1024.0 / longestSide);
    img.Image resized;
    if (scale < 1.0) {
      resized = img.copyResize(decoded,
          width: (decoded.width * scale).round(),
          height: (decoded.height * scale).round());
    } else {
      resized = decoded;
    }

    final resizedJpeg = img.encodeJpg(resized, quality: 80);
    final base64Image = base64Encode(resizedJpeg);

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/detect-edges'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'image': base64Image,
              'width': resized.width,
              'height': resized.height,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final invScale = 1.0 / scale;

        return DocCorners(
          topLeft: Offset(
            (data['topLeft']['x'] as num).toDouble() * invScale,
            (data['topLeft']['y'] as num).toDouble() * invScale,
          ),
          topRight: Offset(
            (data['topRight']['x'] as num).toDouble() * invScale,
            (data['topRight']['y'] as num).toDouble() * invScale,
          ),
          bottomLeft: Offset(
            (data['bottomLeft']['x'] as num).toDouble() * invScale,
            (data['bottomLeft']['y'] as num).toDouble() * invScale,
          ),
          bottomRight: Offset(
            (data['bottomRight']['x'] as num).toDouble() * invScale,
            (data['bottomRight']['y'] as num).toDouble() * invScale,
          ),
          confidence: (data['confidence'] as num?)?.toDouble() ?? 0.5,
        );
      }
    } catch (_) {}

    return DocCorners.fullImage(decoded.width.toDouble(), decoded.height.toDouble());
  }

  /// Perspective crop using bilinear interpolation
  static Uint8List perspectiveCrop(Uint8List imageBytes, DocCorners corners) {
    final src = img.decodeImage(imageBytes);
    if (src == null) return imageBytes;

    final topW = _dist(corners.topLeft, corners.topRight);
    final botW = _dist(corners.bottomLeft, corners.bottomRight);
    final leftH = _dist(corners.topLeft, corners.bottomLeft);
    final rightH = _dist(corners.topRight, corners.bottomRight);

    final w = math.max(topW, botW).round().clamp(100, 4000);
    final h = math.max(leftH, rightH).round().clamp(100, 6000);

    final dst = img.Image(width: w, height: h);

    for (int y = 0; y < h; y++) {
      final ty = y / (h - 1);
      for (int x = 0; x < w; x++) {
        final tx = x / (w - 1);

        final topX = corners.topLeft.dx + tx * (corners.topRight.dx - corners.topLeft.dx);
        final topY = corners.topLeft.dy + tx * (corners.topRight.dy - corners.topLeft.dy);
        final botX = corners.bottomLeft.dx + tx * (corners.bottomRight.dx - corners.bottomLeft.dx);
        final botY = corners.bottomLeft.dy + tx * (corners.bottomRight.dy - corners.bottomLeft.dy);

        final srcX = (topX + ty * (botX - topX)).clamp(0, src.width - 1).toInt();
        final srcY = (topY + ty * (botY - topY)).clamp(0, src.height - 1).toInt();

        dst.setPixel(x, y, src.getPixel(srcX, srcY));
      }
    }

    return Uint8List.fromList(img.encodeJpg(dst, quality: 95));
  }

  /// Apply image filter
  static Uint8List applyFilter(Uint8List imageBytes, DocFilter filter) {
    if (filter == DocFilter.original) return imageBytes;

    final src = img.decodeImage(imageBytes);
    if (src == null) return imageBytes;

    img.Image result;
    switch (filter) {
      case DocFilter.blackWhite:
        result = img.grayscale(src);
        // Simple threshold for clean B&W
        for (int y = 0; y < result.height; y++) {
          for (int x = 0; x < result.width; x++) {
            final p = result.getPixel(x, y);
            final lum = img.getLuminance(p);
            if (lum > 140) {
              result.setPixelRgb(x, y, 255, 255, 255);
            } else {
              result.setPixelRgb(x, y, 0, 0, 0);
            }
          }
        }
        break;
      case DocFilter.highContrast:
        result = img.grayscale(src);
        result = img.adjustColor(result, contrast: 1.8);
        break;
      case DocFilter.sharp:
        result = img.adjustColor(src, contrast: 1.3);
        break;
      default:
        result = src;
    }

    return Uint8List.fromList(img.encodeJpg(result, quality: 92));
  }

  /// Generate PDF via Vercel and upload to Supabase
  static Future<String> generateAndUpload(Uint8List processedImage) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Niste prijavljeni');

    final base64Image = base64Encode(processedImage);

    // Decode to get actual dimensions
    final decoded = img.decodeImage(processedImage);
    final w = decoded?.width ?? 1200;
    final h = decoded?.height ?? 1600;

    final response = await http.post(
      Uri.parse('$_baseUrl/api/scan-document'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'image': 'data:image/jpeg;base64,$base64Image',
        'width': w,
        'height': h,
      }),
    ).timeout(const Duration(seconds: 40));

    if (response.statusCode != 200) throw Exception('PDF greska: ${response.statusCode}');

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

  /// Legacy method for backward compat
  static Future<String> scanAndUpload(Uint8List imageBytes) async {
    return generateAndUpload(imageBytes);
  }

  static double _dist(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return math.sqrt(dx * dx + dy * dy);
  }
}
