#!/usr/bin/env bash
# Provision the single demo host in af-south-1. Idempotent: finds resources by tag/name.
# Usage: deploy/provision.sh   (reads operator creds from ./.env; SSH_CIDR defaults to your current public IP/32)
set -euo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash on Windows: stop /dev/sda1 being rewritten to a Windows path
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a

REGION="${AWS_DEFAULT_REGION:-af-south-1}"
NAME=decidim-demo
TYPE="${INSTANCE_TYPE:-t3.medium}"
KEY_DIR="${KEY_DIR:-$HOME/.ssh}"
KEY_FILE="$KEY_DIR/$NAME.pem"
SSH_CIDR="${SSH_CIDR:-$(curl -fsS https://checkip.amazonaws.com | tr -d '[:space:]')/32}"
TAGS="Key=Project,Value=$NAME Key=Owner,Value=OCL Key=Environment,Value=demo"
aws() { command aws --region "$REGION" "$@"; }

# --- Network: default VPC + a public subnet ---
VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
[ "$VPC_ID" != "None" ] || { echo "No default VPC in $REGION" >&2; exit 1; }
SUBNET_ID=$(aws ec2 describe-subnets --filters Name=vpc-id,Values="$VPC_ID" Name=default-for-az,Values=true \
  --query 'Subnets[0].SubnetId' --output text)

# --- Security group ---
SG_ID=$(aws ec2 describe-security-groups --filters Name=group-name,Values="$NAME-sg" Name=vpc-id,Values="$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' --output text)
if [ "$SG_ID" = "None" ]; then
  SG_ID=$(aws ec2 create-security-group --group-name "$NAME-sg" --description "Decidim demo: web + restricted SSH" \
    --vpc-id "$VPC_ID" --tag-specifications "ResourceType=security-group,Tags=[{Key=Project,Value=$NAME},{Key=Owner,Value=OCL},{Key=Environment,Value=demo}]" \
    --query GroupId --output text)
  aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --ip-permissions \
    "IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0}],Ipv6Ranges=[{CidrIpv6=::/0}]" \
    "IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges=[{CidrIp=0.0.0.0/0}],Ipv6Ranges=[{CidrIpv6=::/0}]" >/dev/null
fi
# (Re)allow SSH from the operator's current IP only
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr "$SSH_CIDR" >/dev/null 2>&1 || true
echo "Security group: $SG_ID (SSH from $SSH_CIDR)"

# --- Key pair (private key kept outside the repo) ---
if ! aws ec2 describe-key-pairs --key-names "$NAME" >/dev/null 2>&1; then
  mkdir -p "$KEY_DIR"
  aws ec2 create-key-pair --key-name "$NAME" --key-type ed25519 \
    --tag-specifications "ResourceType=key-pair,Tags=[{Key=Project,Value=$NAME}]" \
    --query KeyMaterial --output text | tr -d '\r' > "$KEY_FILE"   # aws.exe on Windows emits CRLF
  chmod 600 "$KEY_FILE"
  echo "Saved private key to $KEY_FILE"
fi

# --- Instance ---
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters Name=tag:Project,Values="$NAME" Name=instance-state-name,Values=pending,running,stopping,stopped \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)
if [ "$INSTANCE_ID" = "None" ]; then
  INSTANCE_ID=$(aws ec2 run-instances \
    --image-id resolve:ssm:/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
    --instance-type "$TYPE" --key-name "$NAME" --subnet-id "$SUBNET_ID" --security-group-ids "$SG_ID" \
    --associate-public-ip-address \
    --metadata-options HttpTokens=required,HttpEndpoint=enabled \
    --block-device-mappings 'DeviceName=/dev/sda1,Ebs={VolumeSize=40,VolumeType=gp3,Encrypted=true,DeleteOnTermination=true}' \
    --user-data file://deploy/user-data.sh \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$NAME},{Key=Project,Value=$NAME},{Key=Owner,Value=OCL},{Key=Environment,Value=demo}]" \
                         "ResourceType=volume,Tags=[{Key=Name,Value=$NAME-root},{Key=Project,Value=$NAME},{Key=Owner,Value=OCL},{Key=Environment,Value=demo}]" \
    --query 'Instances[0].InstanceId' --output text)
  echo "Launched $INSTANCE_ID, waiting for running..."
  aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
fi
echo "Instance: $INSTANCE_ID"

# --- Elastic IP ---
ALLOC_ID=$(aws ec2 describe-addresses --filters Name=tag:Project,Values="$NAME" --query 'Addresses[0].AllocationId' --output text)
if [ "$ALLOC_ID" = "None" ]; then
  ALLOC_ID=$(aws ec2 allocate-address --domain vpc \
    --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=$NAME},{Key=Project,Value=$NAME},{Key=Owner,Value=OCL},{Key=Environment,Value=demo}]" \
    --query AllocationId --output text)
fi
aws ec2 associate-address --instance-id "$INSTANCE_ID" --allocation-id "$ALLOC_ID" >/dev/null
EIP=$(aws ec2 describe-addresses --allocation-ids "$ALLOC_ID" --query 'Addresses[0].PublicIp' --output text)
echo "Elastic IP: $EIP"

# --- Daily EBS snapshots via DLM (best effort; needs the DLM default role) ---
if ! aws dlm get-lifecycle-policies --target-tags "Project=$NAME" --query 'Policies[0].PolicyId' --output text 2>/dev/null | grep -q policy-; then
  ROLE_ARN=$(command aws iam get-role --role-name AWSDataLifecycleManagerDefaultRole --query Role.Arn --output text 2>/dev/null || true)
  if [ -z "$ROLE_ARN" ]; then
    command aws dlm create-default-role --region "$REGION" >/dev/null 2>&1 && \
      ROLE_ARN=$(command aws iam get-role --role-name AWSDataLifecycleManagerDefaultRole --query Role.Arn --output text 2>/dev/null || true)
  fi
  if [ -n "$ROLE_ARN" ]; then
    aws dlm create-lifecycle-policy --execution-role-arn "$ROLE_ARN" --state ENABLED \
      --description "$NAME daily snapshots, keep 7" \
      --tags Project=$NAME \
      --policy-details "{\"ResourceTypes\":[\"VOLUME\"],\"TargetTags\":[{\"Key\":\"Project\",\"Value\":\"$NAME\"}],\"Schedules\":[{\"Name\":\"daily\",\"CreateRule\":{\"Interval\":24,\"IntervalUnit\":\"HOURS\",\"Times\":[\"01:30\"]},\"RetainRule\":{\"Count\":7},\"CopyTags\":true}]}" >/dev/null \
      && echo "DLM snapshot policy created" || echo "WARN: could not create DLM policy — take manual snapshots (see README)"
  else
    echo "WARN: no DLM role and no permission to create it — take manual snapshots (see README)"
  fi
fi

echo
echo "SSH: ssh -i $KEY_FILE ubuntu@$EIP"
echo "$EIP" > deploy/.host-ip
