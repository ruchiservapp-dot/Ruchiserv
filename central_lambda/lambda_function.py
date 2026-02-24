# @locked - Core Sync & Messaging Architecture. Do not modify without full understanding.
import json
import boto3
import time
import datetime
import os
from decimal import Decimal
from boto3.dynamodb.conditions import Key, Attr

# Push-Pull Architecture: FCM for real-time sync
_fcm_service = None
def get_fcm():
    global _fcm_service
    if _fcm_service is None:
        from services.fcm import get_fcm_service
        _fcm_service = get_fcm_service()
    return _fcm_service

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

def extract_identity(event, body):
    """Extracts firmId and userId from JWT claims (Cognito) or fallback to body."""
    request_context = event.get('requestContext', {})
    authorizer = request_context.get('authorizer', {})
    claims = authorizer.get('jwt', {}).get('claims', {})
    
    firm_id = claims.get('custom:firmId')
    user_id = claims.get('sub') 
    
    # Fallback for Legacy Login / API calls providing firmId in body
    if not firm_id:
        firm_id = body.get('firmId') or body.get('filters', {}).get('pk')
    
    if firm_id:
        firm_id = str(firm_id).upper()
    
    if not user_id:
        user_id = body.get('mobile', 'UNKNOWN')
        
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

        # 2. Parse Body & Params
        raw_body = event.get('body')
        if isinstance(raw_body, str):
            body = json.loads(raw_body)
        else:
            body = raw_body or {}
        
        # Core Request Params
        method = body.get('method', event.get('httpMethod', 'GET'))
        table_name = body.get('table', 'firms')
        data = body.get('data', {})
        filters = body.get('filters', {})

        # 1. Identity Extraction (Now with body access)
        firm_id, user_id = extract_identity(event, body)

        # 3. Check for Public Access (Filters/Login)
        is_public_request = False
        if body.get('method') == 'GET' and body.get('table') == 'ruchiserv_data' and body.get('filters', {}).get('pk'):
            sk_prefix = body.get('filters', {}).get('sk_prefix', '')
            sk = body.get('filters', {}).get('sk', '')
            # Allow public access for firm registration/auth checks
            if sk.startswith('firms#') or sk.startswith('authorized_mobiles#') or sk_prefix.startswith('firms#'):
                is_public_request = True
                firm_id = body['filters']['pk']
        elif body.get('method') == 'GET' and body.get('table') == 'firms' and body.get('filters'):
            is_public_request = True
        elif body.get('firmId') and body.get('mobile') and body.get('password'):
            is_public_request = True
        elif body.get('method') == 'POST' and str(body.get('table', '')).startswith('messaging/'):
            is_public_request = True  # Messaging uses server-side credentials only

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
            f_id = str(body['firmId']).upper()
            mob = str(body['mobile']).strip()
            pwd = str(body['password']).strip()
            
            db = get_db()
            
            # --- 1. FIRM CHECK ---
            firm_item = None
            # Try Legacy Table
            f_res = db.Table('ruchiserv-firms').query(KeyConditionExpression=Key('firmid').eq(f_id))
            if f_res.get('Items'):
                firm_item = f_res['Items'][0]
            else:
                # Try Unified Table
                f_res = db.Table('ruchiserv_data').query(
                    KeyConditionExpression=Key('pk').eq(f_id) & Key('sk').eq(f'firms#{f_id}')
                )
                if f_res.get('Items'):
                    firm_item = f_res['Items'][0]
            
            if not firm_item: return error("firm_not_found")
            
            # --- 2. USER CHECK ---
            user_item = None
            # Try Legacy Table
            u_res = db.Table('ruchiserv-users').get_item(Key={'ruchiserv-firms': f_id, 'mobile': mob})
            if u_res.get('Item'):
                user_item = u_res['Item']
            else:
                # Try Unified Table
                u_res = db.Table('ruchiserv_data').query(
                    KeyConditionExpression=Key('pk').eq(f_id) & Key('sk').eq(f'users#{mob}')
                )
                if u_res.get('Items'):
                    user_item = u_res['Items'][0]
            
            if not user_item: return error("mobile_not_found")
            
            # --- 3. PASSWORD CHECK ---
            # Handle float/int hashes if any (should be strings)
            stored_pwd = str(user_item.get('passwordHash', ''))
            if stored_pwd != pwd: return error("wrong_password")
                
            return success({'status': 'success', 'user': user_item})

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

        # 7. Messaging Handler (@locked - Stable Meta/Zepto Routing)
        if method == 'POST' and table_name.startswith('messaging/'):
            from services.messaging import WhatsAppService, EmailService, EmailTemplates
            
            if table_name == 'messaging/whatsapp/send':
                wa = WhatsAppService()
                success_sent = wa.send_template(
                    to_mobile=data.get('to'),
                    template_name=data.get('template'),
                    language_code=data.get('language', 'en_US'),
                    components=data.get('components')
                )
                if success_sent: return success({'status': 'success'})
                return error(wa.last_error or "WhatsApp Send Failed", 500)
                
            elif table_name == 'messaging/whatsapp/send_order_pdf':
                wa = WhatsAppService()
                # 1. Upload PDF Media to Meta
                pdf_bytes = __import__('base64').b64decode(data.get('pdf_base64', ''))
                media_id = wa.upload_media(pdf_bytes, filename=f"Order_{data.get('order_id_raw', 'PDF')}.pdf")
                
                if not media_id:
                    return error(wa.last_error or "Media Upload Failed", 500)
                
                # 2. Send Document Template
                success_sent = wa.send_document_template(
                    to_mobile=data.get('to'),
                    template_name='ruchiserv_order_interactive', # Specialized PDF template
                    media_id=media_id,
                    filename=f"Order_{data.get('order_id_raw', 'Details')}.pdf",
                    language_code='en',
                    body_text_params=data.get('text_params')
                )
                if success_sent: return success({'success': True})
                return error(wa.last_error or "WhatsApp PDF Send Failed", 500)

            elif table_name == 'messaging/email/send':
                em = EmailService()
                success_sent = em.send_email(
                    recipient=data.get('to'),
                    subject=data.get('subject'),
                    body=data.get('body'),
                    html_body=data.get('html_body')
                )
                if success_sent: return success({'status': 'success'})
                return error("Email Send Failed", 500)

            elif table_name == 'messaging/transactional/send':
                # New Route for Transactional Emails (Order/PO)
                type = data.get('type')
                payload = data.get('data', {})
                
                em = EmailService()
                templates = EmailTemplates()
                
                html_body = None
                subject = "New Notification"
                
                if type == 'ORDER':
                    order = payload.get('order', {})
                    dishes = payload.get('dishes', [])
                    firm_id = payload.get('firmId')
                    
                    # Fetch firm details if not in payload (optional, but good for completeness)
                    # For now, assuming firmId is enough or we fetch from DB? 
                    # Let's try to fetch firm details from DB to make the email professional
                    firm_details = {}
                    try:
                        db = get_db()
                        f_res = db.Table('ruchiserv-firms').query(KeyConditionExpression=Key('firmid').eq(firm_id))
                        if f_res.get('Items'): firm_details = f_res['Items'][0]
                    except: pass
                    
                    subject = f"Order Confirmation #{order.get('id')}"
                    html_body = templates.generate_order_html(order, dishes, firm_details)
                    
                elif type == 'PO':
                    po = payload.get('po', {})
                    items = payload.get('items', [])
                    firm_id = payload.get('firmId')
                    
                    firm_details = {}
                    try:
                        db = get_db()
                        f_res = db.Table('ruchiserv-firms').query(KeyConditionExpression=Key('firmid').eq(firm_id))
                        if f_res.get('Items'): firm_details = f_res['Items'][0]
                    except: pass

                    subject = f"Purchase Order #{po.get('poNumber')}"
                    html_body = templates.generate_po_html(po, items, firm_details)

                if html_body:
                    success_sent = em.send_email(
                        recipient=data.get('to'),
                        subject=subject,
                        body="Please view this email in a modern client.", # Fallback text
                        html_body=html_body
                    )
                    if success_sent: return success({'status': 'success'})
                    return error(em.last_error or "Transactional Email Failed", 500)
                else:
                    return error("Invalid Transaction Type", 400)

        # 7.5. S3 File Handler (Presigned URLs for image upload/download)
        if table_name.startswith('files/'):
            from services.s3_files import generate_upload_url, generate_download_url
            
            if table_name == 'files/upload-url':
                if not firm_id:
                    return error("firmId required for file upload", 400)
                file_type = data.get('fileType', 'invoices')
                file_name = data.get('fileName')
                
                result = generate_upload_url(firm_id, file_type, file_name)
                _log("INFO", "S3 upload URL generated", firm_id=firm_id, 
                     duration=time.time()-start_time, file_type=file_type)
                return success(result)
            
            elif table_name == 'files/download-url':
                s3_key = data.get('s3Key')
                if not s3_key:
                    return error("s3Key required", 400)
                
                result = generate_download_url(s3_key)
                _log("INFO", "S3 download URL generated", firm_id=firm_id,
                     duration=time.time()-start_time)
                return success(result)
            
            return error(f"Unknown file route: {table_name}", 400)

        # 8. Database Handler
        db = get_db()
        # (Variables method, table_name, data, filters are now defined at the top)

        target_table_name = table_name
        if table_name not in ['ruchiserv_data', 'ruchiserv-audit-log']:
            target_table_name = f'ruchiserv-{table_name}'
        
        table = db.Table(target_table_name)
        result = None

        if method == 'GET':
            # Standardize PK attribute as 'firmid' for consistency across most tables
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
                result = success({'Items': res.get('Items', [])})

            # List/Sync Query
            else:
                sk_prefix = filters.get('sk_prefix')
                query_pk = filters.get('pk') if table_name == 'ruchiserv_data' and filters.get('pk') else firm_id
                
                # Differential Sync: Filter by updatedAt if 'since' is provided
                query_kwargs = {'KeyConditionExpression': Key(pk_attr).eq(query_pk)}
                if sk_prefix:
                    query_kwargs['KeyConditionExpression'] &= Key('sk').begins_with(sk_prefix)
                
                if filters.get('since'):
                    query_kwargs['FilterExpression'] = Attr('updatedAt').gt(filters['since'])
                
                res = table.query(**query_kwargs)
                
                items = res.get('Items', [])
                # For sync results, we include is_deleted=True so that other devices can remove them locally.
                # Standard listings should eventually filter these, but for sync parity, they must propagate.
                result = success({'Items': items})

        elif method == 'PUT':
            safe_data = convert_floats(data)
            pk_attr = 'pk' if table_name == 'ruchiserv_data' else 'firmid'
            if table_name == 'ruchiserv-users': pk_attr = 'ruchiserv-firms'
            
            # 1. Inject firmId/pk
            if table_name == 'ruchiserv_data':
                if not str(safe_data.get('pk', '')).startswith(firm_id): safe_data['pk'] = firm_id
            elif target_table_name == 'ruchiserv-users': safe_data['ruchiserv-firms'] = firm_id
            else: safe_data['firmid'] = firm_id

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
                
                # Push-Pull: Notify all devices in the firm (@locked - Core Sync)
                try:
                    sk = safe_data.get('sk', '')
                    sync_table = sk.split('#')[0] if '#' in sk else table_name
                    get_fcm().notify_firm_sync(firm_id, sync_table, 'SYNC', db)
                except Exception as fcm_err:
                    _log("WARNING", f"FCM notify failed: {fcm_err}", firm_id=firm_id)
            except dynamodb.meta.client.exceptions.ConditionalCheckFailedException:
                _log("WARNING", "Conflict detected (ConditionalCheckFailed)", firm_id=firm_id)
                return error("conflict_detected", 409)

        elif method == 'DELETE':
            pk_attr = 'pk' if table_name == 'ruchiserv_data' else 'firmid'
            if filters.get(pk_attr) != firm_id and table_name != 'ruchiserv_data':
                return error("Unauthorized delete", 403)
            
            # Professional Sync: Use Soft Deletes so other devices can sync the 'deletion' state
            import time
            from datetime import datetime
            now = datetime.now().isoformat()
            
            # We need to fetch the existing item to perform a soft delete via PUT/update
            # or simply put a tombstone. Soft delete is safer.
            try:
                table.update_item(
                    Key={pk_attr: filters[pk_attr], 'sk': filters['sk']},
                    UpdateExpression="SET is_deleted = :d, updatedAt = :u",
                    ExpressionAttributeValues={':d': True, ':u': now}
                )
                result = success({'status': 'DELETED (SOFT)'})
            except Exception as e:
                _log("ERROR", f"Soft delete failed: {e}", firm_id=firm_id)
                return error("Delete failed", 500)
            
            # Push-Pull: Notify all devices in the firm
            try:
                sk = filters.get('sk', '')
                sync_table = sk.split('#')[0] if '#' in sk else table_name
                get_fcm().notify_firm_sync(firm_id, sync_table, 'DELETE', db)
            except Exception as fcm_err:
                _log("WARNING", f"FCM notify failed: {fcm_err}", firm_id=firm_id)

        elapsed = time.time() - start_time
        _log("INFO", f"Sync: {method} {table_name}", firm_id=firm_id, user_id=user_id, duration=elapsed)
        return result or error("Unsupported request", 400)

    except Exception as e:
        elapsed = time.time() - start_time
        _log("ERROR", str(e), firm_id=firm_id, user_id=user_id, duration=elapsed, traceback=True)
        return error(str(e), 500)
