  class AppConstants {
    // 🌐 AWS Base URL
    // 🌐 AWS Base URL
    // static const String apiBaseUrl = 'https://38so00r7ld.execute-api.ap-south-1.amazonaws.com/prod/';
    // Use the config one to avoid split-brain
    static const String apiBaseUrl = 'https://zgcy1tisjc.execute-api.ap-south-1.amazonaws.com/prod/';

    // 📋 Table Names
    static const String tableFirms = 'firms';
    static const String tableUsers = 'users';
    static const String tableOrders = 'orders';
    static const String tableDishes = 'dishes';
    static const String tableAuthLogs = 'auth_logs';

    // 🎨 App Colors (linked to theme)
    static const int primaryColor = 0xFF2ECC71; // Emerald Green
    static const int accentColor = 0xFFE67E22;  // Saffron Orange
    static const int errorColor = 0xFFE74C3C;   // Red

    // ⚙️ Common App Info
    static const String appVersion = '1.0.0';
    static const String buildNumber = '20251029';
  }
