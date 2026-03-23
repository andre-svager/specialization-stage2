#!/bin/bash

set -e

# ==========================================
# CONFIG
# ==========================================
CLUSTER_NAME="tm"
REGION="us-east-1"
ACCOUNT_ID="973397181776"

NODE_TYPE="t3.micro"
NODES=2

SQS_URL="https://sqs.us-east-1.amazonaws.com/973397181776/evaluation-events"
DYNAMO_TABLE="ToggleMasterAnalytics"

echo "Checking AWS credentials..."
aws sts get-caller-identity --region $REGION > /dev/null
echo "AWS OK"
echo ""

# ==========================================
# CLEANUP (IDEMPOTENTE)
# ==========================================
echo "Cleaning previous cluster if exists..."

eksctl delete cluster --name $CLUSTER_NAME --region $REGION || true

aws cloudformation delete-stack \
  --stack-name eksctl-$CLUSTER_NAME-cluster \
  --region $REGION 2>/dev/null || true

sleep 10

# ==========================================
# CREATE CLUSTER WITH OIDC
# ==========================================
echo "Creating EKS cluster with OIDC..."

cat <<EOF > cluster.yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: $CLUSTER_NAME
  region: $REGION

iam:
  withOIDC: true

managedNodeGroups:
  - name: ng-1
    instanceType: $NODE_TYPE
    desiredCapacity: $NODES
    minSize: 1
    maxSize: 2
EOF

eksctl create cluster -f cluster.yaml

echo "Cluster ready"
echo ""

# ==========================================
# ENSURE OIDC
# ==========================================
eksctl utils associate-iam-oidc-provider \
  --region $REGION \
  --cluster $CLUSTER_NAME \
  --approve

# ==========================================
# IAM POLICY FOR LOAD BALANCER
# ==========================================
echo "Creating IAM policy for Load Balancer..."

curl -o iam_policy.json \
https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json \
  2>/dev/null || echo "Policy exists"

# ==========================================
# IRSA FOR LOAD BALANCER CONTROLLER
# ==========================================
echo "Creating IRSA for LB controller..."

eksctl create iamserviceaccount \
  --cluster $CLUSTER_NAME \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve \
  --override-existing-serviceaccounts

# ==========================================
# INSTALL CONTROLLER (SEM HELM)
# ==========================================
echo "Installing AWS Load Balancer Controller (YAML)..."

kubectl apply -k \
"github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"

curl -Lo alb-controller.yaml \
https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/latest/download/v2_6_0_full.yaml

kubectl apply -f alb-controller.yaml

# Set cluster name env
kubectl -n kube-system set env deployment/aws-load-balancer-controller \
  CLUSTER_NAME=$CLUSTER_NAME

# ==========================================
# IRSA FOR APP (SQS + DYNAMODB)
# ==========================================
echo "Creating IAM policy for app..."

cat <<EOF > app-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ],
      "Resource": "arn:aws:sqs:$REGION:$ACCOUNT_ID:evaluation-events"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Resource": "arn:aws:dynamodb:$REGION:$ACCOUNT_ID:table/$DYNAMO_TABLE"
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name ToggleMasterAppPolicy \
  --policy-document file://app-policy.json \
  2>/dev/null || echo "Policy exists"

echo "Creating IRSA for app..."

eksctl create iamserviceaccount \
  --cluster $CLUSTER_NAME \
  --namespace default \
  --name tm-app \
  --attach-policy-arn arn:aws:iam::$ACCOUNT_ID:policy/ToggleMasterAppPolicy \
  --approve \
  --override-existing-serviceaccounts

# ==========================================
# VERIFY
# ==========================================
echo ""
echo "Checking system pods..."

kubectl get pods -n kube-system

echo ""
echo "========================================="
echo "CLUSTER READY (tm)"
echo "========================================="

echo ""
echo "Use in your deployments:"
echo "serviceAccountName: tm-app"

echo ""
echo "SQS:"
echo "$SQS_URL"

echo ""
echo "DynamoDB:"
echo "$DYNAMO_TABLE"