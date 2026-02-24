---
description: CRITICAL - Run this workflow first to prevent code regressions and duplicate UI elements.
---
# Anti-Regression & Pre-Flight Check

To prevent "going in circles" where AI overwrites previous fixes due to disjointed chat sessions, run this workflow before modifying any core UI or DB logic.

1. Fetch latest changes and review git status to prevent branching errors.
// turbo
`git status && git log -n 5 --oneline`

2. Verify that `SettingsScreen` and `GeneralSettingsScreen` do NOT contain duplicated "Payment Settings" or "Manage Subscription" menus.
// turbo
`grep -n "Payment Settings" lib/screens/settings_screen.dart lib/screens/general_settings_screen.dart || true`
`grep -n "Manage Subscription" lib/screens/settings_screen.dart lib/screens/general_settings_screen.dart || true`

3. Verify that the debug "Test Payment Info" or "Fix Database Schema" buttons have NOT been accidentally re-inserted.
// turbo
`grep -n "Test Payment Info" lib/screens/payment_settings_screen.dart || true`
`grep -n "Fix Database Schema" lib/screens/general_settings_screen.dart || true`
