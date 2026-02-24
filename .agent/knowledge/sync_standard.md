# RuchiServ Atomic Sync Knowledge Base

## Overview
This document serves as the source of truth for RuchiServ's synchronization logic and concurrency handling. All future development must adhere to these standards to prevent data loss in multi-device environments.

## The Atomic Merge Pattern
RuchiServ uses **Field-Level Merging** instead of whole-record overwrites. This allows User A to edit one field (e.g., `notes`) while User B edits another (e.g., `discount`) without the two updates nullifying each other.

### Core Implementation
- **Standard Method:** `DatabaseHelper.updateRecord(String table, int id, Map<String, dynamic> updates)`
- **Logic Location:** `DatabaseHelper._getMergedRecord`
- **Mechanism:**
  1. Fetch the remote record (latest from DynamoDB).
  2. Compare each field's current remote value with the proposed update.
  3. If version/timestamp metadata indicates a field-level conflict, the merging logic decides based on `updatedAt` timestamps.
  4. The result is a merged record that hit's the cloud first (`awsFirstUpdate`).

### Synchronization Rules
1. **Cloud as Source of Truth:** Direct `db.update` calls are deprecated. Updates must go through `updateRecord` to ensure the cloud is synchronized before the local state is finalized.
2. **UI Reactivity:** All updates emit a `SyncEvent` through `syncStreamController`. UI providers and screens must listen to this stream to provide real-time updates.
3. **No Polling:** Data propagation is triggered via Firebase Cloud Messaging (FCM) silent pushes. Explicit polling is forbidden to reduce AWS costs.

## Repository Migration Status (Feb 2026)
The following repositories have been 100% migrated to the Atomic Pattern:
- `OrderRepository`
- `FinanceRepository`
- `InventoryRepository`
- `OperationRepository`

---
*Created: Feb 26, 2026*
