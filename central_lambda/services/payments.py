import json
import urllib.request
import os
import time

class CashfreePaymentService:
    def __init__(self):
        self.app_id = os.environ.get('CASHFREE_APP_ID')
        self.secret_key = os.environ.get('CASHFREE_SECRET_KEY')
        self.sandbox = os.environ.get('CASHFREE_SANDBOX', 'true').lower() == 'true'
        
        if self.sandbox:
            self.base_url = "https://sandbox.cashfree.com/pg"
        else:
            self.base_url = "https://api.cashfree.com/pg"
            
        self.headers = {
            "Content-Type": "application/json",
            "x-client-id": self.app_id,
            "x-client-secret": self.secret_key,
            "x-api-version": "2023-08-01"
        }

    def _make_request(self, endpoint, method="POST", data=None):
        url = f"{self.base_url}{endpoint}"
        req = urllib.request.Request(url, method=method)
        for k, v in self.headers.items():
            req.add_header(k, v)
        
        try:
            body = json.dumps(data).encode('utf-8') if data else None
            with urllib.request.urlopen(req, data=body) as resp:
                return json.loads(resp.read().decode('utf-8'))
        except Exception as e:
            print(f"Cashfree API Error: {e}")
            return {"error": str(e)}

    def create_order(self, amount, customer_id, customer_phone, customer_email, order_id=None):
        """Creates a PG order for one-time payments."""
        if not order_id:
            order_id = f"order_{int(time.time() * 1000)}"
            
        data = {
            "order_id": order_id,
            "order_amount": amount,
            "order_currency": "INR",
            "customer_details": {
                "customer_id": customer_id,
                "customer_phone": customer_phone,
                "customer_email": customer_email
            }
        }
        return self._make_request("/orders", data=data)

    def create_subscription(self, plan_id, customer_id, customer_phone, customer_email, subscription_id=None):
        """Creates a subscription for recurring payments (SaaS)."""
        # Mapping to Subscriptions API (v2)
        sub_base = "https://sandbox.cashfree.com/api/v2" if self.sandbox else "https://api.cashfree.com/api/v2"
        
        if not subscription_id:
            subscription_id = f"sub_{int(time.time() * 1000)}"
            
        data = {
            "subscriptionId": subscription_id,
            "planId": plan_id,
            "participantId": customer_id,
            "participantEmail": customer_email,
            "participantPhone": customer_phone
        }
        
        url = f"{sub_base}/subscriptions"
        req = urllib.request.Request(url, method="POST")
        for k, v in self.headers.items():
            req.add_header(k, v)
            
        try:
            body = json.dumps(data).encode('utf-8')
            with urllib.request.urlopen(req, data=body) as resp:
                return json.loads(resp.read().decode('utf-8'))
        except Exception as e:
            print(f"Cashfree Sub Error: {e}")
            return {"error": str(e)}

    def update_mandate(self, subscription_id):
        """Creates a session to update or re-authorize a mandate."""
        # For simplicity, we trigger a new authorization session for the existing subscription
        sub_base = "https://sandbox.cashfree.com/api/v2" if self.sandbox else "https://api.cashfree.com/api/v2"
        url = f"{sub_base}/subscriptions/{subscription_id}/authorization"
        
        req = urllib.request.Request(url, method="POST")
        for k, v in self.headers.items():
            req.add_header(k, v)
            
        try:
            # Mandate update often doesn't need a body if it's just getting a link/session
            with urllib.request.urlopen(req) as resp:
                return json.loads(resp.read().decode('utf-8'))
        except Exception as e:
            print(f"Cashfree Mandate Update Error: {e}")
            return {"error": str(e)}
