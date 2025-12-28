# RuchiServ Pre-Launch Checklist

**Last Updated:** December 16, 2024  
**Project Status:** 85-90% Complete

---

## 1. Technical Preparation

### Android (Play Store)

- [ ] **Keystore Setup**
  - [ ] Create production keystore: `keytool -genkey -v -keystore ruchiserv-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias ruchiserv`
  - [ ] Store keystore securely (backup in multiple locations)
  - [ ] Create `android/key.properties` with credentials

- [ ] **App Configuration**
  - [ ] Update `android/app/build.gradle` with signing config
  - [ ] Set `versionCode` and `versionName` in build.gradle
  - [ ] Update `applicationId` if needed
  - [ ] Verify `minSdkVersion` (21+) and `targetSdkVersion` (34+)

- [ ] **Build & Test**
  - [ ] Run `flutter build appbundle --release`
  - [ ] Test release build on physical device
  - [ ] Test all payment flows in sandbox mode

- [ ] **Play Console**
  - [ ] Create app listing (title, description, screenshots)
  - [ ] Upload app bundle
  - [ ] Complete content rating questionnaire
  - [ ] Set up pricing (Free)
  - [ ] Submit for internal/closed testing first

---

### iOS (App Store)

- [ ] **Apple Developer Account**
  - [ ] Enroll in Apple Developer Program ($99/year)
  - [ ] Create App ID in Apple Developer Portal
  - [ ] Generate Distribution Certificate
  - [ ] Create Provisioning Profile

- [ ] **Xcode Configuration**
  - [ ] Set Bundle Identifier
  - [ ] Configure signing capabilities
  - [ ] Add required privacy descriptions in Info.plist

- [ ] **Build & Submit**
  - [ ] Run `flutter build ipa --release`
  - [ ] Upload via Transporter or Xcode
  - [ ] Complete App Store Connect listing
  - [ ] Submit for TestFlight first

---

### Web Deployment

- [ ] Run `flutter build web --release`
- [ ] Deploy to hosting (Firebase, Vercel, AWS S3, etc.)
- [ ] Configure custom domain
- [ ] Enable HTTPS
- [ ] Test on multiple browsers

---

## 2. Production Configuration

### API & Backend

- [ ] Set up production AWS Lambda/API Gateway
- [ ] Configure production DynamoDB tables
- [ ] Update `lib/secrets.dart` with production values:
  ```dart
  static const bool isProduction = true;
  static const String apiBaseUrl = 'YOUR_PRODUCTION_API_URL';
  ```

### Payment Gateway (Cashfree)

- [ ] Switch from sandbox to production credentials
- [ ] Configure webhook URLs for payment notifications
- [ ] Test production payment flow with minimum amount
- [ ] Enable refund capabilities

### WhatsApp Business API

- [ ] Set up production WhatsApp Business Account
- [ ] Configure message templates
- [ ] Update API credentials

### Push Notifications

- [ ] Configure FCM for production
- [ ] Set up APNs for iOS
- [ ] Test notification delivery

---

## 3. Security Checklist

- [ ] Remove all debug logs from production code
- [ ] Ensure API keys are not hardcoded (use environment variables)
- [ ] Enable ProGuard/R8 for Android
- [ ] Verify biometric authentication works
- [ ] Test session timeout functionality
- [ ] Review permission requests

---

## 4. Legal & Compliance

### Company Registration

- [ ] **Option A: Startup India Registration**
  - DPIIT recognition for tax benefits
  - Simpler compliance for early stage

- [ ] **Option B: Private Limited Company**
  - Better for investors and scaling
  - Requires 2 directors minimum

### Tax Registration

- [ ] GST Registration (mandatory for software services)
- [ ] TAN for TDS purposes
- [ ] PAN for business entity

### Legal Documents

- [ ] Privacy Policy (required for app stores)
- [ ] Terms of Service
- [ ] Refund Policy
- [ ] Cookie Policy (for web)
- [ ] Data Processing Agreement

---

## 5. App Store Assets

### Graphics Required

| Asset | Android | iOS |
|-------|---------|-----|
| App Icon | 512x512 PNG | 1024x1024 PNG |
| Feature Graphic | 1024x500 PNG | - |
| Screenshots | Min 2 (phone), tablet optional | 6.7", 6.5", 5.5" sizes |
| Preview Video | Optional | Optional |

### Store Listing Content

- [ ] App title (30 chars max)
- [ ] Short description (80 chars)
- [ ] Full description (4000 chars)
- [ ] Keywords/tags
- [ ] Category selection
- [ ] Contact email
- [ ] Privacy policy URL

---

## 6. Testing Before Launch

### Functional Testing

- [ ] Complete order flow (create → MRP → dispatch → delivery)
- [ ] Payment collection and recording
- [ ] Staff attendance with geofencing
- [ ] Driver dispatch and tracking
- [ ] Report generation and export
- [ ] Multi-language support

### User Acceptance Testing

- [ ] Admin role complete workflow
- [ ] Staff role permissions
- [ ] Driver role workflow
- [ ] Subcontractor role workflow
- [ ] Supplier role workflow

### Performance Testing

- [ ] App startup time < 3 seconds
- [ ] Smooth scrolling in large lists
- [ ] Offline mode functionality
- [ ] Sync performance

---

## 7. Launch Day Checklist

### Pre-Launch (1 day before)

- [ ] Final backup of all code
- [ ] Verify all production configs
- [ ] Test on fresh device installation
- [ ] Prepare support channels

### Launch Day

- [ ] Publish to Play Store (Android)
- [ ] Submit to App Store (iOS) - allow 24-48 hrs review
- [ ] Deploy web version
- [ ] Monitor crash analytics
- [ ] Monitor user feedback

### Post-Launch (First Week)

- [ ] Monitor app reviews
- [ ] Track crash-free rate (target: >99%)
- [ ] Address critical bugs within 24-48 hrs
- [ ] Gather user feedback

---

## 8. Support & Maintenance

- [ ] Set up error monitoring (Firebase Crashlytics, Sentry)
- [ ] Configure analytics (Firebase Analytics)
- [ ] Create support email/helpdesk
- [ ] Document common issues and solutions
- [ ] Plan update schedule (bi-weekly recommended)

---

## Quick Commands Reference

```bash
# Android Release Build
flutter build appbundle --release

# iOS Release Build
flutter build ipa --release

# Web Release Build
flutter build web --release

# Run on device
flutter run --release

# Check for issues
flutter analyze
flutter test
```

---

**Next Steps:**
1. Complete Android keystore setup
2. Create app store listings
3. Switch to production API credentials
4. Submit for internal testing
5. Launch! 🚀
