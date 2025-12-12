import json
import os
import boto3
import requests
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import letter
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.application import MIMEApplication

# Initialize Clients
ses = boto3.client('ses')

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
    
    # 1. Generate PDF
    pdf_path = generate_pdf(order_data)
    
    # 2. Send WhatsApp
    wa_success = send_whatsapp(mobile, order_data, pdf_path)
    
    # 3. Send Email
    send_email(mobile, order_data, pdf_path)
    
    # 4. Fallback SMS
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

Please find the detailed invoice attached.

For any queries, please contact us.

Best regards,
RuchiServ Team
"""
    msg.attach(MIMEText(body, 'plain'))
    
    # Attach PDF
    with open(pdf_path, 'rb') as f:
        part = MIMEApplication(f.read(), Name=os.path.basename(pdf_path))
        part['Content-Disposition'] = f'attachment; filename="{os.path.basename(pdf_path)}"'
        msg.attach(part)
        
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
