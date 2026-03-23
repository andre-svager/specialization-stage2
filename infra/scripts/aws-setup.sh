#!/bin/bash


AWS_REGION="us-east-1"
DB_SECURITY_GROUP_ID="sg-07e70c2c90038cd76"

DB_SUBNET_GROUP_NAME="tm-db-subnet"
CACHE_SUBNET_GROUP_NAME="tm-cache-subnet"

SUBNET_IDS=("subnet-094046a6952c775a2" "subnet-0b168d46a8d9ccfbd")

DB_INSTANCE_ID="tm-db"
MASTER_USER="postgres"
MASTER_PASSWORD="ChangeMe123"

echo "==========================================="
echo "AWS Setup - ToggleMaster (1 RDS + 3 DBs)"
echo "==========================================="

# ==========================================
# TRY TO CREATE DATABASES (WILL ONLY WORK WHEN READY)
# ==========================================
echo "Attempting to create logical databases..."

DB_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --region $AWS_REGION \
  --query "DBInstances[0].Endpoint.Address" \
  --output text 2>/dev/null || echo "")

if [[ -n "$DB_ENDPOINT" ]]; then
  export PGPASSWORD=$MASTER_PASSWORD

  psql -h "$DB_ENDPOINT" \
       -U "$MASTER_USER" \
       -d postgres <<EOF || true
CREATE DATABASE auth_db;
CREATE DATABASE flag_db;
CREATE DATABASE target_db;
EOF

  echo "Database creation attempted"
else
  echo "RDS not ready yet → skip DB creation"
fi

