import hashlib
import boto3
import os
import json

# Initialize the DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('TABLE_NAME', 'hash_table')
table = dynamodb.Table(table_name)

def generate_md5_hash(text):
    """Generate MD5 hash for the given text."""
    return hashlib.md5(text.encode()).hexdigest()

def lambda_handler(event, context):
    # Extract the list of text from the event body
    body = event.get('body')
    if not body:
        return {
            'statusCode': 400,
            'body': 'No data provided in the request body.'
        }
    
    try:
        text_list = json.loads(body).get('texts', [])
        
        if not text_list or not isinstance(text_list, list):
            return {
                'statusCode': 400,
                'body': 'Invalid data format. Expecting a JSON object with a list of texts.'
            }

        for text in text_list:
            md5_hash = generate_md5_hash(text)
            
            # Put item into DynamoDB
            table.put_item(
                Item={
                    'Plaintext': text,
                    'HashValue': md5_hash
                }
            )

        return {
            'statusCode': 200,
            'body': 'Successfully stored MD5 hashes.'
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': f"An error occurred: {str(e)}"
        }

