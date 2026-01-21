import json
import boto3
import time
import datetime
import uuid
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
AUDIT_TABLE_NAME = 'ruchiserv-audit-log'

def convert_floats(obj):
    """Recursively convert floats to Decimals for DynamoDB compatibility"""
    if isinstance(obj, float):
        return Decimal(str(obj))
    elif isinstance(obj, dict):
        return {k: convert_floats(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [convert_floats(i) for i in obj]
    return obj

def get_timestamp():
    return datetime.datetime.utcnow().isoformat()

def write_audit_log(firm_id, table_name, action, entity_key, actor_id, before_snapshot, after_snapshot):
    """Writes an immutable record to the audit log table"""
    try:
        audit_table = dynamodb.Table(AUDIT_TABLE_NAME)
        log_entry = {
            'pk': f"AUDIT#{firm_id}",
            'sk': f"{int(time.time())}#{uuid.uuid4()}", # Time ordered unique ID
            'timestamp': get_timestamp(),
            'action': action, # CREATE, UPDATE, DELETE (SOFT)
            'target_table': table_name,
            'entity_key': json.dumps(entity_key),
            'actor_id': actor_id, 
            'before_snapshot': json.dumps(convert_floats(before_snapshot), default=str) if before_snapshot else None,
            'after_snapshot': json.dumps(convert_floats(after_snapshot), default=str) if after_snapshot else None
        }
        audit_table.put_item(Item=log_entry)
        print(f"✅ Audit Log Written: {action} on {table_name}")
    except Exception as e:
        print(f"❌ Audit Log Failed: {e}") 
        # meaningful error handling should happen here, but we don't want to crash the main transaction
        # per "Fail Open vs Fail Closed" debate - for now we log error and proceed.

    except Exception as e:
        import traceback
        traceback.print_exc()
        print(f"FATAL ERROR: {e}")
        return error(str(e))

def lambda_handler(event, context):
    try:
        print(f"🔍 DEBUG: Event received: {json.dumps(event, default=str)}")
        
        raw_body = event.get('body')
        if raw_body:
            body = json.loads(raw_body)
            if body is None: body = {}
        else:
            body = {}
            
        # --- SNS DETECTION ---
        if 'Records' in event and len(event['Records']) > 0 and 'Sns' in event['Records'][0]:
            # Direct SNS Trigger
            sns_msg = event['Records'][0]['Sns']
            method = 'POST'
            table_name = 'messaging/ses/webhook'
            data = sns_msg
        elif body.get('Type') in ['Notification', 'SubscriptionConfirmation']:
            # SNS via API Gateway (HTTPS Subscription)
            method = 'POST'
            table_name = 'messaging/ses/webhook'
            data = body
        else:
            # Standard API call
            method = body.get('method', 'GET')
            table_name = body.get('table', 'firms')
            data = body.get('data', {})
            if data is None: data = {}
        
        filters = body.get('filters', {}) if isinstance(body, dict) else {}
        if filters is None: filters = {}
        
        # 1. Table Name Validation
        if table_name in ['ruchiserv_data', 'ruchiserv-audit-log']:
            full_table_name = table_name
        else:
            full_table_name = f'ruchiserv-{table_name}'
        
        table = dynamodb.Table(full_table_name)

        # 2. Extract Identity (Placeholder for Token Logic)
        # In a real JWT world, we extract this from 'Authorization' header.
        # For now, we trust the body but prepare the variable.
        # CRITICAL: Client must send 'firmId' in data for ownership checks in future.
        firm_id = data.get('firmId') or filters.get('firmId') or 'UNKNOWN_FIRM'
        actor_id = data.get('updatedBy') or 'API_USER'

        if method == 'GET':
            if 'sk_prefix' in filters:
                pk = filters.get('pk')
                sk_prefix = filters.get('sk_prefix')
                response = table.query(
                    KeyConditionExpression='pk = :pk AND begins_with(sk, :prefix)',
                    ExpressionAttributeValues={':pk': pk, ':prefix': sk_prefix}
                )
                items = response.get('Items', [])
                # Filter out soft-deleted items
                active_items = [i for i in items if not i.get('is_deleted', False)]
                return success(active_items)
            elif filters:
                response = table.get_item(Key=filters)
                item = response.get('Item')
                if item and item.get('is_deleted', False):
                    return success(None) # Treat as 404
                return success(item)
            else:
                # SCAN is dangerous, but keeping for compatibility. 
                # Should be removed in Phase 2.
                response = table.scan()
                items = response.get('Items', [])
                active_items = [i for i in items if not i.get('is_deleted', False)]
                return success(active_items)
        
        elif method == 'PUT':
            safe_data = convert_floats(data)
            
            # 3. Fetch Before Snapshot (Read before Write)
            # We need the keys to fetch. Assuming 'data' contains the full key.
            # Using get_item is safer than condition check for audit purposes.
            keys = {'pk': safe_data.get('pk'), 'sk': safe_data.get('sk')}
            before_snapshot = None
            if keys['pk'] and keys['sk']:
                try:
                    old_item_resp = table.get_item(Key=keys)
                    before_snapshot = old_item_resp.get('Item')
                except:
                    pass # It might be a new item

            # 4. Perform Write
            table.put_item(Item=safe_data)
            
            # 5. Async Audit Log
            action_type = 'UPDATE' if before_snapshot else 'CREATE'
            write_audit_log(firm_id, full_table_name, action_type, keys, actor_id, before_snapshot, safe_data)
            
            return success({'message': 'Created'})
        
        elif method == 'DELETE':
            # 6. SOFT DELETE IMPL
            # Replaces table.delete_item(Key=filters)
            
            # Fetch before snapshot
            keys = filters
            before_snapshot = None
            try:
                old_item_resp = table.get_item(Key=keys)
                before_snapshot = old_item_resp.get('Item')
            except:
                pass

            if not before_snapshot:
                 return error('Item not found or already deleted')

            # Perform Boolean Soft Delete
            table.update_item(
                Key=keys,
                UpdateExpression="SET is_deleted = :val, active = :activeVar",
                ExpressionAttributeValues={
                    ':val': True,
                    ':activeVar': False
                }
            )
            
            # Audit Log
            write_audit_log(firm_id, full_table_name, 'DELETE (SOFT)', keys, actor_id, before_snapshot, {'is_deleted': True})
            return success({'message': 'Deleted (Soft)'})
        
        # === OTP: POST /auth/otp/request ===
        elif method == 'POST' and table_name == 'auth/otp/request':
            from services.otp.manager import OtpManager
            mobile = data.get('mobile')
            if not mobile: return error('Mobile required')
            
            result = OtpManager().request_otp(mobile)
            if result['success']: return success(result)
            return error(result.get('error', 'Unknown error'))

        # === OTP: POST /auth/otp/verify ===
        elif method == 'POST' and table_name == 'auth/otp/verify':
            from services.otp.manager import OtpManager
            mobile = data.get('mobile')
            code = data.get('otp')
            if not mobile or not code: return error('Mobile and OTP required')
            
            result = OtpManager().verify_otp(mobile, code)
            if result['success']: return success(result)
            return error(result.get('error', 'Verification failed'))

        # === TRANSACTIONAL EMAIL: POST /messaging/transactional/send ===
        elif method == 'POST' and table_name == 'messaging/transactional/send':
            print(f"📧 Transactional Email Request: {data.get('type')}")
            from services.messaging import EmailService, EmailTemplates
            
            msg_type = data.get('type')  # ORDER or PO
            recipient = data.get('to')
            payload_data = data.get('data', {})
            
            if not recipient:
                return error('Recipient email (to) is required')
            
            svc = EmailService()
            
            if msg_type == 'ORDER':
                order = payload_data.get('order', {})
                dishes = payload_data.get('dishes', [])
                firm_id = payload_data.get('firmId', 'DEFAULT')
                
                # Fetch firm details for letterpad (simplified - use defaults if not found)
                firm_details = {'name': 'RuchiServ Partner', 'address': ''}
                try:
                    firm_table = dynamodb.Table('ruchiserv-firms')
                    resp = firm_table.get_item(Key={'pk': f'FIRM#{firm_id}', 'sk': 'PROFILE'})
                    if resp.get('Item'):
                        firm_details = resp['Item']
                except Exception as e:
                    print(f"⚠️ Could not fetch firm details: {e}")
                
                html_body = EmailTemplates.generate_order_html(order, dishes, firm_details)
                subject = f"Order #{order.get('id')} Confirmation - {firm_details.get('name', 'RuchiServ')}"
                plain_body = f"Your order #{order.get('id')} has been confirmed. Total: ₹{order.get('grandTotal', 0)}"
                
                result = svc.send_email(recipient, subject, plain_body, html_body)
                if result:
                    return success({'success': True, 'message': 'Order confirmation email sent'})
                return error('Failed to send order email')
            
            elif msg_type == 'PO':
                po = payload_data.get('po', {})
                items = payload_data.get('items', [])
                firm_id = payload_data.get('firmId', 'DEFAULT')
                
                firm_details = {'name': 'RuchiServ Partner', 'address': ''}
                try:
                    firm_table = dynamodb.Table('ruchiserv-firms')
                    resp = firm_table.get_item(Key={'pk': f'FIRM#{firm_id}', 'sk': 'PROFILE'})
                    if resp.get('Item'):
                        firm_details = resp['Item']
                except Exception as e:
                    print(f"⚠️ Could not fetch firm details: {e}")
                
                html_body = EmailTemplates.generate_po_html(po, items, firm_details)
                subject = f"Purchase Order {po.get('poNumber')} - {firm_details.get('name', 'RuchiServ')}"
                plain_body = f"Purchase Order {po.get('poNumber')} has been created."
                
                result = svc.send_email(recipient, subject, plain_body, html_body)
                if result:
                    return success({'success': True, 'message': 'PO email sent'})
                return error('Failed to send PO email')
            
            else:
                return error(f"Unknown transactional type: {msg_type}")

        # === EMAIL: POST /messaging/email/send ===
        elif method == 'POST' and table_name == 'messaging/email/send':
            from services.messaging import EmailService
            recipient = data.get('to')
            subject = data.get('subject')
            body_content = data.get('body')
            if not recipient or not subject or not body_content:
                return error('to, subject, and body are required')
                
            result = EmailService().send_email(recipient, subject, body_content)
            if result['success']: return success(result)
            return error(result.get('error', 'Email failed'))

        # === WHATSAPP: POST /messaging/whatsapp/send ===
        elif method == 'POST' and table_name == 'messaging/whatsapp/send':
            print(f"🔍 DEBUG: Hitting 'send' route. Data: {data}") # ADDED DEBUG
            from services.messaging import WhatsAppService
            
            to_mobile = data.get('to')
            template = data.get('template')
            language = data.get('language', 'en_US')
            components = data.get('components', [])
            
            if not to_mobile or not template:
                return error('to and template are required')

            svc = WhatsAppService()
            success_status = svc.send_template(to_mobile, template, language, components)
            
            if success_status: 
                return success({'success': True})
            print("❌ DEBUG: send_template returned False") # ADDED DEBUG
            
            # RETURN DETAILED ERROR
            error_msg = getattr(svc, 'last_error', 'Unknown Error') or 'WhatsApp failed (Check logs)'
            return error(f"WhatsApp Failed: {error_msg}")

        # === WHATSAPP: POST /messaging/whatsapp/send_order_pdf ===
        elif method == 'POST' and table_name == 'messaging/whatsapp/send_order_pdf':
            print(f"🔍 DEBUG: Hitting 'send_order_pdf' route. Data Keys: {list(data.keys())}")
            from services.messaging import WhatsAppService
            import base64
            
            to_mobile = data.get('to')
            pdf_base64 = data.get('pdf_base64')
            text_params = data.get('text_params', [])
            order_id = text_params[0] if len(text_params) > 0 else 'Order'
            customer_name = text_params[1] if len(text_params) > 1 else 'Customer'
            
            if not to_mobile or not pdf_base64:
                return error('to and pdf_base64 are required')

            # 1. Upload PDF to S3
            s3_bucket = 'ruchiserv-invoices'
            s3_key = f"invoices/order_{order_id}_{int(time.time())}.pdf"
            s3_url = None
            
            try:
                print("1️⃣ Uploading PDF to S3...")
                s3_client = boto3.client('s3', region_name='ap-south-1')
                pdf_bytes = base64.b64decode(pdf_base64)
                s3_client.put_object(
                    Bucket=s3_bucket,
                    Key=s3_key,
                    Body=pdf_bytes,
                    ContentType='application/pdf'
                )
                s3_url = f"https://{s3_bucket}.s3.ap-south-1.amazonaws.com/{s3_key}"
                print(f"✅ PDF uploaded: {s3_url}")
            except Exception as e:
                print(f"❌ S3 Upload failed: {e}")
                return error(f"S3 Upload failed: {str(e)}")

            # 2. Send WhatsApp Template with View Invoice Button
            print("2️⃣ Sending WhatsApp with View Invoice button...")
            svc = WhatsAppService()
            
            # Template: ruchiserv_order_final with 3 body params + 1 button URL suffix
            # Body: Hi {{1}}, Your order {{2}} has been successfully placed with {{3}}...
            # Button: View Order -> https://ruchiserv.com/orders/{{1}}
            # We'll use S3 URL as the suffix
            
            components = [
                {
                    "type": "body",
                    "parameters": [
                        {"type": "text", "text": customer_name},  # {{1}} Name
                        {"type": "text", "text": str(order_id)},  # {{2}} Order ID
                        {"type": "text", "text": "RuchiServ"},    # {{3}} Company
                    ]
                },
                {
                    "type": "button",
                    "sub_type": "url",
                    "index": "0",
                    "parameters": [
                        {"type": "text", "text": s3_key}  # URL suffix
                    ]
                }
            ]
            
            success_status = svc.send_template(
                to_mobile,
                'ruchiserv_order_final',
                'en_US',
                components
            )
            
            if success_status:
                return success({'success': True, 'pdf_url': s3_url})
            
            error_msg = getattr(svc, 'last_error', 'Unknown Error')
            # Still return success if PDF uploaded but WhatsApp failed (Meta pending)
            return success({'success': True, 'pdf_url': s3_url, 'whatsapp_warning': error_msg})
            
        # === NEW: GET /messaging/whatsapp/webhook (Verification) ===
        elif method == 'GET' and table_name == 'messaging/whatsapp/webhook':
            # Meta sends hub.mode, hub.verify_token, hub.challenge in params
            # In this custom router, they might be in 'data' or 'filters' depending on how API Gateway maps them.
            # Assuming standard query params are mapped to 'filters' or similar.
            # Adjust mapping based on your API Gateway Request Template.
            
            # Standard Lambda Proxy integration maps query params typically.
            # If using custom mapping: let's assume `data` contains query params.
            mode = data.get('hub.mode')
            token = data.get('hub.verify_token')
            challenge = data.get('hub.challenge')
            
            # Use 'ruchiserv_webhook_secret' or similar as your Verify Token
            expected_token = 'ruchiserv_webhook_secure_123' 
            
            if mode == 'subscribe' and token == expected_token:
                print("✅ Webhook Verified!")
                # Must return challenge as plain text int/string, not JSON usually. 
                # But our helper returns JSON. Meta might fail validation if it expects raw int.
                # If API Gateway proxy integration: return body directly.
                return {
                    'statusCode': 200,
                    'body': challenge # Plain text return
                }
            return error('Verification failed')

        # === NEW: POST /messaging/whatsapp/webhook (Event Listener) ===
        elif method == 'POST' and table_name == 'messaging/whatsapp/webhook':
            # Process Incoming Button Clicks
            print(f"📩 Webhook Incoming: {json.dumps(data)}")
            
            # Safe parsing
            try:
                entry = data.get('entry', [])[0]
                changes = entry.get('changes', [])[0]
                value = changes.get('value', {})
                messages = value.get('messages', [])
                
                if messages:
                    msg = messages[0]
                    msg_id = msg.get('id')
                    from_mobile = msg.get('from')
                    
                    # 1. Handle Button Reply
                    if msg.get('type') == 'button':
                        btn_payload = msg.get('button', {}).get('payload') # "Confirm Order" or "Request Changes"
                        btn_text = msg.get('button', {}).get('text')
                        print(f"🔘 Button Clicked: {btn_text} (Payload: {btn_payload})")
                        
                        # Logic to update Order Status
                        # TODO: Extract OrderID from context or payload if possible (e.g. payload="CONFIRM_123")
                        # For now, just logging.
                        
                    # 2. Handle Text Reply
                    elif msg.get('type') == 'text':
                        text_body = msg.get('text', {}).get('body')
                        print(f"💬 Text Received: {text_body}")
                        
            except Exception as e:
                print(f"⚠️ Webhook Parse Error: {e}")
            
            # Always return 200 to acknowledge Receipt
            return success({'status': 'EVENT_RECEIVED'})

        # === SES: POST /messaging/ses/webhook (Bounce/Complaint Handling) ===
        elif method == 'POST' and table_name == 'messaging/ses/webhook':
            print(f"📧 SES Webhook Incoming: {json.dumps(data)}")
            
            # 1. Handle SNS Subscription Confirmation
            if data.get('Type') == 'SubscriptionConfirmation':
                subscribe_url = data.get('SubscribeURL')
                print(f"🔗 SNS Subscription Confirmation: {subscribe_url}")
                # Automatically visit the URL to confirm (optional but helpful)
                import urllib.request
                try:
                    with urllib.request.urlopen(subscribe_url) as resp:
                        print(f"✅ Subscription Confirmed: {resp.status}")
                except Exception as e:
                    print(f"⚠️ Failed to confirm subscription: {e}")
                return success({'status': 'SUBSCRIPTION_CONFIRMED'})

            # 2. Handle SES Notifications
            try:
                msg_body = data.get('Message')
                if not msg_body:
                    # Might be direct SES notification if not via SNS (unlikely for HTTPS but safe)
                    ses_notif = data
                else:
                    ses_notif = json.loads(msg_body)
                
                notif_type = ses_notif.get('notificationType')
                print(f"📢 SES Notification Type: {notif_type}")
                
                blacklist_table = dynamodb.Table('ruchiserv-email-blacklist')
                
                if notif_type == 'Bounce':
                    bounce = ses_notif.get('bounce', {})
                    bounced_recipients = bounce.get('bouncedRecipients', [])
                    for recipient in bounced_recipients:
                        email = recipient.get('emailAddress')
                        reason = bounce.get('bounceType', 'Unknown')
                        print(f"🚫 Blacklisting Bounced Email: {email} ({reason})")
                        blacklist_table.put_item(Item={
                            'email': email,
                            'type': 'BOUNCE',
                            'timestamp': get_timestamp(),
                            'reason': reason,
                            'messageId': ses_notif.get('mail', {}).get('messageId')
                        })
                
                elif notif_type == 'Complaint':
                    complaint = ses_notif.get('complaint', {})
                    complained_recipients = complaint.get('complainedRecipients', [])
                    for recipient in complained_recipients:
                        email = recipient.get('emailAddress')
                        reason = complaint.get('complaintFeedbackType', 'Unknown')
                        print(f"🚫 Blacklisting Complained Email: {email} ({reason})")
                        blacklist_table.put_item(Item={
                            'email': email,
                            'type': 'COMPLAINT',
                            'timestamp': get_timestamp(),
                            'reason': reason,
                            'messageId': ses_notif.get('mail', {}).get('messageId')
                        })
                
                return success({'status': 'PROCESSED'})
            except Exception as e:
                print(f"⚠️ SES Webhook Error: {e}")
                return error(f"Failed to process SES notification: {str(e)}")

        else:
            return error('Unknown method')
            
    except Exception as e:
        print(f"FATAL ERROR: {e}")
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
