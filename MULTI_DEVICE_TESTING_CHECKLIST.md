# 📱 Multi-Device & Multi-Platform Testing Checklist
## Section 17 — RuchiServ Pre-Launch

> **Instructions**: Test the SAME firm account (`RUCHOW1D`) across all combinations simultaneously.  
> Mark each item with ✅ when passed, ❌ when failed (add notes).

---

## Android

### Screen Sizes
| # | Test | Device/Emulator | Status | Notes |
|---|------|-----------------|--------|-------|
| 1 | Small screen (5.5") — no overflow | Any 5.5" Android or emulator `Nexus 5X` | | |
| 2 | Large screen (6.7") — layout scales | Any 6.7" or emulator `Pixel 7 Pro` | | |
| 3 | Tablet 10" landscape — responsive | 10" tablet or emulator `Pixel C` | | |

### Android Versions
| # | Test | How to Verify | Status | Notes |
|---|------|---------------|--------|-------|
| 4 | Android 10 (API 29) — minimum works | Emulator API 29 or physical device | | |
| 5 | Android 14 (API 34) — latest works | Emulator API 34 or physical device | | |

### Device-Specific
| # | Test | What to Check | Status | Notes |
|---|------|---------------|--------|-------|
| 6 | Samsung device — keyboard/UI | Samsung keyboard installs correctly, no UI overlap | | |
| 7 | Xiaomi/Redmi — battery optimization | Disable battery optimization for RuchiServ; verify FCM push and background sync still work after 30min | | |

**Xiaomi Fix Guide**: Settings → Battery → App Battery Saver → RuchiServ → No restrictions

---

## iOS

### Screen Sizes
| # | Test | Device/Simulator | Status | Notes |
|---|------|------------------|--------|-------|
| 8 | iPhone SE (4.7") — no overflow | Simulator: iPhone SE (3rd gen) | | |
| 9 | iPhone 15/16 (6.1") — standard | Simulator: iPhone 15 | | |
| 10 | iPhone 15/16 Pro Max (6.7") — large | Simulator: iPhone 15 Pro Max | | |
| 11 | iPad 10.9" landscape — responsive | Simulator: iPad (10th gen) | | |

### iOS Versions 
| # | Test | How to Verify | Status | Notes |
|---|------|---------------|--------|-------|
| 12 | iOS 15 (minimum) — app runs | Simulator with iOS 15 runtime | | |
| 13 | iOS 18 (latest) — app runs | Simulator with iOS 18 runtime | | |

### System UI
| # | Test | What to Check | Status | Notes |
|---|------|---------------|--------|-------|
| 14 | Notch / Dynamic Island | No content hidden behind system UI. Check: login screen, order calendar, kitchen screen, settings. Global `SafeArea` should protect all screens. | | |

---

## macOS (Desktop)

| # | Test | What to Check | Status | Notes |
|---|------|---------------|--------|-------|
| 15 | App launches and works | `flutter run -d macos` — verify splash → login → main menu | | |
| 16 | Keyboard shortcuts | Tab navigation, Enter to submit forms, Escape to close dialogs | | |
| 17 | Window resizing | Resize from small (800×600) to large (1920×1080) — no overflow, content reflows | | |
| 18 | Menu bar and dock icon | App shows correct icon in dock and menu bar title says "Ruchiserv Kitchen" | | |

---

## Web

### Browser Compatibility
| # | Test | How to Verify | Status | Notes |
|---|------|---------------|--------|-------|
| 19 | Chrome — all features | Open deployed web app in Chrome, test full order flow | | |
| 20 | Safari — all features | Open in Safari, test login + order creation + sync | | |
| 21 | Firefox — basic functionality | Open in Firefox, verify login + navigation work | | |

### Responsive Viewports
| # | Test | How to Verify | Status | Notes |
|---|------|---------------|--------|-------|
| 22 | Mobile browser viewport | Chrome DevTools → Toggle Device → iPhone 12 Pro (390×844) | | |
| 23 | Desktop browser viewport | Full browser window (1440×900+) | | |

### Payments
| # | Test | What to Check | Status | Notes |
|---|------|---------------|--------|-------|
| 24 | Cashfree QR code on web | Navigate to subscription/payment → QR code renders and is scannable | | |

---

## Cross-Device Sync Tests

> **Setup**: Login with the SAME firm account on BOTH devices simultaneously.

### Simultaneous Login
| # | Test | Devices | Steps | Status | Notes |
|---|------|---------|-------|--------|-------|
| 25 | Android + iOS sync | Phone A (Android) + Phone B (iOS) | Login on both → create order on A → check B within 3s | | |
| 26 | Android + macOS sync | Phone (Android) + Mac (macOS) | Login on both → create order on phone → check Mac | | |
| 27 | Android + Web sync | Phone (Android) + Browser (Web) | Login on both → create order on phone → refresh web | | |

### Data Consistency
| # | Test | Steps | Expected | Status | Notes |
|---|------|-------|----------|--------|-------|
| 28 | Create on A → appears on B | Create order on Device A | Appears on Device B within 3 seconds (via FCM push or polling) | | |
| 29 | Edit on B → reflected on A | Edit order name on Device B | Device A shows updated name after sync (pull-to-refresh or auto-poll) | | |
| 30 | Offline edit + reconnect | Put A in airplane mode → edit order → turn off airplane mode | Edited data syncs to cloud and appears on Device B | | |

---

## Quick Test Commands

```bash
# Run all automated tests (unit + sync + responsive)
flutter test

# Run only cross-device sync tests
flutter test test/cross_device_sync_test.dart

# Run only responsive layout tests 
flutter test test/responsive_layout_test.dart

# Run on specific platforms
flutter run -d chrome          # Web
flutter run -d macos           # macOS
flutter run -d <emulator_id>   # Android emulator
flutter run -d <simulator_id>  # iOS simulator

# List available devices
flutter devices
```

---

## Sign-Off

| Tester | Date | Platform | All Tests Passed? |
|--------|------|----------|-------------------|
| | | Android | |
| | | iOS | |
| | | macOS | |
| | | Web | |
| | | Cross-Device | |
