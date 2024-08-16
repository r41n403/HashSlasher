import json
import hashlib
import boto3

# Initialize the DynamoDB resource
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('hash_table')

def lambda_handler(event, context):
    # Extract plaintext from POST data
    body = json.loads(event['body'])
    plaintext = body.get('plaintext', '')

    if not plaintext:
        return {
            'statusCode': 400,
            'body': json.dumps('No plaintext provided')
        }

    # Generate MD5 hash of the plaintext
    md5_hash = hashlib.md5(plaintext.encode()).hexdigest()

    # Prepare the item to insert
    item = {
        'HashValue': md5_hash,
        'Plaintext': plaintext
    }

    # Write to DynamoDB
    table.put_item(Item=item)

    return {
        'statusCode': 200,
        'body': json.dumps(f'Item with hash {md5_hash} stored successfully.')
    }
