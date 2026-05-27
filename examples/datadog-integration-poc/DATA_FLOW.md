# Data Flow Explanation

## Where Does the Data Come From?

### The Complete Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. APPLICATION GENERATES METRICS                                │
│                                                                  │
│    Sample App (memory-monitor-app)                              │
│    - Monitors system memory usage                               │
│    - Increments counter when memory > 60%                       │
│    - Exposes metrics at http://pod-ip:8080/metrics              │
│                                                                  │
│    Metrics Generated:                                            │
│    • memory_threshold_exceeded_total (counter)                   │
│    • app_memory_usage_percent (gauge)                            │
│    • memory_threshold_percent (gauge)                            │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. DATADOG AGENT SCRAPES METRICS (Acts as Prometheus)           │
│                                                                  │
│    Datadog Agent (running as DaemonSet)                         │
│    - Has Prometheus scraping enabled                             │
│    - Discovers services via ServiceMonitor                       │
│    - Scrapes /metrics endpoint every 30 seconds                  │
│    - Converts Prometheus metrics to Datadog format              │
│                                                                  │
│    Configuration:                                                │
│    • DD_PROMETHEUS_SCRAPE_ENABLED=true                          │
│    • DD_PROMETHEUS_SCRAPE_SERVICE_ENDPOINTS=true                │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. DATADOG CLOUD RECEIVES METRICS                               │
│                                                                  │
│    Datadog Platform (https://app.datadoghq.com)                 │
│    - Receives metrics from agent                                 │
│    - Stores time-series data                                     │
│    - Makes data available for queries                            │
│                                                                  │
│    You can view metrics in:                                      │
│    • Metrics Explorer                                            │
│    • Dashboards                                                  │
│    • Monitors                                                    │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ 4. DATADOG MONITOR EVALUATES METRICS                            │
│                                                                  │
│    Monitor Query:                                                │
│    sum(last_5m):sum:memory_threshold_exceeded_total{...} > 0    │
│                                                                  │
│    - Runs every 60 seconds                                       │
│    - Checks if counter > 0 in last 5 minutes                     │
│    - Triggers alert if condition is met                          │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ 5. DATADOG DASHBOARD DISPLAYS DATA                              │
│                                                                  │
│    Dashboard Widgets show:                                       │
│    • Memory usage over time (line chart)                         │
│    • Threshold violations count (number)                         │
│    • Violations timeline (bar chart)                             │
│    • Pod health status                                           │
└─────────────────────────────────────────────────────────────────┘
```

## Key Points

### 1. **No Separate Prometheus Installation Needed**
   - Datadog Agent has built-in Prometheus scraping capability
   - It acts as a Prometheus scraper
   - You don't need to install Prometheus separately

### 2. **Where to View the Data**

#### Option A: Datadog Dashboard (Recommended)
```
URL: https://app.datadoghq.com/dashboard/[dashboard-id]
```
- Visual graphs and charts
- Real-time updates
- Historical data
- Created by the deployment script

#### Option B: Datadog Metrics Explorer
```
URL: https://app.datadoghq.com/metric/explorer
```
- Search for: `memory_threshold_exceeded_total`
- View raw metric data
- Create custom queries

#### Option C: Datadog Monitor
```
URL: https://app.datadoghq.com/monitors/[monitor-id]
```
- Shows alert status
- Alert history
- Evaluation results

#### Option D: Application Metrics Endpoint (Raw Data)
```bash
# Port forward to the app
oc port-forward -n datadog-poc svc/memory-monitor-service 8080:8080

# View raw Prometheus metrics
curl http://localhost:8080/metrics
```

### 3. **How Datadog Discovers Your Metrics**

The ServiceMonitor tells Datadog Agent where to scrape:

```yaml
# k8s/servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: memory-monitor-servicemonitor
  namespace: datadog-poc
spec:
  selector:
    matchLabels:
      app: memory-monitor  # Finds services with this label
  endpoints:
  - port: http             # Scrapes this port
    path: /metrics         # At this path
    interval: 30s          # Every 30 seconds
```

### 4. **Metrics Available in Datadog**

Once deployed, you'll see these metrics in Datadog:

| Metric Name | Type | Description | Where to View |
|-------------|------|-------------|---------------|
| `memory_threshold_exceeded_total` | Counter | Number of times threshold exceeded | Dashboard, Monitor |
| `app_memory_usage_percent` | Gauge | Current memory usage % | Dashboard |
| `memory_threshold_percent` | Gauge | Configured threshold (60%) | Dashboard |

## How to Access Your Data

### Step 1: Wait for Data to Flow (5-10 minutes after deployment)

### Step 2: View in Datadog Metrics Explorer
```
1. Go to: https://app.datadoghq.com/metric/explorer
2. Search for: memory_threshold_exceeded_total
3. You should see the metric with data points
```

### Step 3: View in Dashboard
```
1. Go to the dashboard URL from deployment script output
2. Or navigate to: Dashboards → Dashboard List
3. Search for: "Memory Monitor POC"
4. Open the dashboard
```

### Step 4: Check Monitor Status
```
1. Go to: https://app.datadoghq.com/monitors/manage
2. Search for: "Memory Threshold Exceeded"
3. View alert status and history
```

## Troubleshooting: "I Don't See Data in Datadog"

### Check 1: Is the Application Running?
```bash
oc get pods -n datadog-poc
# Should show: Running

oc logs -n datadog-poc -l app=memory-monitor
# Should show: "Starting application..."
```

### Check 2: Are Metrics Being Exposed?
```bash
oc port-forward -n datadog-poc svc/memory-monitor-service 8080:8080
curl http://localhost:8080/metrics

# Should show:
# memory_threshold_exceeded_total 0
# app_memory_usage_percent 45.2
```

### Check 3: Is Datadog Agent Running?
```bash
oc get pods -n datadog
# Should show: datadog-agent pods Running

oc logs -n datadog -l app=datadog-agent | grep prometheus
# Should show: Prometheus scraping enabled
```

### Check 4: Is ServiceMonitor Created?
```bash
oc get servicemonitor -n datadog-poc
# Should show: memory-monitor-servicemonitor

oc describe servicemonitor memory-monitor-servicemonitor -n datadog-poc
```

### Check 5: Wait for Initial Sync
- First data appears: 5-10 minutes after deployment
- Monitor triggers: 5-10 minutes after threshold exceeded
- Be patient! Initial sync takes time

## Example: Viewing Data Step-by-Step

### 1. Deploy Everything
```bash
# Follow DEPLOYMENT_STEPS.md or QUICK_COMMANDS.md
```

### 2. Trigger the Alert
```bash
oc port-forward -n datadog-poc svc/memory-monitor-service 8080:8080 &
curl http://localhost:8080/simulate-load
```

### 3. Verify Locally
```bash
curl http://localhost:8080/metrics | grep memory_threshold_exceeded_total
# Output: memory_threshold_exceeded_total 1
```

### 4. Wait 5-10 Minutes

### 5. Check Datadog
```
Go to: https://app.datadoghq.com/metric/explorer
Search: memory_threshold_exceeded_total
Result: You should see data points!
```

### 6. View Dashboard
```
Go to: Dashboard URL from deployment script
Result: Graphs showing memory usage and violations
```

### 7. Check Monitor
```
Go to: Monitor URL from deployment script
Result: Alert status should be "Alert" (red)
```

## Summary

**You DON'T need to access Prometheus** - Datadog handles everything:

✅ Datadog Agent scrapes metrics (acts as Prometheus)  
✅ Data is sent to Datadog Cloud automatically  
✅ View data in Datadog Dashboard (created by script)  
✅ Monitor evaluates metrics and triggers alerts  
✅ Everything is in Datadog UI at https://app.datadoghq.com  

**The only "Prometheus" part is the metrics format** - the application exposes metrics in Prometheus format, which Datadog Agent understands and scrapes.