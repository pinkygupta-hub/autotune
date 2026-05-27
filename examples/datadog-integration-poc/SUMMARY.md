# Datadog Integration POC - Summary

## Project Overview

This POC demonstrates a complete end-to-end integration between a sample application and Datadog for monitoring and alerting based on memory thresholds.

## What Was Created

### 1. Sample Application (`sample-app/`)
- **Python Flask Application** ([`app.py`](sample-app/app.py))
  - Exposes Prometheus metrics at `/metrics` endpoint
  - Monitors system memory usage
  - Increments counter when memory exceeds 60% threshold
  - Provides `/simulate-load` endpoint to trigger alerts
  - Health check endpoint at `/health`

- **Dependencies** ([`requirements.txt`](sample-app/requirements.txt))
  - Flask 3.0.0
  - prometheus-client 0.19.0
  - psutil 5.9.6
  - gunicorn 21.2.0

- **Container Image** ([`Dockerfile`](sample-app/Dockerfile))
  - Based on Python 3.11-slim
  - Runs with gunicorn for production readiness

### 2. Kubernetes Manifests (`k8s/`)
- **Namespace** ([`namespace.yaml`](k8s/namespace.yaml))
  - Creates `datadog-poc` namespace

- **Deployment** ([`deployment.yaml`](k8s/deployment.yaml))
  - Deploys memory-monitor-app
  - Configurable memory threshold (default: 60%)
  - Resource limits: 256Mi memory, 200m CPU
  - Health probes configured

- **Service** ([`service.yaml`](k8s/service.yaml))
  - ClusterIP service on port 8080
  - Prometheus scraping annotations

- **ServiceMonitor** ([`servicemonitor.yaml`](k8s/servicemonitor.yaml))
  - Configures Prometheus to scrape metrics every 30s

### 3. Datadog Configuration (`datadog/`)
- **Datadog Agent** ([`datadog-operator.yaml`](datadog-operator.yaml))
  - Deploys Datadog Agent via operator
  - Enables Prometheus scraping
  - Enables APM, logs, and cluster monitoring
  - Configures Kubernetes State Metrics

- **Monitor Configuration** ([`monitor-config.json`](monitor-config.json))
  - Metric alert on `memory_threshold_exceeded_total`
  - Triggers when counter > 0 in last 5 minutes
  - Priority: Medium (P3)
  - Includes detailed alert message with remediation steps

- **Dashboard Configuration** ([`dashboard-config.json`](dashboard-config.json))
  - 6 widgets displaying:
    1. Memory usage percentage with threshold line
    2. Total threshold violations counter
    3. Violations over time (bar chart)
    4. Information panel
    5. Pod health status
    6. Top pods by memory usage

- **Resource Creation Script** ([`create-datadog-resources.sh`](datadog/create-datadog-resources.sh))
  - Automated script to create monitor and dashboard via Datadog API
  - Requires DD_API_KEY and DD_APP_KEY environment variables

### 4. Automation Scripts
- **Deployment Script** ([`deploy.sh`](deploy.sh))
  - Automated end-to-end deployment
  - Checks prerequisites
  - Builds and deploys application
  - Configures Datadog agent
  - Creates monitor and dashboard
  - Provides next steps and troubleshooting info

- **Cleanup Script** ([`cleanup.sh`](cleanup.sh))
  - Removes all OpenShift resources
  - Provides instructions for manual Datadog cleanup

### 5. Documentation
- **Main README** ([`README.md`](README.md))
  - Comprehensive documentation (368 lines)
  - Architecture diagram
  - Detailed setup instructions
  - Troubleshooting guide
  - Customization options

- **Quick Start Guide** ([`QUICKSTART.md`](QUICKSTART.md))
  - 5-step quick setup (under 15 minutes)
  - Prerequisites checklist
  - Testing instructions
  - Troubleshooting tips

- **This Summary** ([`SUMMARY.md`](SUMMARY.md))
  - Overview of all created components

## Key Features

### Metrics Exposed
| Metric | Type | Description |
|--------|------|-------------|
| `memory_threshold_exceeded_total` | Counter | Increments when memory > 60% |
| `app_memory_usage_percent` | Gauge | Current memory usage % |
| `memory_threshold_percent` | Gauge | Configured threshold (60%) |

### Alert Flow
```
Application monitors memory
        ↓
Memory exceeds 60%
        ↓
Counter increments
        ↓
Prometheus scrapes metric
        ↓
Datadog Agent collects metric
        ↓
Datadog Monitor evaluates query
        ↓
Alert triggers (if counter > 0)
        ↓
Dashboard displays alert
```

## How to Use

### Quick Start (Automated)
```bash
# Set Datadog API keys
export DD_API_KEY='your-api-key'
export DD_APP_KEY='your-app-key'

# Run deployment script
cd examples/datadog-integration-poc
./deploy.sh
```

### Manual Setup
Follow the detailed instructions in [`README.md`](README.md)

### Testing the Integration
```bash
# Port forward to application
oc port-forward -n datadog-poc svc/memory-monitor-service 8080:8080

# Check metrics
curl http://localhost:8080/metrics

# Trigger alert
curl http://localhost:8080/simulate-load

# Wait 5-10 minutes and check Datadog dashboard
```

## File Structure
```
datadog-integration-poc/
├── .gitignore                          # Git ignore patterns
├── README.md                           # Main documentation (368 lines)
├── QUICKSTART.md                       # Quick start guide (165 lines)
├── SUMMARY.md                          # This file
├── deploy.sh                           # Automated deployment script (197 lines)
├── cleanup.sh                          # Cleanup script (82 lines)
├── sample-app/
│   ├── app.py                         # Flask application (93 lines)
│   ├── requirements.txt               # Python dependencies
│   └── Dockerfile                     # Container image definition
├── k8s/
│   ├── namespace.yaml                 # Namespace definition
│   ├── deployment.yaml                # Application deployment (56 lines)
│   ├── service.yaml                   # Service definition (20 lines)
│   └── servicemonitor.yaml            # Prometheus scraping config (16 lines)
└── datadog/
    ├── datadog-operator.yaml          # Datadog Agent config (63 lines)
    ├── monitor-config.json            # Monitor definition (37 lines)
    ├── dashboard-config.json          # Dashboard definition (157 lines)
    └── create-datadog-resources.sh    # API script (82 lines)

Total: 18 files, ~1,400 lines of code/config
```

## Prerequisites

### Required
- OpenShift cluster with admin access
- Datadog account (free 15-day trial)
- Datadog API Key and Application Key
- `oc` or `kubectl` CLI
- Docker or Podman

### Optional
- Datadog Operator installed (can be installed via script)

## Integration Points

### Application → Prometheus
- Application exposes `/metrics` endpoint
- ServiceMonitor configures scraping

### Prometheus → Datadog
- Datadog Agent scrapes Prometheus endpoints
- Metrics forwarded to Datadog platform

### Datadog → Alerts
- Monitor evaluates metric queries
- Dashboard visualizes metrics
- Alerts trigger based on thresholds

## Customization Options

### Change Memory Threshold
Edit [`k8s/deployment.yaml`](k8s/deployment.yaml):
```yaml
env:
- name: MEMORY_THRESHOLD
  value: "70"  # Change to desired %
```

### Modify Alert Conditions
Edit [`datadog/monitor-config.json`](datadog/monitor-config.json):
```json
"query": "sum(last_5m):sum:memory_threshold_exceeded_total{...} > 0",
"thresholds": {
  "critical": 0  // Change threshold
}
```

### Add More Metrics
Edit [`sample-app/app.py`](sample-app/app.py) and add Prometheus metrics

## Success Criteria

✅ Application deployed and running  
✅ Metrics exposed at `/metrics` endpoint  
✅ Datadog Agent collecting metrics  
✅ Monitor created in Datadog  
✅ Dashboard created in Datadog  
✅ Alert triggers when threshold exceeded  
✅ Dashboard displays metrics and alerts  

## Troubleshooting

### Common Issues

1. **Metrics not in Datadog**
   - Check Datadog Agent logs
   - Verify ServiceMonitor is created
   - Wait 5-10 minutes for initial sync

2. **Application not starting**
   - Check pod logs
   - Verify image is accessible
   - Check resource limits

3. **Monitor not triggering**
   - Verify metrics are flowing
   - Check monitor query syntax
   - Trigger load manually

See [`README.md`](README.md) for detailed troubleshooting.

## Next Steps

1. **Enhance Application**
   - Add more metrics (CPU, disk, network)
   - Implement custom business metrics
   - Add distributed tracing

2. **Improve Monitoring**
   - Create additional monitors
   - Set up notification channels (Slack, PagerDuty)
   - Configure SLOs

3. **Production Readiness**
   - Add authentication
   - Implement rate limiting
   - Set up log aggregation
   - Configure backup and recovery

## References

- [Datadog Documentation](https://docs.datadoghq.com/)
- [Datadog Operator GitHub](https://github.com/DataDog/datadog-operator)
- [Prometheus Client Python](https://github.com/prometheus/client_python)
- [OpenShift Documentation](https://docs.openshift.com/)

## License

This POC is provided as-is for demonstration purposes.

---

**Created**: 2026-05-26  
**Version**: 1.0  
**Status**: Complete and Ready for Deployment