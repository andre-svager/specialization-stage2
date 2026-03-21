#!/bin/bash

AUTH_URL="http://localhost:8001"
FLAG_URL="http://localhost:8002"
TARGET_URL="http://localhost:8003"
EVAL_URL="http://localhost:8004"
MASTER_KEY="admin-secreto-123"

FLAG_NAME="enable-feature-evaluation-2"

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


echo ""
echo "Create new Flag"
N_FLAG=$(curl -sS -f -X POST "$FLAG_URL/flags" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "name": "'"$FLAG_NAME"'",
    "description": "Ativa nova Feature",
    "is_enabled": true
}')
echo "$N_FLAG" | jq .


echo ""
echo "Create target"
TARGET=$(curl -sS -f -X POST "$TARGET_URL/rules" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "flag_name": "'"$FLAG_NAME"'",
    "is_enabled": true,
    "rules": {
        "type": "PERCENTAGE",
        "value": 90
    }
}')

echo "$TARGET" | jq .
