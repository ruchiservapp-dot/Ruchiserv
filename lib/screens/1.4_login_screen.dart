import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/biometric_service.dart';
import '../services/connectivity_service.dart';
import '../services/auth_service.dart';

import '2.0_orders_calendar_screen.dart';
import '1.6_register_choice.dart';
import '1.7_forgot_password.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firmCtrl = TextEditingController(text: 'RCHSRV'); // default firm code if you like
  final _mobileCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _isLoading = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _prefill();
    _checkBiometric();
  }

  Future<void> _prefill() async {
    final sp = await SharedPreferences.getInstance();
    final lastMobile = sp.getString('auth_mobile');
    if (!mounted) return;
    if (lastMobile != null && lastMobile.isNotEmpty) {
      _mobileCtrl.text = lastMobile;
    }
  }

  Future<void> _checkBiometric() async {
    try {
      final ok = await BiometricService().canCheckBiometrics();
      if (!mounted) return;
      setState(() => _biometricAvailable = ok);
    } catch (_) {
      if (!mounted) return;
      setState(() => _biometricAvailable = false);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final firmId = _firmCtrl.text.trim();
      final mobile = _mobileCtrl.text.trim();
      final pass = _passCtrl.text;

      final online = await ConnectivityService().isOnline();

      bool allowed = false;
      if (online) {
        // Online path (first login MUST be online)
        allowed = await AuthService.loginOnline(
          firmId: firmId,
          mobile: mobile,
          password: pass,
        );
        if (allowed) {
          await AuthService.stampLocalLogin(online: true);
        }
      } else {
        // Offline path (only allowed if previously logged in online and rules pass)
        allowed = await AuthService.canLoginOffline(
          firmId: firmId,
          mobile: mobile,
          password: pass,
        );
        if (allowed) {
          await AuthService.stampLocalLogin(online: false);
        }
      }

      if (!allowed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(online
                ? 'Invalid credentials.'
                : 'Offline login not allowed. Please connect to the internet.'),
          ),
        );
        return;
      }

      // Check subscription status
      if (await AuthService.isExpired()) {
        if (!mounted) return;
        _showExpiryDialog(lock: true);
        return;
      } else if (await AuthService.shouldWarnExpiry()) {
        if (!mounted) return;
        _showExpiryDialog(lock: false);
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OrderCalendarScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Login error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithBiometric() async {
    setState(() => _isLoading = true);
    try {
      final firmId = _firmCtrl.text.trim();

      // Must authenticate with device
      final ok = await BiometricService().authenticate();
      if (!ok) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      // Offline-with-biometric rule
      final can = await AuthService.canLoginOfflineWithBiometric(firmId: firmId);
      if (!can) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Biometric login not allowed. Please login online once.'),
        ));
        return;
      }

      if (await AuthService.isExpired()) {
        if (!mounted) return;
        _showExpiryDialog(lock: true);
        return;
      } else if (await AuthService.shouldWarnExpiry()) {
        if (!mounted) return;
        _showExpiryDialog(lock: false);
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OrderCalendarScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Biometric failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showExpiryDialog({required bool lock}) async {
    final days = await AuthService.daysToExpiry();
    final msg = lock
        ? 'Your subscription has expired. Please renew to continue.'
        : 'Your subscription expires in ${days ?? 0} day(s). Please renew.';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Subscription'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _firmCtrl.dispose();
    _mobileCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logo = Text('RuchiServ',
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ));

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const SizedBox(height: 40),
                    Center(child: logo),
                    const SizedBox(height: 8),
                    const Text('Sign in to continue',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 28),

                    // Firm ID
                    TextFormField(
                      controller: _firmCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Firm ID',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter firm ID'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // Mobile
                    TextFormField(
                      controller: _mobileCtrl,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Enter mobile' : null,
                    ),
                    const SizedBox(height: 12),

                    // Password
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Enter password' : null,
                    ),
                    const SizedBox(height: 16),

                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _login,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Text('Login'),
                            ),
                          ),

                    const SizedBox(height: 8),

                    if (_biometricAvailable)
                      OutlinedButton.icon(
                        onPressed: _loginWithBiometric,
                        icon: const Icon(Icons.fingerprint),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Use Device Security'),
                        ),
                      ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RegisterChoiceScreen()),
                            );
                          },
                          child: const Text('Register'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                            );
                          },
                          child: const Text('Forgot password?'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
