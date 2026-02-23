import boto3
import time
from botocore.exceptions import ClientError

def insert_test_data():
    dynamodb = boto3.resource('dynamodb', region_name='ap-south-1')
    
    # Tables
    firms_table = dynamodb.Table('ruchiserv-firms')
    users_table = dynamodb.Table('ruchiserv-users')
    
    firm_id = 'RCHSRV_TEST'
    mobile = '9876543210'
    password = 'Cashfree@123'
    
    print(f"Inserting Firm: {firm_id}")
    try:
        firms_table.put_item(Item={
            'firmid': firm_id,
            'firmName': 'Test Firm',
            'subscriptionStatus': 'ACTIVE',
            'mobile': mobile,
            'createdAt': int(time.time() * 1000),
            'updatedAt': int(time.time() * 1000)
        })
        print("✅ Firm inserted successfully.")
    except ClientError as e:
        print(f"❌ Error inserting firm: {e}")

    print(f"Inserting User: {mobile} for Firm {firm_id}")
    try:
        users_table.put_item(Item={
            'ruchiserv-firms': firm_id, # Partition Key
            'mobile': mobile,           # Sort Key
            'passwordHash': password,
            'role': 'Admin',
            'username': 'Test Admin',
            'isActive': 1,
            'permissions': 'ALL',
            'createdAt': int(time.time() * 1000),
            'updatedAt': int(time.time() * 1000)
        })
        print("✅ User inserted successfully.")
    except ClientError as e:
        print(f"❌ Error inserting user: {e}")

if __name__ == "__main__":
    insert_test_data()
