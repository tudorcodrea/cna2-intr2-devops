#!/bin/bash

# Deployment script for AWS Lambda functions

set -e

echo "Building Lambda deployment packages..."

# Clean previous builds
rm -f *.zip

# Install dependencies
pip install -r requirements.txt -t .

# Create deployment package for claims-summarizer
echo "Creating claims-summarizer.zip..."
zip -r claims-summarizer.zip claims-summarizer.py boto3 botocore -x "*.git*" "*__pycache__*" "*.DS_Store" "*test*" "*README.md*" "*claim-data-notes-generator.py*" "*deploy.sh*"

# Create deployment package for claim-data-notes-generator
echo "Creating claim-data-notes-generator.zip..."
zip -r claim-data-notes-generator.zip claim-data-notes-generator.py boto3 botocore -x "*.git*" "*__pycache__*" "*.DS_Store" "*test*" "*README.md*" "*claims-summarizer.py*" "*deploy.sh*"

echo "Packages created successfully:"
echo "  - claims-summarizer.zip"
echo "  - claim-data-notes-generator.zip"

# Optional: Deploy to AWS (uncomment and configure)
echo ""
echo "To deploy manually:"
echo "aws lambda create-function --function-name claims-summarizer \\"
echo "  --runtime python3.11 --handler claims-summarizer.lambda_handler \\"
echo "  --zip-file fileb://claims-summarizer.zip --role <lambda-role-arn>"
echo ""
echo "aws lambda create-function --function-name claim_generate_files \\"
echo "  --runtime python3.11 --handler claim-data-notes-generator.lambda_handler \\"
echo "  --zip-file fileb://claim-data-notes-generator.zip --role <lambda-role-arn>"

echo ""
echo "Or update existing functions:"
echo "aws lambda update-function-code --function-name claims-summarizer --zip-file fileb://claims-summarizer.zip"
echo "aws lambda update-function-code --function-name claim_generate_files --zip-file fileb://claim-data-notes-generator.zip"