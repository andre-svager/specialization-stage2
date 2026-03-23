#!/bin/bash

AUTH_URL="http://localhost:8001"
FLAG_URL="http://localhost:8002"
TARGET_URL="http://localhost:8003"
EVAL_URL="http://localhost:8004"
MASTER_KEY="admin-secreto-123"

FLAG_NAME="enable-feature-stage"

# -----------------------------
# EVALUATION SERVICE
# -----------------------------
echo""
echo -n "Starting evaluation-service:"
curl -sS -f "$EVAL_URL/health" 

# echo ""
# CREATE_RESPONSE=$(curl -X POST "$AUTH_URL/admin/keys" \
#   -H "Content-Type: application/json" \
#   -H "Authorization: Bearer $MASTER_KEY" \
#   -d '{"name": "evaluation-service-key"}')
# SERVICE_API_KEY=$(echo "$CREATE_RESPONSE" | jq -r '.key' 2>/dev/null)

SERVICE_API_KEY=tm_key_cd7136878ac6ec0a52a57695f56b34a68bc507cea5631f350d95763dbe457421

echo ""
echo "VALIDATE SERVICE_API_KEY $SERVICE_API_KEY"
VALID_KEY=$(curl "$AUTH_URL/validate" \
  -H "Authorization: Bearer $SERVICE_API_KEY")
echo "$VALID_KEY"

echo ""
echo "GET FLAG"
GET_FLAG=$(curl -sS -f "$FLAG_URL/flags/$FLAG_NAME" \
  -H "Authorization: Bearer $SERVICE_API_KEY")
echo "$GET_FLAG" | jq .


echo ""
echo "Get Rule"
GET_RULE=$(curl -sS -f "$TARGET_URL/rules/$FLAG_NAME" \
  -H "Authorization: Bearer $SERVICE_API_KEY")
echo "$GET_RULE" | jq .

echo ""
echo "docker rm -f evaluation-service"
echo "docker compose up -d --build evaluation-service"