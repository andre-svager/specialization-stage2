#!/bin/bash

AUTH_URL="http://localhost:8001"
FLAG_URL="http://localhost:8002"
TARGET_URL="http://localhost:8003"
FLAG_NAME="enable-feature-evaluation-6"

MASTER_KEY="admin-secreto-123"


# -----------------------------
# TARGET SERVICE
# -----------------------------
echo""
echo -n "Starting target-service:"
curl -sS -f "$TARGET_URL/health" 

echo ""
CREATE_RESPONSE=$(curl -X POST "$AUTH_URL/admin/keys" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MASTER_KEY" \
  -d '{"name": "target-service-key"}')
API_KEY=$(echo "$CREATE_RESPONSE" | jq -r '.key' 2>/dev/null)

echo ""
echo "Create API_KEY $API_KEY"

echo ""
echo "Create TARGET"
TARGET=$(curl -sS -f -X POST "$TARGET_URL/rules" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "flag_name": "'"$FLAG_NAME"'",
    "is_enabled": true,
    "rules": {
        "type": "PERCENTAGE",
        "value": 50
    }
}')

echo "$TARGET" | jq .

echo ""
echo "Get Rule"
RULE=$(curl -sS -f "$TARGET_URL/rules/$FLAG_NAME" \
  -H "Authorization: Bearer $API_KEY")

echo "$RULE" | jq .

echo ""
echo "Updating Rule to 75%"

UPD=$(curl -sS -f -X PUT "$TARGET_URL/rules/$FLAG_NAME" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "rules": {
        "type": "PERCENTAGE",
        "value": 75
    }
}' )

echo "$UPD" | jq .