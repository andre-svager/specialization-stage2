#!/bin/bash

# Script para enviar mensagens manualmente para SQS

QUEUE_URL="https://sqs.us-east-1.amazonaws.com/973397181776/evaluation-events"

echo "Enviando 5 mensagens para SQS..."

for i in {1..5}; do
  aws sqs send-message \
    --queue-url "$QUEUE_URL" \
    --message-body "{\"user_id\":\"user-$i\",\"flag_name\":\"test-flag-$i\",\"result\":true,\"timestamp\":\"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\"}" \
    --region us-east-1
  echo "✓ Mensagem $i enviada"
done

echo ""
echo "Verificando fila..."
aws sqs get-queue-attributes \
  --queue-url "$QUEUE_URL" \
  --attribute-names ApproximateNumberOfMessages \
  --region us-east-1 \
  --query 'Attributes.ApproximateNumberOfMessages' \
  --output text | xargs echo "Total na fila:"
