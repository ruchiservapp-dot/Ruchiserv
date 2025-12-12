class ContentTranslation {
  final int? id;
  final String entityType;
  final int entityId;
  final String languageCode;
  final String fieldName;
  final String translatedText;

  ContentTranslation({
    this.id,
    required this.entityType,
    required this.entityId,
    required this.languageCode,
    this.fieldName = 'name',
    required this.translatedText,
  });

  factory ContentTranslation.fromJson(Map<String, dynamic> json) {
    return ContentTranslation(
      id: json['id'],
      entityType: json['entity_type'],
      entityId: json['entity_id'],
      languageCode: json['language_code'] ?? 'en',
      fieldName: json['field_name'] ?? 'name',
      translatedText: json['text'] ?? json['translated_text'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'entity_type': entityType,
      'entity_id': entityId,
      'language_code': languageCode,
      'field_name': fieldName,
      'translated_text': translatedText,
      // 'created_at': DateTime.now().toIso8601String(), // DB can handle or we pass explicitly
    };
  }
}
