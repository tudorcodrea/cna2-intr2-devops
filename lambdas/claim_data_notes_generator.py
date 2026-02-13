import json
import boto3
import os
import logging
from datetime import datetime
from typing import Dict, Any, Optional
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
s3_client = boto3.client('s3')
bedrock_client = boto3.client('bedrock-runtime', region_name='us-east-1')

# Configuration from environment variables
CLAIMS_TABLE = os.environ.get('CLAIMS_TABLE', 'claims')
CLAIMS_BUCKET = os.environ.get('CLAIMS_BUCKET', 'claims-notes-bucket')
BEDROCK_MODEL_ID = os.environ.get('BEDROCK_MODEL_ID', 'amazon.nova-lite-v1:0')


class ClaimDataNotesGenerator:
    """Lambda function to generate claim-related documents using Amazon Bedrock"""

    def __init__(self):
        self.table = dynamodb.Table(CLAIMS_TABLE)

    def lambda_handler(self, event: Dict[str, Any], context: Any) -> Dict[str, Any]:
        try:
            logger.info(f"Received event: {json.dumps(event)}")

            claim_id = event.get('claimId')
            if not claim_id:
                raise ValueError("claimId is required in the event payload")

            claim_data = event.get('claimData')
            if not claim_data:
                claim_data = self._fetch_claim_from_dynamodb(claim_id)
                if not claim_data:
                    raise ValueError(f"Claim {claim_id} not found in database")

            claim_notes = self._fetch_claim_notes_from_s3(claim_id)

            adjuster_notes = self._generate_adjuster_notes(claim_data, claim_notes)
            customer_correspondence = self._generate_customer_correspondence(claim_data, claim_notes)

            self._store_document_to_s3(claim_id, 'adjuster-notes.json', adjuster_notes)
            self._store_document_to_s3(claim_id, 'customer-correspondence.json', customer_correspondence)

            return {
                'statusCode': 200,
                'claimId': claim_id,
                'generatedFiles': [
                    f's3://{CLAIMS_BUCKET}/{claim_id}/adjuster-notes.json',
                    f's3://{CLAIMS_BUCKET}/{claim_id}/customer-correspondence.json'
                ],
                'generatedAt': datetime.utcnow().isoformat(),
                'message': 'Claim documents generated successfully'
            }

        except Exception as e:
            logger.error(f"Error generating claim documents: {str(e)}")
            return {
                'statusCode': 500,
                'error': str(e),
                'claimId': event.get('claimId'),
                'generatedAt': datetime.utcnow().isoformat()
            }

    def _fetch_claim_from_dynamodb(self, claim_id: str) -> Optional[Dict[str, Any]]:
        try:
            response = self.table.get_item(Key={'claimId': claim_id})
            return response.get('Item')
        except ClientError as e:
            logger.error(f"Error fetching claim {claim_id} from DynamoDB: {e}")
            raise

    def _fetch_claim_notes_from_s3(self, claim_id: str) -> str:
        try:
            response = s3_client.get_object(
                Bucket=CLAIMS_BUCKET,
                Key=f'{claim_id}/notes.txt'
            )
            return response['Body'].read().decode('utf-8')
        except ClientError as e:
            if e.response['Error']['Code'] == 'NoSuchKey':
                logger.warning(f"No notes file found for claim {claim_id}, using default message")
                return "No additional notes available for this claim."
            logger.error(f"Error fetching notes for claim {claim_id}: {e}")
            raise

    def _generate_adjuster_notes(self, claim_data: Dict[str, Any], claim_notes: str) -> Dict[str, Any]:
        prompt = f"""
You are an experienced insurance claims adjuster. Based on the following claim information, generate comprehensive adjuster notes that would be used internally for claim assessment and processing.

Claim Details:
{json.dumps(claim_data, indent=2, default=str)}

Claim Notes:
{claim_notes}

Please generate detailed adjuster notes in the following JSON format:
{{
  \"assessment\": \"Detailed assessment of the claim including coverage analysis and risk evaluation\",
  \"findings\": \"Key findings from the investigation\",
  \"recommendations\": \"Specific recommendations for claim disposition (APPROVE, DENY, REQUEST_MORE_INFO, SCHEDULE_INSPECTION, PENDING_REVIEW)\",
  \"estimatedSettlement\": \"Estimated settlement amount if applicable\",
  \"nextSteps\": \"Recommended next steps for claim processing\",
  \"riskLevel\": \"LOW, MEDIUM, HIGH risk assessment\",
  \"generatedAt\": \"{datetime.utcnow().isoformat()}\"
}}
"""

        response_text = self._invoke_bedrock(prompt)
        # Strip markdown code blocks if present
        if response_text.startswith('```json'):
            response_text = response_text.replace('```json', '').replace('```', '').strip()
        return json.loads(response_text)

    def _generate_customer_correspondence(self, claim_data: Dict[str, Any], claim_notes: str) -> Dict[str, Any]:
        prompt = f"""
You are a professional insurance claims representative. Based on the following claim information, generate a customer-friendly correspondence that explains the current status and next steps.

Claim Details:
{json.dumps(claim_data, indent=2, default=str)}

Claim Notes:
{claim_notes}

Please generate customer correspondence in the following JSON format:
{{
  \"subject\": \"Clear, concise email subject line\",
  \"greeting\": \"Personalized greeting using customer information\",
  \"body\": \"Clear explanation of claim status, what happened, current assessment, and next steps. Use simple language avoiding technical jargon.\",
  \"nextSteps\": \"Specific actions the customer should take or what to expect next\",
  \"contactInformation\": \"How and when the customer can contact us for updates\",
  \"closing\": \"Professional closing\",
  \"generatedAt\": \"{datetime.utcnow().isoformat()}\"
}}
"""

        response_text = self._invoke_bedrock(prompt)
        # Strip markdown code blocks if present
        if response_text.startswith('```json'):
            response_text = response_text.replace('```json', '').replace('```', '').strip()
        return json.loads(response_text)

    def _invoke_bedrock(self, prompt: str) -> str:
        try:
            if BEDROCK_MODEL_ID.startswith('amazon.nova'):
                # Amazon Nova format
                body = {
                    "inferenceConfig": {
                        "maxTokens": 2000,
                        "temperature": 0.1
                    },
                    "messages": [
                        {
                            "role": "user",
                            "content": [
                                {
                                    "text": prompt
                                }
                            ]
                        }
                    ]
                }
            else:
                # Anthropic Claude format (fallback)
                body = {
                    "anthropic_version": "bedrock-2023-05-31",
                    "max_tokens": 2000,
                    "temperature": 0.1,
                    "messages": [{"role": "user", "content": prompt}]
                }

            logger.info(f"Invoking Bedrock with model {BEDROCK_MODEL_ID}")
            logger.info(f"Request body: {json.dumps(body)}")
            
            response = bedrock_client.invoke_model(
                modelId=BEDROCK_MODEL_ID,
                body=json.dumps(body),
                contentType='application/json',
                accept='application/json'
            )

            response_body_raw = response['body'].read()
            logger.info(f"Raw Bedrock response body: {response_body_raw}")
            
            if not response_body_raw:
                raise ValueError("Empty response from Bedrock")
            
            response_body = json.loads(response_body_raw)
            logger.info(f"Parsed Bedrock response: {json.dumps(response_body, indent=2)}")
            
            if BEDROCK_MODEL_ID.startswith('amazon.nova'):
                # Amazon Nova response format
                if 'output' in response_body and 'message' in response_body['output']:
                    if 'content' in response_body['output']['message'] and len(response_body['output']['message']['content']) > 0:
                        content = response_body['output']['message']['content'][0]
                        if 'text' in content:
                            return content['text']
                        else:
                            logger.error(f"No text in content: {content}")
                            raise ValueError(f"No text field in Nova response content: {content}")
                    else:
                        logger.error(f"No content in message: {response_body['output']['message']}")
                        raise ValueError(f"No content in Nova response message: {response_body['output']['message']}")
                else:
                    logger.error(f"Unexpected Nova response structure: {response_body}")
                    raise ValueError(f"Unexpected response structure from Nova model: {response_body}")
            else:
                # Anthropic Claude response format
                if 'content' in response_body and len(response_body['content']) > 0:
                    return response_body['content'][0]['text']
                else:
                    logger.error(f"Unexpected Claude response structure: {response_body}")
                    raise ValueError(f"Unexpected response structure from Claude model: {response_body}")

        except ClientError as e:
            logger.error(f"Error invoking Bedrock: {e}")
            raise
        except Exception as e:
            logger.error(f"Unexpected error in _invoke_bedrock: {e}")
            raise

    def _store_document_to_s3(self, claim_id: str, filename: str, content: Dict[str, Any]) -> None:
        try:
            key = f'{claim_id}/{filename}'
            s3_client.put_object(
                Bucket=CLAIMS_BUCKET,
                Key=key,
                Body=json.dumps(content, indent=2, default=str),
                ContentType='application/json'
            )
            logger.info(f"Stored document {key} to S3")
        except ClientError as e:
            logger.error(f"Error storing document {filename} for claim {claim_id}: {e}")
            raise


def lambda_handler(event, context):
    generator = ClaimDataNotesGenerator()
    return generator.lambda_handler(event, context)
