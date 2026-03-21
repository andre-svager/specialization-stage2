#!/usr/bin/env bash

set -e

echo "🚀 Bootstrapping Feature Flag Platform Infrastructure"

ENV=${1:-local}

if [ "$ENV" = "local" ]; then
  echo "Using LocalStack endpoints"
  export AWS_ENDPOINT="--endpoint-url=http://localhost:4566"
else
  echo "Using real AWS"
  export AWS_ENDPOINT=""
fi

echo ""
echo "1️⃣ Creating SQS resources..."
./infra/sqs.sh

echo ""
echo "2️⃣ Creating DynamoDB tables..."
./infra/dynamodb.sh

echo ""
echo "3️⃣ Starting Redis (evaluation cache)..."
docker compose up -d evaluation-db

echo ""
echo "4️⃣ Running service migrations..."
./infra/migrations.sh

echo ""
echo "✅ Infrastructure ready!"


# RUN IT !!
# ./infra/bootstrap.sh aws
# chmod +x infra/*.sh
# docker compose up -d
# ./infra/bootstrap.sh local
# ./infra/bootstrap.sh aws





aws sqs create-queue \
  --queue-name evaluation-events \
  --region us-east-1

aws sqs list-queues

aws dynamodb create-table \
  --table-name analytics-events \
  --attribute-definitions \
      AttributeName=event_id,AttributeType=S \
  --key-schema \
      AttributeName=event_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

  aws dynamodb list-tables

  aws dynamodb describe-table \
  --table-name analytics-events


  aws dynamodb put-item \
  --table-name analytics-events \
  --item '{
    "event_id": {"S": "1"},
    "flag": {"S": "new-ui"},
    "user": {"S": "123"}
  }'
