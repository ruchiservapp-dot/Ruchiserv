import 'package:ruchiserv/core/app_logger.dart';
// lib/services/s3_upload_service.dart
// S3 Upload Service — Handles image compression, presigned URL upload, and offline queue.
//
// Flow:
//   1. Compress image (JPEG 70%, max 1024px)
//   2. Request presigned PUT URL from Lambda
//   3. Upload directly to S3 (no Lambda in data path)
//   4. Return S3 key for storage in DB
//
// Offline: Queues locally for retry when connectivity returns.

import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../db/aws/aws_api.dart';

class S3UploadService {
  static final S3UploadService _instance = S3UploadService._internal();
  factory S3UploadService() => _instance;
  S3UploadService._internal();

  // Maximum image dimension (width or height)
  static const int _maxDimension = 1024;
  // JPEG quality (0-100)
  static const int _jpegQuality = 70;

  /// Upload an image to S3 with compression.
  ///
  /// Returns the S3 key (e.g., 'FIRMID/invoices/inv_20260217_143022_a1b2c3d4.jpg')
  /// or null if the upload failed (will be queued for retry).
  Future<String?> uploadImage({
    required File imageFile,
    required String fileType, // 'invoices', 'staff_photos', 'utensils'
    String? fileName,
  }) async {
    try {
      // 1. Compress image
      final compressedBytes = await _compressImage(imageFile);
      if (compressedBytes == null) {
        AppLogger.error('❌ S3Upload: Failed to compress image');
        return null;
      }

      AppLogger.info('📸 S3Upload: Compressed ${imageFile.lengthSync()} -> ${compressedBytes.length} bytes '
          '(${(compressedBytes.length / imageFile.lengthSync() * 100).toStringAsFixed(0)}%)');

      // 2. Get presigned upload URL from Lambda
      final urlResult = await _getUploadUrl(fileType: fileType, fileName: fileName);
      if (urlResult == null) {
        // Offline or error — queue for later
        AppLogger.info('⏳ S3Upload: Offline, queuing upload...');
        await _queueUpload(compressedBytes, fileType, fileName);
        return null;
      }

      final uploadUrl = urlResult['uploadUrl'] as String;
      final s3Key = urlResult['s3Key'] as String;

      // 3. Upload directly to S3 via presigned URL
      final response = await http.put(
        Uri.parse(uploadUrl),
        headers: {'Content-Type': 'image/jpeg'},
        body: compressedBytes,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        AppLogger.success('✅ S3Upload: Uploaded successfully -> $s3Key');
        return s3Key;
      } else {
        AppLogger.error('❌ S3Upload: Upload failed with status ${response.statusCode}');
        await _queueUpload(compressedBytes, fileType, fileName);
        return null;
      }
    } catch (e) {
      AppLogger.error('❌ S3Upload: Error: $e');
      // Try to queue for later
      try {
        final bytes = await imageFile.readAsBytes();
        await _queueUpload(bytes, fileType, fileName);
      } catch (_) {}
      return null;
    }
  }

  /// Get a viewable download URL for an S3 image.
  ///
  /// Returns a presigned GET URL valid for 1 hour.
  Future<String?> getDownloadUrl(String s3Key) async {
    try {
      final result = await AwsApi.post(
        path: 'dbhandler',
        body: {
          'table': 'files/download-url',
          'data': {'s3Key': s3Key},
        },
      );

      return result['downloadUrl'] as String?;
    } catch (e) {
      AppLogger.error('❌ S3Upload: Failed to get download URL: $e');
      return null;
    }
  }

  /// Compress image to JPEG with max dimension and quality.
  Future<Uint8List?> _compressImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return null;

      // Resize if larger than max dimension
      if (image.width > _maxDimension || image.height > _maxDimension) {
        if (image.width > image.height) {
          image = img.copyResize(image, width: _maxDimension);
        } else {
          image = img.copyResize(image, height: _maxDimension);
        }
      }

      // Encode as JPEG
      return Uint8List.fromList(img.encodeJpg(image, quality: _jpegQuality));
    } catch (e) {
      AppLogger.error('❌ S3Upload: Compression error: $e');
      return null;
    }
  }

  /// Get presigned upload URL from Lambda.
  Future<Map<String, dynamic>?> _getUploadUrl({
    required String fileType,
    String? fileName,
  }) async {
    try {
      final result = await AwsApi.post(
        path: 'dbhandler',
        body: {
          'table': 'files/upload-url',
          'data': {
            'fileType': fileType,
            if (fileName != null) 'fileName': fileName,
          },
        },
      );
      return result;
    } catch (e) {
      AppLogger.error('❌ S3Upload: Failed to get upload URL: $e');
      return null;
    }
  }

  // ── Offline Queue ──────────────────────────────────────────

  static const String _queueKey = 's3_upload_queue';

  /// Queue a failed upload for retry.
  Future<void> _queueUpload(Uint8List bytes, String fileType, String? fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final queueDir = Directory('${dir.path}/.upload_queue');
      if (!await queueDir.exists()) await queueDir.create(recursive: true);

      final tempFile = File('${queueDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(bytes);

      final sp = await SharedPreferences.getInstance();
      final queue = sp.getStringList(_queueKey) ?? [];
      queue.add(json.encode({
        'filePath': tempFile.path,
        'fileType': fileType,
        'fileName': fileName,
        'queuedAt': DateTime.now().toIso8601String(),
      }));
      await sp.setStringList(_queueKey, queue);

      AppLogger.info('📋 S3Upload: Queued upload (${queue.length} in queue)');
    } catch (e) {
      AppLogger.error('❌ S3Upload: Failed to queue: $e');
    }
  }

  /// Process all queued uploads. Call this on connectivity change or app resume.
  Future<int> processQueue() async {
    final sp = await SharedPreferences.getInstance();
    final queue = sp.getStringList(_queueKey) ?? [];
    if (queue.isEmpty) return 0;

    AppLogger.info('📋 S3Upload: Processing ${queue.length} queued uploads...');
    int processed = 0;
    final remaining = <String>[];

    for (final item in queue) {
      try {
        final data = json.decode(item) as Map<String, dynamic>;
        final file = File(data['filePath']);
        if (!await file.exists()) continue;

        final s3Key = await uploadImage(
          imageFile: file,
          fileType: data['fileType'],
          fileName: data['fileName'],
        );

        if (s3Key != null) {
          processed++;
          await file.delete(); // Clean up temp file
        } else {
          remaining.add(item);
        }
      } catch (e) {
        remaining.add(item);
      }
    }

    await sp.setStringList(_queueKey, remaining);
    AppLogger.success('✅ S3Upload: Processed $processed, ${remaining.length} remaining');
    return processed;
  }
}
