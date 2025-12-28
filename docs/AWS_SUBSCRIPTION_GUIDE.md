# AWS Subscription Backend Guide

This document outlines the backend implementation needed to verify UPI payments and manage subscription status.

## Overview

The app sends payment details (Client UPI ID, UTR, Amount, Plan) to your AWS backend. You verify payments against your bank statement and extend the firm's subscription.

## API Endpoint

### POST `/api/subscription/submit-payment`

**Request Body:**
```json
{
  "firmId": "FIRM123",
  "clientUpiId": "user@upi",
  "planName": "Pro",
  "amount": 2499.00,
  "utr": "412345678901",
  "transactionRef": "RS-FIRM123-1703001234567",
  "timestamp": "2024-12-20T12:30:00Z"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Payment submitted for verification",
  "subscriptionEndDate": "2025-01-20T00:00:00Z"
}
```

## DynamoDB Schema

### `subscriptions` Table

| Field | Type | Description |
|-------|------|-------------|
| firmId | String | Partition Key |
| paymentId | String | Sort Key (timestamp-based) |
| clientUpiId | String | User's UPI ID for matching |
| planName | String | BASIC / PRO / ENTERPRISE |
| amount | Number | Amount in INR |
| utr | String | UPI Transaction Reference |
| status | String | PENDING / VERIFIED / FAILED |
| submittedAt | String | ISO timestamp |
| verifiedAt | String | ISO timestamp (when admin verifies) |
| subscriptionEndDate | String | New expiry date |

## Lambda Function (Python)

```python
import json
import boto3
from datetime import datetime, timedelta

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('subscriptions')

def lambda_handler(event, context):
    body = json.loads(event['body'])
    
    firm_id = body['firmId']
    utr = body['utr']
    amount = body['amount']
    plan_name = body['planName']
    client_upi_id = body['clientUpiId']
    
    # Calculate new end date (30 days from now or current expiry)
    new_end_date = datetime.now() + timedelta(days=30)
    
    # Save to DynamoDB
    payment_id = f"{datetime.now().isoformat()}-{utr}"
    
    table.put_item(Item={
        'firmId': firm_id,
        'paymentId': payment_id,
        'clientUpiId': client_upi_id,
        'planName': plan_name,
        'amount': int(amount),
        'utr': utr,
        'status': 'PENDING',
        'submittedAt': datetime.now().isoformat(),
        'subscriptionEndDate': new_end_date.isoformat(),
    })
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'success': True,
            'message': 'Payment submitted for verification',
            'subscriptionEndDate': new_end_date.isoformat()
        })
    }
```

## Manual Verification Workflow

1. **Check Bank Statement**: Match `UTR` and `clientUpiId` against incoming UPI credits
2. **Update Status**: Set `status` to `VERIFIED` in DynamoDB
3. **Sync to App**: App polls `/api/subscription/status/{firmId}` daily

## Status Check Endpoint

### GET `/api/subscription/status/{firmId}`

Returns current subscription status for the firm. App calls this on startup to sync subscription state.

```json
{
  "firmId": "FIRM123",
  "planName": "Pro",
  "status": "active",
  "subscriptionEndDate": "2025-01-20T00:00:00Z",
  "daysRemaining": 30
}
```

## Security Notes

- Validate `firmId` matches authenticated user's firm
- Rate limit payment submissions (max 5/day per firm)
- Log all payment attempts for audit
