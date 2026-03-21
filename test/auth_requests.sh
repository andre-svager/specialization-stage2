#!/bin/bash

AUTH_URL="http://localhost:8001"
MASTER_KEY="admin-secreto-123"
WRONG_KEY="admin-secreto"

# -----------------------------
# AUTH SERVICE
# -----------------------------
echo -n "Starting auth-service: "
curl -s "$AUTH_URL/health"


CREATE_RESPONSE=$(curl -X POST "$AUTH_URL/admin/keys" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MASTER_KEY" \
  -d '{"name": "evaluation-service-key"}')

echo ""
echo -n "RAW RESPONSE:$CREATE_RESPONSE"
echo ""

API_KEY=$(echo "$CREATE_RESPONSE" | jq -r '.key' 2>/dev/null)

curl "$AUTH_URL/validate" \
  -H "Authorization: Bearer $API_KEY"
echo ""

echo "Tentativa com chave invalida"
curl "$AUTH_URL/validate" \
  -H "Authorization: Bearer $WRONG_KEY"
echo "> $WRONG_KEY"
echo""


