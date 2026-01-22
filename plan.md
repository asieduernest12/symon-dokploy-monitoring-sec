# Ashia LXC Monitoring and Security Stack Deployment Plan

## Overview
Complete Dokploy-deployed monitoring and security stack for LXC containers, featuring Prometheus/Grafana for metrics, Loki/Alloy for logs, and Crowdsec for security with Traefik integration.

## Architecture Components

### Monitoring Stack
- **Prometheus v3.1.0**: Metrics collection and alerting
- **Grafana OSS**: Visualization dashboard for metrics
- **Loki v2.9.2**: Log aggregation
- **Node Exporter v1.9.0**: System metrics exporter for the host
- **cAdvisor v0.54.1**: Container metrics collection
- **Alloy v1.12.1**: Telemetry collection agent

### Security Stack
- **Crowdsec v1.7.0**: Threat detection with Traefik collection
- **Crowdsec Traefik Bouncer**: Forward auth for protected routes

### Infrastructure
- **Dokploy**: Deployment and management platform
- **Traefik**: Reverse proxy with advanced routing and security

## Prerequisites
- Ubuntu/Debian-based Ashia host with Dokploy installed
- Server IP: 74.208.197.64 (accessible via SSH alias ashia-lxc)
- Dokploy API token for authentication
- Docker Engine and Docker Compose
- At least 4GB RAM and 2 CPU cores recommended

## Deployment Steps

### Phase 1: Dokploy Project Setup (API)
```bash
# Create project via API
curl -X POST http://74.208.197.64:3000/api/projects \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ashia-lxc-monitoring",
    "description": "LXC monitoring and security stack",
    "environment": "production"
  }'
```

### Phase 2: Upload Configuration Files (API)
```bash
# Upload docker-compose.yml
curl -X POST http://74.208.197.64:3000/api/projects/ashia-lxc-monitoring/services \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -F "file=@docker-compose.yml" \
  -F "serviceName=monitoring-stack"

# Upload config files
curl -X POST http://74.208.197.64:3000/api/projects/ashia-lxc-monitoring/files \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -F "file=@monitoring/prometheus.yml" \
  -F "path=monitoring/prometheus.yml"

# Repeat for remaining config files:
# - monitoring/loki/config.yml
# - monitoring/grafana/provisioning/datasources.yml
# - monitoring/alloy/config.alloy
# - security/crowdsec/acquis.yaml
```

### Phase 3: Environment Variables (API)
```bash
# Set environment variables
curl -X PUT http://74.208.197.64:3000/api/projects/ashia-lxc-monitoring/env \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "CROWDSEC_API_KEY": ""
  }'
```

### Phase 4: Deploy and Monitor (API)
```bash
# Deploy the stack
curl -X POST http://74.208.197.64:3000/api/projects/ashia-lxc-monitoring/deploy \
  -H "Authorization: Bearer YOUR_API_TOKEN"

# Check deployment status
curl -X GET http://74.208.197.64:3000/api/projects/ashia-lxc-monitoring/status \
  -H "Authorization: Bearer YOUR_API_TOKEN"
```

### Phase 5: Post-Deployment Setup
```bash
# Generate Crowdsec API key via container exec
curl -X POST http://74.208.197.64:3000/api/projects/ashia-lxc-monitoring/exec \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "command": "docker-compose exec crowdsec cscli bouncers add traefik-bouncer -o raw"
  }'

# Update environment with generated key
curl -X PUT http://74.208.197.64:3000/api/projects/ashia-lxc-monitoring/env \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "CROWDSEC_API_KEY": "generated-key-here"
  }'

# Redeploy with updated env
curl -X POST http://74.208.197.64:3000/api/projects/ashia-lxc-monitoring/deploy \
  -H "Authorization: Bearer YOUR_API_TOKEN"
```

### Phase 6: Access Configuration
Services accessible at:
- Grafana: http://74.208.197.64/grafana/
- Prometheus: http://74.208.197.64/prometheus/
- Direct ports available for local access

### Phase 7: Testing and Validation
1. Verify metrics collection from all targets
2. Test log aggregation in Loki
3. Validate Crowdsec threat detection
4. Check Traefik routing and security middlewares

## Configuration Details

### Traefik Integration
- Path-based routing: /grafana, /prometheus
- Security middlewares: Crowdsec auth, rate limiting (50/s, burst 100), security headers
- IP-based rules: Host(`74.208.197.64`)

### Volumes and Persistence
- prometheus_data, grafana_data, loki_data, crowdsec_data, crowdsec_config

### Security Features
- Crowdsec monitors Traefik logs for threats
- Bouncer provides forward authentication
- Rate limiting and security headers on all routes

## Success Criteria
- All services running and collecting metrics/logs
- Grafana dashboards accessible and displaying data
- Crowdsec detecting and blocking threats
- No security regressions

## Timeline Estimate
- Phase 1: 10 minutes
- Phase 2: 15 minutes
- Phase 3: 5 minutes
- Phase 4: 10 minutes
- Phase 5: 10 minutes
- Phase 6: 5 minutes
- Phase 7: 15 minutes
Total: ~70 minutes

## Troubleshooting
1. **API Authentication**: Verify YOUR_API_TOKEN is correct
2. **File Uploads**: Ensure file paths are correct and accessible
3. **Crowdsec Setup**: Check container exec permissions
4. **IP Routing**: Verify Traefik labels use correct IP

## Future Enhancements
- Add alerting rules to Prometheus
- Implement automated backups
- Create custom LXC monitoring dashboards
- Integrate with external notification systems</content>
<parameter name="filePath">/tmp/ashia-lxc-monitoring/plan.md