# Monitor Calico component metrics

## Monitoring via Prometheus

[Monitor Calico component metrics](https://docs.projectcalico.org/maintenance/monitor/monitor-component-metrics)
[Visualizing metrics via Grafana](https://docs.projectcalico.org/maintenance/monitor/monitor-component-visual)

```bash
# Configure Calico to enable metrics reporting
calicoctl patch felixConfiguration default  --patch '{"spec":{"prometheusMetricsEnabled": true}}'

# Creating a service to expose Felix metrics
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: felix-metrics-svc
  namespace: kube-system
  labels:
    calico-prometheus-access: true
spec:
  selector:
    k8s-app: calico-node
  ports:
  - port: 9091
    targetPort: 9091
EOF

# Cluster preparation
# Namespace isolates resources in your cluster. Here you will create a Namespace called calico-monitoring to hold your monitoring resources.

kubectl apply -f -<<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: calico-monitoring
  labels:
    app:  ns-calico-monitoring
    role: monitoring
EOF

# Service account creation
# You need to provide Prometheus a serviceAccount with required permissions to collect information from Calico.

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: calico-prometheus-user
rules:
- apiGroups: [""]
  resources:
  - endpoints
  - services
  - pods
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: calico-prometheus-user
  namespace: calico-monitoring
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: calico-prometheus-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: calico-prometheus-user
subjects:
- kind: ServiceAccount
  name: calico-prometheus-user
  namespace: calico-monitoring
EOF

# Install prometheus - Create prometheus config file
# We can configure Prometheus using a ConfigMap to persistently store the desired settings.

kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: calico-monitoring
data:
  prometheus.yml: |-
    global:
      scrape_interval:   15s
      external_labels:
        monitor: 'tutorial-monitor'
    scrape_configs:
    - job_name: 'prometheus'
      scrape_interval: 5s
      static_configs:
      - targets: ['localhost:9090']
    - job_name: 'felix_metrics'
      scrape_interval: 5s
      scheme: http
      kubernetes_sd_configs:
      - role: endpoints
      relabel_configs:
      - source_labels: [__meta_kubernetes_service_name]
        regex: felix-metrics-svc
        replacement: $1
        action: keep
    - job_name: 'typha_metrics'
      scrape_interval: 5s
      scheme: http
      kubernetes_sd_configs:
      - role: endpoints
      relabel_configs:
      - source_labels: [__meta_kubernetes_service_name]
        regex: typha-metrics-svc
        replacement: $1
        action: keep
EOF

# Create Prometheus pod
# Now that you have a serviceaccount with permissions to gather metrics and have a valid config file for your Prometheus, it’s time to create the Prometheus pod.

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: prometheus-pod
  namespace: calico-monitoring
  labels:
    app: prometheus-pod
    role: monitoring
    calico-prometheus-access: true
spec:
  serviceAccountName: calico-prometheus-user
  containers:
  - name: prometheus-pod
    image: prom/prometheus
    resources:
      limits:
        memory: "128Mi"
        cpu: "500m"
    volumeMounts:
    - name: config-volume
      mountPath: /etc/prometheus/prometheus.yml
      subPath: prometheus.yml
    ports:
    - containerPort: 9090
  volumes:
  - name: config-volume
    configMap:
      name: prometheus-config
EOF

# Check your cluster pods to assure pod creation was successful and prometheus pod is Running.

kubectl get pods prometheus-pod -n calico-monitoring

# View metrics
# You can access prometheus dashboard by using port-forwarding feature.

kubectl port-forward pod/prometheus-pod 9090:9090 -n calico-monitoring

# Browse to http://localhost:9090 you should be able to see prometheus dashboard.
# Type felix_active_local_endpoints in the Expression input textbox then hit the execute button.
# Console table should be populated with all your nodes and quantity of endpoints in each of them.

# ---------- Secure -----------------

[Securing prometheus Metrics](https://docs.projectcalico.org/security/comms/secure-metrics)

# Create a default network policy to allow host traffic
calicoctl delete -f - <<EOF
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: default-host
spec:
  # Select all Calico nodes.
  selector: running-calico == "true"
  order: 5000
  ingress:
  - action: Allow
  egress:
  - action: Allow
EOF

# Create host endpoints for each Calico node.

calicoctl apply -f - <<EOF
apiVersion: projectcalico.org/v3
kind: HostEndpoint
metadata:
  name: master.eth1
  labels:
    running-calico: "true"
spec:
  node: master
  interfaceName: eth1
  expectedIPs:
  - 192.168.50.10
---
apiVersion: projectcalico.org/v3
kind: HostEndpoint
metadata:
  name: worker1.eth1
  labels:
    running-calico: "true"
spec:
  node: worker1
  interfaceName: eth1
  expectedIPs:
  - 192.168.50.11
---
apiVersion: projectcalico.org/v3
kind: HostEndpoint
metadata:
  name: worker2.eth1
  labels:
    running-calico: "true"
spec:
  node: worker2
  interfaceName: eth1
  expectedIPs:
  - 192.168.50.12
EOF

# Create a network policy that restricts access to the calico/node Prometheus metrics port.

# Allow traffic to Prometheus only from sources that are
# labeled as such, but don't impact any other traffic.

calicoctl delete -f - <<EOF
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: restrict-calico-node-prometheus
spec:
  # Select all Calico nodes.
  selector: running-calico == "true"
  order: 500
  types:
  - Ingress
  ingress:
  # Deny anything that tries to access the Prometheus port
  # but that doesn't match the necessary selector.
  - action: Deny
    protocol: TCP
    source:
      notSelector: calico-prometheus-access == "true"
    destination:
      ports:
      - 9091
EOF

calicoctl apply -f - <<EOF
---
apiVersion: projectcalico.org/v3
kind: NetworkPolicy
metadata:
  name: grafana-to-prometheus
  namespace: calico-monitoring
spec:
  order: 0
  selector: app == 'prometheus-pod'
  ingress:
    - action: Allow
      source: {}
      destination: {}
  egress:
    - action: Allow
      source: {}
      destination: {}
---
apiVersion: projectcalico.org/v3
kind: NetworkPolicy
metadata:
  name: prometheus-to-grafana
  namespace: calico-monitoring
spec:
  order: 0
  selector: app == 'grafana-pod'
  ingress:
    - action: Allow
      source: {}
      destination: {}
  egress:
    - action: Allow
      source: {}
      destination: {}
EOF

# Apply labels to any endpoints that should have access to the metrics.
kubectl label pod prometheus-pod calico-prometheus-access=true -n calico-monitoring
kubectl label pod grafana-pod calico-prometheus-access=true -n calico-monitoring
kubectl get pods --show-labels -n calico-monitoring

# Cleanup
# By executing below commands, you will delete all the resource and services created by following this tutorial.

kubectl delete service felix-metrics-svc -n kube-system
kubectl delete namespace calico-monitoring
kubectl delete ClusterRole calico-prometheus-user
kubectl delete clusterrolebinding calico-prometheus-user
```

## Visualizing metrics via Grafana

```bash
# Preparing Promethues
# Here you will create a service to make your prometheus visible to Grafana.

kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: prometheus-dashboard-svc
  namespace: calico-monitoring
spec:
  selector:
      app:  prometheus-pod
      role: monitoring
  ports:
  - port: 9090
    targetPort: 9090
EOF

# Preparing Grafana pod
# Provisioning datasource

# Grafana datasources are storage backends for your time series data.
# Each data source has a specific Query Editor that is customized for the features and capabilities that the particular data source exposes.
# In this section you will use Grafana provisioning capabilities to create a prometheus datasource.
# Here You setup a datasource and pointing it to the prometheus service in your cluster.

# Provisioning Calico dashboards
# Here you will create a configmap with Felix and Typha dashboards.

kubectl apply -f https://docs.projectcalico.org/manifests/grafana-dashboards.yaml

# Creating Grafana pod
# In this step you are going to create your Grafana pod using the config file that was created earlier.

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: grafana-pod
  namespace: calico-monitoring
  labels:
    app:  grafana-pod
    role: monitoring
spec:
  containers:
  - name: grafana-pod
    image: grafana/grafana:latest
    resources:
      limits:
        memory: "128Mi"
        cpu: "500m"
    volumeMounts:
    - name: grafana-config-volume
      mountPath: /etc/grafana/provisioning/datasources
    - name: grafana-dashboards-volume
      mountPath: /etc/grafana/provisioning/dashboards
    - name: grafana-storage-volume
      mountPath: /var/lib/grafana
    ports:
    - containerPort: 3000
  volumes:
  - name: grafana-storage-volume
    emptyDir: {}
  - name: grafana-config-volume
    configMap:
      name: grafana-config
  - name: grafana-dashboards-volume
    configMap:
      name: grafana-dashboards-config
EOF

# Accessing Grafana Dashboard

# At this step You have configured all the necessary components in order to view your Grafana dashboards. By using port-forward feature expose Grafana to your local machine.

kubectl port-forward pod/grafana-pod 3000:3000 -n calico-monitoring

# You can now access Grafana web-ui at http://localhost:3000, if you prefer to visit Felix dashboard directly click [here](http://localhost:3000/d/calico-felix-dashboard/felix-dashboard-calico?orgId=1).
# Note: Both username and password are admin.
# After login you will be prompted to change the default password, you can either change it here (Recommended) and click Save or click Skip and do it later from settings.

# Cleanup

# By executing below command, you will delete all Calico monitoring resources, including the ones created by following this tutorial, and the monitor component metrics guide.

kubectl delete namespace calico-monitoring
```
