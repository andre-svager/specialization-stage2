#!/usr/bin/env bash

set -e

echo "🧹 Cleaning AWS resources..."

QUEUE_URL=$(aws sqs get-queue-url \
  --queue-name evaluation-events \
  --query QueueUrl \
  --output text)

aws sqs delete-queue \
  --queue-url $QUEUE_URL \
  || echo "Queue already deleted"

aws dynamodb delete-table \g
  --table-name analytics-events \
  || echo "Table already deleted"

echo "✅ Cleanup complete"