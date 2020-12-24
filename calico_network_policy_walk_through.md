# Calico Network Policy Walk Through

## Open Grafana for visualization

[Grafana](http://localhost:3000/d/calico-felix-dashboard/felix-dashboard-calico?orgId=1)

## Create namespace for `dev1`

```bash
kubectl get namespace
kubectl create ns dev1
kubectl get namespace
```

## Deploy the bookinfo service

```bash
kubectl get svc -n dev1
kubectl apply -f manifests/bookinfo.yaml -n dev1
kubectl get svc -n dev1
kubectl get pods --show-labels -n dev1

# Test

wget -q --timeout=5 192.168.50.150 -O -
# Browse to http://192.168.50.150 and click the Normal User and Test User...and observe that book details and reviews with stars are shown.
```

## Lockdown the cluster with deny all

```bash
calicoctl get globalNetworkPolicy
calicoctl create -f manifests/fw-deny.yaml
calicoctl get globalNetworkPolicy

# Test
wget -q --timeout=5 192.168.50.150 -O -

# You wont be able to connect
```

## Allow ingress traffic to DMZ

```bash
calicoctl get networkpolicies  -n dev1
calicoctl create -f manifests/fw-dmz.yaml
calicoctl get networkpolicies  -n dev1

# Test

wget -q --timeout=5 192.168.50.150 -O -
# Browse to http://192.168.50.150 You will be able to connect, however when you click the normal user and test user link you will see connectivity issue with details and ratings.
```

## Allow DMZ to connect to Frontend zone

```bash
calicoctl create -f manifests/fw-frontend.yaml
calicoctl get networkpolicies  -n dev1

# Test
#Browse to http://192.168.50.150 You will be able to connect and see the details and reviews but not ratings.
```

## Allow Frontend to connect to Backtend zone

```bash
calicoctl create -f manifests/fw-backend.yaml
calicoctl get networkpolicies  -n dev1

# Test
# Browse to http://192.168.50.150 You will be able to connect and see the details, reviews and ratings.
```

## Clean up

```bash
calicoctl delete -f manifests/fw-dmz.yaml
calicoctl delete -f manifests/fw-frontend.yaml
calicoctl delete -f manifests/fw-backend.yaml
calicoctl delete -f manifests/bookinfo.yaml
kubectl delete namespace dev1
calicoctl delete -f manifests/fw-deny.yaml
```
