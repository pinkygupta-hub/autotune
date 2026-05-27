# Quick Start Guide - Datadog Integration POC

This guide will help you get the POC up and running in under 15 minutes.

## Prerequisites Checklist

- [ ] OpenShift cluster access with admin privileges
- [ ] `oc` CLI installed and configured
- [ ] Docker/Podman installed
- [ ] Datadog account (free 15-day trial)
- [ ] Datadog API Key and Application Key

## Quick Setup (5 Steps)

### 1. Get Datadog Keys (2 minutes)

```bash
# Sign up at https://www.datadoghq.com/
# Get keys from: https://app.datadoghq.com/organization-settings/api-keys

export DD_API_KEY='your-datadog-api-key'
export DD_APP_KEY='your-datadog-app-key'
```

### 2. Install Datadog Operator (3 minutes)

```bash
# Via OpenShift Console:
# Operators → OperatorHub → Search "Datadog Operator" → Install

# Wait for operator to be ready
oc get pods -n openshift-operators | grep datadog
```

### 3. Deploy Datadog Agent (2 minutes)

```bash
cd examples/datadog-integration-poc/datadog

# Update the API keys in datadog-operator.yaml
sed -i "s/<YOUR_DATADOG_API_KEY>/${DD_API_KEY}/g" datadog-operator.yaml
sed -i "s/<YOUR_DATADOG_APP_KEY>/${DD_APP_KEY}/g" datadog-operator.yaml

# Deploy
oc apply -f datadog-operator.yaml

# Verify (wait for pods to be Running)
oc get pods -n datadog
```

### 4. Deploy Sample Application (3 minutes)

```bash
cd ../sample-app

# Build image
docker build -t memory-monitor-app:latest .

# For OpenShift internal registry:
docker tag memory-monitor-app:latest image-registry.openshift-image-registry.svc:5000/datadog-poc/memory-monitor-app:latest

# Login to OpenShift registry
oc registry login
docker push image-registry.openshift-image-registry.svc:5000/datadog-poc/memory-monitor-app:latest

# Deploy
cd ../k8s
oc apply -f namespace.yaml
oc apply -f deployment.yaml
oc apply -f service.yaml
oc apply -f servicemonitor.yaml

# Verify
oc get pods -n datadog-poc
```

### 5. Create Monitor & Dashboard (2 minutes)

```bash
cd ../datadog

# Create resources in Datadog
chmod +x create-datadog-resources.sh
./create-datadog-resources.sh

# Note the URLs provided in the output
```

## Test the Integration

### Verify Metrics

```bash
# Port forward to the application
oc port-forward -n datadog-poc svc/memory-monitor-service 8080:8080 &

# Check metrics endpoint
curl http://localhost:8080/metrics | grep memory

# Expected output:
# memory_threshold_exceeded_total 0
# app_memory_usage_percent 45.2
# memory_threshold_percent 60.0
```

### Trigger Alert

```bash
# Simulate memory load
curl http://localhost:8080/simulate-load

# Wait 30 seconds and check metrics again
sleep 30
curl http://localhost:8080/metrics | grep memory_threshold_exceeded_total

# The counter should have incremented
```

### View in Datadog

1. Open the dashboard URL from step 5
2. You should see:
   - Memory usage graph
   - Threshold violations counter
   - Pod health status

3. Open the monitor URL from step 5
4. Wait 5-10 minutes for the alert to trigger
5. You should see the alert status change to "Alert"

## Troubleshooting

### Metrics not showing in Datadog?

```bash
# Check Datadog agent logs
oc logs -n datadog -l app=datadog-agent --tail=50

# Verify Prometheus scraping is enabled
oc get servicemonitor -n datadog-poc
```

### Application pod not starting?

```bash
# Check pod status
oc get pods -n datadog-poc
oc describe pod -n datadog-poc -l app=memory-monitor
oc logs -n datadog-poc -l app=memory-monitor
```

### Monitor not triggering?

1. Wait 10-15 minutes for metrics to flow
2. Check Datadog Metrics Explorer for `memory_threshold_exceeded_total`
3. Manually trigger load: `curl http://localhost:8080/simulate-load`

## Next Steps

- Customize the memory threshold in `k8s/deployment.yaml`
- Add more metrics to the application
- Configure notification channels in Datadog
- Explore Datadog APM and Log Management

## Clean Up

```bash
# Remove all resources
oc delete namespace datadog-poc
oc delete namespace datadog

# Delete monitor and dashboard from Datadog UI
```

## Support

For issues or questions:
1. Check the main [README.md](README.md) for detailed documentation
2. Review Datadog documentation: https://docs.datadoghq.com/
3. Check OpenShift logs and events