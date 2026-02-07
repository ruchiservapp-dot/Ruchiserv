import json
import boto3
import time
import datetime
import os
from decimal import Decimal
from boto3.dynamodb.conditions import Key

# Globals for lazy loading to reduce cold-start crash risk
_dynamodb = None

def get_db():
    global _dynamodb
    if _dynamodb is None:
        _dynamodb = boto3.resource('dynamodb')
    return _dynamodb

def _log(level, message, firm_id=None, user_id=None, duration=None, **kwargs):
    """Structured JSON logging for CloudWatch Insights."""
    log_entry = {
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

def extract_identity(event):
    """Extracts firmId and userId strictly from JWT claims (Cognito)."""
    request_context = event.get('requestContext', {})
    authorizer = request_context.get('authorizer', {})
    claims = authorizer.get('jwt', {}).get('claims', {})
    
    firm_id = claims.get('custom:firmId')
    user_id = claims.get('sub') 
    return firm_id, user_id

def lambda_handler(event, context):
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
                    'Access-Control-Allow-Headers': 'Content-Type,Authorization'
                },
                'body': ''
            }

        # 1. Identity Extraction
        firm_id, user_id = extract_identity(event)
        
        # 2. Parse Body
        raw_body = event.get('body')
        if isinstance(raw_body, str):
            body = json.loads(raw_body)
        else:
            body = raw_body or {}

        # 3. Check for Public Access (Filters/Login)
        is_public_request = False
        if body.get('method') == 'GET' and body.get('table') == 'ruchiserv_data' and body.get('filters', {}).get('pk'):
            is_public_request = True
            firm_id = body['filters']['pk']
        elif body.get('method') == 'GET' and body.get('table') == 'firms' and body.get('filters'):
            is_public_request = True
        elif body.get('firmId') and body.get('mobile') and body.get('password'):
            is_public_request = True

        if not firm_id and not is_public_request:
            return error("Missing authentication (firmId)", 401)

        # 4. WhatsApp Verification
        qs = event.get('queryStringParameters')
        if qs and qs.get('hub.mode') == 'subscribe':
            if qs.get('hub.verify_token') == 'ruchiserv_webhook_secure_123':
                return {'statusCode': 200, 'headers': {'Content-Type': 'text/plain'}, 'body': str(qs.get('hub.challenge'))}
            return error('Invalid token')

        # 5. Legacy Login Handler
        if body.get('firmId') and body.get('mobile') and body.get('password'):
            f_id = body['firmId']
            mob = body['mobile']
            pwd = body['password']
            
            db = get_db()
            f_res = db.Table('ruchiserv-firms').query(KeyConditionExpression=Key('firmid').eq(f_id))
            if not f_res.get('Items'): return error("firm_not_found")
            
            u_res = db.Table('ruchiserv-users').get_item(Key={'ruchiserv-firms': f_id, 'mobile': mob})
            u_item = u_res.get('Item')
            
            if not u_item: return error("mobile_not_found")
            if u_item.get('passwordHash') != pwd: return error("wrong_password")
                
            return success({'status': 'success', 'user': u_item})

        # 6. Payment Handler (Lazy load expensive service)
        payment_type = body.get('payment_type')
        if payment_type:
            from services.payments import CashfreePaymentService
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
                    customer_email=body.get('customer_email'),
                    return_url=body.get('return_url')
                )
                return success(res)
            elif payment_type == 'VERIFY_PAYMENT':
                sub_id = body.get('subscription_id')
                order_id = body.get('order_id')
                status_data = ps.get_subscription_status(sub_id) if sub_id else ps.get_order_status(order_id)
                return success({'data': status_data})

        # 7. Database Handler
        db = get_db()
        method = body.get('method', 'GET')
        table_name = body.get('table', 'firms')
        data = body.get('data', {})
        filters = body.get('filters', {})

        target_table_name = table_name
        if table_name not in ['ruchiserv_data', 'ruchiserv-audit-log']:
            target_table_name = f'ruchiserv-{table_name}'
        
        table = db.Table(target_table_name)
        result = None

        if method == 'GET':
            pk_attr = 'pk' if table_name == 'ruchiserv_data' else ('ruchiserv-firms' if target_table_name == 'ruchiserv-users' else 'firmid')
            
            # GSI Search
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

            # List/Sync Query
            else:
                sk_prefix = filters.get('sk_prefix')
                query_pk = filters.get('pk') if table_name == 'ruchiserv_data' and filters.get('pk') else firm_id
                
                if sk_prefix:
                    res = table.query(KeyConditionExpression=Key(pk_attr).eq(query_pk) & Key('sk').begins_with(sk_prefix))
                else:
                    res = table.query(KeyConditionExpression=Key(pk_attr).eq(query_pk))
                
                items = res.get('Items', [])
                result = success({'Items': [i for i in items if not i.get('is_deleted', False)]})

        elif method == 'PUT':
            safe_data = convert_floats(data)
            pk_attr = 'pk' if table_name == 'ruchiserv_data' else 'firmId'
            if table_name == 'ruchiserv-users': pk_attr = 'ruchiserv-firms'
            
            # 1. Inject firmId/pk
            if table_name == 'ruchiserv_data':
                if not str(safe_data.get('pk', '')).startswith(firm_id): safe_data['pk'] = firm_id
            elif target_table_name == 'ruchiserv-users': safe_data['ruchiserv-firms'] = firm_id
            else: safe_data['firmId'] = firm_id

            # 2. Scale Protection: Conditional Update (Conflict Detection)
            # If client provides 'prev_updated_at', only update if it matches
            cond = None
            expr_vals = {}
            if body.get('prev_updated_at'):
                # Force failure if updatedAt on server != prev_updated_at
                cond = "attribute_not_exists(#pk) OR updatedAt = :prev"
                expr_vals[':prev'] = body['prev_updated_at']
            
            try:
                put_kwargs = {'Item': safe_data}
                if cond:
                    put_kwargs['ConditionExpression'] = cond
                    put_kwargs['ExpressionAttributeValues'] = expr_vals
                    put_kwargs['ExpressionAttributeNames'] = {"#pk": pk_attr}
                
                table.put_item(**put_kwargs)
                result = success({'status': 'SUCCESS'})
            except dynamodb.meta.client.exceptions.ConditionalCheckFailedException:
                _log("WARNING", "Conflict detected (ConditionalCheckFailed)", firm_id=firm_id)
                return error("conflict_detected", 409)

        elif method == 'DELETE':
            pk_attr = 'pk' if table_name == 'ruchiserv_data' else 'firmId'
            if filters.get(pk_attr) != firm_id and table_name != 'ruchiserv_data':
                return error("Unauthorized delete", 403)
            table.delete_item(Key={pk_attr: filters[pk_attr], 'sk': filters['sk']})
            result = success({'status': 'DELETED'})

        elapsed = time.time() - start_time
        _log("INFO", f"Sync: {method} {table_name}", firm_id=firm_id, user_id=user_id, duration=elapsed)
        return result or error("Unsupported request", 400)

    except Exception as e:
        elapsed = time.time() - start_time
        _log("ERROR", str(e), firm_id=firm_id, user_id=user_id, duration=elapsed, traceback=True)
        return error(str(e), 500)
