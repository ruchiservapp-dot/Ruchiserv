#!/bin/bash

# RuchiServ Local Run Script with Cashfree Sandbox
# Injects all necessary credentials via --dart-define

CASHFREE_APP_ID="YOUR_APP_ID_HERE"
CASHFREE_SECRET_KEY="YOUR_SECRET_KEY_HERE"
CASHFREE_SANDBOX="true"
TWOFACTOR_API_KEY="YOUR_AUTH_KEY_HERE"

echo "🚀 Running RuchiServ with Cashfree Sandbox..."

flutter run \
    --dart-define=CASHFREE_APP_ID=$CASHFREE_APP_ID \
    --dart-define=CASHFREE_SECRET_KEY=$CASHFREE_SECRET_KEY \
    --dart-define=CASHFREE_SANDBOX=$CASHFREE_SANDBOX \
    --dart-define=TWOFACTOR_API_KEY=$TWOFACTOR_API_KEY \
    "$@"
