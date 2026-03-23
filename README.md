# ToggleMaster - Feature Flag Management Service

A **cloud-native feature flag management system** built with microservices architecture, deployed on AWS EKS with event-driven autoscaling using KEDA.

## 📋 Project Overview

ToggleMaster is a distributed system for managing feature flags with:

- **5 Microservices**: Authentication, Flag Management, Targeting, Evaluation, Analytics
- **Event-Driven Architecture**: SQS queue for asynchronous event processing
- **Data Persistence**: PostgreSQL (RDS), Redis Cache, DynamoDB
- **Auto-Scaling**: KEDA-based scaling based on SQS queue depth
- **Load Balancing**: NGINX Ingress Controller with AWS ALB
- **Secure Access**: IRSA (IAM Roles for Service Accounts) via OIDC

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS Load Balancer (ALB)                   │
│        aae373c8b4cdf4430b4aebb82d8b97d1.elb.us-east-1    │
└──────────┬──────────────────────────────────────────────────┘
           │
┌──────────┴───────────────────────────────────────────────────┐
│                  NGINX Ingress Controller                     │
│              (Path-based routing to services)                 │
└──────────┬──────────────────────────────────────────────────┘
           │
    ┌──────┼──────┬──────────┬──────────┐
    │      │      │          │          │
    ▼      ▼      ▼          ▼          ▼
┌─────┐ ┌─────┐ ┌──────┐ ┌──────┐ ┌──────────┐
│Auth │ │Flag │ │Target│ │Eval  │ │Analytics │
│8001 │ │8002 │ │8003  │ │8004  │ │8005      │ <- Microservices
└──┬──┘ └──┬──┘ └──┬───┘ └───┬──┘ └─────┬────┘
   │       │       │          │          │
   ├───────┴───────┘          │          │
   │                           │          │
   ▼                           ▼          │
┌─────────────────┐    ┌──────────┐     │
│    RDS (3 DBs)  │    │  Redis   │     │
│  • auth_db      │    │  Cache   │     │
│  • flag_db      │    │  (30s)   │     │
│  • target_db    │    └──────────┘     │
└─────────────────┘                     │
                                        ▼
                        ┌──────────────────────┐
                        │      AWS SQS         │
                        │ evaluation-events    │
                        └──────────┬───────────┘
                                   │
                    ┌──────────────┘
                    │ (KEDA scales based on queue depth)
                    ▼
                ┌─────────────┐
                │  DynamoDB   │
                │  Analytics  │
                └─────────────┘
```

## 🚀 Quick Start

### **Option 1: Local Development (Docker Compose)**

```bash
# Prerequisites
docker --version           # Docker 20.10+
docker-compose --version   # Docker Compose 1.29+

# Start all services
docker-compose up -d

# Verify services are healthy
for service in auth flag target evaluation analytics; do
  curl -s http://localhost:800${i}/health | jq .
done

# Clean up
docker-compose down
```

### **Option 2: Kubernetes/EKS (Production)**

```bash
# Prerequisites
kubectl version --client    # kubectl 1.24+
aws --version              # AWS CLI v2

# Deploy to EKS cluster
kubectl apply -f infra/

# Verify deployments
kubectl get deployments -n togglemaster

# Port forward to access locally
kubectl port-forward svc/nginx-ingress-controller 8080:80 -n ingress-nginx
```

## 📍 API Endpoints

All endpoints are exposed via AWS Load Balancer at: `http://ALB_DNS/`

### Authentication Service (`/auth`)

```bash
# Health check
curl http://$ALB/auth/health

# Create API key (admin only)
curl -X POST http://$ALB/auth/admin/keys \
  -H "Authorization: Bearer admin-secreto-123" \
  -H "Content-Type: application/json" \
  -d '{"name": "my-key"}'

# Validate API key
curl http://$ALB/auth/validate \
  -H "Authorization: Bearer tm_key_..."
```

### Flag Service (`/flag`)

```bash
# Get flag
curl http://$ALB/flag/flags/my-flag-name \
  -H "Authorization: Bearer tm_key_..."

# Create flag
curl -X POST http://$ALB/flag/flags \
  -H "Authorization: Bearer tm_key_..." \
  -H "Content-Type: application/json" \
  -d '{
    "name": "feature-x",
    "description": "Enable feature X",
    "is_enabled": true
  }'
```

### Target Service (`/target`)

```bash
# Create targeting rule
curl -X POST http://$ALB/target/rules \
  -H "Authorization: Bearer tm_key_..." \
  -H "Content-Type: application/json" \
  -d '{
    "flag_name": "feature-x",
    "is_enabled": true,
    "rules": {
      "type": "PERCENTAGE",
      "value": 75
    }
  }'
```

### Evaluation Service (`/evaluation`)

```bash
# Evaluate flag for user
curl "http://$ALB/evaluation/evaluate?user_id=user-123&flag_name=feature-x"

# Returns: {"flag_name":"feature-x","user_id":"user-123","result":true}
```

### Analytics Service (`/analytics`)

```bash
# Health check
curl http://$ALB/analytics/health

# Get analytics summary
curl http://$ALB/analytics/summary
```

## 🔧 Configuration

### Environment Variables

All configurations are managed in `infra/configmap.yml`:

```yaml
# Service Ports
ANALYTICS_PORT: "8005"
AUTH_PORT: "8001"
EVALUATION_PORT: "8004"
FLAG_PORT: "8002"
TARGET_PORT: "8003"

# Database URLs
DATABASE_URL_AUTH: "postgresql://user@host/auth_db"
DATABASE_URL_FLAG: "postgresql://user@host/flag_db"
DATABASE_URL_TARGET: "postgresql://user@host/target_db"

# Cache & Queue
REDIS_URL: "redis://host:6379"
AWS_SQS_URL: "https://sqs.us-east-1.amazonaws.com/.../evaluation-events"
AWS_DYNAMODB_TABLE: "ToggleMasterAnalytics"
```

### Authentication

Sensitive credentials stored in Kubernetes Secrets:

```bash
# View secrets
kubectl get secrets -n togglemaster

# Update a secret
kubectl create secret generic my-secret --from-literal=key=value \
  --dry-run=client -o yaml | kubectl apply -f -
```

## 📊 Data Flow

### Flag Evaluation Flow

```
1. Client requests: GET /evaluation/evaluate?user_id=X&flag_name=Y

2. Evaluation Service:
   a. Checks Redis cache (30s TTL)
   b. If miss: queries Flag Service + Target Service
   c. Evaluates targeting rules (percentage, user attributes, etc)
   d. Returns result to client
   e. Sends async event to SQS

3. Analytics Service:
   a. Polls SQS queue for events
   b. Extracts user_id, flag_name, result
   c. Saves to DynamoDB for reporting

4. KEDA Auto-scaling:
   a. Monitors SQS queue depth
   b. Scales analytics-service pods (1-5 replicas)
   c. Scales down after cooldown period (5 min)
```

## 🔐 Security Features

### IRSA (IAM Roles for Service Accounts)

Services authenticate to AWS using Kubernetes ServiceAccounts + OIDC:

```bash
# No credentials needed in pods!
# IRSA injects temporary credentials via:
# - AWS_ROLE_ARN environment variable
# - AWS_WEB_IDENTITY_TOKEN_FILE (JWT token)
# - AWS STS validates token via OIDC provider
```

- **evaluation-service**: SQS access via role `evaluation-service-role`
- **analytics-service**: SQS + DynamoDB access via KEDA role
- **ingress-controller**: ALB management via NGINX role

### API Key Generation

```bash
# Create key via auth service
curl -X POST http://localhost:8001/admin/keys \
  -H "Authorization: Bearer admin-secreto-123" \
  -d '{"name": "service-key"}'

# Response: {"key": "tm_key_<64_hex_chars>"}

# Use in requests
curl http://localhost:8002/flags/my-flag \
  -H "Authorization: Bearer tm_key_..."
```

## 📈 Auto-Scaling with KEDA

KEDA monitors SQS queue depth and auto-scales analytics-service:

```yaml
# ScaledObject configuration
minReplicaCount: 1      # Keep 1 pod minimum
maxReplicaCount: 5      # Max 5 pods
queueLength: 5          # 1 pod per 5 messages
pollingInterval: 10     # Check queue every 10s
cooldownPeriod: 300     # Wait 5min before scaling down
```

**Example:**
- Queue empty: 0 pods (after cooldown)
- 5 messages: 1 pod
- 25 messages: 5 pods (maximum)

## 🧪 Testing

### Test Script

```bash
# Run complete flow test
./test/requests.sh

# Send manual SQS messages
./test/send-sqs-messages.sh

# Test KEDA autoscaling
./test/keda-scale-test.sh
```

### Load Testing

```bash
# Send 1000 concurrent evaluation requests
hey -n 1000 -c 50 "http://$ALB/evaluation/evaluate?user_id=user-123&flag_name=test-flag"
```

### Check Logs

```bash
# Stream service logs
kubectl logs deployment/analytics-service -n togglemaster -f

# View KEDA decisions
kubectl describe hpa keda-hpa-analytics-service-sqs-scaler -n togglemaster

# Monitor scaling events
kubectl get events -n togglemaster --sort-by='.lastTimestamp'
```

## 📚 Key Technologies

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Services | Go, Python | Business logic |
| Container Orchestration | Kubernetes/EKS | Pod management |
| Auto-scaling | KEDA | Event-driven scaling |
| Load Balancer | NGINX Ingress + ALB | External access |
| Data Storage | PostgreSQL, Redis, DynamoDB | State management |
| Message Queue | SQS | Async event processing |
| Authentication | OIDC + IRSA | Secure AWS access |
| Local Development | Docker Compose | Test environment |

## 🐛 Troubleshooting

### Issue: Analytics service not processing messages

```bash
# Check if pods are running
kubectl get pods -n togglemaster -l app=analytics-service

# Check SQS queue depth
aws sqs get-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/.../evaluation-events \
  --attribute-names ApproximateNumberOfMessages

# Check pod logs for errors
kubectl logs deployment/analytics-service -n togglemaster | grep ERROR
```

### Issue: Services can't reach database

```bash
# Verify ConfigMap is applied
kubectl get configmap togglemaster-config -n togglemaster

# Check pod environment
kubectl exec -it <pod-name> -n togglemaster -- env | grep DATABASE

# Test database connectivity
kubectl exec -it <pod-name> -n togglemaster -- psql $DATABASE_URL
```

### Issue: KEDA not scaling

```bash
# Check ScaledObject status
kubectl get scaledobject -n togglemaster

# Check HPA metrics
kubectl describe hpa keda-hpa-analytics-service-sqs-scaler -n togglemaster

# Check KEDA operator logs
kubectl logs -n keda deployment/keda-operator
```

## 📖 Documentation

- [IRSA & OIDC Setup](./IRSA_OIDC_SETUP.md) - Detailed IRSA configuration
- [Kubernetes Deployment Guide](./infra/README.md) - Infrastructure details
- [Architecture Overview](./PRESENTATION.md) - Full presentation

## 🤝 Contributing

1. Build locally with Docker Compose
2. Test with provided scripts
3. Deploy to EKS for production testing
4. Monitor with logs and HPA metrics

## 📝 License

Project for FIAP Stage 2
