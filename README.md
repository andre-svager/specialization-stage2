Problemas encontrados

health check unhealth mesmo estando o serviço health devido ausencia do curl nas imagens apline
Aulas de kubernetes não ajudaram no projeto, precisei fazer um curso e ler outros materiais a parte
Gap nas aulas sobre interação docker - docker compose e kubernetes

Integrating a remote sqs

Configure Kubernetes cluster local

    Configure kubeconfig for your EKS cluster
    Run this command to update your kubeconfig:

aws eks update-kubeconfig \
  --region us-east-1 \
  --name your-cluster-name

  This will update ~/.kube/config with your EKS cluster credentials.

Verify the connection
    Check that your cluster appears in the kubeconfig:

    kubectl cluster-info
    kubectl get nodes

    > Kubernetes control plane is running at https://2A4A51EE929D12D62F3352C3D24E73E9.gr7.us-east-1.eks.amazonaws.com
CoreDNS is running at https://2A4A51EE929D12D62F3352C3D24E73E9.gr7.us-east-1.eks.amazonaws.com/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy


> Set default context

If you have multiple clusters, set your EKS cluster as default:
kubectl config use-context your-context-name

To list available contexts:
kubectl config get-contexts





I found several critical misconfigurations in your AWS deployment setup. Here's my analysis:

🔴 Critical Issues:
1. Docker Images - NOT pointing to AWS ECR
All deployments use togglemaster/xxx:latest but should use AWS ECR:

#image: 973397181776.dkr.ecr.us-east-1.amazonaws.com/#auth-service:latest


image: 973397181776.dkr.ecr.us-east-1.amazonaws.com/auth-service:latest
2. Missing Database Services
Your configmap.yml references databases (auth-db, flag-db, target-db) but no Kubernetes deployments exist for them. You need to:

Either deploy PostgreSQL in Kubernetes
Or use AWS RDS and update the connection strings

3. Secrets Hardcoded with "test" Values

AWS_ACCESS_KEY_ID: "test"         # ❌ WRONGAWS_SECRET_ACCESS_KEY: "test"     # ❌ WRONG
Should use AWS IAM roles for EKS pods (IRSA - IAM Roles for Service Accounts)

4. Missing Image Pull Secrets
No imagePullSecrets defined for ECR authentication.

5. No Health Checks or Resource Limits
Deployments lack:

livenessProbe / readinessProbe
resources.requests / resources.limits
6. Database Endpoints Assume Local Stack
ConfigMap references local database URLs that won't work in AWS:

auth-db:5432 → Should be AWS RDS endpoint
evaluation-db:6379 → No Redis deployment exists
7. Missing Service Accounts for IAM Roles
No serviceAccount defined for AWS service access (SQS, DynamoDB)

✅ How to Fix:
Would you like me to update your files to:

Use ECR images with proper AWS account references
Set up RDS or StatefulSet PostgreSQL deployments
Configure IRSA (IAM Roles for Service Accounts) instead of hardcoded credentials
Add health checks, resource limits, and proper service accounts
Create an ImagePullSecret for ECR
Which would you prefer - RDS databases or Kubernetes-managed databases?

## After pull ECR to AWS

### Create namespace
> kubectl apply -f infra/namespace.yml

### Create secrets and config
> kubectl apply -f infra/secret.yml
kubectl apply -f infra/configmap.yml

### Deploy services
> kubectl apply -f infra/auth-service/deployment.yml
kubectl apply -f infra/auth-service/service.yml
##### ... repeat for other services

### Getting AWS ECR repository

aws ecr describe-repositories --region us-east-1 --output table

 > arn:aws:ecr:us-east-1:973397181776:repository/evaluation-service

 > aws ecr describe-repositories --region us-east-1 --query 'repositories[].{Name:repositoryName,URI:repositoryUri}' --output table


statefullsets to rds on ec2 kubernetes 

{
    "clusters": [
        "togglemaster"
    ]
}

### List AWS Clusters
 aws eks list-clusters --region us-east-1

### Get Cluster VPC
aws eks describe-cluster --name togglemaster --region us-east-1 \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text

Now let me create the AWS managed databases. First, I need to set up a security group that allows EKS pods to reach RDS and ElastiCache:  

aws ec2 describe-security-groups --filters "Name=vpc-id,Values=vpc-02c93c9316dc039e5" --region us-east-1 --query 'SecurityGroups[*].[GroupId,GroupName]' --output table

Execute aws-setup

aws rds describe-db-instances --region us-east-1 --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,Endpoint.Address]' --output table

#### Due free tier AWS, its necessary Create a Single RDS instead 3 Replicas

> RDS (tm-db)\
 ├── auth_db\
 ├── flag_db\
 └── target_db