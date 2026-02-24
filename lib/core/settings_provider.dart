import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  bool _whatsappNotifications = true;
  bool _emailNotifications = true;
  bool _otpEnabled = true;

  bool _paymentCashfree = true;
  bool _paymentUpi = true;
  bool _paymentCard = true;

  bool get whatsappNotifications => _whatsappNotifications;
  bool get emailNotifications => _emailNotifications;
  bool get otpEnabled => _otpEnabled;

  bool get paymentCashfree => _paymentCashfree;
  bool get paymentUpi => _paymentUpi;
  bool get paymentCard => _paymentCard;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _whatsappNotifications = prefs.getBool('whatsapp_notifications') ?? true;
    _emailNotifications = prefs.getBool('email_notifications') ?? true;
    _otpEnabled = prefs.getBool('otp_enabled') ?? true;

    _paymentCashfree = prefs.getBool('payment_cashfree') ?? true;
    _paymentUpi = prefs.getBool('payment_upi') ?? true;
    _paymentCard = prefs.getBool('payment_card') ?? true;
    notifyListeners();
  }

  Future<void> setWhatsappNotifications(bool val) async {
    _whatsappNotifications = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('whatsapp_notifications', val);
    notifyListeners();
  }

  Future<void> setEmailNotifications(bool val) async {
    _emailNotifications = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('email_notifications', val);
    notifyListeners();
  }

  Future<void> setOtpEnabled(bool val) async {
    _otpEnabled = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('otp_enabled', val);
    notifyListeners();
  }

  Future<void> setPaymentCashfree(bool val) async {
    _paymentCashfree = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('payment_cashfree', val);
    notifyListeners();
  }

  Future<void> setPaymentUpi(bool val) async {
    _paymentUpi = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('payment_upi', val);
    notifyListeners();
  }

  Future<void> setPaymentCard(bool val) async {
    _paymentCard = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('payment_card', val);
    notifyListeners();
  }
}
