import json
import boto3
import os

sqs = boto3.client('sqs')
QUEUE_URL = os.environ['QUEUE_URL']

def lambda_handler(event, context):
    try:
        body = json.loads(event.get('body', '{}'))
        print(f"Received payload: {body}")
        
        response = sqs.send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=json.dumps(body)
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'status': 'success',
                'messageId': response['MessageId']
            })
        }
    except Exception as e:
        print(f"Error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'status': 'error', 'message': str(e)})
        }
