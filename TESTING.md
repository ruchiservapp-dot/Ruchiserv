# 🧪 Automated Testing Guide

## 1. Automatic Cloud Testing (Recommended)
Every time you push code to GitHub, tests run automatically.
1. Make your changes
2. Run `git push`
3. Go to the **Actions** tab in your GitHub repository to see results.

## 2. Running Tests Locally
Run these commands in your terminal to check your code before pushing:

### ⚡️ Quick Check (Unit Tests)
Runs logic tests for MRP, Sync, Compliance, etc.
```bash
flutter test
```

### 📱 Full App Test (Integration)
Runs the app on a simulator to check Login, Navigation, and Orders.
*Requires an open simulator (iOS/Android) or Chrome.*
```bash
flutter test integration_test/patrol_auth_test.dart
```

### 🔄 Multi-Device Sync Verify
Verifies cloud sync logic without needing two phones.
```bash
flutter test test/sync_logic_test.dart
```

---

## 🚀 Super Automation
I've created a script that runs tests and automatically commits if everything is green.

1. **Make your changes**
2. **Run:**
   ```bash
   ./scripts/smart_commit.sh "Description of what I changed"
   ```
3. **Relax!** Verification, Committing, and Pushing happens automatically.
