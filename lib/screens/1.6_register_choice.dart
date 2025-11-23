// lib/screens/1.6_register_choice.dart
import 'package:flutter/material.dart';
import '../services/otp_service.dart';
import '../services/auth_service.dart';

class RegisterChoiceScreen extends StatefulWidget {
  const RegisterChoiceScreen({super.key});

  @override
  State<RegisterChoiceScreen> createState() => _RegisterChoiceScreenState();
}

class _RegisterChoiceScreenState extends State<RegisterChoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firmCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();

  bool _sending = false;
  int _step = 1; // 1: ask firm+mobile, 2: otp, 3: set password
  String? _otpSessionId;

  @override
  void dispose() {
    _firmCtrl.dispose();
    _mobileCtrl.dispose();
    _otpCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> _startOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);

    final firmId = _firmCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();

    try {
      final pre = await AuthService.precheckRegistration(firmId: firmId, mobile: mobile);
      if (!pre) {
        _showError('This mobile is not allowed for the given firm. Contact admin.');
        return;
      }

      final otpId = await OtpService.sendOtp(mobile: mobile);
      if (otpId == null || otpId.isEmpty) {
        _showError('Failed to send OTP. Try again.');
        return;
      }
      setState(() {
        _otpSessionId = otpId;
        _step = 2;
      });
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpSessionId == null) {
      _showError('No OTP session. Please resend.');
      return;
    }
    final ok = await OtpService.verifyOtp(
      sessionId: _otpSessionId!,
      otp: _otpCtrl.text.trim(),
    );
    if (!ok) {
      _showError('Invalid OTP. Please retry.');
      return;
    }
    setState(() => _step = 3);
  }

  Future<void> _setPassword() async {
    final pwd = _pwdCtrl.text.trim();
    if (pwd.length < 4) {
      _showError('Password must be at least 4 characters.');
      return;
    }
    setState(() => _sending = true);
    try {
      final firmId = _firmCtrl.text.trim();
      final mobile = _mobileCtrl.text.trim();
      final ok = await AuthService.setPassword(
        firmId: firmId,
        mobile: mobile,
        password: pwd,
      );
      if (!ok) {
        _showError('Failed to set password. Try again.');
        return;
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration complete. You can login now.')),
      );
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _sending;
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _step == 1
            ? Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _firmCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Firm ID',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter firm id' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _mobileCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Mobile',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().length < 8) ? 'Enter valid mobile' : null,
                    ),
                    const SizedBox(height: 16),
                    busy
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton.icon(
                            onPressed: _startOtp,
                            icon: const Icon(Icons.sms),
                            label: const Text('Send OTP'),
                          ),
                  ],
                ),
              )
            : _step == 2
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Enter the OTP sent to your mobile'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _otpCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'OTP',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      busy
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: _verifyOtp,
                              child: const Text('Verify OTP'),
                            ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Set your password'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _pwdCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      busy
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton.icon(
                              onPressed: _setPassword,
                              icon: const Icon(Icons.lock),
                              label: const Text('Save Password'),
                            ),
                    ],
                  ),
      ),
    );
  }
}
