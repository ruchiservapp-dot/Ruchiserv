#!/bin/bash

TABLE_FIRMS="ruchiserv-firms"
TABLE_USERS="ruchiserv-users"
TABLE_AUTH="ruchiserv-authorized-mobiles"

# Function to seed a firm and user
seed_firm_user() {
    FIRM_ID=$1
    echo "Seeding Firm: $FIRM_ID"
    
    aws dynamodb put-item \
        --table-name "$TABLE_FIRMS" \
        --item "{
            \"firmid\": {\"S\": \"$FIRM_ID\"},
            \"firmId\": {\"S\": \"$FIRM_ID\"},
            \"firmName\": {\"S\": \"RuchiServ Audit Firm\"},
            \"mobile\": {\"S\": \"9999999999\"},
            \"email\": {\"S\": \"admin@ruchiserv.com\"},
            \"subscriptionTier\": {\"S\": \"ENTERPRISE\"},
            \"subscriptionPlan\": {\"S\": \"ENTERPRISE\"},
            \"subscriptionExpiry\": {\"S\": \"2026-12-31\"},
            \"enabledFeatures\": {\"S\": \"GPS_TRACKING,WHATSAPP,EMAIL,ANALYTICS,MULTI_BRANCH,API_ACCESS\"},
            \"createdAt\": {\"S\": \"2024-01-01T00:00:00Z\"},
            \"updatedAt\": {\"S\": \"2024-01-01T00:00:00Z\"},
            \"subscriptionStatus\": {\"S\": \"ACTIVE\"}
        }"

    aws dynamodb put-item \
        --table-name "$TABLE_USERS" \
        --item "{
            \"ruchiserv-firms\": {\"S\": \"$FIRM_ID\"},
            \"mobile\": {\"S\": \"9999999999\"},
            \"firmId\": {\"S\": \"$FIRM_ID\"},
            \"userId\": {\"S\": \"U-9999999999\"},
            \"username\": {\"S\": \"Audit User\"},
            \"passwordHash\": {\"S\": \"test1234\"},
            \"role\": {\"S\": \"Admin\"},
            \"isActive\": {\"N\": \"1\"},
            \"createdAt\": {\"S\": \"2024-01-01T00:00:00Z\"},
            \"updatedAt\": {\"S\": \"2024-01-01T00:00:00Z\"}
        }"

    aws dynamodb put-item \
        --table-name "$TABLE_AUTH" \
        --item "{
            \"firmId\": {\"S\": \"$FIRM_ID\"},
            \"mobile\": {\"S\": \"9999999999\"},
            \"name\": {\"S\": \"Audit User\"},
            \"role\": {\"S\": \"Admin\"},
            \"isActive\": {\"N\": \"1\"},
            \"addedAt\": {\"S\": \"2024-01-01T00:00:00Z\"}
        }"
}

seed_firm_user "RCHSRV"
seed_firm_user "rchsrv"

echo "Seeding completed successfully."
