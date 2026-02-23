# RuchiServ E2E Pre-Launch Testing & QA Process

This document outlines the comprehensive End-to-End (E2E) testing and Quality Assurance (QA) process for the RuchiServ application. Following these steps ensures MNC-standard validation before Play Store listing.

**Objective**: Test the application on Android (Physical Device), macOS (Desktop), and Web (Chrome) from initial registration to all end flows, capturing evidence for each step.

---

## 1. Environment Setup & Preparation

1. **Connect Android Device**: Connect your physical Android phone to the MacBook via USB. Ensure USB Debugging is enabled.
2. **Build and Load**:
   - Android: `flutter run -d <android-device-id> --release`
   - macOS: `flutter run -d macos`
   - Chrome: `flutter run -d chrome`
3. **Evidence Folder Setup**: Create a folder named `qa_evidence` in the project root to store screenshots and screen recordings.
   ```bash
   mkdir qa_evidence
   echo "*" > qa_evidence/.gitignore # Optional: if you don't want to bloat the main repo, or just track it if required.
   ```
   *Note: If you want to lock these in Git as requested, do not ignore them. Commit them with standard tags.*

---

## 2. MNC Standard Testing Practices to Apply

During each module test, apply these standard enterprise testing methodologies:

- **Regression Testing**: Verify that newly added features (like AWS Sync or new APIs) haven't broken the existing core UI and database flows.
- **Stress & Load Testing**: 
  - Rapidly tap buttons (e.g., submit order 10 times in 1 second) to check for double-submissions.
  - Load lists with hundreds of dummy items to test scrolling performance and memory limits.
- **Interruption Testing (Mobile)**: 
  - Minimize the app and restore it.
  - Receive a phone call or alarm while processing a payment or order.
  - Lock the screen and unlock it while the app is running.
- **Network Resilience (Chaos Testing)**:
  - Turn off Wi-Fi/Data mid-operation. Does it queue locally?
  - Switch from Wi-Fi to Mobile Data.
  - Test on a severely throttled connection (3G speeds) to ensure timeouts are handled gracefully.
- **Security & Authorization**:
  - Attempt to access admin-only menus using a Staff or Driver account.
  - Input malicious strings (e.g., SQL injection characters like `' OR 1=1`) in text fields to ensure proper sanitization.

---

## 3. Evidence Collection & Git Commit Protocol

After completing the tests for a specific screen/module on a platform:
1. **Take a Screenshot/Screen Recording**.
2. **Save it** to `qa_evidence/` (e.g., `qa_evidence/android_login_success.png`).
3. **Commit & Lock in Git**:
   ```bash
   git add qa_evidence/
   git commit -m "[QA - Android] Passed Login and Registration module. Stress testing verified."
   ```

---

## 4. Comprehensive Module Test Checklist

*Perform this checklist iteratively on **Android**, **macOS**, and **Chrome**.*

### A. Onboarding & Authentication
- [ ] Fresh Install: Verify splash screen and initial load times (< 3 seconds).
- [ ] Registration: Create a new firm. Verify validation (invalid emails, short passwords).
- [ ] Login: Test successful login.
- [ ] Login: Test incorrect credentials (verify error messages).
- [ ] Role Based Login: Login as Admin, Staff, and Driver. Verify menu restrictions are enforced.
- [ ] **Stress Test**: Mash the login button to ensure duplicate API requests aren't fired.

### B. Core Settings & Master Data
- [ ] App Settings: Toggle dark/light mode and verify UI responsiveness.
- [ ] Profile Settings: Update firm name, logo, address. Verify changes reflect instantly.
- [ ] Taxes & Discounts: Add/Edit/Delete tax brackets. 
- [ ] **Network Test**: Turn off Wi-Fi, add a tax bracket, turn on Wi-Fi, verify Cloud Sync pushes it to AWS.

### C. Kitchen & Dishes Module
- [ ] Create Dish: Add a new dish with image, price, and category.
- [ ] Edit/Delete Dish: Modify details and delete.
- [ ] Kitchen Display System (KDS): Verify orders appear here dynamically.
- [ ] Production Queue TV: Verify the dedicated TV/Display queue auto-updates and alerts when orders are ready.
- [ ] **Interruption Test**: Lock phone while creating a dish, unlock, and ensure data isn't lost.

### D. Order Management (The Happy Path)
- [ ] Create Order: Add multiple distinct items to the cart.
- [ ] Modify Order: Change quantities, remove items before submitting.
- [ ] Apply Discounts & Taxes: Verify the math is 100% accurate.
- [ ] Submit Order: Verify state changes to 'Pending' or 'Sent to Kitchen'.
- [ ] **Stress Test**: Add 100+ items to an order to check if the UI stutters or crashes.

### E. Billing & Finance
- [ ] Process Payment: Generate an invoice.
- [ ] Split Payments: Test paying partially by Cash, partially by UPI.
- [ ] Refund/Cancel: Cancel an order and verify inventory/revenue reverts.
- [ ] Cash Drawer/Day End: Simulate closing the register for the day.

### F. Staff & Attendance (Mobile Heavy)
- [ ] Geofence Check-in: Verify GPS correctly blocks check-ins outside the perimeter (Android).
- [ ] Check-out: Record checkout time and calculate shift hours.
- [ ] Permissions: Ensure staff cannot alter their own attendance records.

### G. Dispatch & MRP
- [ ] Assign Driver: Assign a packed order to a driver.
- [ ] Driver Flow: Log in as driver, accept order, mark as 'Delivered'.
- [ ] User Map Tracking: Test the end-user side tracking link/map view to ensure real-time location updates of the driver are accurate.
- [ ] Live Tracking (if applicable): Validate GPS coordinate updates.

### H. Subcontractor Workflow
- [ ] Assign Order: Route a specific order or item to a subcontractor.
- [ ] Subcontractor Login: Log in as a subcontractor and verify restricted view of assigned orders.
- [ ] Status Update: Subcontractor marks item as finished/completed. Verify sync back to main kitchen/admin.

### I. Analytics & Reports
- [ ] Daily Summary: Check if today's test orders appear accurately in revenue.
- [ ] Date Filtering: Pick custom date ranges and ensure graphs update.
- [ ] **Performance Test**: Run an "All Time" report. Verify the app shows a loading spinner and doesn't freeze.

### J. Cloud Sync & Cross-Platform Integrity
- [ ] **The "Simultaneous" Test**: 
  1. Open App on macOS and Android simultaneously.
  2. Create an order on Android.
  3. Verify it appears on macOS within 3-5 seconds without manual refresh.
- [ ] Database Integrity: Clear app cache/data on Android, log back in, and ensure 100% of the data is restored from AWS.

---

## 5. Final Sign-Off

Once every item is checked for all 3 platforms and evidence is committed:
1. Review crash logs (`flutter crashlytics` or standard console output) to ensure 0 fatal errors occurred during testing.
2. Sign off on the release candidate.
3. Proceed to update `pubspec.yaml` version number and initiate Play Store / App Store builds!
