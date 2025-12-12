import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_theme.dart';
import '1.4_login_screen.dart'; // Full version with biometrics

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    // Show splash for 2 seconds
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;

    // Navigate to Login Screen
    // (Login Screen handles auto-login logic internally if needed, 
    // or we can just go there and let it decide)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Black Background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image.asset(
              'assets/images/logo.png',
              width: 300,
              height: 300,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
