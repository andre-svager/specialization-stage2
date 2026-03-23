1. Deploy Infrastructure to Kubernetes:
### Create namespace, secrets, configmap
kubectl apply -f infra/namespace.yml
kubectl apply -f infra/secret.yml
kubectl apply -f infra/configmap.yml

### Deploy all services
kubectl apply -f infra/*/deployment.yml
kubectl apply -f infra/*/service.yml

2. Verify Deployment:
### Check pods status
kubectl get pods -n togglemaster

### Check services
kubectl get svc -n togglemaster

### Check specific service
kubectl describe pod -n togglemaster <pod-name>

### 3. Check Logs:
#### View service logs
kubectl logs -n togglemaster <pod-name>

### Follow logs in real-time
> kubectl logs -n togglemaster <pod-name> -f

## 4. Test Connectivity:
### Port forward to test locally
kubectl port-forward -n togglemaster svc/auth-service 8001:8001

# Ver pods escalando
watch "kubectl get pods -n togglemaster -l app=analytics-service"

# Ver HPA status
kubectl get hpa -n togglemaster

# Ver ScaleObject
kubectl get scaledobjects -n togglemaster

# Ver fila SQS
aws sqs get-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/973397181776/evaluation-events \
  --attribute-names ApproximateNumberOfMessages \
  --region us-east-1


Your current IAM principal doesn't have access to Kubernetes objects on this cluster.
This might be due to the current principal not having an IAM access entry with permissions to access the cluster.

create access entry

Your current IAM principal doesn’t have access to Kubernetes objects on this cluster.
This may be due to the current user or role not having Kubernetes RBAC permissions to describe cluster resources or not having an entry in the cluster’s auth config map.Learn more 


# Problem

I see the problem! Your pods still can't be scheduled even with 3 nodes because:

"0/3 nodes are available: 3 Insufficient memory, 3 Too many pods"

This means:

✅ You have 3 nodes now (good progress!)
❌ But ALL 3 nodes are out of memory
❌ And all 3 nodes are too full (too many pods already running)

Considered options for restarting a scaled-down pod
Start a Pod Again (3 Options):
Option 1: Scale Back to 1 Replica (EASIEST)
If you scaled deployments to 0, just scale them back:

### update nodegroup

aws eks update-nodegroup-config --cluster-name tm --nodegroup-name ng-1 --scaling-config minSize=2,maxSize=5,desiredSize=4 --region us-east-1


# Scale to more nodes (up to max of 5)
aws eks update-nodegroup-config --cluster-name tm --nodegroup-name ng-1 --scaling-config minSize=2,maxSize=5,desiredSize=4 --region us-east-1

# Or change to larger instances (recommended for your case)
# First, create a NEW nodegroup with t3.small instances
aws eks create-nodegroup \
  --cluster-name tm \
  --nodegroup-name ng-2 \
  --scaling-config minSize=2,maxSize=5,desiredSize=3 \
  --instance-types t3.small \
  --subnets subnet-0b168d46a8d9ccfbd subnet-094046a6952c775a2 \
  --node-role arn:aws:iam::973397181776:role/eksctl-tm-nodegroup-ng-1-NodeInstanceRole-nn6xohMHt4It \
  --region us-east-1

# Then drain and delete the old nodegroup
kubectl drain --all --force --grace-period=0 --ignore-daemonsets -l alpha.eksctl.io/nodegroup-name=ng-1

aws eks delete-nodegroup --cluster-name tm --nodegroup-name ng-1 --region us-east-1


inbound rule para security group

The security group rule should allow it now, but the error persists. Let me check the pod's network configuration:

The pods are on subnet 192.168.29.x but Redis is on 192.168.9.x. This might be a subnet routing issue. Also, let me add port 5432 for PostgreSQL while we're fixing network issues:


Conta free tier, so pode crair 2 rds


aws: [ERROR]: An error occurred (InstanceQuotaExceeded) when calling the CreateDBInstance operation: You reached the maximum number of instances available with free plan accounts. To remove all limitations, upgrade your account plan.

Additional error details:



# Scale all deployments back to 1 replicakubectl scale deployment --all --replicas=1 -n togglemaster# Verify pods are startingkubectl get pods -n togglemaster# Watch them come upkubectl get pods -n togglemaster -w
✅ This is the fastest way - no need to reapply anything!

Option 2: Apply Deployment (If Deployment Was Deleted)
If you deleted deployments entirely, reapply:


# Reapply all deploymentskubectl apply -f infra/*/deployment.yml# Verifykubectl get pods -n togglemaster
Option 3: Edit Replicas Directly

# Edit a specific deploymentkubectl edit deployment auth-service -n togglemaster# Find "replicas: 0" and change to "replicas: 1"# Save and exit (Ctrl+X in vi/nano)# Verifykubectl get pods -n togglemaster

## Quick Summary

###  Scaled to 0 (pods paused)
kubectl scale deployment --all --replicas=1 -n togglemaster

 ### Deleted deployments	

 kubectl apply -f infra/*/deployment.yml

 ### Want to check status /
	kubectl get pods -n togglemaster -w

### Start all pods
kubectl scale deployment --all --replicas=1 -n togglemaster

### Watch them start
kubectl get pods -n togglemaster -w

### Check logs if they fail
kubectl logs -f <pod-name> -n togglemaster


# Scale all deployments to 0 replicas
kubectl scale deployment --all --replicas=0 -n togglemaster

# Verify pods are gone
kubectl get pods -n togglemaster

# Delete all deployments
kubectl delete deployment --all -n togglemaster

# Verify
kubectl get pods -n togglemaster

### Restar pod after change
kubectl apply -f deployment.yml
kubectl rollout restart deployment auth-service -n togglemaster

### Listar todos PODs
 kubectl get pods -A


🧱 PARTE 1 — Remover AWS keys e usar IRSA
🎯 O que é IRSA?

IRSA = IAM Roles for Service Accounts

👉 Em vez de usar:

AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY

👉 você deixa o próprio Kubernetes assumir uma role IAM automaticamente.


## Policy
✅ Passo 1 — Criar IAM Policy

Crie uma policy com acesso ao que você usa:

{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ],
      "Resource": "arn:aws:sqs:us-east-1:973397181776:evaluation-events"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:GetItem"
      ],
      "Resource": "arn:aws:dynamodb:us-east-1:973397181776:table/ToggleMasterAnalytics"
    }
  ]
}
✅ Passo 2 — Criar ServiceAccount com IRSA
apiVersion: v1
kind: ServiceAccount
metadata:
  name: evaluation-service-sa
  namespace: togglemaster
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::973397181776:role/tm-evaluation-role
✅ Passo 3 — Usar no Deployment
spec:
  serviceAccountName: evaluation-service-sa
🔥 Resultado

👉 Seu código Go/Python continua igual:

boto3.client("sqs")

👉 E funciona sem credenciais




Resumo: Removido Hardcoded AWS Credentials
O que foi feito:
Removido do secret:

❌ AWS_ACCESS_KEY_ID: "AKIA6FIX6IVIMGYDGELO"
❌ AWS_SECRET_ACCESS_KEY: "..."
Criado IAM setup com IRSA:

✅ IAM Policy: AnalyticsServicePolicy (SQS + DynamoDB)
✅ IAM Role: AnalyticsServiceRole (com OIDC trust policy)
✅ Kubernetes ServiceAccount: analytics-service
✅ IRSA annotation que liga SA → Role
Resultado nos logs:


✓ Clientes Boto3 inicializados na região us-east-1✓ Iniciando o worker SQS...
Como funciona agora:

Pod analytics-service (+ ServiceAccount: analytics-service com IRSA annotation)         ↓    OIDC Provider no EKS         ↓    Assume Role: AnalyticsServiceRole         ↓    Credenciais AWS temporárias injectadas         ↓    Pod pode acessar SQS + DynamoDB
Segurança:
✅ Antes: Credenciais plaintext em Secret (risco de exposição)
✅ Depois: Credenciais temporárias via OIDC (expira automaticamente)

Vantagens:
✅ Sem credenciais hardcoded
✅ Credenciais auto-renovam a cada 1h
✅ Rastreamento de auditoria (quem acessou o quê)
✅ Revogação fácil (delete SA ou desativar role)
Seu secret agora só contém dados não-sensíveis: URLs, chaves de serviço públicas, etc.