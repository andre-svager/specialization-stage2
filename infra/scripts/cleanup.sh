#!/usr/bin/env bash

set -e

echo "Cleaning AWS resources..."

QUEUE_URL=$(aws sqs get-queue-url \
  --queue-name evaluation-events \
  --query QueueUrl \
  --output text)

aws sqs delete-queue \
  --queue-url $QUEUE_URL \
  || echo "Queue already deleted"

aws dynamodb delete-table \g
  --table-name analytics-events \
  || echo "Table already deleted"

aws ecr list-images \
    --repository-name <NOME_DO_REPO> \
    --region us-east-1  

aws ecr batch-delete-image \
    --repository-name <NOME_DO_REPO> \
    --image-ids imageTag=<TAG_DA_IMAGEM> \
    --region us-east-1   

# DELETA todas imagens
aws ecr list-images \
    --repository-name <NOME_DO_REPO> \
    --region us-east-1 \
    --query 'imageIds[*]' \
    --output json \
| xargs -I {} aws ecr batch-delete-image \
    --repository-name <NOME_DO_REPO> \
    --image-ids {}     

eksctl delete cluster \
  --name togglemaster \
  --region us-east-1

#Depois de deletar, você pode verificar se ainda existem recursos órfãos:
#VPCs:
aws ec2 describe-vpcs --region us-east-1
#Subnets:
aws ec2 describe-subnets --region us-east-1
#Security Groups:
aws ec2 describe-security-groups --region us-east-1
#IAM Roles:
aws iam list-roles | grep togglemaster

echo "Cleanup complete"