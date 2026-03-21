#!/bin/bash

AUTH_URL="http://localhost:8001"
FLAG_URL="http://localhost:8002"
TARGET_URL="http://localhost:8003"
EVAL_URL="http://localhost:8004"
MASTER_KEY="admin-secreto-123"

FLAG_NAME="enable-feature-evaluation-6"

# -----------------------------
# EVALUATION SERVICE
# -----------------------------
echo""
echo -n "Starting evaluation-service:"
curl -sS -f "$EVAL_URL/health" 

echo ""
CREATE_RESPONSE=$(curl -X POST "$AUTH_URL/admin/keys" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MASTER_KEY" \
  -d '{"name": "evaluation-service-key"}')
API_KEY=$(echo "$CREATE_RESPONSE" | jq -r '.key' 2>/dev/null)

echo ""
echo "Create API_KEY $API_KEY"
VALID_KEY=$(curl "$AUTH_URL/validate" \
  -H "Authorization: Bearer $API_KEY")
echo "$VALID_KEY"

echo ""
echo "GET FLAG"
GET_FLAG=$(curl -sS -f "$FLAG_URL/flags/$FLAG_NAME" \
  -H "Authorization: Bearer $API_KEY")
echo "$GET_FLAG" | jq .


echo ""
echo "Get Rule"
GET_RULE=$(curl -sS -f "$TARGET_URL/rules/$FLAG_NAME" \
  -H "Authorization: Bearer $API_KEY")
echo "$GET_RULE" | jq .
