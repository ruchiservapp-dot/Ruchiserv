// lib/screens/1.7_forgot_password.dart
import 'package:flutter/material.dart';
import '../services/otp_service.dart';
import '../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final firmController = TextEditingController();
  final mobileController = TextEditingController();
  final otpController = TextEditingController();
  final pwdController = TextEditingController();
  String? _otpSessionId;
  int _step = 1; // 1: ask firm+mobile, 2: otp, 3: new password
  bool _busy = false;

  @override
  void dispose() {
    firmController.dispose();
    mobileController.dispose();
    otpController.dispose();
    pwdController.dispose();
    super.dispose();
  }

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> _sendOtp() async {
    final firmId = firmController.text.trim();
    final mobile = mobileController.text.trim();
    if (firmId.isEmpty || mobile.length < 8) {
      _err('Enter valid firm id and mobile');
      return;
    }
    setState(() => _busy = true);
    try {
      final otpId = await OtpService.sendOtp(mobile: mobile);
      if (otpId == null || otpId.isEmpty) {
        _err('Failed to send OTP');
        return;
      }
      setState(() {
        _otpSessionId = otpId;
        _step = 2;
      });
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpSessionId == null) {
      _err('No OTP session. Please resend.');
      return;
    }
    final ok = await OtpService.verifyOtp(
      sessionId: _otpSessionId!,
      otp: otpController.text.trim(),
    );
    if (!ok) {
      _err('Invalid OTP.');
      return;
    }
    setState(() => _step = 3);
  }

  Future<void> _resetPwd() async {
    final firmId = firmController.text.trim();
    final mobile = mobileController.text.trim();
    final pwd = pwdController.text.trim();
    if (pwd.length < 4) {
      _err('Password must be at least 4 characters.');
      return;
    }
    setState(() => _busy = true);
    try {
      final ok = await AuthService.resetPassword(
        firmId: firmId,
        mobile: mobile,
        newPassword: pwd,
      );
      if (!ok) {
        _err('Failed to reset password. Try again.');
        return;
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successful.')),
      );
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _busy;
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _step == 1
            ? Column(
                children: [
                  TextField(
                    controller: firmController,
                    decoration: const InputDecoration(
                      labelText: 'Firm ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: mobileController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Mobile',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  busy
                      ? const CircularProgressIndicator()
                      : ElevatedButton.icon(
                          onPressed: _sendOtp,
                          icon: const Icon(Icons.sms),
                          label: const Text('Send OTP'),
                        ),
                ],
              )
            : _step == 2
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'OTP',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      busy
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: _verifyOtp,
                              child: const Text('Verify OTP'),
                            ),
                    ],
                  )
                : Column(
                    children: [
                      TextField(
                        controller: pwdController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'New Password',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      busy
                          ? const CircularProgressIndicator()
                          : ElevatedButton.icon(
                              onPressed: _resetPwd,
                              icon: const Icon(Icons.lock),
                              label: const Text('Save New Password'),
                            ),
                    ],
                  ),
      ),
    );
  }
}
