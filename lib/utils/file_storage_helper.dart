import 'package:ruchiserv/core/app_logger.dart';
// lib/utils/file_storage_helper.dart
// S3-First File Storage with Local Cache.
//
// Strategy:
//   - Upload: Compress → S3 → store S3 key in DB
//   - View: Check local cache → if miss, get presigned URL from S3 → cache locally
//   - Cache limit: 100MB, LRU eviction
//
// The imageUrl field in the DB now stores S3 keys (e.g., 'FIRMID/invoices/inv_123.jpg')
// instead of local file paths.

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../services/s3_upload_service.dart';

class FileStorageHelper {
  // ── Upload (S3-First) ────────────────────────────────────

  /// Upload an image to S3. Returns the S3 key for storage in DB.
  /// Falls back to local-only storage if S3 upload fails (queued for retry).
  static Future<String> saveAndUploadImage(
    File imageFile, {
    String fileType = 'invoices',
  }) async {
    final s3Service = S3UploadService();

    // Try S3 upload first
    final s3Key = await s3Service.uploadImage(
      imageFile: imageFile,
      fileType: fileType,
    );

    if (s3Key != null) {
      // Also cache locally for immediate offline access
      await _cacheFile(imageFile, s3Key);
      return s3Key;
    }

    // Fallback: save locally with a pending marker prefix
    // The queue processor will upload later
    final localPath = await _saveLocally(imageFile, fileType);
    return 'pending:$localPath';
  }

  // ── Download / View ──────────────────────────────────────

  /// Check if a file exists locally (cache or legacy path).
  static bool fileExists(String? pathOrKey) {
    if (pathOrKey == null || pathOrKey.isEmpty) return false;
    
    // Legacy local file path
    if (pathOrKey.startsWith('/')) return File(pathOrKey).existsSync();
    
    // Pending upload (still local)
    if (pathOrKey.startsWith('pending:')) {
      return File(pathOrKey.substring(8)).existsSync();
    }
    
    // S3 key — check local cache
    final cachePath = _getCachePath(pathOrKey);
    if (cachePath != null) return File(cachePath).existsSync();
    
    return false;
  }
  
  /// Get the local file path for display (cache, legacy, or pending).
  /// Returns null if file needs to be downloaded from S3 first.
  static String? getLocalPath(String? pathOrKey) {
    if (pathOrKey == null || pathOrKey.isEmpty) return null;
    
    // Legacy local path
    if (pathOrKey.startsWith('/')) return pathOrKey;
    
    // Pending upload
    if (pathOrKey.startsWith('pending:')) return pathOrKey.substring(8);
    
    // S3 key — check cache
    return _getCachePath(pathOrKey);
  }

  /// Get a displayable URL or file path for an image.
  /// For S3 keys, this will return a presigned URL.
  /// For local files, returns the file path directly.
  static Future<String?> getViewableUrl(String? pathOrKey) async {
    if (pathOrKey == null || pathOrKey.isEmpty) return null;
    
    // Legacy local path
    if (pathOrKey.startsWith('/')) return pathOrKey;
    
    // Pending upload
    if (pathOrKey.startsWith('pending:')) return pathOrKey.substring(8);
    
    // S3 key — check cache first
    final cached = _getCachePath(pathOrKey);
    if (cached != null && File(cached).existsSync()) return cached;
    
    // Download from S3
    final s3Service = S3UploadService();
    final url = await s3Service.getDownloadUrl(pathOrKey);
    
    if (url != null) {
      // Download and cache
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final cacheFile = await _ensureCachePath(pathOrKey);
          await cacheFile.writeAsBytes(response.bodyBytes);
          return cacheFile.path;
        }
      } catch (e) {
        AppLogger.warning('⚠️ FileStorage: Cache download failed: $e');
        return url; // Return the presigned URL directly as fallback
      }
    }
    
    return null;
  }

  /// Check if a path/key represents an S3 key (not a local path).
  static bool isS3Key(String? pathOrKey) {
    if (pathOrKey == null || pathOrKey.isEmpty) return false;
    return !pathOrKey.startsWith('/') && !pathOrKey.startsWith('pending:');
  }

  // ── Cache Management ─────────────────────────────────────

  static String? _cacheBasePath;

  static String? _getCachePath(String s3Key) {
    if (_cacheBasePath == null) return null;
    final safeName = s3Key.replaceAll('/', '_');
    return '$_cacheBasePath/$safeName';
  }

  static Future<File> _ensureCachePath(String s3Key) async {
    if (_cacheBasePath == null) {
      final dir = await getApplicationDocumentsDirectory();
      _cacheBasePath = '${dir.path}/.image_cache';
      await Directory(_cacheBasePath!).create(recursive: true);
    }
    final safeName = s3Key.replaceAll('/', '_');
    return File('$_cacheBasePath/$safeName');
  }

  static Future<void> _cacheFile(File source, String s3Key) async {
    try {
      final cacheFile = await _ensureCachePath(s3Key);
      await source.copy(cacheFile.path);
    } catch (e) {
      AppLogger.warning('⚠️ FileStorage: Cache write failed: $e');
    }
  }

  /// Initialize cache directory on app startup.
  static Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    _cacheBasePath = '${dir.path}/.image_cache';
    await Directory(_cacheBasePath!).create(recursive: true);
  }

  /// Clear cache if it exceeds 100MB.
  static Future<void> cleanCacheIfNeeded() async {
    if (_cacheBasePath == null) return;
    final cacheDir = Directory(_cacheBasePath!);
    if (!await cacheDir.exists()) return;

    int totalBytes = 0;
    final files = <FileSystemEntity>[];
    
    await for (final entity in cacheDir.list()) {
      if (entity is File) {
        totalBytes += await entity.length();
        files.add(entity);
      }
    }

    // 100MB cache limit
    if (totalBytes > 100 * 1024 * 1024) {
      // Sort by modified time (oldest first) and delete until under limit
      files.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
      
      for (final file in files) {
        if (totalBytes <= 50 * 1024 * 1024) break; // Target 50MB
        final size = await (file as File).length();
        await file.delete();
        totalBytes -= size;
      }
      AppLogger.info('🗑️ FileStorage: Cleaned cache, now ${(totalBytes / 1024 / 1024).toStringAsFixed(1)}MB');
    }
  }

  // ── Legacy Local Storage (Fallback) ──────────────────────

  static Future<String> _saveLocally(File imageFile, String fileType) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/$fileType');
    if (!await dir.exists()) await dir.create(recursive: true);

    final fileName = '${fileType}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedFile = await imageFile.copy('${dir.path}/$fileName');
    return savedFile.path;
  }

  // ── Legacy method for backward compatibility ─────────────

  /// @deprecated Use saveAndUploadImage instead
  static Future<String> saveInvoiceImage(File imageFile) async {
    return saveAndUploadImage(imageFile, fileType: 'invoices');
  }
}
