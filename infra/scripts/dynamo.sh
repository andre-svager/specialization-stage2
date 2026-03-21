#!/usr/bin/env bash

TABLE_NAME="analytics-events"

echo "Creating DynamoDB table: $TABLE_NAME"

aws $AWS_ENDPOINT dynamodb create-table \
  --table-name $TABLE_NAME \
  --attribute-definitions \
    AttributeName=event_id,AttributeType=S \
  --key-schema \
    AttributeName=event_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  || echo "Table already exists"

echo "DynamoDB ready"

# aws dynamodb delete-table \
#  --table-name analytics-events

# verify 
# aws dynamodb list-tables