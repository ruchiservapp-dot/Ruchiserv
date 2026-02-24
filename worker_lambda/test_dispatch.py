import json
import os
from lambda_function import process_notification, ses

# Mock environment variables
os.environ['SENDER_EMAIL'] = 'admin@ruchiserv.com'
os.environ['META_TOKEN'] = 'mocked_token'
os.environ['META_PHONE_ID'] = 'mocked_id'

# Mock SES to prevent actual sending and just print
def mock_send(Source, Destinations, RawMessage):
    print("--- MOCKED SES SEND ---")
    print(f"From: {Source}")
    print(f"To: {Destinations}")
    print(f"Body:\n{RawMessage['Data']}")
    print("-----------------------")

ses.send_raw_email = mock_send

payload = {
    "type": "DISPATCH_NOTIFICATION",
    "mobile": "+919633022800",
    "email": "test@ruchiserv.com",
    "dispatchId": 12345,
    "customerName": "Test Dispatch Customer",
    "driverName": "Test Driver",
    "driverMobile": "+919876543210",
    "vehicleNumber": "KL-01-AB-1234",
    "orderData": {
        "id": "ORD-54321"
    }
}

print("Testing DISPATCH_NOTIFICATION...")
process_notification(payload)
print("Done.")
