# central_lambda/services/fcm.py
# @locked - Core Push-Pull architecture. Do not modify without full understanding.
# Sends Silent Push Notifications via Firebase Cloud Messaging (FCM) to trigger client-side sync.
import json
import os
import urllib.request
import urllib.error

# Google OAuth2 token endpoint
GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
FCM_SEND_URL = "https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"


class FcmService:
    """
    Firebase Cloud Messaging service for Push-Pull sync architecture.
    
    This service sends "Silent Push" notifications to all devices of a firm
    when data changes, triggering them to sync immediately.
    """
    
    def __init__(self):
        self.project_id = None
        self.credentials = None
        self._access_token = None
        self._token_expiry = 0
        self._load_credentials()
    
    def _load_credentials(self):
        """Load FCM credentials from environment variable."""
        creds_json = os.environ.get('FCM_SERVICE_ACCOUNT_JSON')
        if not creds_json:
            print("⚠️ FCM: FCM_SERVICE_ACCOUNT_JSON not set. Push notifications disabled.")
            return
        
        try:
            self.credentials = json.loads(creds_json)
            self.project_id = self.credentials.get('project_id')
            print(f"✅ FCM: Loaded credentials for project {self.project_id}")
        except json.JSONDecodeError as e:
            print(f"❌ FCM: Failed to parse credentials JSON: {e}")
    
    def _get_access_token(self) -> str:
        """Get a valid OAuth2 access token for FCM API calls."""
        import time
        
        # Return cached token if still valid
        if self._access_token and time.time() < self._token_expiry - 60:
            return self._access_token
        
        if not self.credentials:
            return None
        
        # Generate JWT for service account
        import jwt
        now = int(time.time())
        payload = {
            "iss": self.credentials['client_email'],
            "scope": "https://www.googleapis.com/auth/firebase.messaging",
            "aud": GOOGLE_TOKEN_URL,
            "iat": now,
            "exp": now + 3600,
        }
        
        try:
            signed_jwt = jwt.encode(
                payload,
                self.credentials['private_key'],
                algorithm='RS256'
            )
        except Exception as e:
            print(f"❌ FCM: JWT signing failed: {e}")
            return None
        
        # Exchange JWT for access token
        try:
            data = urllib.parse.urlencode({
                'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion': signed_jwt
            }).encode('utf-8')
            
            req = urllib.request.Request(GOOGLE_TOKEN_URL, data=data, method='POST')
            req.add_header('Content-Type', 'application/x-www-form-urlencoded')
            
            with urllib.request.urlopen(req) as response:
                result = json.loads(response.read().decode())
                self._access_token = result['access_token']
                self._token_expiry = now + result.get('expires_in', 3600)
                return self._access_token
                
        except Exception as e:
            print(f"❌ FCM: Token exchange failed: {e}")
            return None
    
    def send_silent_push(self, fcm_token: str, table: str, action: str = 'SYNC') -> bool:
        """
        Send a silent push notification to a single device.
        
        Args:
            fcm_token: The device's FCM registration token
            table: The table name that was modified (e.g., 'orders')
            action: The action type ('SYNC', 'DELETE', etc.)
        
        Returns:
            True if notification was sent successfully
        """
        if not self.project_id:
            return False
        
        access_token = self._get_access_token()
        if not access_token:
            return False
        
        # Construct FCM v1 API message (Silent Push)
        message = {
            "message": {
                "token": fcm_token,
                "data": {
                    "type": "SYNC",
                    "table": table,
                    "action": action,
                    "timestamp": str(int(__import__('time').time() * 1000))
                },
                # Android: Ensure delivery even when app is in background
                "android": {
                    "priority": "high"
                },
                # iOS: Silent notification (no alert)
                "apns": {
                    "headers": {
                        "apns-priority": "10"
                    },
                    "payload": {
                        "aps": {
                            "content-available": 1
                        }
                    }
                }
            }
        }
        
        url = FCM_SEND_URL.format(project_id=self.project_id)
        
        try:
            data = json.dumps(message).encode('utf-8')
            req = urllib.request.Request(url, data=data, method='POST')
            req.add_header('Authorization', f'Bearer {access_token}')
            req.add_header('Content-Type', 'application/json')
            
            with urllib.request.urlopen(req) as response:
                result = json.loads(response.read().decode())
                print(f"✅ FCM: Push sent for {table} -> {fcm_token[:20]}...")
                return True
                
        except urllib.error.HTTPError as e:
            error_body = e.read().decode()
            print(f"❌ FCM: HTTP {e.code} - {error_body}")
            # Handle invalid token (uninstalled app, etc.)
            if e.code == 404 or 'UNREGISTERED' in error_body:
                print(f"🗑️ FCM: Token is invalid/expired. Consider cleanup.")
            return False
        except Exception as e:
            print(f"❌ FCM: Send failed: {e}")
            return False
    
    def notify_firm_sync(self, firm_id: str, table: str, action: str = 'SYNC', db=None) -> int:
        """
        Notify all devices of a firm that data has changed.
        
        Args:
            firm_id: The firm whose devices should be notified
            table: The table that was modified
            action: The action type
            db: Optional boto3 dynamodb resource (for dependency injection)
        
        Returns:
            Number of devices successfully notified
        """
        if not self.project_id:
            print("⚠️ FCM: Not configured, skipping push")
            return 0
        
        # Get all users for this firm
        import boto3
        if db is None:
            db = boto3.resource('dynamodb')
        
        try:
            # Query users table for this firm
            users_table = db.Table('ruchiserv_data')
            response = users_table.query(
                KeyConditionExpression='pk = :pk AND begins_with(sk, :sk_prefix)',
                ExpressionAttributeValues={
                    ':pk': firm_id,
                    ':sk_prefix': 'users#'
                },
                ProjectionExpression='fcmToken'
            )
            
            tokens = set()  # Use set to deduplicate
            for user in response.get('Items', []):
                token = user.get('fcmToken')
                if token and len(token) > 10:  # Basic validation
                    tokens.add(token)
            
            if not tokens:
                print(f"ℹ️ FCM: No FCM tokens found for firm {firm_id}")
                return 0
            
            # Send to all devices
            success_count = 0
            for token in tokens:
                if self.send_silent_push(token, table, action):
                    success_count += 1
            
            print(f"📤 FCM: Notified {success_count}/{len(tokens)} devices for {firm_id}:{table}")
            return success_count
            
        except Exception as e:
            print(f"❌ FCM: Failed to query users for {firm_id}: {e}")
            return 0


# Singleton instance for Lambda reuse
_fcm_service = None

def get_fcm_service() -> FcmService:
    """Get the singleton FCM service instance."""
    global _fcm_service
    if _fcm_service is None:
        _fcm_service = FcmService()
    return _fcm_service
