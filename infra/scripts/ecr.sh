# # First create repositories:

# AWS_ACCOUNT_ID=973397181776 

# aws ecr create-repository --repository-name auth-service --region us-east-1
# aws ecr create-repository --repository-name flag-service --region us-east-1
# aws ecr create-repository --repository-name target-service --region us-east-1
# aws ecr create-repository --repository-name evaluation-service --region us-east-1
# aws ecr create-repository --repository-name analytics-service --region us-east-1

# # Login
# aws ecr get-login-password \
# --region us-east-1 \
# | docker login \
# --username AWS \
# --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# # Tag images
# docker tag stage2-flag-service \
# $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/flag-service:latest

# docker tag stage2-target-service \
# $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/target-service:latest

# docker tag stage2-evaluation-service \
# $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/evaluation-service:latest

# docker tag stage2-analytics-service \
# $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/analytics-service:latest

# # Push
# docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/flag-service:latest
# docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/target-service:latest
# docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/evaluation-service:latest
# docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/analytics-service:latest

# Create cluster using:  eksctl (easiest)
# This creates: EKS cluster - VPC - worker nodes - security groups - IAM roles

#which eksctl
#aws sts get-caller-identity
 eksctl create cluster \
 --name tm \
 --region us-east-1