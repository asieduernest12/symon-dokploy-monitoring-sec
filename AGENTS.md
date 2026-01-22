# AGENTS.md - Ashia LXC Monitoring and Security Implementation Guide

## Project Overview
This document guides the implementation of a Dokploy-deployed Docker Compose-based monitoring and security system for LXC containers running on an Ashia host. The project aims to provide comprehensive observability and threat detection capabilities through Dokploy, a self-hosted PaaS platform.

## Architecture Components

### Monitoring Stack
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization dashboard for metrics
- **Loki**: Log aggregation
- **Node Exporter**: System metrics exporter for the host
- **cAdvisor**: Container metrics collection
- **Alloy**: Telemetry collection agent

### Security Stack
- **Crowdsec**: Threat detection with Traefik integration
- **Crowdsec Traefik Bouncer**: Forward auth for protected routes

### Infrastructure
- **Dokploy**: Deployment and management platform for Docker Compose
- **Traefik**: Reverse proxy and load balancer (optional for external access)

## Prerequisites
- Ubuntu/Debian-based Ashia host with LXC support
- Docker Engine installed
- Docker Compose v2.0+
- Dokploy installed and running (see Dokploy documentation for installation)
- At least 4GB RAM and 2 CPU cores recommended
- sudo access for container management

## Implementation Steps

### Step 1: Dokploy Setup
1. Install Dokploy on your Ashia host following the [Dokploy Installation Guide](https://docs.dokploy.com/docs/core/installation).
2. Access the Dokploy web interface (default: http://your-server-ip:3000).
3. Create a new Project in Dokploy for the monitoring and security stack.

### Step 2: Project Setup
```bash
# Clone or create project directory
mkdir -p /tmp/ashia-lxc-monitoring
cd /tmp/ashia-lxc-monitoring

# Initialize basic structure
mkdir -p docker-compose monitoring security config

# Create docker-compose.yml
touch docker-compose.yml
```

### Step 2: Docker Compose Configuration
Create `docker-compose.yml` with the following services:

```yaml
version: '3.8'
services:
  prometheus:
    image: prom/prometheus:v3.1.0
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
      - '--enable-feature=remote-write-receiver'
      - '--web.external-url=http://74.208.197.64/prometheus/'
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.prometheus.rule=Host(`74.208.197.64`) && PathPrefix(`/prometheus`)"
      - "traefik.http.routers.prometheus.middlewares=prometheus-stripprefix,crowdsec-auth,security-headers,rate-limit"
      - "traefik.http.services.prometheus.loadbalancer.server.port=9090"
      - "traefik.http.middlewares.prometheus-stripprefix.stripprefix.prefixes=/prometheus"

  grafana:
    image: grafana/grafana-oss
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/grafana/provisioning:/etc/grafana/provisioning
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_ROOT_URL=%(protocol)s://%(domain)s/grafana/
      - GF_SERVER_SERVE_FROM_SUB_PATH=true
    depends_on:
      - prometheus
      - loki
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.grafana.rule=Host(`74.208.197.64`) && PathPrefix(`/grafana`)"
      - "traefik.http.routers.grafana.middlewares=grafana-stripprefix,crowdsec-auth,security-headers,rate-limit"
      - "traefik.http.services.grafana.loadbalancer.server.port=3000"
      - "traefik.http.middlewares.grafana-stripprefix.stripprefix.prefixes=/grafana"
      - "traefik.http.middlewares.crowdsec-auth.forwardauth.address=http://crowdsec-bouncer-traefik:8080/api/v1/forwardAuth"
      - "traefik.http.middlewares.security-headers.headers.customrequestheaders.X-Forwarded-Proto=https"
      - "traefik.http.middlewares.security-headers.headers.stsseconds=31536000"
      - "traefik.http.middlewares.security-headers.headers.stsincludesubdomains=true"
      - "traefik.http.middlewares.security-headers.headers.stspreload=true"
      - "traefik.http.middlewares.rate-limit.ratelimit.burst=100"
      - "traefik.http.middlewares.rate-limit.ratelimit.average=50"

  loki:
    image: grafana/loki:2.9.2
    ports:
      - "3100:3100"
    volumes:
      - ./monitoring/loki/config.yml:/etc/loki/local-config.yaml
      - loki_data:/loki
    command: -config.file=/etc/loki/local-config.yaml

  node-exporter:
    image: prom/node-exporter:v1.9.0
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'

  cadvisor:
    image: ghcr.io/google/cadvisor:0.54.1
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    devices:
      - /dev/kmsg

  alloy:
    image: grafana/alloy:v1.12.1
    volumes:
      - ./monitoring/alloy/config.alloy:/etc/alloy/config.alloy
      - /var/log:/var/log:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    command:
      - run
      - /etc/alloy/config.alloy
      - --server.http.listen-addr=0.0.0.0:12345
      - --storage.path=/tmp/alloy

  crowdsec:
    image: crowdsecurity/crowdsec:v1.7.0
    volumes:
      - crowdsec_data:/var/lib/crowdsec/data
      - crowdsec_config:/etc/crowdsec
      - ./security/crowdsec/acquis.yaml:/etc/crowdsec/acquis.yaml:ro
      - /var/log:/var/log:ro
    environment:
      - COLLECTIONS=crowdsecurity/traefik
    ports:
      - "8080:8080"  # LAPI port

  crowdsec-bouncer-traefik:
    image: fbonalair/traefik-crowdsec-bouncer:latest
    ports:
      - "8081:8080"
    environment:
      - CROWDSEC_BOUNCER_API_KEY=${CROWDSEC_API_KEY}
      - CROWDSEC_AGENT_HOST=crowdsec:8080
    depends_on:
      - crowdsec

volumes:
  prometheus_data:
  grafana_data:
  loki_data:
  crowdsec_data:
  crowdsec_config:
```

### Step 3: Configuration Files

#### Prometheus Configuration (`monitoring/prometheus.yml`)
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'loki'
    static_configs:
      - targets: ['loki:3100']

  - job_name: 'crowdsec'
    static_configs:
      - targets: ['crowdsec:6060']

  - job_name: 'traefik'
    static_configs:
      - targets: ['host.docker.internal:8080']  # Assuming Traefik metrics are exposed on host
```

#### Crowdsec Acquis Configuration (`security/crowdsec/acquis.yaml`)
```yaml
filenames:
  - /var/log/traefik/*.log
labels:
  type: traefik
```

#### Loki Configuration (`monitoring/loki/config.yml`)
```yaml
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  instance_addr: 127.0.0.1
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://localhost:9093

analytics:
  reporting_enabled: false
```

#### Alloy Configuration (`monitoring/alloy/config.alloy`)
```alloy
// Alloy configuration for log collection and additional metrics

// Log collection
loki.source.file "varlogcontainers" {
  targets = [
    {__path__ = "/var/log/containers/*.log", "job" = "varlogcontainers"},
  ]
  forward_to = [loki.write.logs_service.receiver]
}

loki.source.file "varlogpods" {
  targets = [
    {__path__ = "/var/log/pods/**/*.log", "job" = "varlogpods"},
  ]
  forward_to = [loki.write.logs_service.receiver]
}

loki.source.file "systemd" {
  targets = [
    {__path__ = "/var/log/journal/**/*.log", "job" = "systemd"},
  ]
  forward_to = [loki.write.logs_service.receiver]
}

loki.write "logs_service" {
  endpoint {
    url = "http://loki:3100/loki/api/v1/push"
  }
}
```

### Step 4: LXC Integration
The cAdvisor service is already included in the docker-compose.yml for monitoring container metrics, which applies to both Docker containers and LXC containers on the host.

### Step 5: Security Hardening
- Run containers with non-root users where possible
- Use secrets management for sensitive configurations
- Implement network segmentation with Docker networks
- Regular security scans of container images

## Common Commands

### Dokploy Operations
- Deploy the project via Dokploy web interface (upload docker-compose.yml and config files)
- View logs through Dokploy dashboard
- Restart services via Dokploy
- Scale services through Dokploy configuration

### Monitoring Commands
```bash
# Check Prometheus targets
curl http://localhost:9090/targets

# Access Grafana
# Open http://localhost:3000 (admin/admin)

# Check Falco alerts (via Dokploy logs or)
docker-compose logs falco  # if running locally
```

### Dokploy-Specific Commands
- Access Dokploy: http://your-server-ip:3000
- Manage projects, services, and deployments through the web UI

### LXC-Specific Commands
```bash
# List LXC containers
lxc list

# Get container info for monitoring
lxc info [container_name]

# Check container resource usage
lxc exec [container_name] -- free -h
```

## Troubleshooting

### Common Issues
1. **Permission denied errors**: Ensure Docker socket permissions are correct
   ```bash
   sudo chmod 666 /var/run/docker.sock
   ```

2. **Falco not detecting events**: Check if privileged mode is enabled and volumes are mounted correctly

3. **Prometheus not scraping metrics**: Verify target endpoints are accessible and configurations are correct

4. **Grafana login issues**: Check environment variables and data volume permissions

### Logs and Debugging
```bash
# View all service logs
docker-compose logs

# Follow specific service logs
docker-compose logs -f prometheus

# Check container resource usage
docker stats

# Inspect running containers
docker-compose ps
```

## Security Considerations
- Regularly update container images
- Monitor for privilege escalation attempts
- Implement log aggregation and alerting
- Use TLS for external access
- Audit container configurations periodically

## Future Enhancements
- Integration with ELK stack for log aggregation
- Automated incident response
- Custom dashboards for LXC metrics
- Container vulnerability scanning
- Backup and recovery procedures

## References
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Falco Documentation](https://falco.org/docs/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [LXC Documentation](https://linuxcontainers.org/lxc/documentation/)

---

*This guide should be updated as the project evolves. Use opencode for any code changes and testing.*