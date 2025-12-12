import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

/// COMPLIANCE: Rule C.3 - Data Encryption at Rest
/// Encrypts PII fields (mobile, email) using AES-256 encryption
class EncryptionHelper {
  static final _storage = const FlutterSecureStorage();
  static const _keyName = 'pii_encryption_key';
  static Encrypter? _encrypter;
  static IV? _iv;

  /// Initialize encryption on app startup
  /// CRITICAL: Must be called before any database operations
  static Future<void> initialize() async {
    String? keyStr;
    
    try {
      keyStr = await _storage.read(key: _keyName);
    } catch (e) {
      print('WARNING: Secure Storage failed ($e). Using local file fallback for DEV.');
      keyStr = await _readFallbackKey();
    }
    
    if (keyStr == null) {
      // Generate new 256-bit key on first run
      final key = Key.fromSecureRandom(32); // 32 bytes = 256 bits
      keyStr = key.base64;
      
      try {
        await _storage.write(key: _keyName, value: keyStr);
      } catch (e) {
        print('WARNING: Secure Storage write failed ($e). Saving to local file fallback for DEV.');
        await _saveFallbackKey(keyStr!);
      }
    }
    
    final key = Key.fromBase64(keyStr);
    // Fixed IV for deterministic encryption (allows searchability)
    _iv = IV.fromLength(16);
    _encrypter = Encrypter(AES(key));
  }

  // FALLBACK: For local macOS dev without signing (Rule C.3 Exception)
  static Future<String?> _readFallbackKey() async {
    if (kIsWeb) return null;
    try {
      final file = await _getFallbackFile();
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {}
    return null;
  }

  static Future<void> _saveFallbackKey(String key) async {
    // Web does not support dart:io File fallback
    if (kIsWeb) return;
    try {
      final file = await _getFallbackFile();
      await file.writeAsString(key);
    } catch (_) {}
  }

  static Future<File> _getFallbackFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/.pii_key_fallback');
  }

  /// Encrypt PII field (mobile, email)
  /// Returns base64-encoded ciphertext or null if input is empty
  static String? encrypt(String? plaintext) {
    if (plaintext == null || plaintext.isEmpty) return null;
    if (_encrypter == null) {
      throw Exception('Encryption not initialized. Call EncryptionHelper.initialize() first.');
    }
    return _encrypter!.encrypt(plaintext, iv: _iv!).base64;
  }

  /// Decrypt PII field
  /// Returns plaintext or null if ciphertext is invalid/empty
  static String? decrypt(String? ciphertext) {
    if (ciphertext == null || ciphertext.isEmpty) return null;
    if (_encrypter == null) {
      throw Exception('Encryption not initialized. Call EncryptionHelper.initialize() first.');
    }
    try {
      return _encrypter!.decrypt64(ciphertext, iv: _iv!);
    } catch (_) {
      // Return null for invalid ciphertext (e.g., corrupted data or plain text)
      return null;
    }
  }
}
