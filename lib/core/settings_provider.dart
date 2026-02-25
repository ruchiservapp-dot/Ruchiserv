import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  // --- Notification & Payment Settings ---
  bool _whatsappNotifications = true;
  bool _emailNotifications = true;
  bool _otpEnabled = true;
  bool _paymentCashfree = true;
  bool _paymentUpi = true;
  bool _paymentCard = true;

  // --- Session & Identity Settings ---
  String? _firmId;
  String? _userId;
  String? _username;
  String? _lastRole;
  String? _lastEmail;
  bool _isLoggedIn = false;

  // --- Theme Settings ---
  ThemeMode _themeMode = ThemeMode.light;

  // Getters
  bool get whatsappNotifications => _whatsappNotifications;
  bool get emailNotifications => _emailNotifications;
  bool get otpEnabled => _otpEnabled;
  bool get paymentCashfree => _paymentCashfree;
  bool get paymentUpi => _paymentUpi;
  bool get paymentCard => _paymentCard;

  String? get firmId => _firmId;
  String? get userId => _userId;
  String? get username => _username;
  String? get lastRole => _lastRole;
  String? get lastEmail => _lastEmail;
  bool get isLoggedIn => _isLoggedIn;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  SettingsProvider() {
    _loadAllSettings();
  }

  Future<void> _loadAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Notifications & Payments
    _whatsappNotifications = prefs.getBool('whatsapp_notifications') ?? true;
    _emailNotifications = prefs.getBool('email_notifications') ?? true;
    _otpEnabled = prefs.getBool('otp_enabled') ?? true;
    _paymentCashfree = prefs.getBool('payment_cashfree') ?? true;
    _paymentUpi = prefs.getBool('payment_upi') ?? true;
    _paymentCard = prefs.getBool('payment_card') ?? true;

    // Session
    _firmId = prefs.getString('firm_id');
    _userId = prefs.getString('user_id');
    _username = prefs.getString('username');
    _lastRole = prefs.getString('last_role');
    _lastEmail = prefs.getString('last_email');
    _isLoggedIn = prefs.getString('jwt_token') != null;

    // Theme
    final isDark = prefs.getBool('dark_mode') ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;

    notifyListeners();
  }

  // --- Setters with Persistence ---

  Future<void> setFirmId(String? id) async {
    _firmId = id;
    final prefs = await SharedPreferences.getInstance();
    if (id == null) await prefs.remove('firm_id');
    else await prefs.setString('firm_id', id);
    notifyListeners();
  }

  Future<void> setUserId(String? id) async {
    _userId = id;
    final prefs = await SharedPreferences.getInstance();
    if (id == null) await prefs.remove('user_id');
    else await prefs.setString('user_id', id);
    notifyListeners();
  }

  Future<void> setUsername(String? name) async {
    _username = name;
    final prefs = await SharedPreferences.getInstance();
    if (name == null) await prefs.remove('username');
    else await prefs.setString('username', name);
    notifyListeners();
  }

  Future<void> setLastRole(String? role) async {
    _lastRole = role;
    final prefs = await SharedPreferences.getInstance();
    if (role == null) await prefs.remove('last_role');
    else await prefs.setString('last_role', role);
    notifyListeners();
  }

  Future<void> setLastEmail(String? email) async {
    _lastEmail = email;
    final prefs = await SharedPreferences.getInstance();
    if (email == null) await prefs.remove('last_email');
    else await prefs.setString('last_email', email);
    notifyListeners();
  }

  Future<void> setLoggedIn(bool status) async {
    _isLoggedIn = status;
    notifyListeners();
  }

  Future<void> setTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', isDark);
    notifyListeners();
  }

  // --- Original Setters ---

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
