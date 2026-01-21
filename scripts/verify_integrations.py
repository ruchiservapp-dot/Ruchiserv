import sys
import os
import json
import urllib.request

# Add central_lambda to path to import services
current_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(current_dir)
lambda_path = os.path.join(project_root, 'central_lambda')

# We need to add the parent of 'services' which IS lambda_path
# This allows 'from services.messaging import ...'
sys.path.insert(0, lambda_path)

import importlib.util

# ... (path setup remains similar to locate file)

# Construct path to messaging.py
messaging_py_path = os.path.join(lambda_path, 'services', 'messaging.py')

try:
    # Try to load .env ...
    try:
        from dotenv import load_dotenv
        env_path = os.path.join(project_root, '.env')
        load_dotenv(env_path)
        print(f"✅ Loaded environment from {env_path}")
    except ImportError:
        print("⚠️  python-dotenv not installed. Using existing environment variables.")

    # Load messaging module directly from file path
    spec = importlib.util.spec_from_file_location("services.messaging", messaging_py_path)
    messaging_module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(messaging_module)
    
    EmailService = messaging_module.EmailService
    WhatsAppService = messaging_module.WhatsAppService

except Exception as e:
    print(f"❌ Failed to import services: {e}")
    sys.exit(1)

def test_email(to_email):
    print(f"\n📧 Testing Email to {to_email}...")
    svc = EmailService()
    if not svc.from_email:
        print("❌ SKIPPING: SES_FROM_EMAIL not set.")
        return
    
    success = svc.send_email(
        recipient=to_email,
        subject="RuchiServ Integration Test",
        body="This is a test email from the RuchiServ verification script."
    )
    if success:
        print("✅ Email Sent Successfully!")
    else:
        print("❌ Email Failed.")

def test_whatsapp(to_mobile):
    print(f"\n💬 Testing WhatsApp to {to_mobile}...")
    svc = WhatsAppService()
    if not svc.phone_id or not svc.token: # Changed from 'self' to 'svc' to be syntactically correct in a function
        print("❌ WhatsApp Error: Credentials not found in Env Vars.")
        svc.last_error = "Credentials not found in Env Vars" # Changed from 'self' to 'svc'
        return False # Changed from 'return' to 'return False' to match the diff's return type

    # DEBUG: Fetch WABA ID and List Templates
    try:
        # 1. Get WABA ID
        waba_url = f"https://graph.facebook.com/{svc.api_version}/{svc.phone_id}?fields=business_account"
        req = urllib.request.Request(waba_url, method='GET')
        req.add_header('Authorization', f'Bearer {svc.token}')
        waba_id = None
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode())
            waba_id = data.get('business_account', {}).get('id')
            print(f"🕵️ WABA ID: {waba_id}")

        # 2. List Templates
        if waba_id:
            tpl_url = f"https://graph.facebook.com/{svc.api_version}/{waba_id}/message_templates?fields=name,status,language"
            req2 = urllib.request.Request(tpl_url, method='GET')
            req2.add_header('Authorization', f'Bearer {svc.token}')
            with urllib.request.urlopen(req2) as response:
                tpls = json.loads(response.read().decode())
                print("\n📜 FOUND TEMPLATES:")
                for t in tpls.get('data', []):
                    print(f"   - {t['name']} ({t['language']}): {t['status']}")
                print("-------------------\n")

    except Exception as e:
        print(f"⚠️ DEBUG Check Failed: {e}")

    # Use a simple text template if available, or just send a hello world if using raw API?
    # Template: ruchiserv_order_final
    # Body: Hi {{1}}, Your order {{2}} has been successfully placed with {{3}}... 
    # Button: View Order (Dynamic URL suffix)
    
    template = "ruchiserv_order_final"
    
    # 1. Body Parameters (3 params)
    body_params = [
        {"type": "text", "text": "Test User"},   # {{1}} Name
        {"type": "text", "text": "ORD-1234"},    # {{2}} Order ID
        {"type": "text", "text": "RuchiServ"},   # {{3}} Company
    ]
    
    # 2. Button Parameter (Dynamics URL Suffix)
    # The base is https://ruchiserv.com/orders/
    # We add the suffix: invoice_1234.pdf
    button_params = [
        {"type": "text", "text": "invoice_1234.pdf"} 
    ]

    # Construct Components
    components = [
        {
            "type": "body", 
            "parameters": body_params
        },
        {
            "type": "button",
            "sub_type": "url",
            "index": "0", # First button
            "parameters": button_params
        }
    ]

    success = svc.send_template(
        to_mobile=to_mobile,
        template_name=template,
        language_code="en_US",
        components=components
    )
    
    if success:
        print("✅ WhatsApp Sent Successfully!")
    else:
        print(f"❌ WhatsApp Failed: {svc.last_error}")

if __name__ == "__main__":
    print("--- RuchiServ Integration Verifier ---")
    
    # 1. Check Env Vars
    missing = []
    if not os.environ.get('SES_FROM_EMAIL'): missing.append('SES_FROM_EMAIL')
    if not os.environ.get('WA_PHONE_NUMBER_ID'): missing.append('WA_PHONE_NUMBER_ID')
    if not os.environ.get('WA_ACCESS_TOKEN'): missing.append('WA_ACCESS_TOKEN')
    
    if missing:
        print(f"⚠️  Missing Environment Variables: {', '.join(missing)}")
        print("   Please create a .env file in 'ruchiserv/' or export variables.")
    
    # 2. Get Targets
    email = input("Enter test email address (or press Enter to skip): ").strip()
    mobile = input("Enter test mobile number (with country code, e.g., 919876543210): ").strip()
    
    if email:
        test_email(email)
    
    if mobile:
        test_whatsapp(mobile)
        
    print("\n--- Done ---")
