#!/bin/bash

# ==========================================
# FREE TIER EC2 DATABASE SETUP FOR TOGGLEMASTER
# ==========================================
# Creates EC2 instances with PostgreSQL and Redis
# Uses t2.micro instances (free tier eligible)

set -e

# Configuration
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="973397181776"
VPC_ID="vpc-02c93c9316dc039e5"
SECURITY_GROUP_ID="sg-038d6f7aa1d188f06"
SUBNET_ID="subnet-06af8ef5e40a9e596"  # us-east-1a subnet

# Database credentials
AUTH_DB_PASSWORD="ChangeMe123!auth"
FLAG_DB_PASSWORD="ChangeMe123!flag"
TARGET_DB_PASSWORD="ChangeMe123!target"

echo "==========================================="
echo "Free Tier EC2 Database Setup for ToggleMaster"
echo "==========================================="
echo ""

# Check credentials
echo "Checking AWS credentials..."
aws sts get-caller-identity --region $AWS_REGION > /dev/null || exit 1
echo "AWS credentials valid"
echo ""

# ==========================================
# STEP 1: CREATE EC2 INSTANCE WITH POSTGRESQL
# ==========================================
echo "Creating EC2 instance with PostgreSQL..."
echo ""

# User data script to install PostgreSQL
USER_DATA_POSTGRES=$(cat << 'EOF'
#!/bin/bash
yum update -y
amazon-linux-extras install postgresql14 -y
systemctl start postgresql
systemctl enable postgresql

# Create databases and users
sudo -u postgres psql -c "CREATE USER auth_user WITH PASSWORD '$AUTH_DB_PASSWORD';"
sudo -u postgres psql -c "CREATE DATABASE auth_db OWNER auth_user;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE auth_db TO auth_user;"

sudo -u postgres psql -c "CREATE USER flag_user WITH PASSWORD '$FLAG_DB_PASSWORD';"
sudo -u postgres psql -c "CREATE DATABASE flag_db OWNER flag_user;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE flag_db TO flag_user;"

sudo -u postgres psql -c "CREATE USER target_user WITH PASSWORD '$TARGET_DB_PASSWORD';"
sudo -u postgres psql -c "CREATE DATABASE target_db OWNER target_user;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE target_db TO target_user;"

# Configure PostgreSQL to listen on all interfaces
echo "listen_addresses = '*'" >> /var/lib/pgsql/data/postgresql.conf
echo "host all all 0.0.0.0/0 md5" >> /var/lib/pgsql/data/pg_hba.conf

systemctl restart postgresql
EOF
)

# Replace password variables in user data
USER_DATA_POSTGRES=$(echo "$USER_DATA_POSTGRES" | sed "s/\$AUTH_DB_PASSWORD/$AUTH_DB_PASSWORD/g")
USER_DATA_POSTGRES=$(echo "$USER_DATA_POSTGRES" | sed "s/\$FLAG_DB_PASSWORD/$FLAG_DB_PASSWORD/g")
USER_DATA_POSTGRES=$(echo "$USER_DATA_POSTGRES" | sed "s/\$TARGET_DB_PASSWORD/$TARGET_DB_PASSWORD/g")

aws ec2 run-instances \
    --image-id ami-0c02fb55956c7d316 \
    --count 1 \
    --instance-type t2.micro \
    --security-group-ids $SECURITY_GROUP_ID \
    --subnet-id $SUBNET_ID \
    --user-data "$USER_DATA_POSTGRES" \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=togglemaster-postgres}]' \
    --region $AWS_REGION \
    --query 'Instances[0].InstanceId' --output text

echo "PostgreSQL EC2 instance created"
echo ""

# ==========================================
# STEP 2: CREATE EC2 INSTANCE WITH REDIS
# ==========================================
echo "Creating EC2 instance with Redis..."
echo ""

USER_DATA_REDIS=$(cat << 'EOF'
#!/bin/bash
yum update -y
amazon-linux-extras install redis6 -y
systemctl start redis
systemctl enable redis

# Configure Redis to listen on all interfaces
sed -i 's/bind 127.0.0.1/bind 0.0.0.0/' /etc/redis/redis.conf
systemctl restart redis
EOF
)

aws ec2 run-instances \
    --image-id ami-0c02fb55956c7d316 \
    --count 1 \
    --instance-type t2.micro \
    --security-group-ids $SECURITY_GROUP_ID \
    --subnet-id $SUBNET_ID \
    --user-data "$USER_DATA_REDIS" \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=togglemaster-redis}]' \
    --region $AWS_REGION \
    --query 'Instances[0].InstanceId' --output text

echo "Redis EC2 instance created"
echo ""

echo "==========================================="
echo "Free Tier EC2 Setup Complete!"
echo "==========================================="
echo ""
echo "Next steps:"
echo "1. Get the public/private IPs of the EC2 instances"
echo "2. Update ConfigMap with the instance IPs"
echo "3. Test connectivity from EKS pods"
echo ""
echo "Get instance IPs:"
echo "  aws ec2 describe-instances --region $AWS_REGION --filters 'Name=tag:Name,Values=togglemaster-*' --query 'Reservations[*].Instances[*].[Tags[?Key==\`Name\`].Value|[0],PrivateIpAddress,PublicIpAddress]' --output table"
echo ""