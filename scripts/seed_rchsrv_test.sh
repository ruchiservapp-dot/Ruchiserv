#!/bin/bash

# Configuration
TABLE_NAME="ruchiserv_data"
FIRM_ID="RCHSRV_TEST"
MOBILE="9999999999"
PASSWORD="test1234"
REGION="ap-south-1"

echo "Seeding RCHSRV_TEST into $TABLE_NAME..."

# 1. Seed Firm
echo "Creating Firm..."
aws dynamodb put-item \
    --table-name "$TABLE_NAME" \
    --item "{
        \"pk\": {\"S\": \"$FIRM_ID\"},
        \"sk\": {\"S\": \"firms#$FIRM_ID\"},
        \"firmId\": {\"S\": \"$FIRM_ID\"},
        \"firmName\": {\"S\": \"RuchiServ Test Firm\"},
        \"mobile\": {\"S\": \"$MOBILE\"},
        \"email\": {\"S\": \"test@ruchiserv.com\"},
        \"status\": {\"S\": \"ACTIVE\"},
        \"subscriptionTier\": {\"S\": \"ENTERPRISE\"},
        \"subscriptionStatus\": {\"S\": \"ACTIVE\"},
        \"subscriptionExpiry\": {\"S\": \"2030-12-31\"},
        \"enabledFeatures\": {\"S\": \"GPS_TRACKING,WHATSAPP,EMAIL,ANALYTICS,MULTI_BRANCH,API_ACCESS\"},
        \"createdAt\": {\"S\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"},
        \"updatedAt\": {\"S\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}
    }"

# 2. Seed Users
echo "Creating Restricted Users for Verification..."

# User 1: 9999999999
aws dynamodb put-item \
    --table-name "$TABLE_NAME" \
    --region "$REGION" \
    --item "{
        \"pk\": {\"S\": \"$FIRM_ID\"},
        \"sk\": {\"S\": \"users#9999999999\"},
        \"firmId\": {\"S\": \"$FIRM_ID\"},
        \"ruchiserv-firms\": {\"S\": \"$FIRM_ID\"},
        \"userId\": {\"S\": \"U-9999999999\"},
        \"username\": {\"S\": \"Cashfree Verifier 1\"},
        \"mobile\": {\"S\": \"9999999999\"},
        \"passwordHash\": {\"S\": \"$PASSWORD\"},
        \"role\": {\"S\": \"Manager\"},
        \"moduleAccess\": {\"S\": \"SETTINGS\"},
        \"isActive\": {\"N\": \"1\"},
        \"createdAt\": {\"S\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"},
        \"updatedAt\": {\"S\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}
    }"

# User 2: 9876543210 (The current testing user)
aws dynamodb put-item \
    --table-name "$TABLE_NAME" \
    --region "$REGION" \
    --item "{
        \"pk\": {\"S\": \"$FIRM_ID\"},
        \"sk\": {\"S\": \"users#9876543210\"},
        \"firmId\": {\"S\": \"$FIRM_ID\"},
        \"ruchiserv-firms\": {\"S\": \"$FIRM_ID\"},
        \"userId\": {\"S\": \"U-9876543210\"},
        \"username\": {\"S\": \"Cashfree Verifier 2\"},
        \"mobile\": {\"S\": \"9876543210\"},
        \"passwordHash\": {\"S\": \"Cashfree@123\"},
        \"role\": {\"S\": \"Manager\"},
        \"moduleAccess\": {\"S\": \"SETTINGS\"},
        \"isActive\": {\"N\": \"1\"},
        \"createdAt\": {\"S\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"},
        \"updatedAt\": {\"S\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}
    }"

# 3. Seed Authorized Mobiles
echo "Authorizing Mobiles..."
aws dynamodb put-item \
    --table-name "$TABLE_NAME" \
    --region "$REGION" \
    --item "{
        \"pk\": {\"S\": \"$FIRM_ID\"},
        \"sk\": {\"S\": \"authorized_mobiles#9999999999\"},
        \"firmId\": {\"S\": \"$FIRM_ID\"},
        \"mobile\": {\"S\": \"9999999999\"},
        \"name\": {\"S\": \"Cashfree Verifier 1\"},
        \"role\": {\"S\": \"Manager\"},
        \"isActive\": {\"N\": \"1\"},
        \"addedBy\": {\"S\": \"SEED_SCRIPT\"},
        \"addedAt\": {\"S\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}
    }"

aws dynamodb put-item \
    --table-name "$TABLE_NAME" \
    --region "$REGION" \
    --item "{
        \"pk\": {\"S\": \"$FIRM_ID\"},
        \"sk\": {\"S\": \"authorized_mobiles#9876543210\"},
        \"firmId\": {\"S\": \"$FIRM_ID\"},
        \"mobile\": {\"S\": \"9876543210\"},
        \"name\": {\"S\": \"Cashfree Verifier 2\"},
        \"role\": {\"S\": \"Manager\"},
        \"isActive\": {\"N\": \"1\"},
        \"addedBy\": {\"S\": \"SEED_SCRIPT\"},
        \"addedAt\": {\"S\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}
    }"

# 5. Legacy Tables (For Fallback Login)
echo "Updating Legacy Tables (ruchiserv-users, ruchiserv-firms)..."

# Legacy Firm
aws dynamodb put-item \
    --table-name "ruchiserv-firms" \
    --region "$REGION" \
    --item "{
        \"firmid\": {\"S\": \"$FIRM_ID\"},
        \"firmname\": {\"S\": \"RuchiServ Verification Test\"}
    }"

# Legacy User 1: 9999999999
aws dynamodb put-item \
    --table-name "ruchiserv-users" \
    --region "$REGION" \
    --item "{
        \"ruchiserv-firms\": {\"S\": \"$FIRM_ID\"},
        \"mobile\": {\"S\": \"9999999999\"},
        \"passwordHash\": {\"S\": \"$PASSWORD\"},
        \"role\": {\"S\": \"Manager\"},
        \"moduleAccess\": {\"S\": \"SETTINGS\"},
        \"isActive\": {\"N\": \"1\"}
    }"

# Legacy User 2: 9876543210
aws dynamodb put-item \
    --table-name "ruchiserv-users" \
    --region "$REGION" \
    --item "{
        \"ruchiserv-firms\": {\"S\": \"$FIRM_ID\"},
        \"mobile\": {\"S\": \"9876543210\"},
        \"passwordHash\": {\"S\": \"Cashfree@123\"},
        \"role\": {\"S\": \"Manager\"},
        \"moduleAccess\": {\"S\": \"SETTINGS\"},
        \"isActive\": {\"N\": \"1\"}
    }"

echo "✅ Seed Complete for $FIRM_ID"
echo "You can now login with Firm: $FIRM_ID, Mobile: 9876543210, Password: Cashfree@123"
