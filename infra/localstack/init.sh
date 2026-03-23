#!/bin/bash

set -e

MAX_RETRIES=40
RETRY_COUNT=0

echo "=== LocalStack Initialization Script ==="
echo "Waiting for LocalStack services to be ready..."

# Wait for LocalStack SQS to be available with intelligent retry
until awslocal sqs list-queues &>/dev/null; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -gt $MAX_RETRIES ]; then
        echo "ERROR: LocalStack SQS did not become available after $((RETRY_COUNT * 2))s"
        exit 1
    fi
    echo "Waiting for LocalStack SQS... (attempt $RETRY_COUNT/$MAX_RETRIES, ${RETRY_COUNT}0 seconds)"
    sleep 2
done

echo "✓ LocalStack SQS is ready"

# Create SQS Queue with explicit region
echo "Creating SQS queue 'evaluation-events'..."
if awslocal sqs create-queue --queue-name evaluation-events --region us-east-1 2>&1; then
    echo "✓ Queue created successfully"
else
    echo "✓ Queue already exists (idempotent)"
fi

# Get queue URL for verification
QUEUE_URL=$(awslocal sqs get-queue-url --queue-name evaluation-events --region us-east-1 2>/dev/null | grep -o 'http[^"]*' || echo "unknown")
echo "Queue URL: $QUEUE_URL"

# Create DynamoDB Table
echo "Creating DynamoDB table 'ToggleMasterAnalytics'..."
if awslocal dynamodb create-table \
  --table-name ToggleMasterAnalytics \
  --attribute-definitions AttributeName=flag_id,AttributeType=S \
  --key-schema AttributeName=flag_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1 2>&1; then
    echo "✓ DynamoDB table created successfully"
else
    echo "✓ DynamoDB table already exists (idempotent)"
fi

echo "=== LocalStack Initialization Complete ==="
echo "Services ready:"
echo "  - SQS: evaluation-events"
echo "  - DynamoDB: ToggleMasterAnalytics"