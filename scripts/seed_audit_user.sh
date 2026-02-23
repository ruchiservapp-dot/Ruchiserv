#!/bin/bash

TABLE_NAME="ruchiserv_data"

# Function to seed a firm and user
seed_firm_user() {
    FIRM_ID=$1
    MOBILE="9999999999"
    PASSWORD="test1234"
    
    echo "Seeding Firm: $FIRM_ID into $TABLE_NAME (Single Table Design)"
    
    # 1. Seed Firm
    aws dynamodb put-item \
        --table-name "$TABLE_NAME" \
        --item "{
            \"pk\": {\"S\": \"$FIRM_ID\"},
            \"sk\": {\"S\": \"firms#$FIRM_ID\"},
            \"firmId\": {\"S\": \"$FIRM_ID\"},
            \"firmName\": {\"S\": \"RuchiServ Audit Firm\"},
            \"mobile\": {\"S\": \"$MOBILE\"},
            \"email\": {\"S\": \"admin@ruchiserv.com\"},
            \"subscriptionTier\": {\"S\": \"ENTERPRISE\"},
            \"subscriptionStatus\": {\"S\": \"ACTIVE\"},
            \"subscriptionExpiry\": {\"S\": \"2030-12-31\"},
            \"enabledFeatures\": {\"S\": \"GPS_TRACKING,WHATSAPP,EMAIL,ANALYTICS,MULTI_BRANCH,API_ACCESS\"},
            \"createdAt\": {\"S\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"},
            \"updatedAt\": {\"S\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}
        }"

    # 2. Seed User
    aws dynamodb put-item \
        --table-name "$TABLE_NAME" \
        --item "{
            \"pk\": {\"S\": \"$FIRM_ID\"},
            \"sk\": {\"S\": \"users#$MOBILE\"},
            \"ruchiserv-firms\": {\"S\": \"$FIRM_ID\"},
            \"mobile\": {\"S\": \"$MOBILE\"},
            \"firmId\": {\"S\": \"$FIRM_ID\"},
            \"userId\": {\"S\": \"U-$MOBILE\"},
            \"username\": {\"S\": \"Audit User\"},
            \"passwordHash\": {\"S\": \"$PASSWORD\"},
            \"role\": {\"S\": \"Admin\"},
            \"isActive\": {\"N\": \"1\"},
            \"createdAt\": {\"S\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"},
            \"updatedAt\": {\"S\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}
        }"

    # 3. Seed Authorized Mobile
    aws dynamodb put-item \
        --table-name "$TABLE_NAME" \
        --item "{
            \"pk\": {\"S\": \"$FIRM_ID\"},
            \"sk\": {\"S\": \"authorized_mobiles#$MOBILE\"},
            \"firmId\": {\"S\": \"$FIRM_ID\"},
            \"mobile\": {\"S\": \"$MOBILE\"},
            \"name\": {\"S\": \"Audit User\"},
            \"role\": {\"S\": \"Admin\"},
            \"isActive\": {\"N\": \"1\"},
            \"addedAt\": {\"S\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}
        }"
}

seed_firm_user "RCHSRV"
seed_firm_user "rchsrv"
seed_firm_user "RCHSRV_TEST"

echo "Seeding completed successfully for Single Table Architecture."
