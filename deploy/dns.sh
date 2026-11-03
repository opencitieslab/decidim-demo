#!/usr/bin/env bash
# Cloudflare DNS for the demo host + Amazon SES domain identity (Easy DKIM). Idempotent.
# Usage: deploy/dns.sh   (needs deploy/.host-ip from provision.sh)
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a

REGION="${AWS_DEFAULT_REGION:-af-south-1}"
ZONE_NAME=opencitieslab.africa
HOST="${DEMO_HOST:-participate.opencitieslab.africa}"
EIP=$(cat deploy/.host-ip)
CF=https://api.cloudflare.com/client/v4

cf() { curl -fsS -H "Authorization: Bearer $CF_TOKEN" -H "Content-Type: application/json" "$@"; }
json() { python -I -c "import sys,json; d=json.load(sys.stdin); print($1)"; }

ZONE_ID=$(cf "$CF/zones?name=$ZONE_NAME" | json "d['result'][0]['id']")

# upsert TYPE NAME CONTENT
upsert() {
  local type=$1 name=$2 content=$3 id
  id=$(cf "$CF/zones/$ZONE_ID/dns_records?type=$type&name=$name" | json "d['result'][0]['id'] if d['result'] else ''")
  local body
  body=$(python -I -c "import json,sys; print(json.dumps({'type':sys.argv[1],'name':sys.argv[2],'content':sys.argv[3],'ttl':300,'proxied':False}))" "$type" "$name" "$content")
  if [ -n "$id" ]; then
    cf -X PUT "$CF/zones/$ZONE_ID/dns_records/$id" --data "$body" >/dev/null
  else
    cf -X POST "$CF/zones/$ZONE_ID/dns_records" --data "$body" >/dev/null
  fi
  echo "DNS $type $name -> $content"
}

# Web
upsert A "$HOST" "$EIP"

# SES identity with Easy DKIM
if ! aws sesv2 get-email-identity --region "$REGION" --email-identity "$HOST" >/dev/null 2>&1; then
  aws sesv2 create-email-identity --region "$REGION" --email-identity "$HOST" \
    --tags Key=Project,Value=decidim-demo >/dev/null
fi
for token in $(aws sesv2 get-email-identity --region "$REGION" --email-identity "$HOST" \
                 --query 'DkimAttributes.Tokens' --output text); do
  upsert CNAME "${token}._domainkey.$HOST" "${token}.dkim.amazonses.com"
done
upsert TXT "$HOST" "v=spf1 include:amazonses.com ~all"
upsert TXT "_dmarc.$HOST" "v=DMARC1; p=none;"

echo
aws sesv2 get-email-identity --region "$REGION" --email-identity "$HOST" \
  --query '{Verified:VerifiedForSendingStatus,Dkim:DkimAttributes.Status}' --output table
echo "Sandbox: verify each tester with: aws sesv2 create-email-identity --region $REGION --email-identity tester@example.org"
