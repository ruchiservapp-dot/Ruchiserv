import boto3
import json

dynamodb = boto3.resource('dynamodb', region_name='ap-south-1')
table = dynamodb.Table('ruchiserv-users')

from boto3.dynamodb.conditions import Key

# Check users for firm RUCHIC5M
response = table.query(
    KeyConditionExpression=Key('ruchiserv-firms').eq('RUCHIC5M')
)
print(json.dumps(response.get('Items', []), indent=2))
