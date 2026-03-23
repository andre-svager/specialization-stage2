#!/bin/bash

# Internet
#    ↓
# Load Balancer (AWS)
#    ↓
# Ingress (NGINX)
#    ↓
# Service (ClusterIP)
#    ↓
# Pods

AUTH_URL="http://aae373c8b4cdf4430b4aebb82d8b97d1-bb79570497308936.elb.us-east-1.amazonaws.com/auth"
EVALUATION_URL="http://aae373c8b4cdf4430b4aebb82d8b97d1-bb79570497308936.elb.us-east-1.amazonaws.com/evaluation"
ANALYTICS_URL="http://aae373c8b4cdf4430b4aebb82d8b97d1-bb79570497308936.elb.us-east-1.amazonaws.com/analytics"
FLAG_URL="http://aae373c8b4cdf4430b4aebb82d8b97d1-bb79570497308936.elb.us-east-1.amazonaws.com/flag"
TARGET_URL="http://aae373c8b4cdf4430b4aebb82d8b97d1-bb79570497308936.elb.us-east-1.amazonaws.com/target"

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