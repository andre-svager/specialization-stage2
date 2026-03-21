#!/usr/bin/env bash

QUEUE_NAME="evaluation-events"

echo "Creating SQS queue: $QUEUE_NAME"

aws $AWS_ENDPOINT sqs create-queue \
  --queue-name $QUEUE_NAME \
  --attributes VisibilityTimeout=30 \
  || echo "Queue already exists"

echo "SQS ready"

# aws sqs get-queue-url \
#  --queue-name evaluation-events
#  
# aws sqs delete-queue \
#  --queue-url https://sqs.us-east-1.amazonaws.com/973397181776/evaluation-events

# verify deletion
#aws sqs list-queues