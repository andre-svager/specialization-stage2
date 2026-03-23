#!/bin/bash

AUTH_URL="http://localhost:8001"
FLAG_URL="http://localhost:8002"
TARGET_URL="http://localhost:8003"
EVAL_URL="http://localhost:8004"
ANALYTICS_URL="http://localhost:8005"
MASTER_KEY="admin-secreto-123"

FLAG_NAME="enable-feature-evaluation-12"

# -----------------------------
# EVALUATION SERVICE
# -----------------------------
echo""
echo -n "Starting analytics-service:"
curl -sS -f "$ANALYTICS_URL/health" 

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
