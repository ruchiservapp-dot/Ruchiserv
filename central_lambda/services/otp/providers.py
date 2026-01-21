from abc import ABC, abstractmethod
import json
import urllib.request
import urllib.parse
import ssl

# Create a context that ignores SSL verification errors if needed (optional but safer for some legacy endpoints)
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

class OtpProvider(ABC):
    @abstractmethod
    def send_otp(self, mobile: str, otp: str, template_id: str = None) -> bool:
        """Sends OTP to the given mobile number. Returns True on success."""
        pass
    
    @abstractmethod
    def verify_otp(self, mobile: str, otp: str) -> bool:
        """Verifies OTP (if provider supports direct verification) or just returns True if using our own DB."""
        pass

class TwoFactorProvider(OtpProvider):
    def __init__(self, api_key: str):
        self.api_key = api_key
        self.base_url = "https://2factor.in/API/V1"

    def send_otp(self, mobile: str, otp: str, template_id: str = None) -> bool:
        if not self.api_key:
            print("⚠️ 2Factor API Key missing")
            return False
            
        # Format: /{api_key}/SMS/{phone_number}/{otp_value}/{template_name}
        url = f"{self.base_url}/{self.api_key}/SMS/{mobile}/{otp}"
        if template_id:
            url += f"/{template_id}"
            
        try:
            with urllib.request.urlopen(url, context=ctx) as response:
                resp_body = response.read().decode('utf-8')
                data = json.loads(resp_body)
                if data.get("Status", "").lower() == "success":
                    return True
                print(f"❌ 2Factor Error: {data}")
                return False
        except Exception as e:
            print(f"❌ 2Factor Exception: {e}")
            return False

    def verify_otp(self, mobile: str, otp: str) -> bool:
        return True

class Msg91Provider(OtpProvider):
    def __init__(self, auth_key: str, template_id: str):
        self.auth_key = auth_key
        self.template_id = template_id
        self.url = "https://api.msg91.com/api/v5/otp"

    def send_otp(self, mobile: str, otp: str, template_id: str = None) -> bool:
        if not self.auth_key:
            print("⚠️ MSG91 Auth Key missing")
            return False

        payload = {
            "template_id": template_id or self.template_id,
            "mobile": "91" + mobile, 
            "authkey": self.auth_key,
            "otp": otp
        }
        
        try:
            json_data = json.dumps(payload).encode('utf-8')
            req = urllib.request.Request(
                self.url, 
                data=json_data, 
                headers={'Content-Type': 'application/json'}
            )
            with urllib.request.urlopen(req, context=ctx) as response:
                resp_body = response.read().decode('utf-8')
                data = json.loads(resp_body)
                if data.get("type", "") == "success":
                    return True
                print(f"❌ MSG91 Error: {data}")
                return False
        except Exception as e:
            print(f"❌ MSG91 Exception: {e}")
            return False

    def verify_otp(self, mobile: str, otp: str) -> bool:
        return True

class Fast2SmsProvider(OtpProvider):
    def __init__(self, api_key: str):
        self.api_key = api_key
        self.url = "https://www.fast2sms.com/dev/bulkV2"

    def send_otp(self, mobile: str, otp: str, template_id: str = None) -> bool:
        if not self.api_key:
            print("⚠️ Fast2SMS API Key missing")
            return False
            
        payload = {
            "route": "otp",
            "variables_values": otp,
            "numbers": mobile,
        }
        
        try:
            json_data = json.dumps(payload).encode('utf-8')
            req = urllib.request.Request(
                self.url,
                data=json_data,
                headers={
                    "authorization": self.api_key,
                    "Content-Type": "application/json"
                }
            )
            with urllib.request.urlopen(req, context=ctx) as response:
                resp_body = response.read().decode('utf-8')
                data = json.loads(resp_body)
                if data.get("return") == True:
                    return True
                print(f"❌ Fast2SMS Error: {data}")
                return False
        except Exception as e:
            print(f"❌ Fast2SMS Exception: {e}")
            return False

    def verify_otp(self, mobile: str, otp: str) -> bool:
        return True
