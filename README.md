# Ashia LXC Monitoring and Security Implementation

This project replicates the monitoring and security stack from schrep-ofin to ashia-lxc using Dokploy.

## Services Included

- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization dashboard
- **Loki**: Log aggregation
- **Node Exporter**: System metrics
- **cAdvisor**: Container metrics
- **Alloy**: Telemetry collection agent
- **Crowdsec**: Threat detection with Traefik bouncer

## Deployment to Dokploy

1. **Create Project**:
   ```bash
   # Via Dokploy API (replace with your values)
   curl -X POST http://your-dokploy-server:3000/api/projects \
     -H "Authorization: Bearer YOUR_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"name": "monitoring-manager", "description": "LXC monitoring and security"}'
   ```

2. **Upload Configuration**:
   - Upload `docker-compose.yml`
   - Upload all config files in `monitoring/` and `security/`
   - Set environment variables from `.env`

3. **Configure Domain**:
   - Set domain to `monitoring.ashia-lxc.com`
   - Ensure SSL certificates are configured

4. **Deploy**:
   - Deploy the stack via Dokploy interface
   - Run the setup script to generate Crowdsec API keys

## Local Development

```bash
# Copy environment
cp .env.example .env

# Edit .env with your values

# Run setup
./setup.sh

# Access services locally:
# Grafana: http://localhost:3000
# Prometheus: http://localhost:9090
```

## Configuration Files

- `monitoring/prometheus.yml`: Prometheus scrape targets
- `monitoring/loki/config.yml`: Loki configuration
- `monitoring/alloy/config.alloy`: Alloy telemetry config
- `security/crowdsec/acquis.yaml`: Crowdsec log sources
- `monitoring/grafana/provisioning/datasources.yml`: Grafana datasources

## Security Features

- Crowdsec threat detection
- Rate limiting (50 req/min, burst 100)
- Security headers (HSTS, etc.)
- Path-based authentication for services

## Monitoring URLs

- Grafana: `https://monitoring.ashia-lxc.com/grafana`
- Prometheus: `https://monitoring.ashia-lxc.com/prometheus`

## Troubleshooting

1. **Crowdsec not detecting threats**: Check acquis.yaml and log paths
2. **Metrics not appearing**: Verify service discovery in Prometheus
3. **Traefik routing issues**: Check labels and domain configuration
4. **Bouncer blocking legitimate traffic**: Adjust Crowdsec rules