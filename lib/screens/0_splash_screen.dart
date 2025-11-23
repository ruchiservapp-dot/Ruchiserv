  import 'dart:async';
  import 'package:flutter/material.dart';
  import 'package:shared_preferences/shared_preferences.dart';
  import '1.4_login_screen.dart';

  class SplashScreen extends StatefulWidget {
    const SplashScreen({super.key});

    @override
    State<SplashScreen> createState() => _SplashScreenState();
  }

  class _SplashScreenState extends State<SplashScreen> {
    Timer? _timer;

    @override
    void initState() {
      super.initState();
      // Show splash for exactly 2 seconds
      _timer = Timer(const Duration(seconds: 2), _goToNext);
    }

    Future<void> _goToNext() async {
      try {
        // Read any flags you want later in Login (optional)
        final prefs = await SharedPreferences.getInstance();
        // Example keys for your Login to use (Login screen should read these itself)
        // bool biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
        // String? lastUser = prefs.getString('last_username');

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } catch (_) {
        // Even if prefs fail, still go to login
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }

    @override
    void dispose() {
      _timer?.cancel();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      // Simple, brand-first splash; keep your existing visuals if you already had them
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // If you have an asset logo, uncomment below and ensure pubspec includes it:
              // Image.asset('assets/images/logo.png', width: 120, height: 120),
              const Icon(Icons.restaurant_menu, size: 96, color: Colors.indigo),
              const SizedBox(height: 16),
              const Text(
                'RuchiServ',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Catering Ops • Orders • Pax',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }
  }
