#!/bin/bash

awslocal sqs create-queue --queue-name evaluation-events

awslocal dynamodb create-table \
  --table-name ToggleMasterAnalytics \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST