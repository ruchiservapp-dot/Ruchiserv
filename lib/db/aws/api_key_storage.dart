import 'package:shared_preferences/shared_preferences.dart';

class ApiKeyStorage {
  static const _keyName = "aws_api_key";

  /// Save API Key locally
  static Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, apiKey);
  }

  /// Read API Key
  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyName);
  }

  /// Delete API Key (for logout or reset)
  static Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyName);
  }
}
    