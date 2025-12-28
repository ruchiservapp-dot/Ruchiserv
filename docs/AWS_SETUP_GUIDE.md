# AWS Cost-Optimized Setup Guide for RuchiServ

## Why ₹8000 Bill Without Usage?

Common causes:
1. **NAT Gateway** - ₹3000+/month if left running
2. **RDS Database** - ₹2500+/month for db.t3.micro
3. **CloudWatch Logs** - Grows silently if not configured
4. **Lambda Provisioned Concurrency** - Charges 24/7
5. **API Gateway REST API** - More expensive than HTTP API

> **Solution**: Use **serverless-only** architecture with **DynamoDB** instead of RDS

---

## Recommended Architecture (10-25 Clients)

```
┌──────────────┐     ┌───────────────────┐     ┌─────────────┐
│  Flutter App │────▶│  API Gateway HTTP │────▶│   Lambda    │
└──────────────┘     └───────────────────┘     └──────┬──────┘
                                                      │
                                                      ▼
                                               ┌─────────────┐
                                               │  DynamoDB   │
                                               └─────────────┘
```

**Monthly Cost Estimate: ₹0 - ₹500** (Free tier + minimal usage)

---

## Step-by-Step Setup

### Step 1: Set Billing Alert (CRITICAL - Do First!)

1. Go to **AWS Console → Billing → Budgets**
2. Click **Create Budget → Cost Budget**
3. Set:
   - Budget name: `RuchiServ-Alert`
   - Amount: `₹1000` (or $12)
   - Alert threshold: `80%`
   - Email: Your email
4. **Create Budget**

### Step 2: Create DynamoDB Tables (Free Tier: 25GB + 25 WCU/RCU)

1. Go to **DynamoDB → Create Table**
2. Create these tables:

| Table Name | Partition Key | Sort Key | Billing Mode |
|------------|--------------|----------|--------------|
| `ruchiserv-firms` | `firmId` (S) | - | On-demand |
| `ruchiserv-users` | `firmId` (S) | `mobile` (S) | On-demand |
| `ruchiserv-sync` | `firmId` (S) | `timestamp` (S) | On-demand |
| `ruchiserv-subscriptions` | `firmId` (S) | `paymentId` (S) | On-demand |

> **On-demand billing** = Pay per request (best for 10-25 clients)

### Step 3: Create Lambda Function

1. Go to **Lambda → Create Function**
2. Settings:
   - Name: `ruchiserv-api`
   - Runtime: `Python 3.12`
   - Architecture: `arm64` (cheaper than x86)
   - Memory: `128 MB` (minimum)
   - Timeout: `10 seconds`

3. **Deploy this code:**

```python
import json
import boto3
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    try:
        body = json.loads(event.get('body', '{}'))
        method = body.get('method')
        table_name = body.get('table')
        data = body.get('data', {})
        filters = body.get('filters', {})
        
        table = dynamodb.Table(f'ruchiserv-{table_name}')
        
        if method == 'GET':
            response = table.get_item(Key=filters)
            return success(response.get('Item'))
        
        elif method == 'PUT':
            table.put_item(Item=data)
            return success({'message': 'Created'})
        
        elif method == 'UPDATE':
            # Build update expression
            update_expr = 'SET ' + ', '.join([f'{k} = :{k}' for k in data.keys()])
            expr_values = {f':{k}': v for k, v in data.items()}
            table.update_item(
                Key=filters,
                UpdateExpression=update_expr,
                ExpressionAttributeValues=expr_values
            )
            return success({'message': 'Updated'})
        
        elif method == 'DELETE':
            table.delete_item(Key=filters)
            return success({'message': 'Deleted'})
        
        elif method == 'SCAN':
            response = table.scan()
            return success(response.get('Items', []))
        
        else:
            return error('Unknown method')
            
    except Exception as e:
        return error(str(e))

def success(data):
    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
        'body': json.dumps(data, default=str)
    }

def error(msg):
    return {
        'statusCode': 400,
        'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
        'body': json.dumps({'error': msg})
    }
```

4. **Add DynamoDB permissions:**
   - Go to Configuration → Permissions → Click role name
   - Attach policy: `AmazonDynamoDBFullAccess`

### Step 4: Create API Gateway (HTTP API - Cheaper!)

1. Go to **API Gateway → Create API → HTTP API**
2. Name: `ruchiserv-api`
3. Add integration:
   - Type: Lambda
   - Function: `ruchiserv-api`
4. Route: `POST /dbhandler` → Lambda
5. Stage: `prod` (auto-deploy: ON)
6. **Copy the Invoke URL** (e.g., `https://xxxxx.execute-api.ap-south-1.amazonaws.com`)

### Step 5: Update App Config

Update `lib/db/aws/aws_api.dart`:

```dart
static const String _baseUrl = 'YOUR_NEW_API_GATEWAY_URL';
static const String _stage = 'prod';
```

---

## Cost Comparison

| Resource | Previous Setup | Optimized Setup |
|----------|---------------|-----------------|
| Database | RDS (₹2500/mo) | DynamoDB (Free) |
| Compute | Lambda + NAT Gateway | Lambda only (Free tier: 1M/mo) |
| API | REST API | HTTP API (70% cheaper) |
| Storage | EBS volumes | None needed |
| **Total** | **₹8000/mo** | **₹0-500/mo** |

---

## Free Tier Limits (12 months)

| Service | Free Limit | Your Usage (25 clients) |
|---------|-----------|------------------------|
| Lambda | 1M requests/mo | ~50K |
| API Gateway | 1M calls/mo | ~50K |
| DynamoDB | 25 WCU/RCU, 25GB | ~5GB |
| CloudWatch | 5GB logs | Configure retention |

---

## Important: Disable Unused Resources

Check and delete if exists:
1. **EC2 Instances** (even stopped ones have EBS charges)
2. **NAT Gateways** (₹3000+/mo)
3. **RDS Databases**
4. **Elastic IPs** (₹300/mo if unattached)
5. **Load Balancers**

**To find all resources:**
- Go to **Resource Groups → Tag Editor → All Regions → All Resource Types → Search**

---

## CloudWatch Log Retention

1. Go to **CloudWatch → Log Groups**
2. For each log group:
   - Click → Actions → Edit retention
   - Set to **7 days** (instead of "Never expire")

---

## Quick Checklist

- [ ] Budget alert set (₹1000)
- [ ] DynamoDB tables created (On-demand billing)
- [ ] Lambda function deployed (128MB, arm64)
- [ ] HTTP API Gateway created (not REST API)
- [ ] App config updated with new URL
- [ ] Old account: Delete all resources
- [ ] CloudWatch logs: 7-day retention
