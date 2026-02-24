import boto3
import json
from decimal import Decimal

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return str(obj)
        return super(DecimalEncoder, self).default(obj)

dynamodb = boto3.resource('dynamodb', region_name='ap-south-1')
table = dynamodb.Table('ruchiserv_data')

from boto3.dynamodb.conditions import Key

# Check users for firm RUCHIC5M
try:
    response = table.query(
        KeyConditionExpression=Key('pk').eq('RUCHIC5M') & Key('sk').begins_with('users#')
    )
    print("Unified Table Data:")
    print(json.dumps(response.get('Items', []), indent=2, cls=DecimalEncoder))
except Exception as e:
    print(f"Error querying unified table: {e}")
