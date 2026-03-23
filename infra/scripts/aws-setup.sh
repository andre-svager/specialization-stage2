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
# VALIDATE AWS
# ==========================================
aws sts get-caller-identity --region $AWS_REGION >/dev/null
echo "AWS OK"

# ==========================================
# ENSURE DB SUBNET GROUP
# ==========================================
if ! aws rds describe-db-subnet-groups \
  --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
  --region $AWS_REGION >/dev/null 2>&1; then

  aws rds create-db-subnet-group \
    --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
    --db-subnet-group-description "ToggleMaster RDS subnet group" \
    --subnet-ids "${SUBNET_IDS[@]}" \
    --region $AWS_REGION
fi

# ==========================================
# ENSURE CACHE SUBNET GROUP
# ==========================================
if ! aws elasticache describe-cache-subnet-groups \
  --cache-subnet-group-name "$CACHE_SUBNET_GROUP_NAME" \
  --region $AWS_REGION >/dev/null 2>&1; then

  aws elasticache create-cache-subnet-group \
    --cache-subnet-group-name "$CACHE_SUBNET_GROUP_NAME" \
    --cache-subnet-group-description "ToggleMaster Redis subnet group" \
    --subnet-ids "${SUBNET_IDS[@]}" \
    --region $AWS_REGION
fi

# ==========================================
# CREATE RDS (SINGLE)
# ==========================================
if ! aws rds describe-db-instances \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --region $AWS_REGION >/dev/null 2>&1; then

  echo "Creating RDS..."

  aws rds create-db-instance \
    --db-instance-identifier "$DB_INSTANCE_ID" \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --master-username "$MASTER_USER" \
    --master-user-password "$MASTER_PASSWORD" \
    --allocated-storage 20 \
    --db-name "postgres" \
    --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
    --vpc-security-group-ids "$DB_SECURITY_GROUP_ID" \
    --no-publicly-accessible \
    --backup-retention-period 0 \
    --region $AWS_REGION

else
  echo "RDS already exists"
fi

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



# ==========================================
# CREATE REDIS (SIMPLE)
# ==========================================
if ! aws elasticache describe-cache-clusters \
  --cache-cluster-id tm-redis \
  --region $AWS_REGION >/dev/null 2>&1; then

  echo "Creating Redis..."

  aws elasticache create-cache-cluster \
    --cache-cluster-id tm-redis \
    --engine redis \
    --cache-node-type cache.t3.micro \
    --num-cache-nodes 1 \
    --cache-subnet-group-name "$CACHE_SUBNET_GROUP_NAME" \
    --security-group-ids "$DB_SECURITY_GROUP_ID" \
    --region $AWS_REGION

else
  echo "Redis already exists"
fi

# ==========================================
# OUTPUT
# ==========================================
echo ""
echo "==========================================="
echo "INFO"
echo "==========================================="

echo "Check RDS status:"
echo "aws rds describe-db-instances --region $AWS_REGION"

echo ""
echo "When ready, run this to create databases:"
echo ""
echo "export PGPASSWORD=$MASTER_PASSWORD"
echo "psql -h <RDS-ENDPOINT> -U $MASTER_USER -d postgres"
echo ""
echo "CREATE DATABASE auth_db;"
echo "CREATE DATABASE flag_db;"
echo "CREATE DATABASE target_db;"

echo ""
echo "Connection strings (same host):"
echo "auth_db:   postgres://$MASTER_USER:$MASTER_PASSWORD@<ENDPOINT>:5432/auth_db"
echo "flag_db:   postgres://$MASTER_USER:$MASTER_PASSWORD@<ENDPOINT>:5432/flag_db"
echo "target_db: postgres://$MASTER_USER:$MASTER_PASSWORD@<ENDPOINT>:5432/target_db"

echo ""
echo "DONE"