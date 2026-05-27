# Step-by-Step Deployment Guide

This guide provides the exact commands to deploy the Datadog Integration POC to your OpenShift cluster.

## Prerequisites

- OpenShift cluster is provisioned and accessible
- `oc` CLI installed on your machine
- Datadog account with API Key and Application Key
- Docker/Podman installed

## Step 1: Login to OpenShift Cluster

```bash
# Get your cluster login command from OpenShift Console
# Usually looks like this:
oc login --token=<your-token> --server=https://<your-cluster-url>:6443

# Verify you're logged in
oc whoami
oc cluster-info
```

## Step 2: Install Datadog Operator

### Option A: Via OpenShift Console (Recommended)

1. Login to OpenShift Console in your browser
2. Navigate to **Operators** → **OperatorHub**
3. Search for "**Datadog Operator**"
4. Click on it and click **Install**
5. Select:
   - **Installation Mode**: All namespaces on the cluster
   - **Installed Namespace**: openshift-operators
   - **Update approval**: Automatic
6. Click **Install**
7. Wait for the operator to be ready (Status: Succeeded)

### Option B: Via CLI

```bash
# Create operator subscription
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: datadog-operator
  namespace: openshift-operators
spec:
  channel: alpha
  name: datadog-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
EOF

# Wait for operator to be ready
oc get csv -n openshift-operators | grep datadog
```

## Step 3: Create Datadog API Key Secret

```bash
# Set your Datadog API keys
export DD_API_KEY='98f612e01477fc24cb48822288ba502c'
export DD_APP_KEY='ddapp_FTG4edSKSDkXVftwMSgHMEcqCWrK1LTmmk'

# Create the secret in openshift-operators namespace
oc create secret generic datadog-secret \
  --from-literal api-key=${DD_API_KEY} \
  --from-literal app-key=${DD_APP_KEY} \
  -n openshift-operators

# Verify secret was created
oc get secret datadog-secret -n openshift-operators
```

## Step 4: Deploy Datadog Agent

```bash
cd examples/datadog-integration-poc/datadog

# Create datadog namespace
oc create namespace datadog

# Copy the secret to datadog namespace
oc get secret datadog-secret -n openshift-operators -o yaml | \
  sed 's/namespace: openshift-operators/namespace: datadog/' | \
  oc apply -f -

# Deploy Datadog Agent (using the secret we created)
cat <<EOF | oc apply -f -
apiVersion: datadoghq.com/v2alpha1
kind: DatadogAgent
metadata:
  name: datadog
  namespace: datadog
spec:
  global:
    credentials:
      apiSecret:
        secretName: datadog-secret
        keyName: api-key
      appSecret:
        secretName: datadog-secret
        keyName: app-key
    site: datadoghq.com
    clusterName: my-openshift-cluster
  features:
    prometheusScrape:
      enabled: true
      serviceEndpoints: true
    apm:
      enabled: true
    logCollection:
      enabled: true
      containerCollectAll: true
    clusterChecks:
      enabled: true
    kubeStateMetricsCore:
      enabled: true
  override:
    nodeAgent:
      tolerations:
      - operator: Exists
      env:
      - name: DD_PROMETHEUS_SCRAPE_ENABLED
        value: "true"
      - name: DD_PROMETHEUS_SCRAPE_SERVICE_ENDPOINTS
        value: "true"
      - name: DD_LOGS_ENABLED
        value: "true"
      - name: DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL
        value: "true"
EOF

# Wait for Datadog Agent pods to be ready (this may take 2-3 minutes)
oc get datadogagent -n openshift-operators
oc get pods -n openshift-operators
----------
oc get pods -n datadog -w
# Press Ctrl+C when you see pods in Running state
```

## Step 5: Build and Deploy Sample Application

```bash
cd ../sample-app

# Build the Docker image
docker buildx build --platform linux/amd64 -t memory-monitor-app:latest --load ./examples/datadog-integration-poc/sample-app

# Tag for OpenShift internal registry (if using)
# First, get your registry URL
REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')
// bob fix
oc patch configs.imageregistry.operator.openshift.io/cluster \
  --type=merge \
  -p '{"spec":{"defaultRoute":true}}'
oc get route default-route -n openshift-image-registry
REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')



# Login to OpenShift registry
docker login -u kubeadmin -p $(oc whoami -t) $REGISTRY
oc new-project datadog-poc

# Tag and push
docker tag memory-monitor-app:latest $REGISTRY/datadog-poc/memory-monitor-app:latest
docker push $REGISTRY/datadog-poc/memory-monitor-app:latest

# OR if using external registry (Docker Hub, Quay.io, etc.)
# docker tag memory-monitor-app:latest your-registry/memory-monitor-app:latest
# docker push your-registry/memory-monitor-app:latest
```

## Step 6: Deploy Application to OpenShift

```bash
cd ../k8s

# Create namespace
oc apply -f namespace.yaml

# Deploy application
oc apply -f deployment.yaml
oc apply -f service.yaml
oc apply -f servicemonitor.yaml

# Verify deployment
oc get pods -n datadog-poc
oc get svc -n datadog-poc

# Wait for pod to be ready
oc wait --for=condition=ready pod -l app=memory-monitor -n datadog-poc --timeout=300s
```

## Step 7: Verify Metrics are Flowing

```bash
# Port forward to the application
oc port-forward -n datadog-poc svc/memory-monitor-service 8080:8080 &

# Check metrics endpoint
curl http://localhost:8080/metrics

# You should see output like:
# memory_threshold_exceeded_total 0
# app_memory_usage_percent 45.2
# memory_threshold_percent 60.0

# Stop port forward
kill %1
```

## Step 8: Create Datadog Monitor and Dashboard

```bash
cd ../datadog

# Make sure your API keys are still set
echo $DD_API_KEY
echo $DD_APP_KEY

# If not set, export them again
export DD_API_KEY='your-api-key'
export DD_APP_KEY='your-app-key'

# Run the script to create monitor and dashboard
chmod +x create-datadog-resources.sh
./create-datadog-resources.sh

# Note the URLs provided in the output
```
Useful links:

Monitor: https://app.us5.datadoghq.com/monitors/20052095
Dashboard: https://app.us5.datadoghq.com/dashboard/7xz-x7n-6zm

## Step 9: Test the Integration

```bash
# Port forward again
oc port-forward -n datadog-poc svc/memory-monitor-service 8080:8080 &

# Trigger memory load to exceed threshold
curl http://localhost:8080/simulate-load

# Check metrics again
curl http://localhost:8080/metrics | grep memory_threshold_exceeded_total


# The counter should have incremented

# Stop port forward
kill %1
```

## Step 10: View in Datadog

1. **Open Dashboard**
   - Go to the dashboard URL from Step 8
   - You should see memory usage graphs
   - Wait 5-10 minutes for data to populate

2. **Check Monitor**
   - Go to the monitor URL from Step 8
   - Wait 5-10 minutes for the alert to trigger
   - Status should change to "Alert" when threshold is exceeded

## Troubleshooting

### Datadog Operator Not Installing
```bash
# Check operator status
oc get csv -n openshift-operators | grep datadog

# Check operator logs
oc logs -n openshift-operators -l name=datadog-operator
```

### Datadog Agent Not Starting
```bash
# Check DatadogAgent resource
oc get datadogagent -n datadog

# Check agent pods
oc get pods -n datadog

# Check agent logs
oc logs -n datadog -l app=datadog-agent
```

### Application Pod Not Starting
```bash
# Check pod status
oc get pods -n datadog-poc

# Describe pod
oc describe pod -n datadog-poc -l app=memory-monitor

# Check logs
oc logs -n datadog-poc -l app=memory-monitor
```

### Metrics Not Appearing in Datadog
```bash
# Check ServiceMonitor
oc get servicemonitor -n datadog-poc

# Check if Datadog is scraping
oc logs -n datadog -l app=datadog-agent | grep prometheus

# Wait 10-15 minutes for initial sync
```

## Quick Commands Reference

```bash
# Check all resources
oc get all -n datadog-poc
oc get all -n datadog

# View application logs
oc logs -n datadog-poc -l app=memory-monitor -f

# View Datadog agent logs
oc logs -n datadog -l app=datadog-agent -f

# Restart application
oc rollout restart deployment/memory-monitor-app -n datadog-poc

# Delete everything
oc delete namespace datadog-poc
oc delete namespace datadog
```

## Cleanup

```bash
cd examples/datadog-integration-poc
./cleanup.sh
```

## Summary

You've successfully:
✅ Logged into OpenShift cluster  
✅ Installed Datadog Operator  
✅ Created Datadog API key secret  
✅ Deployed Datadog Agent  
✅ Built and deployed sample application  
✅ Created Datadog monitor and dashboard  
✅ Verified metrics are flowing  
✅ Triggered alerts  

**Next Steps**: Monitor your application in Datadog and customize as needed!