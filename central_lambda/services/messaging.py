import boto3
import os
from botocore.exceptions import ClientError
# @locked: This file contains stable ZeptoMail logic. Do not modify without explicit user request.

class EmailService:
    def __init__(self):
        # Initialize ZeptoMail credentials
        self.token = os.environ.get('ZEPTO_MAIL_TOKEN')
        self.from_email = os.environ.get('ZEPTO_FROM_EMAIL', 'no-reply@ruchiserv.com')
        self.from_name = os.environ.get('ZEPTO_FROM_NAME', 'RuchiServ Admin')
        
        # Keep DynamoDB for local blacklist check (optional extra safety)
        self.dynamodb = boto3.resource('dynamodb', region_name='ap-south-1')
        self.blacklist_table = self.dynamodb.Table('ruchiserv-email-blacklist')

    def is_blacklisted(self, email: str) -> bool:
        """Checks if an email is in the blacklist table."""
        try:
            for block_type in ['BOUNCE', 'COMPLAINT']:
                response = self.blacklist_table.get_item(Key={'email': email, 'type': block_type})
                if 'Item' in response:
                    print(f"🚫 Email {email} is blacklisted (Type: {block_type})")
                    return True
            return False
        except Exception as e:
            print(f"⚠️ Error checking blacklist for {email}: {e}")
            return False

    def send_email(self, recipient: str, subject: str, body: str, html_body: str = None) -> bool:
        """
        Sends an email via Zoho ZeptoMail API.
        """
        if not self.token or not self.from_email:
            print("Error: ZEPTO_MAIL_TOKEN or ZEPTO_FROM_EMAIL not set")
            return False

        if self.is_blacklisted(recipient):
            print(f"❌ Skipping email to {recipient} - Address is blacklisted.")
            return False

        url = "https://api.zeptomail.in/v1.1/email"
        
        # Construct Payload
        payload = {
            "from": { "address": self.from_email, "name": self.from_name },
            "to": [ { "email_address": { "address": recipient } } ],
            "subject": subject,
            "htmlbody": html_body if html_body else f"<div>{body}</div>",
        }

        headers = {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': self.token
        }

        try:
            data = json.dumps(payload).encode('utf-8')
            req = urllib.request.Request(url, data=data, headers=headers, method='POST')
            
            with urllib.request.urlopen(req) as response:
                result = json.loads(response.read().decode())
                print(f"📧 Email sent via ZeptoMail to {recipient}! Response: {result}")
                return True
                
        except urllib.error.HTTPError as e:
            error_body = e.read().decode()
            print(f"❌ ZeptoMail Failed ({e.code}): {error_body}")
            return False
        except Exception as e:
            print(f"❌ Failed to send email: {str(e)}")
            return False

# ... (Existing EmailService) ...
import json
import urllib.request
import urllib.error

class WhatsAppService:
    def __init__(self):
        self.phone_id = os.environ.get('WA_PHONE_NUMBER_ID')
        self.token = os.environ.get('WA_ACCESS_TOKEN')
        self.api_version = 'v19.0'
        self.last_error = None
        
    def upload_media(self, file_bytes: bytes, mime_type: str = 'application/pdf', filename: str = 'order.pdf') -> str:
        """
        Uploads media to Meta and returns the Media ID.
        """
        if not self.phone_id or not self.token:
            self.last_error = "Missing Credentials (WA_PHONE_NUMBER_ID or WA_ACCESS_TOKEN)"
            return None

        url = f"https://graph.facebook.com/{self.api_version}/{self.phone_id}/media"
        
        # Meta requires multipart/form-data. Using basic urllib is complex for multipart.
        # Ideally we use 'requests' lib, but if not available in Lambda layer, we might need a workaround.
        # Assuming 'requests' IS available (standard in many layers) or we rely on 'requests_toolbelt'.
        # For simplicity in this raw script without layers, we'll try a basic construction or assume requests.
        # Fallback: We will strictly use the standard library 'urllib' with manual multipart construction.
        
        boundary = 'wL36Yn8afVp8Ag7AmP8qZ0SA4n1v9T'
        
        # Build Body
        body = []
        # messaging_product="whatsapp"
        body.append(f'--{boundary}')
        body.append('Content-Disposition: form-data; name="messaging_product"')
        body.append('')
        body.append('whatsapp')
        
        # file
        body.append(f'--{boundary}')
        body.append(f'Content-Disposition: form-data; name="file"; filename="{filename}"')
        body.append(f'Content-Type: {mime_type}')
        body.append('')
        # (We append bytes later)
        
        # End
        footer = f'\r\n--{boundary}--\r\n'
        
        # Combine
        header_bytes = '\r\n'.join(body).encode('utf-8') + b'\r\n'
        final_body = header_bytes + file_bytes + footer.encode('utf-8')
        
        try:
            req = urllib.request.Request(url, data=final_body, method='POST')
            req.add_header('Authorization', f'Bearer {self.token}')
            req.add_header('Content-Type', f'multipart/form-data; boundary={boundary}')
            
            with urllib.request.urlopen(req) as response:
                resp_data = json.loads(response.read().decode())
                print(f"📡 Meta Media Upload Success: {resp_data}")
                return resp_data.get('id')
        except urllib.error.HTTPError as e:
            err_body = e.read().decode()
            print(f"❌ Meta Media Upload HTTP Error ({e.code}): {err_body}")
            self.last_error = f"Meta Media HTTP {e.code}: {err_body}"
            return None
        except Exception as e:
            print(f"❌ Meta Media Upload Exception: {e}")
            self.last_error = f"Exception: {str(e)}"
            return None

    def send_document_template(self, to_mobile: str, template_name: str, media_id: str, filename: str, language_code: str = 'en_US', body_text_params: list = None, buttons: list = None) -> bool:
        """
        Sends a Document Template (Header=PDF) with optional Buttons.
        """
        components = [
            {
                "type": "header",
                "parameters": [
                    {
                        "type": "document",
                        "document": {
                            "id": media_id,
                            "filename": filename
                        }
                    }
                ]
            }
        ]
        
        if body_text_params:
            components.append({
                "type": "body",
                "parameters": [{"type": "text", "text": p} for p in body_text_params]
            })

        if buttons:
            # Each quick_reply button needs a separate component entry with its own index
            for idx, btn_payload in enumerate(buttons):
                components.append({
                    "type": "button",
                    "sub_type": "quick_reply",
                    "index": str(idx),  # "0", "1", etc.
                    "parameters": [{"type": "payload", "payload": btn_payload}]
                })
            
        return self.send_template(to_mobile, template_name, language_code, components)

    def send_template(self, to_mobile: str, template_name: str, language_code: str = 'en_US', components: list = None) -> bool:
        """
        Sends a WhatsApp Template message via Meta Graph API.
        """
        if not self.phone_id or not self.token:
            print("❌ WhatsApp Error: Credentials not found in Env Vars.")
            self.last_error = "Credentials not found in Env Vars"
            return False

        url = f"https://graph.facebook.com/{self.api_version}/{self.phone_id}/messages"
        
        # Clean mobile number
        to_mobile = to_mobile.replace('+', '').replace(' ', '').replace('-', '')
        
        # Construct payload
        payload = {
            "messaging_product": "whatsapp",
            "to": to_mobile,
            "type": "template",
            "template": {
                "name": template_name,
                "language": {"code": "en" if template_name == "ruchiserv_order_interactive" else language_code}
            }
        }
        
        if components:
            payload["template"]["components"] = components

        try:
            data = json.dumps(payload).encode('utf-8')
            req = urllib.request.Request(url, data=data, method='POST')
            req.add_header('Authorization', f'Bearer {self.token}')
            req.add_header('Content-Type', 'application/json')
            
            with urllib.request.urlopen(req) as response:
                resp_data = json.loads(response.read().decode())
                print(f"📡 Meta Send Success: {resp_data}")
                print(f"💬 WhatsApp sent to {to_mobile}: ID {resp_data['messages'][0]['id']}")
                return True
                
        except urllib.error.HTTPError as e:
            err_body = e.read().decode()
            print(f"❌ WhatsApp Failed ({e.code}): {err_body}")
            self.last_error = f"WhatsApp HTTP {e.code}: {err_body}"
            return False
        except Exception as e:
            print(f"❌ WhatsApp Exception: {str(e)}")
            self.last_error = f"Exception: {str(e)}"
            return False

class EmailTemplates:
    @staticmethod
    def _get_header(firm_details: dict) -> str:
        """Generates a professional Letter Pad header with full firm details."""
        name = firm_details.get('firmName', firm_details.get('name', 'RuchiServ Partner'))
        address = firm_details.get('address', '')
        mobile = firm_details.get('mobile') or firm_details.get('primaryMobile', '')
        email = firm_details.get('primaryEmail') or firm_details.get('email', '')
        website = firm_details.get('website', '')
        gstin = firm_details.get('gstNumber') or firm_details.get('gstin', '')
        logo_url = firm_details.get('logoUrl', '')

        contact_parts = []
        if mobile: contact_parts.append(f"📞 {mobile}")
        if email: contact_parts.append(f"✉️ {email}")
        if website: contact_parts.append(f"🌐 {website}")
        
        contact_line = " &nbsp;|&nbsp; ".join(contact_parts)
        gst_line = f"<p style='margin: 5px 0 0 0; font-size: 14px; font-weight: bold;'>GSTIN: {gstin}</p>" if gstin else ""
        
        logo_html = ""
        if logo_url:
            logo_html = f'<img src="{logo_url}" alt="Logo" style="max-height: 80px; margin-bottom: 10px;">'

        return f"""
        <div style="border-bottom: 4px solid #e65100; padding-bottom: 20px; margin-bottom: 30px; text-align: center;">
            {logo_html}
            <h1 style="color: #e65100; margin: 0; font-size: 32px; font-weight: bold; font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;">{name}</h1>
            
            <p style="color: #555; margin: 10px 0 5px 0; font-size: 15px; line-height: 1.4;">
                {address}
            </p>
            
            <p style="color: #777; margin: 5px 0; font-size: 14px;">
                {contact_line}
            </p>
            
            {gst_line}
        </div>
        """

    @staticmethod
    def _get_styles() -> str:
        return """
        <style>
            @import url('https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;700&display=swap');
            
            body { 
                font-family: 'Outfit', 'Helvetica Neue', Helvetica, Arial, sans-serif; 
                background-color: #f0f2f5; 
                margin: 0; 
                padding: 0; 
                color: #1a1c1e; 
                -webkit-font-smoothing: antialiased;
            }
            .wrapper { width: 100%; table-layout: fixed; background-color: #f0f2f5; padding-bottom: 40px; }
            .container {
                max-width: 600px;
                margin: 20px auto;
                background: #ffffff;
                border-radius: 16px;
                box-shadow: 0 10px 30px rgba(0, 0, 0, 0.08);
                overflow: hidden;
            }
            .header-banner {
                background: linear-gradient(135deg, #FF5722 0%, #F44336 100%);
                padding: 40px 20px;
                text-align: center;
                color: white;
            }
            .header-banner h1 { margin: 0; font-size: 32px; font-weight: 700; letter-spacing: -1px; }
            .header-info { margin-top: 12px; font-size: 15px; opacity: 0.9; }
            
            .content { padding: 40px 30px; }
            
            .order-meta {
                margin-bottom: 40px;
                padding: 24px;
                background: #f8fafc;
                border-radius: 12px;
                display: block;
            }
            .meta-row { display: flex; justify-content: space-between; margin-bottom: 12px; }
            .meta-row:last-child { margin-bottom: 0; }
            .meta-label { font-size: 13px; color: #64748b; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; }
            .meta-value { font-size: 15px; font-weight: 700; color: #1e293b; }
            
            .section-title { 
                font-size: 18px; 
                font-weight: 700; 
                color: #1e293b; 
                margin-bottom: 20px;
                padding-bottom: 10px;
                border-bottom: 2px solid #f1f5f9;
            }
            
            table { width: 100%; border-collapse: collapse; margin-bottom: 30px; }
            th { 
                text-align: left; 
                padding: 12px 0; 
                color: #64748b; 
                font-size: 12px; 
                text-transform: uppercase; 
                letter-spacing: 1px;
                border-bottom: 2px solid #f1f5f9;
            }
            td { padding: 18px 0; border-bottom: 1px solid #f1f5f9; font-size: 15px; }
            
            .category-row td {
                background: #fff5f2;
                color: #FF5722;
                font-weight: 700;
                padding: 12px 15px;
                font-size: 13px;
                border-radius: 4px;
            }
            
            .item-name { font-weight: 600; color: #1e293b; }
            .item-meta { font-size: 13px; color: #64748b; margin-top: 4px; }
            
            .summary-card {
                background: #1e293b;
                color: white;
                border-radius: 12px;
                padding: 30px;
                margin-top: 40px;
            }
            .summary-row { display: flex; justify-content: space-between; margin-bottom: 15px; font-size: 15px; color: #94a3b8; }
            .total-row { 
                margin-top: 20px;
                padding-top: 20px;
                border-top: 1px solid #334155;
                display: flex;
                justify-content: space-between;
                align-items: center;
            }
            .total-label { font-size: 18px; font-weight: 700; color: white; }
            .total-value { font-size: 28px; font-weight: 700; color: #FF5722; }
            
            .footer { 
                padding: 40px 20px; 
                text-align: center; 
                font-size: 13px; 
                color: #64748b;
            }
            
            @media only screen and (max-width: 480px) {
                .content { padding: 30px 20px; }
                .header-banner h1 { font-size: 26px; }
                .total-value { font-size: 24px; }
            }
        </style>
        """

    @staticmethod
    def generate_order_html(order: dict, dishes: list, firm_details: dict) -> str:
        styles = EmailTemplates._get_styles()
        
        import datetime
        # 1. Standardized Date Formatting
        try:
            # Prioritize eventDate for the invoice itself
            raw_date = order.get('eventDate') or order.get('date') or order.get('createdAt') or datetime.datetime.now().isoformat()
            if 'T' in raw_date: dt = datetime.datetime.fromisoformat(raw_date.replace('Z', '+00:00'))
            else: dt = datetime.datetime.now()
            display_date = dt.strftime('%d %B %Y') 
            
            # Order ID logic
            yy, mm = dt.strftime('%y'), dt.strftime('%m')
            try:
                raw_id_int = int(order.get('id', 0))
                display_order_id = f"{yy}-{mm}-{raw_id_int:03d}"
            except: display_order_id = f"#{order.get('id')}"
        except:
            display_date = order.get('eventDate', order.get('date', 'N/A'))
            display_order_id = f"#{order.get('id', 'N/A')}"

        # 2. Standardize Time Format: 6:36 PM
        def format_time(t_str):
            if not t_str or t_str == 'N/A': return 'N/A'
            try:
                parts = t_str.split(':')
                if len(parts) >= 2:
                    h, m = int(parts[0]), int(parts[1])
                    suffix = "AM"
                    if h >= 12:
                        suffix = "PM"
                        if h > 12: h -= 12
                    elif h == 0: h = 12
                    return f"{h}:{m:02d} {suffix}"
            except: pass
            return t_str

        display_time = format_time(order.get('eventTime', order.get('time', 'N/A')))

        firm_name = firm_details.get('firmName', firm_details.get('name', 'RuchiServ Partner'))
        firm_logo = firm_details.get('logoUrl', '')
        
        # 2. Group Dishes
        categorized_dishes = {}
        for d in dishes:
            cat = d.get('category', 'General Items') or 'General Items'
            if cat not in categorized_dishes: categorized_dishes[cat] = []
            categorized_dishes[cat].append(d)
        
        menu_html = ""
        for category in sorted(categorized_dishes.keys()):
            menu_html += f'<tr class="category-row"><td colspan="3">{category.upper()}</td></tr>'
            for d in categorized_dishes[category]:
                name = d.get('dishName', 'Item')
                qty = d.get('pax', 0)
                rate = d.get('pricePerPlate', 0)
                amount = float(qty) * float(rate)
                menu_html += f"""
                <tr>
                    <td>
                        <div class="item-name">{name}</div>
                        <div class="item-meta">₹{rate:,.0f} x {qty} Pax</div>
                    </td>
                    <td align="right" style="font-weight: 700; color: #1e293b;">₹{amount:,.0f}</td>
                </tr>
                """

        # 3. Totals
        grand_total = float(order.get('grandTotal', 0))
        discount = float(order.get('discountAmount', 0))
        subtotal = grand_total + discount # Approximate

        subtotal = grand_total + discount # Approximate
        
        header_html = EmailTemplates._get_header(firm_details)

        return f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            {styles}
        </head>
        <body>
            <div class="wrapper">
                <div class="container">
                    {header_html}
                    
                    <div class="content">
                    
                    <div class="content">
                        <div class="order-meta">
                            <table style="width: 100%; border-collapse: collapse; margin-bottom: 0;">
                                <tr>
                                    <td style="border:none; padding: 0; width: 50%;">
                                        <span class="meta-label" style="display:block; margin-bottom: 4px;">Order ID</span>
                                        <span class="meta-value" style="font-size: 16px;">{display_order_id}</span>
                                    </td>
                                    <td align="right" style="border:none; padding: 0; width: 50%;">
                                        <span class="meta-label" style="display:block; margin-bottom: 4px;">Event Date</span>
                                        <span class="meta-value" style="font-size: 16px;">{display_date}</span>
                                    </td>
                                </tr>
                                <tr><td colspan="2" style="border:none; height: 24px;"></td></tr>
                                <tr>
                                    <td style="border:none; padding: 0; width: 50%;">
                                        <span class="meta-label" style="display:block; margin-bottom: 4px;">Event Time</span>
                                        <span class="meta-value" style="font-size: 16px;">{display_time}</span>
                                    </td>
                                    <td align="right" style="border:none; padding: 0; width: 50%;">
                                        <span class="meta-label" style="display:block; margin-bottom: 4px;">Client Name</span>
                                        <span class="meta-value" style="font-size: 16px;">{order.get('customerName')}</span>
                                    </td>
                                </tr>
                            </table>
                        </div>

                        <div class="section-title">SERVICE DETAILS</div>
                        <div class="order-meta" style="background: #fff; border: 1px solid #f1f5f9; padding: 25px;">
                            <table style="width: 100%; border-collapse: collapse; margin-bottom: 0;">
                                <tr>
                                    <td style="border:none; padding: 0 0 15px 0;">
                                        <span class="meta-label" style="display:block; margin-bottom: 4px;">Service Style</span>
                                        <span class="meta-value" style="color:#FF5722; font-size: 18px;">{order.get('serviceType', 'N/A').upper()}</span>
                                    </td>
                                    <td align="right" style="border:none; padding: 0 0 15px 0;">
                                        <span class="meta-label" style="display:block; margin-bottom: 4px;">Guests (Pax)</span>
                                        <span class="meta-value" style="font-size: 18px;">{order.get('totalPax', 0)}</span>
                                    </td>
                                </tr>
                                <tr>
                                    <td colspan="2" style="border:none; padding: 15px 0 0 0; border-top: 1px solid #f1f5f9;">
                                        <span class="meta-label" style="display:block; margin-bottom: 8px;">Logistics & Setup</span>
                                        <span class="meta-value" style="color: #64748b; font-weight: normal;">
                                            <b style="color: #1a1c1e;">{order.get('counterCount', 1)}</b> Counters &nbsp;&bull;&nbsp; 
                                            <b style="color: #1a1c1e;">{order.get('staffCount', 0)}</b> Service Staff
                                        </span>
                                    </td>
                                </tr>
                            </table>
                        </div>

                        <div class="section-title">ORDER SUMMARY</div>
                        <table>
                            {menu_html}
                        </table>
                        
                        <div class="summary-card">
                            <div class="summary-row">
                                <span>Item Subtotal</span>
                                <span>₹{subtotal:,.0f}</span>
                            </div>
                            {f'<div class="summary-row" style="color:#fb7185;"><span>Discount ({order.get("discountPercent", 0)}%)</span><span>-₹{discount:,.0f}</span></div>' if discount > 0 else ''}
                            <div class="total-row">
                                <span class="total-label">GRAND TOTAL</span>
                                <span class="total-value">₹{grand_total:,.0f}</span>
                            </div>
                        </div>

                        <div style="margin-top: 40px; font-size: 14px; color: #64748b; line-height: 1.6;">
                            <strong>Delivery Notes:</strong><br>
                            {order.get('notes', 'No special instructions provided.')}
                        </div>
                    </div>
                    
                    <div class="footer">
                        <p>Thank you for choosing {firm_name}!<br>We look forward to serving you.</p>
                        <p style="margin-top: 20px; font-size: 11px; opacity: 0.5;">POWERED BY RUCHISERV</p>
                    </div>
                </div>
            </div>
        </body>
        </html>
        """


    @staticmethod
    def generate_po_html(po: dict, items: list, firm_details: dict) -> str:
        # Reusing the new style for PO as well for consistency
        styles = EmailTemplates._get_styles()
        
        firm_name = firm_details.get('firmName', firm_details.get('name', 'RuchiServ Partner'))
        
        items_html = ""
        for i, item in enumerate(items, 1):
            name = item.get('itemName', 'Item')
            qty = item.get('quantity', 0)
            unit = item.get('unit', '')
            items_html += f"<tr><td style='width: 10%'>{i}</td><td style='width: 70%'>{name}</td><td style='text-align: right;'>{qty} {unit}</td></tr>"

        return f"""
        <!DOCTYPE html>
        <html>
        <head>{styles}</head>
        <body>
            <div class="container">
                <div class="header-banner" style="background: linear-gradient(135deg, #2d3436 0%, #636e72 100%);">
                    <h1>{firm_name}</h1>
                    <div class="header-info">PURCHASE ORDER</div>
                </div>
                
                <div class="content">
                    <div class="order-meta">
                        <div class="meta-block">
                            <h3>PO Number</h3>
                            <p>{po.get('poNumber')}</p>
                        </div>
                        <div class="meta-block" style="text-align: right;">
                            <h3>Vendor</h3>
                            <p>{po.get('vendorName')}</p>
                        </div>
                    </div>

                    <table>
                        <thead>
                            <tr>
                                <th>#</th>
                                <th>Item Description</th>
                                <th style="text-align: right;">Quantity</th>
                            </tr>
                        </thead>
                        <tbody>
                            {items_html}
                        </tbody>
                    </table>
                    
                    <div style="margin-top: 30px; padding: 20px; background: #f8fafc; border-radius: 8px; text-align: center;">
                        <p style="margin: 0; font-weight: 600;">Please verify stock and confirm delivery date.</p>
                    </div>
                </div>
                
                <div class="footer">
                    Authorized Signatory: {firm_name}
                </div>
            </div>
        </body>
        </html>
        """
