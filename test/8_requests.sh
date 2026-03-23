#!/bin/bash

AUTH_URL="http://aae373c8b4cdf4430b4aebb82d8b97d1-bb79570497308936.elb.us-east-1.amazonaws.com/auth"
EVALUATION_URL="http://aae373c8b4cdf4430b4aebb82d8b97d1-bb79570497308936.elb.us-east-1.amazonaws.com/evaluation"
ANALYTICS_URL="http://aae373c8b4cdf4430b4aebb82d8b97d1-bb79570497308936.elb.us-east-1.amazonaws.com/analytics"
FLAG_URL="http://aae373c8b4cdf4430b4aebb82d8b97d1-bb79570497308936.elb.us-east-1.amazonaws.com/flag"
TARGET_URL="http://aae373c8b4cdf4430b4aebb82d8b97d1-bb79570497308936.elb.us-east-1.amazonaws.com/target"

FLAG_NAME="enable-feature-stage-2"
MASTER_KEY="admin-secreto-123"

echo -n "Starting auth-service: "
curl -s "$AUTH_URL/health"
echo ""
echo -n "Starting evaluation-service: "
curl -s "$EVALUATION_URL/health"
echo ""
echo -n "Starting analytics-service: "
curl -s "$ANALYTICS_URL/health"
echo ""
echo -n "Starting flag-service: "
curl -s "$FLAG_URL/health"
echo ""
echo -n "Starting target-service: "
curl -s "$TARGET_URL/health"
echo ""

# echo "Creating API key"
# CREATE_RESPONSE=$(curl -X POST "$AUTH_URL/admin/keys" \
#   -H "Content-Type: application/json" \
#   -H "Authorization: Bearer $MASTER_KEY" \
#   -d '{"name": "evaluation-service-key"}')
# API_KEY=$(echo "$CREATE_RESPONSE" | jq -r '.key' 2>/dev/null)
# echo ""
# echo "$API_KEY"

SERVICE_API_KEY="tm_key_53ed2f650f6a5d2131e3d94b5cfeab31af3a1106f68493ca35d5440eb222d3ee"


echo ""
echo "VALIDATE SERVICE_API_KEY $SERVICE_API_KEY"
VALID_KEY=$(curl "$AUTH_URL/validate" \
  -H "Authorization: Bearer $SERVICE_API_KEY")
echo "$VALID_KEY"

echo ""
echo "CREATE Flag $FLAG_NAME"
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
echo "Create Rule for $FLAG_NAME"
TARGET=$(curl -sS -f -X POST "$TARGET_URL/rules" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "flag_name": "'"$FLAG_NAME"'",
    "is_enabled": true,
    "rules": {
        "type": "PERCENTAGE",
        "value": 75
    }
}')
echo "$TARGET" | jq .

echo "Evaluating flag for test users..."
read -n 1 -s -r -p "Change secret SERVICE_API_KEY then press enter..."
echo ""

# Test User 1
USER1="user-123"
RESULT1=$(curl -s "http://aae373c8b4cdf4430b4aebb82d8b97d1-bb79570497308936.elb.us-east-1.amazonaws.com/evaluation/evaluate?user_id=user-123&flag_name=$FLAG_NAME")
echo "User $USER1: $RESULT1"

# Test User 2
USER2="user-abc"
RESULT2=$(curl -s "http://aae373c8b4cdf4430b4aebb82d8b97d1-bb79570497308936.elb.us-east-1.amazonaws.com/evaluation/evaluate?user_id=$USER2&flag_name=$FLAG_NAME")
echo "User $USER2: $RESULT2"
echo ""
echo "Check SQS for evaluation events..."

echo "Running cache test (repeat evaluation for User 1)..."
CACHE_TEST=$(curl -s "http://aae373c8b4cdf4430b4aebb82d8b97d1-bb79570497308936.elb.us-east-1.amazonaws.com/evaluation/evaluate?user_id=$USER1&flag_name=$FLAG_NAME")
echo "Repeat evaluation User $USER1: $CACHE_TEST"

echo "Evaluation events should now be visible in your SQS queue."
