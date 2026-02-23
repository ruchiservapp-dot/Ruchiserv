#!/bin/bash

# Navigate to central_lambda directory
cd "$(dirname "$0")"

# Remove old deployment zip
rm -f lambda_deployment.zip

# Zip the main function and services folder (includes s3_files.py)
zip -r lambda_deployment.zip lambda_function.py services/

echo "✅ Created lambda_deployment.zip"
echo "   Includes: lambda_function.py + services/ (s3_files.py, messaging, payments, etc.)"
echo "👉 Upload this file to your AWS Lambda Function 'Code' tab."
