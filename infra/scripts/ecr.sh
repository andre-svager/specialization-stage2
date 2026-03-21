# First create repositories:
aws ecr create-repository --repository-name auth-service
aws ecr create-repository --repository-name flag-service
aws ecr create-repository --repository-name target-service
aws ecr create-repository --repository-name evaluation-service
aws ecr create-repository --repository-name analytics-service

# Login
aws ecr get-login-password \
--region us-east-1 \
| docker login \
--username AWS \
--password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

# Tag images
docker tag stage2-auth-service \
<AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/auth-service:latest

# Push
docker push <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/auth-service:latest

# Create cluster using:  eksctl (easiest)
# This creates: EKS cluster - VPC - worker nodes - security groups - IAM roles

eksctl create cluster \
--name togglemaster \
--region us-east-1