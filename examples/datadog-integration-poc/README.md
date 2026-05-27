# Datadog Integration POC

This POC demonstrates how to integrate a sample application with Datadog for monitoring and alerting based on memory thresholds.

## Overview

The POC includes:
- **Sample Application**: Python Flask app that exposes Prometheus metrics
- **Memory Monitoring**: Tracks memory usage and increments a counter when threshold (60%) is exceeded
- **Datadog Integration**: Monitors metrics and creates alerts
- **Dashboard**: Visualizes memory usage and threshold violations

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    OpenShift Cluster                         │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Namespace: datadog-poc                              │  │
│  │                                                       │  │
│  │  ┌─────────────────────────────────────────────┐    │  │
│  │  │  Memory Monitor App (Pod)                   │    │  │
│  │  │  - Exposes /metrics endpoint                │    │  │
│  │  │  - Tracks memory usage                      │    │  │
│  │  │  - Increments counter when > 60%            │    │  │
│  │  └─────────────────────────────────────────────┘    │  │
│  │                      ↓                               │  │
│  │  ┌─────────────────────────────────────────────┐    │  │
│  │  │  Service (ClusterIP)                        │    │  │
│  │  │  - Port 8080                                │    │  │
│  │  └─────────────────────────────────────────────┘    │  │
│  │                      ↓                               │  │
│  │  ┌─────────────────────────────────────────────┐    │  │
│  │  │  ServiceMonitor                             │    │  │
│  │  │  - Prometheus scraping config               │    │  │
│  │  └─────────────────────────────────────────────┘    │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Namespace: datadog                                  │  │
│  │                                                       │  │
│  │  ┌─────────────────────────────────────────────┐    │  │
│  │  │  Datadog Agent (DaemonSet)                  │    │  │
│  │  │  - Scrapes Prometheus metrics               │    │  │
│  │  │  - Sends to Datadog platform                │    │  │
│  │  └─────────────────────────────────────────────┘    │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           ↓
                  ┌────────────────┐
                  │  Datadog Cloud │
                  │  - Monitor     │
                  │  - Dashboard   │
                  │  - Alerts      │
                  └────────────────┘
```

## Prerequisites

1. **OpenShift Cluster**: Access to an OpenShift cluster with admin privileges
2. **Datadog Account**: Free 15-day trial account from [Datadog](https://www.datadoghq.com/)
3. **Datadog API Keys**: 
   - API Key
   - Application Key
4. **Tools**:
   - `oc` or `kubectl` CLI
   - `docker` or `podman` for building images
   - `curl` for API calls

## Directory Structure

```
datadog-integration-poc/
├── sample-app/
│   ├── app.py                  # Flask application with Prometheus metrics
│   ├── requirements.txt        # Python dependencies
│   └── Dockerfile             # Container image definition
├── k8s/
│   ├── namespace.yaml         # Kubernetes namespace
│   ├── deployment.yaml        # Application deployment
│   ├── service.yaml           # Service definition
│   └── servicemonitor.yaml    # Prometheus ServiceMonitor
├── datadog/
│   ├── datadog-operator.yaml  # Datadog Agent configuration
│   ├── monitor-config.json    # Monitor definition
│   ├── dashboard-config.json  # Dashboard definition
│   └── create-datadog-resources.sh  # Script to create resources
└── README.md                  # This file
```

## Setup Instructions

### Step 1: Get Datadog API Keys

1. Sign up for a free Datadog trial: https://www.datadoghq.com/
2. Navigate to **Organization Settings** → **API Keys**
3. Create or copy your **API Key**
4. Navigate to **Organization Settings** → **Application Keys**
5. Create or copy your **Application Key**

### Step 2: Install Datadog Operator on OpenShift

```bash
# Login to your OpenShift cluster
oc login <your-cluster-url>

# Install the Datadog Operator from OperatorHub
# Via OpenShift Console:
# 1. Navigate to Operators → OperatorHub
# 2. Search for "Datadog Operator"
# 3. Click Install
# 4. Select "All namespaces" and click Install

# Or via CLI:
oc create -f https://operatorhub.io/install/datadog-operator.yaml
```

### Step 3: Configure Datadog Agent

```bash
# Update the API keys in the datadog-operator.yaml file
cd examples/datadog-integration-poc/datadog

# Edit the file and replace placeholders
vi datadog-operator.yaml
# Replace <YOUR_DATADOG_API_KEY> with your actual API key
# Replace <YOUR_DATADOG_APP_KEY> with your actual Application key

# Apply the configuration
oc apply -f datadog-operator.yaml

# Verify Datadog Agent is running
oc get pods -n datadog
```

### Step 4: Build and Deploy Sample Application

```bash
cd examples/datadog-integration-poc/sample-app

# Build the Docker image
docker build -t memory-monitor-app:latest .

# Tag for your registry (if using external registry)
docker tag memory-monitor-app:latest <your-registry>/memory-monitor-app:latest
docker push <your-registry>/memory-monitor-app:latest

# Update deployment.yaml with your image if needed
cd ../k8s

# Deploy the application
oc apply -f namespace.yaml
oc apply -f deployment.yaml
oc apply -f service.yaml
oc apply -f servicemonitor.yaml

# Verify deployment
oc get pods -n datadog-poc
oc get svc -n datadog-poc
```

### Step 5: Create Datadog Monitor and Dashboard

```bash
cd ../datadog

# Set environment variables
export DD_API_KEY='your-api-key'
export DD_APP_KEY='your-app-key'
export DD_SITE='datadoghq.com'  # or datadoghq.eu for EU

# Make script executable
chmod +x create-datadog-resources.sh

# Run the script
./create-datadog-resources.sh
```

The script will output URLs to view your monitor and dashboard in Datadog.

### Step 6: Verify Metrics Flow

```bash
# Check if metrics are being exposed
oc port-forward -n datadog-poc svc/memory-monitor-service 8080:8080

# In another terminal, check metrics endpoint
curl http://localhost:8080/metrics

# You should see metrics like:
# memory_threshold_exceeded_total 0
# app_memory_usage_percent 45.2
# memory_threshold_percent 60.0
```

### Step 7: Trigger Alert

```bash
# Simulate memory load to trigger threshold
curl http://localhost:8080/simulate-load

# Check metrics again
curl http://localhost:8080/metrics

# The memory_threshold_exceeded_total counter should increment
# when memory usage exceeds 60%
```

### Step 8: View in Datadog

1. **Dashboard**: Navigate to the dashboard URL provided by the script
   - View memory usage trends
   - See threshold violations
   - Monitor pod health

2. **Monitor**: Navigate to the monitor URL
   - Check alert status
   - View alert history
   - Configure notification channels

## Application Endpoints

- `GET /` - Application info and available endpoints
- `GET /health` - Health check endpoint
- `GET /metrics` - Prometheus metrics endpoint
- `GET /simulate-load` - Trigger memory load simulation

## Metrics Exposed

| Metric Name | Type | Description |
|-------------|------|-------------|
| `memory_threshold_exceeded_total` | Counter | Increments when memory usage exceeds 60% |
| `app_memory_usage_percent` | Gauge | Current memory usage percentage |
| `memory_threshold_percent` | Gauge | Configured memory threshold (60%) |

## Monitor Configuration

The Datadog monitor is configured to:
- **Query**: `sum(last_5m):sum:memory_threshold_exceeded_total{kube_namespace:datadog-poc} by {pod}.as_count() > 0`
- **Threshold**: Alert when counter > 0 in last 5 minutes
- **Evaluation**: Every 60 seconds
- **No Data**: Alert if no data for 10 minutes

## Dashboard Widgets

1. **Memory Usage Percentage**: Line chart showing memory usage over time with 60% threshold marker
2. **Total Threshold Violations**: Query value showing total count
3. **Violations Over Time**: Bar chart of violations
4. **Information Panel**: POC description and instructions
5. **Pod Health Status**: Kubernetes pod readiness checks
6. **Top Pods by Memory**: Ranked list of memory usage

## Troubleshooting

### Metrics Not Appearing in Datadog

```bash
# Check Datadog Agent logs
oc logs -n datadog -l app=datadog-agent

# Verify ServiceMonitor is created
oc get servicemonitor -n datadog-poc

# Check if Prometheus is scraping
oc get servicemonitor memory-monitor-servicemonitor -n datadog-poc -o yaml
```

### Application Not Starting

```bash
# Check pod logs
oc logs -n datadog-poc -l app=memory-monitor

# Check pod events
oc describe pod -n datadog-poc -l app=memory-monitor

# Verify image is accessible
oc get deployment -n datadog-poc memory-monitor-app -o yaml
```

### Monitor Not Triggering

1. Verify metrics are flowing to Datadog:
   - Go to Datadog → Metrics → Explorer
   - Search for `memory_threshold_exceeded_total`

2. Check monitor query:
   - Go to Datadog → Monitors → Manage Monitors
   - Edit the monitor and test the query

3. Trigger the threshold manually:
   ```bash
   oc port-forward -n datadog-poc svc/memory-monitor-service 8080:8080
   curl http://localhost:8080/simulate-load
   ```

## Cleanup

```bash
# Delete application resources
oc delete namespace datadog-poc

# Delete Datadog resources (optional)
oc delete namespace datadog

# Delete monitor and dashboard via Datadog UI or API
```

## Customization

### Adjust Memory Threshold

Edit [`k8s/deployment.yaml`](k8s/deployment.yaml):
```yaml
env:
- name: MEMORY_THRESHOLD
  value: "70"  # Change to desired percentage
```

### Modify Monitor Query

Edit [`datadog/monitor-config.json`](datadog/monitor-config.json) and update the query or thresholds.

### Add More Metrics

Edit [`sample-app/app.py`](sample-app/app.py) and add additional Prometheus metrics using the `prometheus_client` library.

## References

- [Datadog Documentation](https://docs.datadoghq.com/)
- [Datadog Operator](https://github.com/DataDog/datadog-operator)
- [Prometheus Client Python](https://github.com/prometheus/client_python)
- [OpenShift Documentation](https://docs.openshift.com/)

## License

This POC is provided as-is for demonstration purposes.