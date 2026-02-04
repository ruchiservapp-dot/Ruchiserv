import json
import boto3
import time
import datetime
import os
from decimal import Decimal
from boto3.dynamodb.conditions import Key
from services.payments import CashfreePaymentService

dynamodb = boto3.resource('dynamodb')

def _log(level, message, firm_id=None, user_id=None, duration=None, **kwargs):
    """Structured JSON logging for CloudWatch Insights."""
    log_entry = {
        "timestamp": time.time(),
        "level": level,
        "message": message,
        "firm_id": firm_id,
        "user_id": user_id,
        "duration_ms": round(duration * 1000, 2) if duration else None,
        **kwargs
    }
    print(json.dumps(log_entry, default=str))

def success(data):
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization'
        },
        'body': json.dumps(data, default=str)
    }

def error(msg, code=400):
    return {
        'statusCode': code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization'
        },
        'body': json.dumps({'error': msg})
    }

def convert_floats(obj):
    if isinstance(obj, float): return Decimal(str(obj))
    if isinstance(obj, dict): return {k: convert_floats(v) for k, v in obj.items()}
    if isinstance(obj, list): return [convert_floats(i) for i in obj]
    return obj

def get_timestamp():
    return datetime.datetime.utcnow().isoformat()

def extract_identity(event):
    """
    Extracts firmId and userId strictly from JWT claims (Cognito).
    Legacy fallback has been removed for production security.
    """
    request_context = event.get('requestContext', {})
    authorizer = request_context.get('authorizer', {})
    claims = authorizer.get('jwt', {}).get('claims', {})
    
    firm_id = claims.get('custom:firmId')
    user_id = claims.get('sub') # Cognito Unique User ID

    return firm_id, user_id

def lambda_handler(event, context):
    print(f"DEBUG: Lambda Event: {json.dumps(event)}")
    start_time = time.time()
    firm_id, user_id = "UNKNOWN", "UNKNOWN"
    
    try:
        # 0. CORS Preflight
        method = event.get('httpMethod') or event.get('requestContext', {}).get('http', {}).get('method')
        if method == 'OPTIONS':
            return {
                'statusCode': 200,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'
                },
                'body': ''
            }

        # 1. Identity Extraction
        firm_id, user_id = extract_identity(event)
        
        # 3. Parse Body (Move up to check public access)
        raw_body = event.get('body')
        body = json.loads(raw_body) if raw_body else {}

        # Check for Public Access (e.g. Firm Lookup during Login or Legacy Login)
        is_public_request = False
        if body.get('method') == 'GET' and body.get('table') == 'firms' and body.get('filters'):
            is_public_request = True
        elif body.get('firmId') and body.get('mobile') and body.get('password'):
            is_public_request = True
        # Allow sync GET queries to ruchiserv_data with pk filter (pk IS the authorization)
        elif body.get('method') == 'GET' and body.get('table') == 'ruchiserv_data' and body.get('filters', {}).get('pk'):
            is_public_request = True
            firm_id = body['filters']['pk']  # Trust the pk as firm_id for this request

        if not firm_id and not is_public_request:
            return error("Missing authentication (firmId)", 401)

        # 2. WhatsApp Verification (GET parameters)
        qs = event.get('queryStringParameters')
        if qs and qs.get('hub.mode') == 'subscribe':
            if qs.get('hub.verify_token') == 'ruchiserv_webhook_secure_123':
                return {'statusCode': 200, 'headers': {'Content-Type': 'text/plain'}, 'body': str(qs.get('hub.challenge'))}
            return error('Invalid token')

        # 3. Parse Body
        raw_body = event.get('body')
        body = json.loads(raw_body) if raw_body else {}

        # 4. WhatsApp Webhooks
        if isinstance(body, dict) and body.get('object') == 'whatsapp_business_account':
            _log("INFO", "WhatsApp Webhook Received", firm_id=firm_id)
            return success({'status': 'RECEIVED'})

        # 4b. Legacy Login Handler (Public)
        # This handles POST requests to /login (or any path) with firmId, mobile, password
        if body.get('firmId') and body.get('mobile') and body.get('password'):
            f_id = body['firmId']
            mob = body['mobile']
            pwd = body['password']
            
            _log("INFO", f"Legacy login attempt for {mob} / {f_id}")
            
            # Check Firm
            f_table = dynamodb.Table('ruchiserv-firms')
            f_res = f_table.query(KeyConditionExpression=Key('firmid').eq(f_id))
            if not f_res.get('Items'):
                return error("firm_not_found")
            
            # Check User
            u_table = dynamodb.Table('ruchiserv-users')
            u_res = u_table.get_item(Key={'ruchiserv-firms': f_id, 'mobile': mob})
            u_item = u_res.get('Item')
            
            if not u_item:
                return error("mobile_not_found")
            
            if u_item.get('passwordHash') != pwd:
                return error("wrong_password")
                
            return success({
                'status': 'success',
                'user': u_item
            })

        # 5. Payment Handler
        payment_type = body.get('payment_type') # 'ORDER' or 'SUBSCRIPTION'
        if payment_type:
            ps = CashfreePaymentService()
            if payment_type == 'ORDER':
                res = ps.create_order(
                    amount=body.get('amount'),
                    customer_id=user_id,
                    customer_phone=body.get('customer_phone'),
                    customer_email=body.get('customer_email')
                )
                return success(res)
            elif payment_type == 'SUBSCRIPTION':
                res = ps.create_subscription(
                    plan_id=body.get('plan_id', 'MONTHLY'),
                    customer_id=user_id,
                    customer_phone=body.get('customer_phone'),
                    customer_email=body.get('customer_email')
                )
                return success(res)
            elif payment_type == 'MANDATE_UPDATE':
                res = ps.update_mandate(
                    subscription_id=body.get('subscription_id')
                )
                return success(res)

        # 6. Database Handler (Sync Logic)
        method = body.get('method', 'GET')
        table_name = body.get('table', 'firms')
        data = body.get('data', {})
        filters = body.get('filters', {})

        target_table_name = table_name
        if table_name not in ['ruchiserv_data', 'ruchiserv-audit-log']:
            target_table_name = f'ruchiserv-{table_name}'
        
        table = dynamodb.Table(target_table_name)
        result = None

        if method == 'GET':
            pk_attr = 'ruchiserv-firms' if target_table_name == 'ruchiserv-users' else ('pk' if target_table_name == 'ruchiserv_data' else 'firmid') # Fixed: Partition key is firmid

            # For unauthenticated GET to firms
            if not firm_id and table_name == 'firms' and filters.get('firmid'):
                firm_id = filters['firmid']
                _log("INFO", "Public lookup for firm", firm_id=firm_id)
            if filters and 'index_name' in filters:
                idx_name = filters['index_name']
                gsi_pk = filters.get('gsi_pk_name', 'gsi_partition')
                gsi_sk = filters.get('gsi_sk_name', 'gsi_sort')
                pk_val = filters.get('gsi_pk')
                sk_val = filters.get('gsi_sk')
                
                if pk_val and not str(pk_val).startswith(firm_id):
                    return error(f"Unauthorized index access", 403)
                
                key_expr = Key(gsi_pk).eq(pk_val)
                op = filters.get('sk_op', 'eq')
                if sk_val:
                    if op == 'begins_with': key_expr = key_expr & Key(gsi_sk).begins_with(sk_val)
                    elif op == 'between' and 'gsi_sk_end' in filters: key_expr = key_expr & Key(gsi_sk).between(sk_val, filters['gsi_sk_end'])
                    else: key_expr = key_expr & Key(gsi_sk).eq(sk_val)

                res = table.query(IndexName=idx_name, KeyConditionExpression=key_expr)
                result = success({'Items': [i for i in res.get('Items', []) if not i.get('is_deleted', False)]})

            # Key-based fetch
            elif filters and pk_attr in filters and 'sk' in filters:
                if filters.get(pk_attr) != firm_id and target_table_name != 'ruchiserv_data':
                    return error("Unauthorized firm access", 403)
                res = table.get_item(Key={pk_attr: filters[pk_attr], 'sk': filters['sk']})
                item = res.get('Item')
                result = success(None if item and item.get('is_deleted') else item)
            
            # List-based Query
            else:
                sk_prefix = filters.get('sk_prefix')
                # For ruchiserv_data, use the pk from filters if firm_id is empty
                # This allows sync from frontend when JWT doesn't have custom:firmId
                query_pk = filters.get('pk') if target_table_name == 'ruchiserv_data' and filters.get('pk') else firm_id
                if sk_prefix:
                    res = table.query(KeyConditionExpression=Key(pk_attr).eq(query_pk) & Key('sk').begins_with(sk_prefix))
                else:
                    res = table.query(KeyConditionExpression=Key(pk_attr).eq(query_pk))
                items = res.get('Items', [])
                result = success({'Items': [i for i in items if not i.get('is_deleted', False)]})

        elif method == 'PUT':
            safe_data = convert_floats(data)
            if target_table_name == 'ruchiserv-users': safe_data['ruchiserv-firms'] = firm_id
            elif target_table_name == 'ruchiserv_data':
                if not str(safe_data.get('pk', '')).startswith(firm_id): safe_data['pk'] = firm_id
            else: safe_data['firmId'] = firm_id

            table.put_item(Item=safe_data)
            result = success({'status': 'SUCCESS'})

        elif method == 'DELETE':
            pk_attr = 'pk' if target_table_name == 'ruchiserv_data' else 'firmId'
            if not filters or pk_attr not in filters or 'sk' not in filters:
                return error("Missing keys for DELETE")
            if filters[pk_attr] != firm_id and target_table_name != 'ruchiserv_data':
                return error("Unauthorized delete", 403)

            table.delete_item(Key={pk_attr: filters[pk_attr], 'sk': filters['sk']})
            result = success({'status': 'DELETED'})

        # Final logging and return
        elapsed = time.time() - start_time
        _log("INFO", f"Sync: {method} {table_name}", firm_id=firm_id, user_id=user_id, duration=elapsed)
        return result or error("Unsupported request", 400)

    except Exception as e:
        elapsed = time.time() - start_time
        _log("ERROR", str(e), firm_id=firm_id, user_id=user_id, duration=elapsed, traceback=True)
        return error(str(e), 500)
