#!/bin/bash

AUTH_URL="http://localhost:8001"
FLAG_URL="http://localhost:8002"
TARGET_URL="http://localhost:8003"
EVAL_URL="http://localhost:8004"
FLAG_NAME="enable-feature-a2"

MASTER_KEY="admin-secreto-123"

# -----------------------------
# AUTH SERVICE
# -----------------------------
echo -n "Starting auth-service: "
curl -s "$FLAG_URL/health"
echo ""
echo "Creating API key..."

CREATE_RESPONSE=$(curl -X POST "$AUTH_URL/admin/keys" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MASTER_KEY" \
  -d '{"name": "evaluation-service-key"}')
  #-d '{"name": "test-service"}')

echo -n "RAW RESPONSE:$CREATE_RESPONSE"
echo ""

API_KEY=$(echo "$CREATE_RESPONSE" | jq -r '.key' 2>/dev/null)

curl "$AUTH_URL/validate" \
  -H "Authorization: Bearer $API_KEY"
echo ""


# -----------------------------
# FLAG SERVICE
# -----------------------------
echo -n "Starting flag-service:"
curl -s "$FLAG_URL/health"

curl -sS -f -X POST "$FLAG_URL/flags" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "name": "'"$FLAG_NAME"'",
    "description": "Ativa nova Feature",
    "is_enabled": false
}'

FLAGS=$(curl -sS -f "$FLAG_URL/flags" \
  -H "Authorization: Bearer $API_KEY")

echo "$FLAGS" | jq .

echo "Enabling Flag"
curl -sS -f -X PUT "$FLAG_URL/flags/$FLAG_NAME" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{"is_enabled": true}'
echo""


# -----------------------------
# TARGET SERVICE
# -----------------------------
echo -n "Starting target-service:"
curl -sS -f "$TARGET_URL/health" 

curl -sS -f -X POST "$TARGET_URL/rules" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "flag_name": "'"$FLAG_NAME"'",
    "is_enabled": true,
    "rules": {
        "type": "PERCENTAGE",
        "value": 50
    }
}'

RULE=$(curl -sS -f "$TARGET_URL/rules/$FLAG_NAME" \
  -H "Authorization: Bearer $API_KEY")

echo "$RULE" | jq .

echo "Updating Rule to 75%"
curl -sS -f -X PUT "$TARGET_URL/rules/$FLAG_NAME" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "rules": {
        "type": "PERCENTAGE",
        "value": 75
    }
}' 


# -----------------------------
# EVALUATION SERVICE
# -----------------------------

 EVALUATION_RESPONSE=$(curl -X POST "$AUTH_URL/admin/keys" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MASTER_KEY" \
  -d '{"name": "evaluation-service-key"}')

API_KEY_EVAL=$(echo "$EVALUATION_RESPONSE" | jq -r '.key' 2>/dev/null)   
echo -n "EVALUATION KEY:$API_KEY_EVAL"

echo""
echo "Update Evaluation SERVICE_API_KEY them Press Enter to continue..."
read

echo "Checking evaluation-service health..."
HEALTH=$(curl -s "$EVAL_URL/health")
echo "Health: $HEALTH"

echo "Evaluating flag for test users..."

# Test User 1
USER1="user-123"
RESULT1=$(curl -s "$EVAL_URL/evaluate?user_id=$USER1&flag_name=$FLAG_NAME")
echo "User $USER1: $RESULT1"

# Test User 2
USER2="user-abc"
RESULT2=$(curl -s "$EVAL_URL/evaluate?user_id=$USER2&flag_name=$FLAG_NAME")
echo "User $USER2: $RESULT2"

echo "Running cache test (repeat evaluation for User 1)..."
CACHE_TEST=$(curl -s "$EVAL_URL/evaluate?user_id=$USER1&flag_name=$FLAG_NAME")
echo "Repeat evaluation User $USER1: $CACHE_TEST"

echo "Evaluation events should now be visible in your SQS queue."


echo ""
read -p "Press enter to exit"