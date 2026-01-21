import json
from lambda_function import process_notification, messaging

def trigger_test():
    # Mock payload simulating an order from the app
    test_data = {
        "mobile": "+919633022800",
        "orderData": {
            "id": "TEST_123",
            "customerName": "Test Customer",
            "finalAmount": 1500,
            "date": "2026-01-18",
            "eventTime": "10:00 PM",
            "firmId": "RUCHJB4I",
            "dishes": [
                {"name": "Chicken Biryani", "pax": 10, "rate": 150, "cost": 1500}
            ]
        }
    }
    
    # ADVANCED TESTING: If you have your FCM token from the Flutter logs, 
    # paste it here to bypass DynamoDB lookup and test the push immediately!
    manual_token = "f8i0BZtAWQH9rUz5RWIL3V:APA91bEuB1qcD7vxGki7zzP9AlVQkgazeXaGZmsvtfzbkCuBsImhHbIHwZ08Xk9Huh6gDzTUvuESS92l4Q6Mm_tQ51_ID-rKqlYBwGFMu65iuy9Gp5Ez7P4"
    
    if manual_token:
        print(f"🎯 Manual Token detected. Sending direct test notification...")
        try:
            message = messaging.Message(
                notification=messaging.Notification(
                    title="Direct Test Notification",
                    body="This is a direct test using your manual token! 🔥",
                ),
                token=manual_token,
            )
            response = messaging.send(message)
            print(f"✅ Success! FCM sent directly: {response}")
            return
        except Exception as e:
            print(f"❌ Direct FCM failed: {e}")
            return

    print("🚀 Triggering full process_notification flow...")
    try:
        process_notification(test_data)
        print("✅ Process notification called. Check logs for FCM/WhatsApp/Email status.")
    except Exception as e:
        print(f"❌ Failed to trigger notification: {e}")

if __name__ == "__main__":
    trigger_test()
