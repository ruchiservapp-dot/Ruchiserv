import json
import os
import boto3
import requests
import firebase_admin
from firebase_admin import credentials, messaging

# Optional PDF generation (handles local testing compatibility)
try:
    from reportlab.pdfgen import canvas
    from reportlab.lib.pagesizes import letter
    REPORTLAB_AVAILABLE = True
except ImportError:
    print("⚠️ ReportLab/PIL not available (likely binary mismatch on local Mac). PDF generation will be skipped.")
    REPORTLAB_AVAILABLE = False

from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.application import MIMEApplication


# Initialize Firebase Admin
if not firebase_admin._apps:
    try:
        # Check if running in Lambda environment or locally
        cred_path = os.path.join(os.path.dirname(__file__), 'firebase_service_account.json')
        if os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
            print("✅ Firebase Admin initialized")
        else:
            print("⚠️ Firebase Service Account JSON not found")
    except Exception as e:
        print(f"❌ Firebase Admin init failed: {e}")

# Initialize Clients
ses = boto3.client('ses')
dynamodb = boto3.resource('dynamodb')

class WhatsAppService:
    """Helper class to send WhatsApp templates via Meta Graph API."""
    def __init__(self):
        self.phone_id = os.environ.get('META_PHONE_ID')
        self.token = os.environ.get('META_TOKEN')
        self.api_version = 'v21.0'
        
    def send_template(self, to_mobile: str, template_name: str, language_code: str = 'en_US', components: list = None) -> bool:
        if not self.phone_id or not self.token:
            print("❌ WhatsApp Error: META_TOKEN or META_PHONE_ID not set in environment.")
            return False

        url = f"https://graph.facebook.com/{self.api_version}/{self.phone_id}/messages"
        
        # Clean mobile number
        to_mobile = to_mobile.replace('+', '').replace(' ', '').replace('-', '')
        if len(to_mobile) == 10: to_mobile = '91' + to_mobile # Default to India
        
        payload = {
            "messaging_product": "whatsapp",
            "to": to_mobile,
            "type": "template",
            "template": {
                "name": template_name,
                "language": {"code": language_code},
                "components": components or []
            }
        }

        try:
            headers = {
                'Authorization': f'Bearer {self.token}',
                'Content-Type': 'application/json'
            }
            res = requests.post(url, headers=headers, json=payload)
            if res.status_code == 200:
                print(f"✅ WhatsApp template '{template_name}' sent to {to_mobile}")
                return True
            else:
                print(f"❌ WhatsApp Failed ({res.status_code}): {res.text}")
                return False
        except Exception as e:
            print(f"❌ WhatsApp Exception: {e}")
            return False


def lambda_handler(event, context):
    for record in event['Records']:
        try:
            payload = json.loads(record['body'])
            print(f"Processing Order: {payload.get('orderId')}")
            process_notification(payload)
        except Exception as e:
            print(f"Error processing record: {e}")
            # In production, you might want to raise e to trigger DLQ
            
    return {'statusCode': 200, 'body': 'Processed'}

def process_notification(data):
    mobile = data.get('mobile')
    order_data = data.get('orderData', {})
    firm_id = order_data.get('firmId') or data.get('firmId')
    
    # Support both 'type' (from Flutter) and 'notification_type'
    notif_type = data.get('notification_type') or data.get('type') or 'NEW_ORDER'

    print(f"🔔 Processing Notification Type: {notif_type}")

    # === HANDLE STATUS UPDATES (No PDF/Email needed) ===
    if notif_type == 'STATUS_UPDATE':
        action = order_data.get('action')
        oid = order_data.get('id')
        
        status_text = "Confirmed" if action == 'CONFIRM_ORDER' else "Requested Changes"
        title = f"Order #{oid} Update"
        body = f"Client has {status_text} this order."
        
        if firm_id:
            send_fcm_to_firm(firm_id, title, body, {'orderId': str(oid), 'type': 'STATUS_UPDATE'})
        return

    # === HANDLE DISPATCH NOTIFICATION (From Admin App) ===
    if notif_type == 'DISPATCH_NOTIFICATION':
        print("🚚 Processing Dispatch Notification")
        customer_name = data.get('customerName') or order_data.get('customerName', 'Customer')
        order_id = str(data.get('orderId') or order_data.get('id', 'Unknown'))
        # Use eventTime if available, fallback to time
        delivery_time = data.get('deliveryTime') or order_data.get('eventTime') or order_data.get('time') or 'N/A'
        
        wa_svc = WhatsAppService()
        # Template: dispatch_notification (Expected Params: {{1}} Name, {{2}} Time, {{3}} OrderId)
        success = wa_svc.send_template(
            mobile, 
            'dispatch_notification', 
            'en_US', 
            [
                {
                    "type": "body", 
                    "parameters": [
                        {"type": "text", "text": customer_name},
                        {"type": "text", "text": delivery_time},
                        {"type": "text", "text": order_id}
                    ]
                }
            ]
        )
        
        if not success:
            print(f"⚠️ Template dispatch_notification failed.")
            
        return

    # === HANDLE DISPATCH ACCEPTED (Send Tracking Link from Driver App) ===
    if notif_type == 'DISPATCH_ACCEPTED':
        print("🚚 Processing Dispatch Accepted")
        track_token = order_data.get('dispatchId') 
        # Token for URL button (just the suffix usually, or full URL depending on config)
        # Assuming Dynamic URL button: https://ruchiserv.com/track.html?token={{1}}
        # So we pass just the token.
        
        # Body Params: {{1}} Name, {{2}} OrderId, {{3}} DriverName, {{4}} DriverMobile
        customer_name = order_data.get('customerName', 'Customer')
        order_id = str(order_data.get('orderId', 'Unknown')) # Use Display ID if available
        driver_name = order_data.get('driverName', 'Our Driver')
        driver_mobile = order_data.get('driverMobile', '')
        
        wa_svc = WhatsAppService()
        
        # Template: delivery_update_2 (en_US)
        success = wa_svc.send_template(
            mobile, 
            'delivery_update_2', 
            'en_US', 
            [
                {
                    "type": "body", 
                    "parameters": [
                        {"type": "text", "text": customer_name},
                        {"type": "text", "text": order_id},
                        {"type": "text", "text": driver_name},
                        {"type": "text", "text": driver_mobile}
                    ]
                },
                {
                    "type": "button",
                    "sub_type": "url",
                    "index": "0",
                    "parameters": [
                        {"type": "text", "text": f"?token={track_token}"} 
                    ]
                }
            ]
        )
        
        if not success:
            print(f"⚠️ Template delivery_update_2 failed.")
            
        return


    # === HANDLE NEW ORDERS (Full Workflow) ===
    
    # 1. Generate PDF
    pdf_path = None
    if REPORTLAB_AVAILABLE:
        try:
            pdf_path = generate_pdf(order_data)
        except Exception as e:
            print(f"⚠️ PDF Generation failed: {e}")
    else:
        print("⏭️ Skipping PDF generation (ReportLab unavailable)")
    
    # 2. Send WhatsApp
    wa_success = send_whatsapp(mobile, order_data, pdf_path)
    
    # 3. Send Email
    send_email(mobile, order_data, pdf_path)

    
    # 4. FCM Notifications (Business Staff/Drivers)
    if firm_id:
        send_fcm_to_firm(firm_id, 
                        f"New Order #{order_data.get('id')}", 
                        f"Order for {order_data.get('customerName')} at {order_data.get('eventTime')}",
                        {'orderId': str(order_data.get('id')), 'type': 'NEW_ORDER'})
    
    # 5. Fallback SMS
    if not wa_success:
        send_sms(mobile, order_data)


def generate_pdf(order):
    from reportlab.lib import colors
    from reportlab.lib.units import inch
    
    path = f"/tmp/order_{order.get('id')}.pdf"
    c = canvas.Canvas(path, pagesize=letter)
    width, height = letter
    
    # ==================== HEADER SECTION ====================
    # Blue Header Bar (App Color)
    c.setFillColor(colors.HexColor('#1976D2'))  # App blue color
    c.rect(0, height - 80, width, 80, fill=True, stroke=False)
    
    # Company Name
    c.setFillColor(colors.white)
    c.setFont("Helvetica-Bold", 32)
    c.drawString(50, height - 50, "RuchiServ")
    
    # Tagline
    c.setFont("Helvetica", 12)
    c.drawString(50, height - 68, "Professional Catering & Kitchen Management")
    
    # ==================== ORDER INFO BOX ====================
    y = height - 110
    
    # Light blue info box background
    # Increased height to 160 and moved bottom down to y-170 to fit all content comfortably
    box_height = 160
    box_bottom = y - 170
    
    c.setFillColor(colors.HexColor('#E3F2FD'))  # Light blue
    c.rect(40, box_bottom, width - 80, box_height, fill=True, stroke=True)
    c.setStrokeColor(colors.HexColor('#1976D2'))
    c.setLineWidth(2)
    c.rect(40, box_bottom, width - 80, box_height, fill=False, stroke=True)
    
    # Order Confirmation Title
    y -= 25
    c.setFillColor(colors.HexColor('#1976D2'))  # Dark blue
    c.setFont("Helvetica-Bold", 16)
    c.drawString(50, y, f"Order Confirmation #{order.get('id')}")
    
    # Customer Details
    y -= 30
    c.setFillColor(colors.black)
    c.setFont("Helvetica-Bold", 11)
    c.drawString(50, y, "Customer:")
    c.setFont("Helvetica", 10)
    c.drawString(130, y, f"{order.get('customerName')[:40]}")  # Increased truncation limit
    
    c.setFont("Helvetica-Bold", 11)
    c.drawString(350, y, "Date:")
    c.setFont("Helvetica", 10)
    c.drawString(400, y, f"{order.get('date')[:15]}")
    
    y -= 25  # Increased spacing
    c.setFont("Helvetica-Bold", 11)
    c.drawString(50, y, "Mobile:")
    c.setFont("Helvetica", 10)
    c.drawString(130, y, f"{order.get('mobile', 'N/A')[:20]}")
    
    if order.get('email'):
        c.setFont("Helvetica-Bold", 11)
        c.drawString(350, y, "Email:")
        c.setFont("Helvetica", 9)
        email_text = order.get('email', '')[:30]
        c.drawString(400, y, email_text)
    
    y -= 25
    c.setFont("Helvetica-Bold", 11)
    c.drawString(50, y, "Location:")
    c.setFont("Helvetica", 10)
    location_text = order.get('location', 'N/A')[:40]
    c.drawString(130, y, location_text)
    
    y -= 25
    c.setFont("Helvetica-Bold", 11)
    c.drawString(50, y, "Event Time:")
    c.setFont("Helvetica", 10)
    c.drawString(130, y, f"{order.get('eventTime', 'N/A')[:20]}")
    
    c.setFont("Helvetica-Bold", 11)
    c.drawString(350, y, "Meal Type:")
    c.setFont("Helvetica", 10)
    c.drawString(420, y, f"{order.get('mealType', 'N/A')[:20]}")
    
    y -= 25
    c.setFont("Helvetica-Bold", 11)
    c.drawString(50, y, "Total Pax:")
    c.setFont("Helvetica", 10)
    c.drawString(130, y, f"{order.get('totalPax', 'N/A')}")
    
    # ==================== DISHES TABLE ====================
    y -= 60  # Adjusted starting position for table
    c.setFont("Helvetica-Bold", 14)
    c.setFillColor(colors.HexColor('#1976D2'))  # Blue instead of orange
    c.drawString(50, y, "Order Details")
    
    y -= 30
    
    # Table Header Background
    c.setFillColor(colors.HexColor('#4CAF50'))  # Green
    c.rect(40, y - 5, width - 80, 25, fill=True, stroke=False)
    
    # Table Headers
    c.setFillColor(colors.white)
    c.setFont("Helvetica-Bold", 11)
    c.drawString(50, y + 5, "Dish Name")
    c.drawString(300, y + 5, "Pax")
    c.drawString(380, y + 5, "Rate")
    c.drawString(480, y + 5, "Amount")
    
    y -= 25
    c.setStrokeColor(colors.HexColor('#4CAF50'))
    c.setLineWidth(1)
    c.line(40, y, width - 40, y)
    
    y -= 20
    
    # Table Rows with Alternating Colors
    c.setFont("Helvetica", 10)
    total = 0
    row_num = 0
    
    for dish in order.get('dishes', []):
        # Alternate row background
        if row_num % 2 == 0:
            c.setFillColor(colors.HexColor('#F5F5F5'))  # Light gray
            c.rect(40, y - 5, width - 80, 18, fill=True, stroke=False)
        
        dish_name = dish.get('name', 'Unknown Dish')
        pax = dish.get('pax', 0)
        rate = dish.get('rate', 0)
        cost = dish.get('cost', 0)
        
        c.setFillColor(colors.black)
        c.drawString(50, y, dish_name[:35])  # Truncate if too long
        c.drawString(300, y, str(pax))
        c.drawString(380, y, f"Rs. {rate}")
        c.drawString(480, y, f"Rs. {cost:.2f}")
        
        total += cost
        y -= 18
        row_num += 1
        
        if y < 150:  # New page if running out of space
            c.showPage()
            y = height - 50
            row_num = 0
    
    # ==================== TOTAL SECTION ====================
    y -= 10
    c.setStrokeColor(colors.HexColor('#4CAF50'))
    c.setLineWidth(2)
    c.line(40, y, width - 40, y)
    
    y -= 30
    
    # Total Background
    c.setFillColor(colors.HexColor('#E8F5E9'))  # Light green
    c.rect(350, y - 5, width - 390, 30, fill=True, stroke=False)
    
    c.setFillColor(colors.HexColor('#2E7D32'))  # Dark green
    c.setFont("Helvetica-Bold", 14)
    c.drawString(370, y + 5, "TOTAL:")
    c.setFont("Helvetica-Bold", 16)
    c.drawString(480, y + 5, f"Rs. {order.get('finalAmount', total)}")
    
    # ==================== FOOTER ====================
    c.setFillColor(colors.HexColor('#1976D2'))  # Blue footer bar (App color)
    c.rect(0, 0, width, 40, fill=True, stroke=False)
    
    c.setFillColor(colors.white)
    c.setFont("Helvetica-Bold", 11)
    c.drawString(50, 20, "Thank you for choosing RuchiServ!")
    c.setFont("Helvetica", 9)
    c.drawString(width - 180, 20, f"Firm ID: {order.get('firmId', 'N/A')}")
    
    c.save()
    return path
    
    c.save()
    return path

def send_whatsapp(mobile, order, pdf_path):
    token = os.environ.get('META_TOKEN')
    phone_id = os.environ.get('META_PHONE_ID')
    
    if not token or not phone_id:
        print("Skipping WhatsApp: Missing credentials")
        return False

    url = f"https://graph.facebook.com/v17.0/{phone_id}/messages"
    
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    # Template Message
    payload = {
        "messaging_product": "whatsapp",
        "to": mobile,
        "type": "template",
        "template": {
            "name": "order_confirmation",
            "language": {"code": "en_US"},
            "components": [
                {
                    "type": "body",
                    "parameters": [
                        {"type": "text", "text": str(order.get('customerName'))},
                        {"type": "text", "text": str(order.get('id'))},
                        {"type": "text", "text": str(order.get('finalAmount'))}
                    ]
                }
            ]
        }
    }
    
    try:
        res = requests.post(url, headers=headers, json=payload)
        if res.status_code == 200:
            print("WhatsApp Sent")
            return True
        else:
            print(f"WhatsApp Failed: {res.text}")
            return False
    except Exception as e:
        print(f"WhatsApp Error: {e}")
        return False

def send_email(mobile, order, pdf_path):
    sender = os.environ.get('SENDER_EMAIL')
    if not sender:
        print("Skipping Email: Missing SENDER_EMAIL")
        return

    # Extract email from order data
    recipient = order.get('email')
    
    # Skip if no email provided
    if not recipient or recipient.strip() == '':
        print(f"Skipping Email: No email address for order #{order.get('id')}")
        return
    
    msg = MIMEMultipart()
    msg['Subject'] = f"RuchiServ - Order Confirmation #{order.get('id')}"
    msg['From'] = sender
    msg['To'] = recipient
    
    # Enhanced email body with more details
    dishes_text = "\n".join([
        f"  - {d.get('name', 'Unknown')} ({d.get('pax', 0)} pax)"
        for d in order.get('dishes', [])
    ])
    
    body = f"""Dear {order.get('customerName')},

Thank you for choosing RuchiServ Catering!

Your order has been confirmed with the following details:

Order ID: #{order.get('id')}
Date: {order.get('date')}
Event Time: {order.get('eventTime', 'Not specified')}
Location: {order.get('location', 'Not specified')}
Meal Type: {order.get('mealType', 'Not specified')}
Total Pax: {order.get('totalPax', 'Not specified')}

Dishes:
{dishes_text}

Total Amount: ₹{order.get('finalAmount')}

For any queries, please contact us.

Best regards,
RuchiServ Team
"""
    msg.attach(MIMEText(body, 'plain'))
    
    # Attach PDF if available
    if pdf_path and os.path.exists(pdf_path):
        with open(pdf_path, 'rb') as f:
            part = MIMEApplication(f.read(), Name=os.path.basename(pdf_path))
            part['Content-Disposition'] = f'attachment; filename="{os.path.basename(pdf_path)}"'
            msg.attach(part)
    elif pdf_path:
        print(f"⚠️ PDF path provided but file not found: {pdf_path}")
    else:
        print("ℹ️ Sending email without PDF attachment.")

        
    try:
        ses.send_raw_email(
            Source=sender,
            Destinations=[recipient],
            RawMessage={'Data': msg.as_string()}
        )
        print(f"✅ Email sent to: {recipient}")
    except Exception as e:
        print(f"❌ Email Error: {e}")

def send_sms(mobile, order):
    api_key = os.environ.get('SMS_API_KEY')
    if not api_key:
        print("Skipping SMS: Missing SMS_API_KEY")
        return

    # 2Factor API (Example)
    url = f"https://2factor.in/API/V1/{api_key}/SMS/{mobile}/{order.get('id')}/AUTOGEN"
    
    try:
        requests.get(url)
        print("SMS Sent")
    except Exception as e:
        print(f"SMS Error: {e}")

def get_fcm_tokens_for_firm(firm_id):
    """Fetch all FCM tokens for a given firm from the users table"""
    try:
        from boto3.dynamodb.conditions import Key
        table_name = 'ruchiserv-users'
        
        # Check if table exists in current account/region (prevents ResourceNotFound crash)
        try:
            # We don't want to scan/query yet, just check if it exists
            table = dynamodb.Table(table_name)
            table.table_status # Accessing property triggers error if table doesn't exist
        except Exception:
             print(f"⚠️ DynamoDB Table '{table_name}' not found in this account/region. Skipping lookup.")
             return []

        response = table.query(
            KeyConditionExpression=Key('ruchiserv-firms').eq(firm_id)
        )
        
        items = response.get('Items', [])
        tokens = [item['fcmToken'] for item in items if item.get('fcmToken')]
        print(f"Found {len(tokens)} tokens for firm {firm_id}")
        return tokens
    except Exception as e:
        print(f"❌ Error fetching tokens for {firm_id}: {e}")
        return []


def send_fcm_to_firm(firm_id, title, body, data_payload=None):
    """Send push notification to all staff members of a firm"""
    tokens = get_fcm_tokens_for_firm(firm_id)
    if not tokens:
        print(f"Skipping FCM: No tokens found for firm {firm_id}")
        return

    for token in tokens:
        try:
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=data_payload or {},
                token=token,
            )
            response = messaging.send(message)
            print(f"✅ FCM sent to {token[:10]}...: {response}")
        except Exception as e:
            print(f"⚠️ FCM send failed for a token: {e}")

