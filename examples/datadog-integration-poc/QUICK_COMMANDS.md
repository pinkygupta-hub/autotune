# Quick Command Reference

Copy and paste these commands in order once your OpenShift cluster is ready.

## 1. Login to OpenShift

```bash
# Get login command from OpenShift Console → Copy Login Command
oc login --token=<your-token> --server=https://<your-cluster>:6443

# Verify
oc whoami
```

## 2. Set Datadog API Keys

```bash
export DD_API_KEY='your-datadog-api-key'
export DD_APP_KEY='your-datadog-app-key'
```

## 3. Install Datadog Operator (Via Console)

1. OpenShift Console → **Operators** → **OperatorHub**
2. Search "**Datadog Operator**" → **Install**
3. Select "All namespaces" → **Install**
4. Wait for "Succeeded" status

## 4. Create Datadog Secret

```bash
# Create secret in openshift-operators namespace
oc create secret generic datadog-secret \
  --from-literal api-key=${DD_API_KEY} \
  --from-literal app-key=${DD_APP_KEY} \
  -n openshift-operators
```

## 5. Deploy Datadog Agent

```bash
cd examples/datadog-integration-poc/datadog

# Create datadog namespace
oc create namespace datadog

# Copy secret to datadog namespace
oc get secret datadog-secret -n openshift-operators -o yaml | \
  sed 's/namespace: openshift-operators/namespace: datadog/' | \
  oc apply -f -

# Deploy agent
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
EOF

# Wait for pods (takes 2-3 minutes)
oc get pods -n datadog -w
```

## 6. Build Application

```bash
cd ../sample-app

# Build image
docker build -t memory-monitor-app:latest .

# For OpenShift internal registry:
REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')
docker login -u $(oc whoami) -p $(oc whoami -t) $REGISTRY
docker tag memory-monitor-app:latest $REGISTRY/datadog-poc/memory-monitor-app:latest
docker push $REGISTRY/datadog-poc/memory-monitor-app:latest
```

## 7. Deploy Application

```bash
cd ../k8s

oc apply -f namespace.yaml
oc apply -f deployment.yaml
oc apply -f service.yaml
oc apply -f servicemonitor.yaml

# Wait for ready
oc wait --for=condition=ready pod -l app=memory-monitor -n datadog-poc --timeout=300s
```

## 8. Verify Metrics

```bash
oc port-forward -n datadog-poc svc/memory-monitor-service 8080:8080 &
curl http://localhost:8080/metrics
kill %1
```

## 9. Create Monitor & Dashboard

```bash
cd ../datadog
./create-datadog-resources.sh
```

## 10. Trigger Alert

```bash
oc port-forward -n datadog-poc svc/memory-monitor-service 8080:8080 &
curl http://localhost:8080/simulate-load
curl http://localhost:8080/metrics | grep memory_threshold_exceeded_total
kill %1
```

## Troubleshooting Commands

```bash
# Check all resources
oc get all -n datadog-poc
oc get all -n datadog

# Check logs
oc logs -n datadog-poc -l app=memory-monitor -f
oc logs -n datadog -l app=datadog-agent -f

# Check Datadog Agent status
oc get datadogagent -n datadog
oc describe datadogagent datadog -n datadog
```

## Cleanup

```bash
cd examples/datadog-integration-poc
./cleanup.sh
```

---

**For detailed explanations, see**: [`DEPLOYMENT_STEPS.md`](DEPLOYMENT_STEPS.md)