#!/usr/bin/env bash
# Destroy everything tagged Project=decidim-demo (plus its DNS + SES identity). Irreversible.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a
REGION="${AWS_DEFAULT_REGION:-af-south-1}"
NAME=decidim-demo
HOST="${DEMO_HOST:-participate.opencitieslab.africa}"
aws() { command aws --region "$REGION" "$@"; }

read -r -p "Type '$NAME' to destroy the demo (instance, data volume, EIP, SG, key, DNS, SES identity): " ok
[ "$ok" = "$NAME" ] || { echo "Aborted"; exit 1; }

for id in $(aws ec2 describe-instances --filters Name=tag:Project,Values=$NAME Name=instance-state-name,Values=pending,running,stopping,stopped \
              --query 'Reservations[].Instances[].InstanceId' --output text); do
  aws ec2 terminate-instances --instance-ids "$id" >/dev/null; aws ec2 wait instance-terminated --instance-ids "$id"; echo "Terminated $id"
done
for a in $(aws ec2 describe-addresses --filters Name=tag:Project,Values=$NAME --query 'Addresses[].AllocationId' --output text); do
  aws ec2 release-address --allocation-id "$a"; echo "Released $a"
done
for p in $(aws dlm get-lifecycle-policies --target-tags Project=$NAME --query 'Policies[].PolicyId' --output text 2>/dev/null); do
  aws dlm delete-lifecycle-policy --policy-id "$p"; echo "Deleted DLM $p"
done
SG_ID=$(aws ec2 describe-security-groups --filters Name=group-name,Values=$NAME-sg --query 'SecurityGroups[0].GroupId' --output text)
[ "$SG_ID" = "None" ] || { aws ec2 delete-security-group --group-id "$SG_ID"; echo "Deleted $SG_ID"; }
aws ec2 delete-key-pair --key-name $NAME >/dev/null 2>&1 && echo "Deleted key pair" || true
aws sesv2 delete-email-identity --email-identity "$HOST" >/dev/null 2>&1 && echo "Deleted SES identity" || true

CF=https://api.cloudflare.com/client/v4
ZONE_ID=$(curl -fsS -H "Authorization: Bearer $CF_TOKEN" "$CF/zones?name=opencitieslab.africa" | python -I -c "import sys,json;print(json.load(sys.stdin)['result'][0]['id'])")
for rid in $(curl -fsS -H "Authorization: Bearer $CF_TOKEN" "$CF/zones/$ZONE_ID/dns_records?per_page=100" \
  | python -I -c "import sys,json; h=sys.argv[1]; [print(r['id']) for r in json.load(sys.stdin)['result'] if r['name']==h or r['name'].endswith('.'+h)]" "$HOST"); do
  curl -fsS -X DELETE -H "Authorization: Bearer $CF_TOKEN" "$CF/zones/$ZONE_ID/dns_records/$rid" >/dev/null; echo "Deleted DNS $rid"
done
echo "Snapshots (if any) are kept — delete manually in the EC2 console when no longer needed."
