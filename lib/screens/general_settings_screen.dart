import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../core/locale_provider.dart';
import '../core/settings_provider.dart';

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  // Local state removed, using SettingsProvider via Consumer


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("General Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Appearance",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Consumer<SettingsProvider>(
            builder: (context, settings, child) {
              return SwitchListTile(
                title: const Text("Dark Mode"),
                subtitle: const Text("Enable dark theme"),
                value: settings.isDarkMode,
                onChanged: (val) {
                  settings.setTheme(val);
                },
              );
            },
          ),
          const Divider(),
          const SizedBox(height: 16),
          const Text("Language",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                    DropdownMenuItem(
                        value: 'ml', child: Text('Malayalam (മലയാളം)')),
                    DropdownMenuItem(value: 'ta', child: Text('Tamil (தமிழ்)')),
                    DropdownMenuItem(value: 'hi', child: Text('Hindi (हिंदी)')),
                    DropdownMenuItem(
                        value: 'kn', child: Text('Kannada (ಕನ್ನಡ)')),
                    DropdownMenuItem(
                        value: 'te', child: Text('Telugu (తెలుగు)')),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          const SizedBox(height: 16),
          const Text("Notifications",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Consumer<SettingsProvider>(
            builder: (context, settings, child) {
              return Column(
                children: [
                  SwitchListTile(
                    title: const Text("WhatsApp Notifications"),
                    subtitle: const Text("Send updates via WhatsApp"),
                    value: settings.whatsappNotifications,
                    onChanged: (val) {
                      settings.setWhatsappNotifications(val);
                    },
                  ),
                  SwitchListTile(
                    title: const Text("Email Notifications"),
                    subtitle: const Text("Send updates via Email"),
                    value: settings.emailNotifications,
                    onChanged: (val) {
                      settings.setEmailNotifications(val);
                    },
                  ),
                ],
              );
            },
          ),
          const Divider(),
          const SizedBox(height: 16),
          const Text("Security",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Consumer<SettingsProvider>(
            builder: (context, settings, child) {
              return SwitchListTile(
                title: const Text("OTP Verification"),
                subtitle: const Text("Require OTP for login"),
                value: settings.otpEnabled,
                onChanged: (val) {
                  settings.setOtpEnabled(val);
                },
              );
            },
          ),
          const Divider(),
        ],
      ),
    );
  }
}
