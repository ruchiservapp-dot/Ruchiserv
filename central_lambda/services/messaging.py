import boto3
import os
from botocore.exceptions import ClientError
# @locked: This file contains stable ZeptoMail logic. Do not modify without explicit user request.

class EmailService:
    def __init__(self):
        # Initialize ZeptoMail credentials
        self.token = os.environ.get('ZEPTO_MAIL_TOKEN')
        self.from_email = os.environ.get('ZEPTO_FROM_EMAIL')
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
                return resp_data.get('id')
        except Exception as e:
            print(f"❌ Media Upload Failed: {e}")
            self.last_error = f"Media Upload Failed: {e}"
            return None

    def send_document_template(self, to_mobile: str, template_name: str, media_id: str, filename: str, language_code: str = 'en_US', body_text_params: list = None) -> bool:
        """
        Sends a Document Template (Header=PDF).
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
                "language": {"code": language_code}
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
            @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap');
            
            body { 
                font-family: 'Inter', 'Helvetica Neue', Helvetica, Arial, sans-serif; 
                background-color: #f4f6f8; 
                margin: 0; 
                padding: 40px 0; 
                color: #2d3436; 
                -webkit-font-smoothing: antialiased;
            }
            .container {
                max-width: 600px;
                margin: 0 auto;
                background: #ffffff;
                border-radius: 12px;
                box-shadow: 0 4px 20px rgba(0, 0, 0, 0.05);
                overflow: hidden;
            }
            .header-banner {
                background: linear-gradient(135deg, #e65100 0%, #ff9800 100%);
                padding: 30px;
                text-align: center;
                color: white;
            }
            .header-banner h1 { margin: 0; font-size: 28px; font-weight: 700; letter-spacing: -0.5px; }
            .header-info { margin-top: 10px; font-size: 14px; opacity: 0.9; }
            
            .content { padding: 40px; }
            
            .order-meta {
                display: flex;
                justify-content: space-between;
                align-items: center;
                margin-bottom: 30px;
                padding-bottom: 20px;
                border-bottom: 1px solid #edf2f7;
            }
            .meta-block h3 { margin: 0 0 5px 0; font-size: 12px; text-transform: uppercase; color: #a0aec0; letter-spacing: 0.5px; }
            .meta-block p { margin: 0; font-size: 16px; font-weight: 600; color: #2d3436; }
            
            .badge {
                background: #fff3e0;
                color: #e65100;
                padding: 6px 12px;
                border-radius: 20px;
                font-size: 12px;
                font-weight: 600;
                display: inline-block;
            }
            
            table { width: 100%; border-collapse: separate; border-spacing: 0; margin-bottom: 30px; }
            th { 
                text-align: left; 
                padding: 12px 0; 
                color: #718096; 
                font-size: 11px; 
                text-transform: uppercase; 
                letter-spacing: 0.5px; 
                border-bottom: 1px solid #edf2f7;
            }
            td { padding: 16px 0; border-bottom: 1px dashed #edf2f7; font-size: 14px; }
            tr:last-child td { border-bottom: none; }
            
            .category-header { 
                color: #e65100; 
                font-weight: 700; 
                font-size: 13px; 
                padding-top: 25px; 
                padding-bottom: 5px;
                border-bottom: none !important;
            }
            
            .amount-col { text-align: right; font-weight: 600; }
            
            .billing-summary {
                background: #f8fafc;
                border-radius: 8px;
                padding: 20px;
            }
            .summary-row { display: flex; justify-content: space-between; margin-bottom: 10px; font-size: 14px; color: #718096; }
            .summary-row.total { 
                border-top: 1px solid #edf2f7; 
                padding-top: 15px; 
                margin-top: 10px; 
                font-size: 18px; 
                font-weight: 700; 
                color: #2d3436; 
            }
            .summary-row.discount { color: #38a169; }
            
            .footer { 
                background: #f8fafc; 
                padding: 20px; 
                text-align: center; 
                font-size: 12px; 
                color: #a0aec0; 
                border-top: 1px solid #edf2f7;
            }
            
            .gst-info { margin-top: 5px; font-size: 12px; opacity: 0.8; }
        </style>
        """

    @staticmethod
    def generate_order_html(order: dict, dishes: list, firm_details: dict) -> str:
        styles = EmailTemplates._get_styles()
        
        # 1. Custom Order ID Display (YY-MM-ID)
        # Try to use 'createdAt' or 'date' to get Year/Month
        import datetime
        try:
            date_str = order.get('createdAt') or order.get('date') or datetime.datetime.now().isoformat()
            # Handle variable date formats roughly
            if 'T' in date_str: dt = datetime.datetime.fromisoformat(date_str.replace('Z', '+00:00'))
            else: dt = datetime.datetime.now() # Fallback if standard parsing fails
            
            yy = dt.strftime('%y')
            mm = dt.strftime('%m')
            # Ensure ID is treated as int for formatting
            try:
                raw_id_int = int(order.get('id', 0))
                display_order_id = f"{yy}-{mm}-{raw_id_int:03d}" # e.g. 24-01-005
            except:
                display_order_id = f"#{order.get('id')}"
        except:
            display_order_id = f"#{order.get('id', 'N/A')}"

        # 2. Firm Branding
        firm_name = firm_details.get('firmName', firm_details.get('name', 'RuchiServ Partner'))
        firm_logo = firm_details.get('logoUrl', '')
        
        # 3. Group Dishes
        categorized_dishes = {}
        for d in dishes:
            cat = d.get('category', 'General') or 'General'
            if cat not in categorized_dishes: categorized_dishes[cat] = []
            categorized_dishes[cat].append(d)
        
        sorted_categories = sorted(categorized_dishes.keys())

        # 4. Build Menu Content
        menu_html = ""
        for category in sorted_categories:
            menu_html += f"""
            <tr style="background-color: #fff8e1;">
                <td colspan="4" class='category-header' style="padding-left: 15px; border-left: 4px solid #ff9800;">
                    {category}
                </td>
            </tr>
            """
            
            for d in categorized_dishes[category]:
                name = d.get('dishName', 'Item')
                qty = d.get('pax', 0)
                rate = d.get('pricePerPlate', 0)
                total = qty * rate
                menu_html += f"""
                <tr>
                    <td style="width: 50%; padding-left: 15px;">{name}</td>
                    <td style="width: 15%">{qty}</td>
                    <td style="width: 15%">₹{rate}</td>
                    <td class="amount-col">₹{total:,.0f}</td>
                </tr>
                """

        # 5. Billing Calculations
        def to_float(val):
            try: return float(val) if val else 0.0
            except: return 0.0

        grand_total = to_float(order.get('grandTotal'))
        service_cost = to_float(order.get('serviceCost'))
        counter_cost = to_float(order.get('counterSetupCost'))
        discount = to_float(order.get('discountAmount'))
        
        # Calculate Base Subtotal (Reverse engineer or approximate)
        # Showing line items + extras is safer
        
        billing_html = ""
        if service_cost > 0:
            billing_html += f'<div class="summary-row"><span>Service Charges</span><span>+ ₹{service_cost:,.2f}</span></div>'
        if counter_cost > 0:
            billing_html += f'<div class="summary-row"><span>Counter Setup</span><span>+ ₹{counter_cost:,.2f}</span></div>'
        if discount > 0:
            billing_html += f'<div class="summary-row discount"><span>Discount</span><span>- ₹{discount:,.2f}</span></div>'

        # 6. Contact Info Line
        contact_parts = []
        if firm_details.get('mobile'): contact_parts.append(firm_details['mobile'])
        if firm_details.get('email'): contact_parts.append(firm_details['email'])
        contact_info = " • ".join(contact_parts)

        return f"""
        <!DOCTYPE html>
        <html>
        <head>{styles}</head>
        <body>
            <div class="container">
                <div class="header-banner">
                    {'<img src="' + firm_logo + '" style="height: 60px; background: white; padding: 5px; border-radius: 8px; margin-bottom: 10px;">' if firm_logo else ''}
                    <h1>{firm_name}</h1>
                    <div class="header-info">{contact_info}</div>
                    {f'<div class="gst-info">GSTIN: {firm_details["gstNumber"]}</div>' if firm_details.get('gstNumber') else ''}
                </div>
                
                <div class="content">
                    <div class="order-meta">
                        <div class="meta-block">
                            <h3>Order ID</h3>
                            <p>{display_order_id}</p>
                        </div>
                        <div class="meta-block">
                            <h3>Event Date</h3>
                            <p>{order.get('eventDate', order.get('date', 'N/A'))}</p>
                        </div>
                        <div class="meta-block" style="text-align: right;">
                            <h3>Customer</h3>
                            <p>{order.get('customerName')}</p>
                            <span class="badge" style="margin-top: 5px;">{order.get('mealType')}</span>
                        </div>
                    </div>

                    <table>
                        <thead>
                            <tr>
                                <th>Item</th>
                                <th>Qty</th>
                                <th>Rate</th>
                                <th style="text-align: right;">Amount</th>
                            </tr>
                        </thead>
                        <tbody>
                            {menu_html}
                        </tbody>
                    </table>
                    
                    <div class="billing-summary">
                        {billing_html}
                        <div class="summary-row total">
                            <span>Grand Total</span>
                            <span>₹{grand_total:,.2f}</span>
                        </div>
                    </div>

                    <div style="margin-top: 30px; font-size: 13px; color: #718096; background: #fff8e1; padding: 15px; border-radius: 6px;">
                        <strong>📝 Notes:</strong> {order.get('notes', 'No specific notes.')}
                    </div>
                </div>
                
                <div class="footer">
                    <p>Thank you for choosing {firm_name}!</p>
                    <p style="margin-top: 5px; font-size: 10px;">Powered by RuchiServ</p>
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
