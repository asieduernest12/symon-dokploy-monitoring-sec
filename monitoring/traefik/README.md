# Traefik Monitoring and Security Integration

This directory contains configuration files for integrating Traefik with the monitoring and security stack in Dokploy.

## Overview

The integration provides:
- **Prometheus Metrics**: Comprehensive monitoring of Traefik performance
- **CrowdSec Protection**: IP-based threat detection and blocking
- **Log Collection**: Centralized logging via Loki

## Files

- `dynamic_config.yml` - Main Traefik dynamic configuration
- `middlewares/crowdsec.yaml` - CrowdSec forwardAuth middleware

## Integration Components

### 1. Metrics Collection

**Configuration**: Traefik exposes Prometheus metrics on port 8082

**Flow**:
```
Traefik (port 8082) → Alloy (scrapes metrics) → Prometheus (storage) → Grafana (visualization)
```

**Metrics Included**:
- Entry point metrics (requests, duration, bytes)
- Router metrics (requests, errors)
- Service metrics (response times, errors)
- TLS metrics (versions, ciphers)

### 2. CrowdSec Integration

**Configuration**: ForwardAuth middleware protects routes

**Flow**:
```
Client Request → Traefik → CrowdSec Bouncer → Allow/Deny Decision
```

**Protection Features**:
- IP reputation checking
- Brute force protection
- Malicious bot detection
- Custom scenarios

### 3. Log Collection

**Configuration**: Docker-based log collection

**Flow**:
```
Traefik Container → Docker API → CrowdSec (threat detection) → Loki (storage)
```

## Dokploy Integration

### Setup Instructions

1. **Mount Configuration Files**:
   ```yaml
   # In your Dokploy Traefik service configuration
   volumes:
     - ./monitoring/traefik/dynamic_config.yml:/etc/traefik/dynamic_config.yml
     - ./monitoring/traefik/middlewares:/etc/traefik/middlewares
   ```

2. **Enable Metrics Port**:
   ```yaml
   # Expose metrics port in Traefik service
   ports:
     - "8082:8082"  # Metrics port
   ```

3. **Configure Traefik Command**:
   ```yaml
   command:
     - --configFile=/etc/traefik/traefik.yml
     - --providers.file.directory=/etc/traefik/
     - --providers.file.watch=true
   ```

### Example Service Configuration

```yaml
services:
  traefik:
    image: traefik:v3.6
    ports:
      - "80:80"
      - "443:443"
      - "8082:8082"  # Metrics port
    volumes:
      - ./monitoring/traefik/dynamic_config.yml:/etc/traefik/dynamic_config.yml
      - ./monitoring/traefik/middlewares:/etc/traefik/middlewares
      - /var/run/docker.sock:/var/run/docker.sock
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.rule=Host(`traefik.yourdomain.com`)"
      - "traefik.http.routers.traefik.service=api@internal"
      - "traefik.http.routers.traefik.middlewares=crowdsec-bouncer@file"
```

## CrowdSec Configuration

### Bouncer Setup

Ensure the CrowdSec bouncer is properly configured:

```yaml
# In your docker-compose.yml
services:
  crowdsec-bouncer-traefik:
    image: fbonalair/traefik-crowdsec-bouncer:latest
    environment:
      - CROWDSEC_BOUNCER_API_KEY=${CROWDSEC_API_KEY}
      - CROWDSEC_AGENT_HOST=crowdsec:8080
    depends_on:
      - crowdsec
```

### Log Acquisition

CrowdSec is configured to collect Traefik logs from Docker:

```yaml
# In monitoring/crowdsec/config/acquis.yaml
source: docker
container_name:
  - dokploy-traefik
  - traefik
labels:
  type: traefik
```

## Monitoring and Alerting

### Grafana Dashboards

Import the official Traefik dashboards:
- **Traefik Overview**: ID 17346
- **Traefik Detailed**: ID 17347

### Key Metrics to Monitor

1. **Request Rates**: `traefik_entrypoint_requests_total`
2. **Error Rates**: `traefik_entrypoint_requests_total{code=~"5.."}`
3. **Response Times**: `traefik_entrypoint_request_duration_seconds`
4. **TLS Usage**: `traefik_entrypoint_requests_tls_total`

### Alert Rules

Example alert rules for Traefik:

```yaml
# High error rate alert
groups:
  - name: traefik-alerts
    rules:
      - alert: HighTraefikErrorRate
        expr: rate(traefik_entrypoint_requests_total{code=~"5.."}[5m]) > 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate on Traefik entrypoint {{ $labels.entrypoint }}"
```

## Security Best Practices

### Middleware Chaining

Combine CrowdSec with other security middlewares:

```yaml
# In your Traefik router configuration
middlewares:
  - crowdsec-bouncer@file
  - rate-limit@file
  - security-headers@file
```

### Protected Routes

Apply CrowdSec protection to sensitive routes:

```yaml
# Example protected route
http:
  routers:
    admin-route:
      rule: Host(`admin.yourdomain.com`)
      service: admin-service
      middlewares:
        - crowdsec-bouncer@file
        - security-headers@file
      entryPoints:
        - websecure
```

## Troubleshooting

### Common Issues

1. **Metrics not appearing**:
   - Verify Traefik metrics port (8082) is exposed
   - Check Alloy logs for scrape errors
   - Confirm Traefik container name matches discovery filter

2. **CrowdSec not blocking**:
   - Verify bouncer API key is correct
   - Check CrowdSec logs for decision errors
   - Test with known malicious IP

3. **Logs not collected**:
   - Ensure Docker socket is mounted in CrowdSec container
   - Verify container names match acquis.yaml
   - Check CrowdSec log parsing

### Debugging Commands

```bash
# Check Traefik metrics endpoint
curl http://localhost:8082/metrics

# Check CrowdSec decisions
curl http://crowdsec:8080/api/v1/decisions

# Check Alloy targets
curl http://alloy:12345/targets
```

## References

- [Traefik Metrics Documentation](https://doc.traefik.io/traefik/observability/metrics/prometheus/)
- [CrowdSec Traefik Integration](https://doc.crowdsec.net/docs/next/bouncers/traefik)
- [Traefik ForwardAuth Middleware](https://doc.traefik.io/traefik/middlewares/forwardauth/)