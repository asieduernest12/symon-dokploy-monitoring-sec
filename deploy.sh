#!/bin/bash

# Ashia LXC Monitoring Deployment Script
# Usage: ./deploy.sh YOUR_API_TOKEN

if [ $# -eq 0 ]; then
    echo "Error: API token required"
    echo "Usage: $0 YOUR_API_TOKEN"
    exit 1
fi

API_TOKEN=$1
BASE_URL="http://74.208.197.64:3000/api"
PROJECT_NAME="ashia-lxc-monitoring"

echo "Starting Dokploy deployment for $PROJECT_NAME..."

# Phase 1: Create project
echo "Phase 1: Creating Dokploy project..."
curl -X POST "$BASE_URL/project.create" \
  -H "X-API-Key: $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"$PROJECT_NAME\",
    \"description\": \"LXC monitoring and security stack\",
    \"env\": \"production\"
  }" || { echo "Failed to create project"; exit 1; }

echo "Project created successfully."

# Phase 2: Upload docker-compose.yml
echo "Phase 2: Uploading docker-compose.yml..."
curl -X POST "$BASE_URL/projects/$PROJECT_NAME/services" \
  -H "Authorization: Bearer $API_TOKEN" \
  -F "file=@docker-compose.yml" \
  -F "serviceName=monitoring-stack" || { echo "Failed to upload docker-compose.yml"; exit 1; }

echo "docker-compose.yml uploaded."

# Upload config files
echo "Uploading configuration files..."

curl -X POST "$BASE_URL/projects/$PROJECT_NAME/files" \
  -H "Authorization: Bearer $API_TOKEN" \
  -F "file=@monitoring/prometheus.yml" \
  -F "path=monitoring/prometheus.yml" || { echo "Failed to upload prometheus.yml"; exit 1; }

curl -X POST "$BASE_URL/projects/$PROJECT_NAME/files" \
  -H "Authorization: Bearer $API_TOKEN" \
  -F "file=@monitoring/loki/config.yml" \
  -F "path=monitoring/loki/config.yml" || { echo "Failed to upload loki config"; exit 1; }

curl -X POST "$BASE_URL/projects/$PROJECT_NAME/files" \
  -H "Authorization: Bearer $API_TOKEN" \
  -F "file=@monitoring/grafana/provisioning/datasources.yml" \
  -F "path=monitoring/grafana/provisioning/datasources.yml" || { echo "Failed to upload grafana datasources"; exit 1; }

curl -X POST "$BASE_URL/projects/$PROJECT_NAME/files" \
  -H "Authorization: Bearer $API_TOKEN" \
  -F "file=@monitoring/alloy/config.alloy" \
  -F "path=monitoring/alloy/config.alloy" || { echo "Failed to upload alloy config"; exit 1; }

curl -X POST "$BASE_URL/projects/$PROJECT_NAME/files" \
  -H "Authorization: Bearer $API_TOKEN" \
  -F "file=@security/crowdsec/acquis.yaml" \
  -F "path=security/crowdsec/acquis.yaml" || { echo "Failed to upload crowdsec acquis"; exit 1; }

echo "All configuration files uploaded."

# Phase 3: Set environment variables
echo "Phase 3: Setting environment variables..."
curl -X PUT "$BASE_URL/projects/$PROJECT_NAME/env" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "CROWDSEC_API_KEY": ""
  }' || { echo "Failed to set environment variables"; exit 1; }

echo "Environment variables set."

# Phase 4: Deploy the stack
echo "Phase 4: Deploying the stack..."
curl -X POST "$BASE_URL/projects/$PROJECT_NAME/deploy" \
  -H "Authorization: Bearer $API_TOKEN" || { echo "Failed to deploy stack"; exit 1; }

echo "Deployment initiated. Waiting 60 seconds for services to start..."
sleep 60

# Phase 5: Generate Crowdsec API key
echo "Phase 5: Generating Crowdsec API key..."
CROWDSEC_KEY=$(curl -X POST "$BASE_URL/projects/$PROJECT_NAME/exec" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "command": "docker-compose exec crowdsec cscli bouncers add traefik-bouncer -o raw"
  }' 2>/dev/null | tr -d '\n\r')

if [ -z "$CROWDSEC_KEY" ] || [ "$CROWDSEC_KEY" = "null" ]; then
    echo "Warning: Failed to generate Crowdsec API key automatically"
    echo "You may need to generate it manually later"
    CROWDSEC_KEY=""
else
    echo "Crowdsec API key generated: $CROWDSEC_KEY"
fi

# Update environment with Crowdsec key if generated
if [ -n "$CROWDSEC_KEY" ]; then
    echo "Updating environment with Crowdsec API key..."
    curl -X PUT "$BASE_URL/projects/$PROJECT_NAME/env" \
      -H "Authorization: Bearer $API_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{
        \"CROWDSEC_API_KEY\": \"$CROWDSEC_KEY\"
      }" || { echo "Failed to update Crowdsec API key"; }

    echo "Redeploying with Crowdsec key..."
    curl -X POST "$BASE_URL/projects/$PROJECT_NAME/deploy" \
      -H "Authorization: Bearer $API_TOKEN" || { echo "Failed to redeploy"; }
fi

# Phase 6: Verification
echo "Phase 6: Verifying deployment..."
STATUS=$(curl -X GET "$BASE_URL/projects/$PROJECT_NAME/status" \
  -H "Authorization: Bearer $API_TOKEN" 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "Deployment status: $STATUS"
else
    echo "Could not retrieve deployment status"
fi

echo ""
echo "Deployment complete!"
echo "Access your services at:"
echo "- Grafana: http://74.208.197.64/grafana/"
echo "- Prometheus: http://74.208.197.64/prometheus/"
echo ""
if [ -n "$CROWDSEC_KEY" ]; then
    echo "Crowdsec API key: $CROWDSEC_KEY"
else
    echo "Note: You may need to generate and set the CROWDSEC_API_KEY manually"
fi</content>
<parameter name="filePath">/tmp/ashia-lxc-monitoring/deploy.sh