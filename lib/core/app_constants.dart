  class AppConstants {
    // 🌐 AWS Base URL
    // Use the config one to avoid split-brain
    static const String apiBaseUrl = 'https://do3uf8e3w6.execute-api.ap-south-1.amazonaws.com/prod/';

    // 📋 Table Names
    static const String tableFirms = 'firms';
    static const String tableUsers = 'users';
    static const String tableOrders = 'orders';
    static const String tableDishes = 'dishes';
    static const String tableAuthLogs = 'auth_logs';

    // 🎨 Colors: Use AppColors from core/app_theme.dart for all UI colors.

    // ⚙️ Common App Info
    static const String appVersion = '1.0.0';
    static const String buildNumber = '20260222';
  }
