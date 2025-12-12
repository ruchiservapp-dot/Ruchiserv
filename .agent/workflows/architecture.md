---
description: RuchiServ Architecture & Design Decisions - DO NOT MODIFY WITHOUT FULL UNDERSTANDING
---

# RuchiServ – Master Architecture Document

> ⚠️ **CRITICAL**: Read this BEFORE making any changes to the codebase.

## Overview

**RuchiServ** is a **multi-tenant SaaS catering management app** for Indian catering businesses.

| Attribute | Value |
|-----------|-------|
| **Platform** | Flutter (macOS/iOS/Android/Web) |
| **Backend** | AWS (API Gateway + Lambda + DynamoDB) |
| **Local DB** | SQLite v19 (sqflite) – offline-first |
| **Architecture** | Offline-first with background sync |
| **Screens** | 56 screens across 8 modules |

---

## Core Design Principles

### 1. Multi-Tenancy via `firmId`
Every data entity **MUST belong to a firm**.
- `firmId` stored in SharedPreferences as `last_firm`
- All DB operations respect firmId for data isolation

### 2. Offline-First Architecture
- Local SQLite is the **source of truth** for UI
- Changes queue to `pending_sync` table when offline
- User can work fully offline for 30 days after last online login

### 3. PII Encryption (Compliance Rule C.3)
- Mobile/email encrypted using `EncryptionHelper`
- Initialized in `main.dart` BEFORE any DB operations

### 4. Web Platform Support
- Uses `sqflite_common_ffi_web` for SQLite on Web
- Web binaries: `sqflite_sw.js`, `sqlite3.wasm` in `/web/`
- Platform guards (`kIsWeb`) for file operations

---

## Module Structure (56 Screens)

### 0.x – Splash & Subscription
| Screen | File | Purpose |
|--------|------|---------|
| Splash | `0.0_splash_screen.dart` | App initialization |
| Subscription Lock | `0.1_subscription_lock_screen.dart` | Expired subscription UI |
| OTP Verification | `0.2_otp_verification_screen.dart` | Mobile OTP flow |

### 1.x – Authentication
| Screen | File | Purpose |
|--------|------|---------|
| Login | `1.4_login_screen.dart` | Mobile + password login |
| Register Choice | `1.6_register_choice.dart` | New user/firm registration |
| Forgot Password | `1.7_forgot_password.dart` | Password reset via OTP |
| Subscription Required | `1.8_subscription_required.dart` | Subscription paywall |

### 2.x – Orders Module
| Screen | File | Purpose |
|--------|------|---------|
| Calendar | `2.0_orders_calendar_screen.dart` | Heat map view, daily pax |
| Add/Edit Order | `2.1_add_order_screen.dart` | Full order creation (48KB) |
| Orders List | `2.2_orders_list_screen.dart` | Filterable order list |
| Summary | `2.3_summary_screen.dart` | Order summary report |

### 3.x – Operations Module
| Screen | File | Purpose |
|--------|------|---------|
| Operations Hub | `3.0_operations_screen.dart` | Module navigation |
| Kitchen Queue | `3.1_kitchen_screen.dart` | Production queue with BOM |
| Dispatch Board | `3.2_dispatch_screen.dart` | Dispatch management |
| Staff List | `3.3_staff_screen.dart` | Staff directory |
| Staff Detail | `3.3.1_staff_detail_screen.dart` | Profile, bank, advances |
| Staff Payroll | `3.3.2_staff_payroll_screen.dart` | Salary processing |
| My Attendance | `3.3.3_my_attendance_screen.dart` | GPS punch in/out |
| Utensils | `3.4_utensils_screen.dart` | Utensil inventory |

### 4.x – Inventory Module
| Screen | File | Purpose |
|--------|------|---------|
| Inventory Hub | `4.0_inventory_screen.dart` | Module navigation |
| Ingredients | `4.1_ingredients_screen.dart` | Raw materials master |
| Bill of Materials | `4.2_bom_screen.dart` | Recipe/ingredient mapping |
| MRP Run | `4.3_mrp_run_screen.dart` | Material requirement planning |
| MRP Output | `4.4_mrp_output_screen.dart` | MRP results display |
| Allotment | `4.5_allotment_screen.dart` | Ingredient allocation |
| Suppliers | `4.6_supplier_screen.dart` | Vendor management |
| Subcontractors | `4.7_subcontractor_screen.dart` | Outsourcing partners |
| Purchase Orders | `4.8_purchase_orders_screen.dart` | PO generation |

### 5.x – Dispatch & Reports
| Screen | File | Purpose |
|--------|------|---------|
| Dispatch Hub | `5.0_dispatch_hub_screen.dart` | Complete dispatch workflow |
| Dispatch List | `5.1_dispatch_list_screen.dart` | Vehicle dispatch tracking |
| Dispatch Detail | `5.2_dispatch_screen.dart` | Loading/dispatch actions |
| Return Screen | `5.3_return_screen.dart` | Return qty entry |
| Kitchen Unload | `5.4_kitchen_unload_screen.dart` | Unload qty entry |
| Reports Hub | `5.0_reports_screen.dart` | Analytics dashboard |
| Finance | `5.1_finance_screen.dart` | Financial overview |
| Transactions | `5.2_transactions_screen.dart` | Payment history |
| Ledger | `5.3_ledger_screen.dart` | Account ledger |

### 6.x – Settings & Masters
| Screen | File | Purpose |
|--------|------|---------|
| Settings | `6.0_settings_screen.dart` | App settings hub |
| About | `6.1_about_screen.dart` | App info |
| User Management | `6.2_user_management_screen.dart` | User CRUD |
| User Hub | `6.2_user_management_hub.dart` | RBAC management |
| Payment Settings | `6.3_payment_settings_screen.dart` | Payment config |
| General Settings | `6.4_general_settings_screen.dart` | App preferences |
| Authorized Mobiles | `6.5_manage_authorized_mobiles_screen.dart` | Mobile whitelist |
| Subscription | `6.6_subscription_screen.dart` | Plan management |
| Firm Profile | `6.7_firm_profile_screen.dart` | Business details |
| User Profile | `6.8_user_profile_screen.dart` | Personal settings |
| Vehicle Master | `6.9_vehicle_master_screen.dart` | Fleet management |
| Utensil Master | `6.10_utensil_master_screen.dart` | Utensil types |

### 7.x – Audit & Compliance
| Screen | File | Purpose |
|--------|------|---------|
| Audit Report | `7.1_audit_report_screen.dart` | Change logs, CSV export |

---

## Database Schema (Version 19)

### Core Tables
| Table | Purpose |
|-------|---------|
| `orders` | Customer orders with service/counter costs |
| `dishes` | Line items with production status |
| `dish_master` | Autocomplete suggestions |
| `firms` | Tenant info, GPS location, subscription |
| `users` | User accounts per firm |
| `local_users` | Offline login cache |
| `authorized_mobiles` | Mobile whitelist |
| `pending_sync` | Offline queue |

### Operations Tables
| Table | Purpose |
|-------|---------|
| `staff` | Employee master with payroll info |
| `attendance` | GPS-based punch records |
| `staff_advances` | Salary advances |
| `staff_assignments` | Order-staff mapping |
| `vehicles` | Fleet master |
| `dispatches` | Dispatch tracking |
| `dispatch_items` | Items per dispatch |
| `utensils` | Utensil inventory |

### Inventory Tables
| Table | Purpose |
|-------|---------|
| `ingredients` | Raw materials master |
| `ingredients_master` | System preloaded ingredients |
| `recipe_detail` | BOM per dish |
| `suppliers` | Vendor master |
| `subcontractors` | Outsourcing partners |
| `purchase_orders` | PO tracking |
| `service_rates` | Last used rates |
| `audit_log` | Change tracking |

---

## Key Workflows

### Order → Kitchen → Dispatch Flow
```
Order Created → Dishes PENDING
     ↓
Kitchen marks COMPLETED
     ↓
Dispatch loads items → Status: LOADING
     ↓
Vehicle dispatched → Status: DISPATCHED
     ↓
Delivery confirmed → Status: DELIVERED
     ↓
Returns entered → Status: RETURNING
     ↓
Kitchen unload → Status: COMPLETED
```

### Offline Sync Flow
```
User action → Write to SQLite
           → Add to pending_sync
           → Check connectivity
           → If online: Push to AWS
           → AWS confirms: Remove from queue
```

---

## Changelog

### 2025-12-09: Web Platform Support
- Added `sqflite_common_ffi_web` for SQLite on Web
- Platform guards in `EncryptionHelper`, `AuditReportScreen`, `StaffDetailScreen`
- Added `assets/fonts/` to pubspec for Web fonts

### 2025-12-08: Return & Kitchen Unload Screens
- Built `5.3_return_screen.dart` for dispatch returns
- Built `5.4_kitchen_unload_screen.dart` for kitchen receiving
- Column-based layout with validated quantity inputs

### 2025-12-05: Kitchen BOM Integration
- Added ingredient details to Kitchen Queue
- Integrated `recipe_detail` and `ingredients_master` tables
- Per-dish ingredient quantity calculation

### 2025-12-06: Service & Counter Setup
- Added 10 service fields to orders table
- StaffingLogic helper for auto-calculating servers
- Grand Total = Dishes + Service + Counter costs

---

## DO NOT CHANGE (Locked Logic)

1. **Auth flow** – firmId + mobile based login
2. **Encryption** – PII encryption in EncryptionHelper
3. **Subscription checks** – Grace period logic
4. **Audit logging** – All changes logged
5. **Offline sync** – pending_sync queue mechanism
6. **Web factory** – `databaseFactory = databaseFactoryFfiWeb`

