// @locked
// lib/screens/1.7_forgot_password.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final confirmPwdController = TextEditingController();
  String? _otpSessionId;
  int _step = 1; // 1: ask firm+mobile, 2: otp, 3: new password
  bool _busy = false;
  
  // OTP attempt tracking
  int _otpAttempts = 0;
  DateTime? _lockoutUntil;

  @override
  void initState() {
    super.initState();
    _loadOtpAttempts();
  }

  @override
  void dispose() {
    firmController.dispose();
    mobileController.dispose();
    otpController.dispose();
    pwdController.dispose();
    confirmPwdController.dispose();
    super.dispose();
  }

  Future<void> _loadOtpAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    final mobile = mobileController.text.trim();
    if (mobile.isEmpty) return;
    
    final key = 'otp_attempts_$mobile';
    final lockoutKey = 'otp_lockout_$mobile';
    
    _otpAttempts = prefs.getInt(key) ?? 0;
    final lockoutTimestamp = prefs.getInt(lockoutKey);
    
    if (lockoutTimestamp != null) {
      _lockoutUntil = DateTime.fromMillisecondsSinceEpoch(lockoutTimestamp);
      if (_lockoutUntil!.isAfter(DateTime.now())) {
        setState(() {});
      } else {
        // Lockout expired, reset
        await _resetOtpAttempts();
      }
    }
  }

  Future<void> _resetOtpAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    final mobile = mobileController.text.trim();
    final key = 'otp_attempts_$mobile';
    final lockoutKey = 'otp_lockout_$mobile';
    
    await prefs.remove(key);
    await prefs.remove(lockoutKey);
    
    setState(() {
      _otpAttempts = 0;
      _lockoutUntil = null;
    });
  }

  Future<void> _incrementOtpAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    final mobile = mobileController.text.trim();
    final key = 'otp_attempts_$mobile';
    final lockoutKey = 'otp_lockout_$mobile';
    
    _otpAttempts++;
    await prefs.setInt(key, _otpAttempts);
    
    if (_otpAttempts >= 3) {
      // Lock out for 1 hour
      final lockoutTime = DateTime.now().add(const Duration(hours: 1));
      await prefs.setInt(lockoutKey, lockoutTime.millisecondsSinceEpoch);
      setState(() {
        _lockoutUntil = lockoutTime;
      });
    }
  }

  bool _isLockedOut() {
    if (_lockoutUntil == null) return false;
    return _lockoutUntil!.isAfter(DateTime.now());
  }

  String _getRemainingLockoutTime() {
    if (_lockoutUntil == null) return '';
    final remaining = _lockoutUntil!.difference(DateTime.now());
    if (remaining.isNegative) return '';
    
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return '${minutes}m ${seconds}s';
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
      // Validate Firm and Mobile
      final validation = await AuthService.validateFirmAndMobile(
        firmId: firmId,
        mobile: mobile,
      );
      
      if (validation['valid'] != true) {
        _err(validation['error'] ?? 'Validation failed');
        return;
      }

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
    // Check lockout
    if (_isLockedOut()) {
      _err('Too many failed attempts. Try again in ${_getRemainingLockoutTime()}');
      return;
    }
    
    if (_otpSessionId == null) {
      _err('No OTP session. Please resend.');
      return;
    }
    
    final ok = await OtpService.verifyOtp(
      sessionId: _otpSessionId!,
      otp: otpController.text.trim(),
    );
    
    if (!ok) {
      await _incrementOtpAttempts();
      final remaining = 3 - _otpAttempts;
      if (remaining > 0) {
        _err('Invalid OTP. $remaining attempts remaining.');
      } else {
        _err('Too many failed attempts. Try again after 1 hour.');
      }
      return;
    }
    
    // Success - reset attempts
    await _resetOtpAttempts();
    setState(() => _step = 3);
  }

  Future<void> _resetPwd() async {
    final firmId = firmController.text.trim();
    final mobile = mobileController.text.trim();
    final pwd = pwdController.text.trim();
    final confirmPwd = confirmPwdController.text.trim();
    
    if (pwd.length < 4) {
      _err('Password must be at least 4 characters.');
      return;
    }
    
    if (pwd != confirmPwd) {
      _err('Passwords do not match. Please check and try again.');
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
                      if (_isLockedOut())
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lock_clock, color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Too many failed attempts. Please wait ${_getRemainingLockoutTime()} before trying again.',
                                  style: TextStyle(color: Colors.red.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      TextField(
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        enabled: !_isLockedOut(),
                        decoration: InputDecoration(
                          labelText: 'OTP',
                          border: const OutlineInputBorder(),
                          helperText: _otpAttempts > 0 && !_isLockedOut()
                              ? 'Attempts: $_otpAttempts/3'
                              : null,
                          helperStyle: TextStyle(
                            color: _otpAttempts >= 2 ? Colors.red : Colors.orange,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      busy
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: _isLockedOut() ? null : _verifyOtp,
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
                          helperText: 'Enter your new password (min 4 characters)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: confirmPwdController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm New Password',
                          border: OutlineInputBorder(),
                          helperText: 'Re-enter password to confirm',
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
