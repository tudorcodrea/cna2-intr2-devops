import json
import boto3
import os
from datetime import datetime
from botocore.exceptions import ClientError

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
s3_client = boto3.client('s3')
bedrock_client = boto3.client('bedrock-runtime', region_name='us-east-1')

# Configuration
CLAIMS_TABLE = os.environ.get('CLAIMS_TABLE', 'claims')
CLAIMS_BUCKET = os.environ.get('CLAIMS_BUCKET', 'claims-notes-bucket')
BEDROCK_MODEL_ID = os.environ.get('BEDROCK_MODEL_ID', 'amazon.nova-lite-v1:0')


class ClaimsSummarizer:
    def __init__(self):
        self.table = dynamodb.Table(CLAIMS_TABLE)

    def lambda_handler(self, event, context):
        claim_id = event.get('claimId')
        if not claim_id:
            return {'error': 'claimId required'}

        # Fetch claim
        claim = self.table.get_item(Key={'claimId': claim_id}).get('Item')
        if not claim:
            return {'error': 'Claim not found'}

        # Fetch notes
        try:
            notes = s3_client.get_object(Bucket=CLAIMS_BUCKET, Key=f'{claim_id}/notes.txt')['Body'].read().decode('utf-8')
        except:
            notes = 'No notes available'

        # Generate summary
        summary = self._generate_summary(claim, notes)

        return {
            'claimId': claim_id,
            'summaries': summary,
            'generatedAt': datetime.utcnow().isoformat(),
            'modelUsed': BEDROCK_MODEL_ID
        }

    def _generate_summary(self, claim, notes):
        prompt = f"""
Analyze this insurance claim and provide a summary in JSON format.

Claim: {json.dumps(claim, default=str)}
Notes: {notes}

Return only JSON:
{{
  "overall": "Brief summary",
  "customer": "Customer explanation",
  "adjuster": "Adjuster details",
  "recommendation": "APPROVE/DENY/etc"
}}
"""

        # Call Bedrock
        body = {
            "inferenceConfig": {"maxTokens": 1000, "temperature": 0.1},
            "messages": [{"role": "user", "content": [{"text": prompt}]}]
        }

        response = bedrock_client.invoke_model(
            modelId=BEDROCK_MODEL_ID,
            body=json.dumps(body),
            contentType='application/json',
            accept='application/json'
        )

        result = json.loads(response['body'].read())
        text = result['output']['message']['content'][0]['text']

        # Strip markdown if present
        if text.startswith('```json'):
            text = text[7:].strip()
        if text.endswith('```'):
            text = text[:-3].strip()

        return json.loads(text)


def lambda_handler(event, context):
    summarizer = ClaimsSummarizer()
    return summarizer.lambda_handler(event, context)
