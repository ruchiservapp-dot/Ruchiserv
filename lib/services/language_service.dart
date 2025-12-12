import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/translation_model.dart';

class LanguageService {
  static final LanguageService _instance = LanguageService._internal();

  factory LanguageService() {
    return _instance;
  }

  LanguageService._internal();

  // Cache for translations: Map<LanguageCode, Map<Key, String>>
  // Key = "EntityType_EntityId" e.g "DISH_101"
  final Map<String, Map<String, String>> _cache = {};

  String _currentLanguage = 'en';

  String get currentLanguage => _currentLanguage;

  void setLanguage(String code) {
    _currentLanguage = code;
    // Potentially load cache for this language
  }

  /// Initial Load of translations from DB for the active language
  Future<void> loadTranslations(String languageCode) async {
    if (languageCode == 'en') return;

    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'content_translations',
      where: 'language_code = ?',
      whereArgs: [languageCode],
    );

    if (maps.isEmpty) {
      // Lazy load from seed if empty
      await seedTranslations(languageCode);
      // Re-query after seeding
      final retryMaps = await db.query(
        'content_translations',
        where: 'language_code = ?',
        whereArgs: [languageCode],
      );
      if (retryMaps.isNotEmpty) {
        _cache[languageCode] = {};
        for (var map in retryMaps) {
          final t = ContentTranslation.fromJson(map);
          final key = '${t.entityType}_${t.entityId}';
          _cache[languageCode]![key] = t.translatedText;
        }
        return;
      }
    }

    _cache[languageCode] = {};
    for (var map in maps) {
      final t = ContentTranslation.fromJson(map);
      final key = '${t.entityType}_${t.entityId}';
      _cache[languageCode]![key] = t.translatedText;
    }
  }

  /// Get display name for an entity
  /// Returns translated text if available, otherwise returns defaultName
  String getLocalizedName({
    required String entityType, // 'DISH' or 'INGREDIENT'
    required int entityId,
    required String defaultName,
  }) {
    if (_currentLanguage == 'en') return defaultName;

    final key = '${entityType}_$entityId';
    return _cache[_currentLanguage]?[key] ?? defaultName;
  }

  /// Helper to load seed data (called from DatabaseHelper or Settings)
  Future<void> seedTranslations(String languageCode) async {
    try {
      final db = await DatabaseHelper().database;
      final jsonString = await rootBundle.loadString('assets/seeds/translations_$languageCode.json');
      final List<dynamic> jsonList = json.decode(jsonString);

      final batch = db.batch();
      for (var item in jsonList) {
        batch.insert(
          'content_translations',
          {
            'entity_type': item['entity_type'],
            'entity_id': item['entity_id'],
            'language_code': item['language_code'],
            'field_name': item['field_name'] ?? 'name',
            'translated_text': item['translated_text'],
            'created_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      // Reload cache after seeding
      await loadTranslations(languageCode);
    } catch (e) {
      print("Error seeding translations for $languageCode: $e");
    }
  }
}
