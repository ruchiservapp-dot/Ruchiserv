import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../core/locale_provider.dart';
import '../db/database_helper.dart';
import '../db/schema_manager.dart';

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  bool _isDarkMode = false;
  bool _whatsappNotifications = true;
  bool _emailNotifications = true;
  bool _otpEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('dark_mode') ?? false;
      _whatsappNotifications = prefs.getBool('whatsapp_notifications') ?? true;
      _emailNotifications = prefs.getBool('email_notifications') ?? true;
      _otpEnabled = prefs.getBool('otp_enabled') ?? true;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("General Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Appearance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SwitchListTile(
            title: const Text("Dark Mode"),
            subtitle: const Text("Enable dark theme"),
            value: _isDarkMode,
            onChanged: (val) {
              setState(() => _isDarkMode = val);
              _savePreference('dark_mode', val);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Theme will apply on next restart")),
              );
            },
          ),
          const Divider(),
          const SizedBox(height: 16),
          const Text("Language", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Consumer<LocaleProvider>(
            builder: (context, provider, child) {
              return ListTile(
                title: const Text("App Language"),
                subtitle: const Text("Select your preferred language"),
                trailing: DropdownButton<String>(
                  value: provider.locale?.languageCode ?? 'en',
                  underline: const SizedBox(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      provider.setLocale(Locale(newValue));
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'ml', child: Text('Malayalam (മലയാളം)')),
                    DropdownMenuItem(value: 'ta', child: Text('Tamil (தமிழ்)')),
                    DropdownMenuItem(value: 'hi', child: Text('Hindi (हिंदी)')),
                    DropdownMenuItem(value: 'kn', child: Text('Kannada (ಕನ್ನಡ)')),
                    DropdownMenuItem(value: 'te', child: Text('Telugu (తెలుగు)')),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          const SizedBox(height: 16),
          const Text("Notifications", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SwitchListTile(
            title: const Text("WhatsApp Notifications"),
            subtitle: const Text("Send updates via WhatsApp"),
            value: _whatsappNotifications,
            onChanged: (val) {
              setState(() => _whatsappNotifications = val);
              _savePreference('whatsapp_notifications', val);
            },
          ),
          SwitchListTile(
            title: const Text("Email Notifications"),
            subtitle: const Text("Send updates via Email"),
            value: _emailNotifications,
            onChanged: (val) {
              setState(() => _emailNotifications = val);
              _savePreference('email_notifications', val);
            },
          ),
          const Divider(),
          const SizedBox(height: 16),
          const Text("Security", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SwitchListTile(
            title: const Text("OTP Verification"),
            subtitle: const Text("Require OTP for login"),
            value: _otpEnabled,
            onChanged: (val) {
              setState(() => _otpEnabled = val);
              _savePreference('otp_enabled', val);
            },
          ),
          const Divider(),
          const SizedBox(height: 16),
          const Text("Maintenance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ListTile(
            leading: const Icon(Icons.build_circle, color: Colors.orange),
            title: const Text("Fix Database Schema"),
            subtitle: const Text("Run if you see missing column errors"),
            onTap: () async {
              try {
                final db = DatabaseHelper();
                final database = await db.database;
                await SchemaManager.syncSchema(database);
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Database Schema Synced! Try your action again."), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Fix failed: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
