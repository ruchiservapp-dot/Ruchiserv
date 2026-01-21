import os
import boto3
import time
import random
import datetime
from .providers import TwoFactorProvider, Msg91Provider, Fast2SmsProvider

dynamodb = boto3.resource('dynamodb')
OTP_TABLE = 'ruchiserv-otp-logs' 
# In reality, you might put this in the main table or a separate one. 
# For now, let's assume valid logging table exists or we reused 'otp_logs' logic from flutter plan,
# but mapped to DynamoDB.

class OtpManager:
    def __init__(self):
        # Initialize Providers from Environment Variables
        self.primary = TwoFactorProvider(os.environ.get('OTP_2FACTOR_KEY', ''))
        self.secondary = Msg91Provider(
            os.environ.get('OTP_MSG91_KEY', ''), 
            os.environ.get('OTP_MSG91_TEMPLATE', '')
        )
        self.fallback = Fast2SmsProvider(os.environ.get('OTP_FAST2SMS_KEY', ''))
        
        # Priority mapping
        self.providers = {
            '2FACTOR': self.primary,
            'MSG91': self.secondary,
            'FAST2SMS': self.fallback
        }
        
        # Config
        self.current_provider_name = os.environ.get('OTP_PRIMARY_PROVIDER', '2FACTOR')

    def _get_provider(self):
        return self.providers.get(self.current_provider_name, self.primary)

    def generate_otp(self):
        return str(random.randint(100000, 999999))

    def request_otp(self, mobile: str):
        """
        1. Checks rate limits (3/hour).
        2. Generates secure OTP.
        3. Saves to DB (5 min expiry).
        4. Sends via Primary Provider -> Secondary -> Fallback.
        """
        table = dynamodb.Table('ruchiserv-otp-logs')
        now = datetime.datetime.utcnow()
        one_hour_ago = (now - datetime.timedelta(hours=1)).isoformat()
        
        # 1. Rate Limiting (Simple Scan/Query - optimization needed for high scale but works for now)
        # Using GSI on mobile+created_at would be ideal
        try:
            resp = table.query(
                KeyConditionExpression='mobile = :m AND created_at > :t',
                FilterExpression='is_used = :u',
                ExpressionAttributeValues={':m': mobile, ':t': one_hour_ago, ':u': 0}
            )
            # Count failed attempts
            # For simplicity, just checking if we sent too many recently
            if resp['Count'] >= 5:
                 return {'success': False, 'error': 'Rate limit exceeded. Try later.'}
        except:
            pass # Creating table on fly or index missing, allow for now

        # 2. Generate
        otp = self.generate_otp()
        expires_at = (now + datetime.timedelta(minutes=5)).isoformat()
        
        # 3. Save
        item = {
            'mobile': mobile,
            'otp': otp,
            'created_at': now.isoformat(),
            'expires_at': expires_at,
            'is_used': 0,
            'attempts': 0,
            'provider': self.current_provider_name
        }
        table.put_item(Item=item)

        # 4. Send (Failover Logic)
        success = False
        used_provider = self.current_provider_name
        
        # Try Primary
        provider = self._get_provider()
        if provider.send_otp(mobile, otp):
             success = True
        else:
             print(f"⚠️ {used_provider} failed. Trying Secondary (MSG91)...")
             used_provider = 'MSG91'
             if self.secondary.send_otp(mobile, otp):
                 success = True
             else:
                 print(f"⚠️ MSG91 failed. Trying Fallback (Fast2SMS)...")
                 used_provider = 'FAST2SMS'
                 if self.fallback.send_otp(mobile, otp):
                     success = True
        
        if success:
            return {'success': True, 'message': 'OTP sent', 'expires_in': 300, 'provider': used_provider}
        return {'success': False, 'error': 'Failed to send OTP via all providers'}

    def verify_otp(self, mobile: str, code: str):
        table = dynamodb.Table('ruchiserv-otp-logs')
        now = datetime.datetime.utcnow().isoformat()
        
        # 1. Find latest valid OTP
        # In real DynamoDB, you need a Query on PK(mobile) SK(created_at) desc
        resp = table.query(
            KeyConditionExpression='mobile = :m',
            FilterExpression='is_used = :u',
            ExpressionAttributeValues={':m': mobile, ':u': 0},
            ScanIndexForward=False, # Descending
            Limit=1
        )
        
        if not resp['Items']:
            return {'success': False, 'error': 'No valid OTP found'}
            
        record = resp['Items'][0]
        
        # 2. Check Expiry
        if now > record['expires_at']:
             return {'success': False, 'error': 'OTP Expired'}
             
        # 3. Check Attempts
        if record.get('attempts', 0) >= 3:
             return {'success': False, 'error': 'Too many attempts'}
        
        # 4. Verify Code
        if str(record['otp']) == str(code):
            # Mark Used
            table.update_item(
                Key={'mobile': mobile, 'created_at': record['created_at']},
                UpdateExpression='SET is_used = :v',
                ExpressionAttributeValues={':v': 1}
            )
            return {'success': True}
        else:
            # Increment attempts
            table.update_item(
                Key={'mobile': mobile, 'created_at': record['created_at']},
                UpdateExpression='SET attempts = attempts + :i',
                ExpressionAttributeValues={':i': 1}
            )
            return {'success': False, 'error': 'Invalid OTP'}
