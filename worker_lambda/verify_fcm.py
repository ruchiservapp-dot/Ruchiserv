import os
import firebase_admin
from firebase_admin import credentials, messaging

def test_fcm():
    try:
        cred_path = 'firebase_service_account.json'
        if not firebase_admin._apps:
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
            print("✅ Firebase initialized")

        # Test with a dummy token (this will fail with INVALID_ARGUMENT but proves the SDK works)
        dummy_token = "dummy_token_for_validation"
        message = messaging.Message(
            notification=messaging.Notification(
                title="Test Title",
                body="Test Body",
            ),
            token=dummy_token,
        )
        
        try:
            response = messaging.send(message, dry_run=True)
            print(f"✅ Success (Dry Run): {response}")
        except Exception as e:
            if "registration-token-not-registered" in str(e).lower() or "invalid-argument" in str(e).lower():
                print("✅ SDK call successful: Caught expected token error")
            else:
                print(f"❌ SDK call failed unexpectedly: {e}")

    except Exception as e:
        print(f"❌ Test failed during init: {e}")

if __name__ == "__main__":
    test_fcm()
