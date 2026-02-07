#!/bin/bash

# RuchiServ Web Deployment Script
# 1. Updates version.json with current timestamp
# 2. Builds Flutter Web in Production mode
# 3. Uploads to S3 bucket

echo "🚀 STATUS: Starting Web Deployment..."

# Get current timestamp
TIMESTAMP=$(date +%s)
BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "🔢 STEP 1: Updating version.json to $TIMESTAMP..."
cat > web/version.json <<EOF
{
  "version": "$TIMESTAMP",
  "buildTime": "$BUILD_TIME"
}
EOF

echo "🏗️ STEP 2: Building Flutter Web (Production)..."
flutter build web --dart-define=PRODUCTION=true --release
if [ $? -ne 0 ]; then
    echo "❌ FAILURE: Flutter build failed."
    exit 1
fi

echo "☁️ STEP 3: Syncing to S3 (ruchiserv-events-web)..."
aws s3 sync build/web/ s3://ruchiserv-events-web/ --region ap-south-1 --delete
if [ $? -ne 0 ]; then
    echo "❌ FAILURE: S3 sync failed."
    exit 1
fi

echo "🎉 DONE: Web App is live with version $TIMESTAMP!"
