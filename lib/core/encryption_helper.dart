import 'package:ruchiserv/core/app_logger.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

/// COMPLIANCE: Rule C.3 - Data Encryption at Rest
/// Encrypts PII fields (mobile, email) using AES-256 encryption
/// Uses random IV per encryption for proper security.
class EncryptionHelper {
  static final _storage = const FlutterSecureStorage();
  static const _keyName = 'pii_encryption_key';
  static Encrypter? _encrypter;
  static Key? _key;

  // Legacy fixed IV for migrating old data
  static final _legacyIV = IV.fromLength(16);

  /// Initialize encryption on app startup
  /// CRITICAL: Must be called before any database operations
  static Future<void> initialize() async {
    String? keyStr;

    try {
      keyStr = await _storage.read(key: _keyName);
    } catch (e) {
      AppLogger.info(
          'WARNING: Secure Storage failed ($e). Using local file fallback for DEV.');
      keyStr = await _readFallbackKey();
    }

    if (keyStr == null) {
      // Generate new 256-bit key on first run
      final key = Key.fromSecureRandom(32); // 32 bytes = 256 bits
      keyStr = key.base64;

      try {
        await _storage.write(key: _keyName, value: keyStr);
      } catch (e) {
        AppLogger.info(
            'WARNING: Secure Storage write failed ($e). Saving to local file fallback for DEV.');
        await _saveFallbackKey(keyStr);
      }
    }

    _key = Key.fromBase64(keyStr);
    _encrypter = Encrypter(AES(_key!));
  }

  // FALLBACK: For local macOS dev without signing (Rule C.3 Exception)
  static Future<String?> _readFallbackKey() async {
    if (kIsWeb) return null;
    try {
      final file = await _getFallbackFile();
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {
      AppLogger.error('Caught error: $_');
    }
    return null;
  }

  static Future<void> _saveFallbackKey(String key) async {
    // Web does not support dart:io File fallback
    if (kIsWeb) return;
    try {
      final file = await _getFallbackFile();
      await file.writeAsString(key);
    } catch (_) {
      AppLogger.error('Caught error: $_');
    }
  }

  static Future<File> _getFallbackFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/.pii_key_fallback');
  }

  /// Encrypt PII field (mobile, email)
  /// Returns base64-encoded string: first 16 bytes = IV, rest = ciphertext
  static String? encrypt(String? plaintext) {
    if (plaintext == null || plaintext.isEmpty) return null;
    if (_encrypter == null) {
      throw Exception(
          'Encryption not initialized. Call EncryptionHelper.initialize() first.');
    }
    // Generate random IV for every encryption operation
    final iv = IV.fromSecureRandom(16);
    final encrypted = _encrypter!.encrypt(plaintext, iv: iv);
    // Prepend IV bytes to ciphertext bytes, then base64-encode the whole thing
    final combined = Uint8List.fromList(iv.bytes + encrypted.bytes);
    return base64.encode(combined);
  }

  /// Decrypt PII field
  /// Extracts IV from first 16 bytes of ciphertext, then decrypts.
  /// Falls back to legacy fixed-IV decryption for old data.
  static String? decrypt(String? ciphertext) {
    if (ciphertext == null || ciphertext.isEmpty) return null;
    if (_encrypter == null) {
      throw Exception(
          'Encryption not initialized. Call EncryptionHelper.initialize() first.');
    }
    try {
      final combined = base64.decode(ciphertext);
      if (combined.length <= 16) {
        // Too short — try legacy decryption
        return _legacyDecrypt(ciphertext);
      }
      // Extract IV (first 16 bytes) and ciphertext (rest)
      final iv = IV(Uint8List.fromList(combined.sublist(0, 16)));
      final encryptedBytes = Uint8List.fromList(combined.sublist(16));
      final encrypted = Encrypted(encryptedBytes);
      return _encrypter!.decrypt(encrypted, iv: iv);
    } catch (_) {
      // Fallback: try legacy fixed-IV decryption for old data
      return _legacyDecrypt(ciphertext);
    }
  }

  /// Legacy decryption with fixed IV for backward compatibility
  static String? _legacyDecrypt(String? ciphertext) {
    if (ciphertext == null || ciphertext.isEmpty) return null;
    try {
      return _encrypter!.decrypt64(ciphertext, iv: _legacyIV);
    } catch (_) {
      // Return null for genuinely invalid data
      return null;
    }
  }
}
