#!/bin/bash

AUTH_URL="http://localhost:8001"
FLAG_URL="http://localhost:8002"
FLAG_NAME="enable-feature-evaluation-6"

MASTER_KEY="admin-secreto-123"

# -----------------------------
# FLAG SERVICE
# -----------------------------
echo ""
echo -n "Starting flag-service:"
curl -s "$FLAG_URL/health"

echo ""
echo "Create API_KEY"
CREATE_RESPONSE=$(curl -X POST "$AUTH_URL/admin/keys" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MASTER_KEY" \
  -d '{"name": "flag-service-key"}')
API_KEY=$(echo "$CREATE_RESPONSE" | jq -r '.key' 2>/dev/null)

echo ""
echo "Create new Flag"
N_FLAG=$(curl -sS -f -X POST "$FLAG_URL/flags" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "name": "'"$FLAG_NAME"'",
    "description": "Ativa nova Feature",
    "is_enabled": false
}')
echo "$N_FLAG" | jq .

echo ""
echo "List Flags"
FLAGS=$(curl -sS -f "$FLAG_URL/flags" \
  -H "Authorization: Bearer $API_KEY")

echo "$FLAGS" | jq .


echo ""
echo "Enable Flag"
DIS_FLAGS=$(curl -sS -f -X PUT "$FLAG_URL/flags/$FLAG_NAME" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{"is_enabled": true}')
echo "$DIS_FLAGS" | jq .