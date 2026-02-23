#!/bin/bash
# ============================================================
# S3 Bucket Setup for RuchiServ Image Storage
# Run once to create the bucket and configure it.
# ============================================================

BUCKET_NAME="ruchiserv-files"
REGION="ap-south-1"

echo "🪣 Creating S3 bucket: $BUCKET_NAME in $REGION..."

# 1. Create Bucket
aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION"

# 2. Enable Server-Side Encryption (SSE-S3 - free)
aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# 3. Block Public Access (all images accessed via presigned URLs only)
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration '{
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
  }'

# 4. Enable Intelligent-Tiering for cost optimization
aws s3api put-bucket-intelligent-tiering-configuration \
  --bucket "$BUCKET_NAME" \
  --id "auto-tier" \
  --intelligent-tiering-configuration '{
    "Id": "auto-tier",
    "Status": "Enabled",
    "Tierings": [
      {"AccessTier": "ARCHIVE_ACCESS", "Days": 90},
      {"AccessTier": "DEEP_ARCHIVE_ACCESS", "Days": 180}
    ]
  }'

# 5. Lifecycle Rule: Move to Glacier after 365 days
aws s3api put-bucket-lifecycle-configuration \
  --bucket "$BUCKET_NAME" \
  --lifecycle-configuration '{
    "Rules": [{
      "ID": "archive-old-images",
      "Status": "Enabled",
      "Filter": {"Prefix": ""},
      "Transitions": [{
        "Days": 365,
        "StorageClass": "GLACIER"
      }]
    }]
  }'

# 6. CORS Configuration (for direct browser uploads if needed)
aws s3api put-bucket-cors \
  --bucket "$BUCKET_NAME" \
  --cors-configuration '{
    "CORSRules": [{
      "AllowedHeaders": ["*"],
      "AllowedMethods": ["PUT", "GET"],
      "AllowedOrigins": ["*"],
      "ExposeHeaders": ["ETag"],
      "MaxAgeSeconds": 3600
    }]
  }'

echo ""
echo "✅ S3 bucket '$BUCKET_NAME' created and configured!"
echo ""
echo "📋 Next Steps:"
echo "  1. Ensure your Lambda execution role has S3 permissions:"
echo "     - s3:PutObject"
echo "     - s3:GetObject"  
echo "     - s3:ListBucket"
echo ""
echo "  2. Add this IAM policy to your Lambda role:"
echo '     {'
echo '       "Effect": "Allow",'
echo '       "Action": ["s3:PutObject", "s3:GetObject"],'
echo '       "Resource": "arn:aws:s3:::ruchiserv-files/*"'
echo '     }'
echo ""
echo "  3. Deploy the updated Lambda with S3 routes."
