#!/bin/bash

# Setup script for Ashia LXC Monitoring and Security Stack

echo "Setting up monitoring and security stack..."

# Copy environment file
if [ ! -f .env ]; then
    cp .env.example .env
    echo "Please edit .env file with your actual values"
    exit 1
fi

# Start the services
docker-compose up -d

echo "Waiting for Crowdsec to initialize..."
sleep 30

# Generate Crowdsec API key for bouncer
echo "Generating Crowdsec API key..."
API_KEY=$(docker-compose exec crowdsec cscli bouncers add traefik-bouncer -o raw)
echo "API_KEY=$API_KEY"

# Update .env with the generated key
sed -i "s/CROWDSEC_API_KEY=.*/CROWDSEC_API_KEY=$API_KEY/" .env

# Restart bouncer with new key
docker-compose up -d crowdsec-bouncer-traefik

echo "Setup complete. Services should be accessible at:"
echo "- Grafana: https://monitoring.ashia-lxc.com/grafana"
echo "- Prometheus: https://monitoring.ashia-lxc.com/prometheus"
echo ""
echo "Crowdsec API Key: $API_KEY"