---
description: Rules for AWS/DynamoDB data operations
---

# AWS Data Safety Rules

## NEVER DO WITHOUT EXPLICIT USER APPROVAL:
1. **Manual data restoration** - Do not manually insert/update DynamoDB records
2. **Bulk deletes** - Never delete multiple records
3. **Schema changes** - Do not modify table structures
4. **Direct boto3 operations** - All production data changes must go through the app's API

## Before ANY Data Operation:
- [ ] Ask user for explicit approval
- [ ] Explain what will be changed
- [ ] Wait for confirmation

## Debugging Only:
- READ operations (GET, scan) are allowed for debugging
- Use `curl` with the API endpoint, not direct AWS SDK calls
