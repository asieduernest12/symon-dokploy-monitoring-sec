#!/bin/bash

# Test script for monitoring and security stack

echo "Testing monitoring and security stack..."

# Test Prometheus targets
echo "Testing Prometheus targets..."
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}' || echo "Prometheus not accessible"

# Test Grafana
echo "Testing Grafana..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health || echo "Grafana not accessible"

# Test Loki
echo "Testing Loki..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:3100/ready || echo "Loki not accessible"

# Test Crowdsec
echo "Testing Crowdsec..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/v1/health || echo "Crowdsec not accessible"

# Test Node Exporter
echo "Testing Node Exporter..."
curl -s http://localhost:9100/metrics | head -5 || echo "Node Exporter not accessible"

# Test cAdvisor
echo "Testing cAdvisor..."
curl -s http://localhost:8080/api/v1.3/machine | jq '.num_cores' || echo "cAdvisor not accessible"

# Test Alloy
echo "Testing Alloy..."
curl -s http://localhost:12345/metrics | head -5 || echo "Alloy not accessible"

echo "Test complete. Check above for any failed services."