import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/1.4_login_screen.dart';
import 'screens/2.0_orders_calendar_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RuchiServApp());
}

class RuchiServApp extends StatelessWidget {
  const RuchiServApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RuchiServ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        fontFamily: 'Poppins',
      ),
      home: const _StartupRouter(),
    );
  }
}

class _StartupRouter extends StatefulWidget {
  const _StartupRouter();

  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  Widget? _next;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // Very simple: if we have a last mobile saved, show Login directly,
    // else still show Login. (We can add auto route to calendar later if needed.)
    final sp = await SharedPreferences.getInstance();
    final lastMobile = sp.getString('auth_mobile') ?? '';
    await Future.delayed(const Duration(milliseconds: 800)); // splash feel

    if (!mounted) return;
    setState(() {
      _next = const LoginScreen();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _next == null
        ? const Scaffold(
            body: Center(child: Text('RuchiServ', style: TextStyle(fontSize: 24))),
          )
        : _next!;
  }
}
