# Walkthrough

```bash
# open the terminal in k8s-iac directory
vagrant up

# Configure routing in testvm
vagrant ssh testvm
sudo rc-update add staticroute
sudo vi /etc/route.conf
net 192.168.50.0 netmask 255.255.255.0 gw 192.168.150.254
sudo /etc/init.d/staticroute restart
ping 192.168.50.10

# Connect to tor

# Ensure you are receiving bgp routes from the cluster
net show route
```

## Deploy Bookinfo App

### Create namespace for `dev1`

```bash
kubectl get namespace
kubectl create ns dev1
kubectl get namespace
```

### Deploy the bookinfo app in `dev1` namespace

```bash
kubectl apply -f manifests/bookinfo.yaml -n dev1

# Its going to take some time for the app to be deployed...
# Watch the pods and make sure they are running. Its going to take roughly 4 min
watch kubectl get pods --show-labels -n dev1
kubectl get svc -n dev1
kubectl get pods --show-labels -n dev1

# Test from cluster, tor and testvm

wget -q --timeout=5 192.168.50.150 -O -

# ------ Browse to http://192.168.50.150 and click the Normal User and Test User ------
# ------ and observe that book details and reviews with stars are shown. ------
# ------ also ensure that the reviews are being load balanced ------
```

### Lockdown the cluster with deny all

```bash
calicoctl get globalNetworkPolicy
calicoctl apply -f manifests/fw-deny.yaml
calicoctl get globalNetworkPolicy

# Test
wget -q --timeout=5 192.168.50.150 -O -

# You wont be able to connect
```

### Allow ingress traffic to DMZ

```bash
calicoctl get networkpolicies  -n dev1
calicoctl apply -f manifests/fw-dmz.yaml
calicoctl get networkpolicies  -n dev1

# Test

wget -q --timeout=5 192.168.50.150 -O -
# Browse to http://192.168.50.150 You will be able to connect, however when you click the normal user and test user link you will see connectivity issue with details and ratings.

# Test POD connectivities....
# Internet will work but not to other svc
kubectl run -it --namespace=dev1 --rm -l fw-zone=dmz --image praqma/network-multitool hackon  -- bash
ping google.com
kubectl get svc -n dev1
telnet 10.49.61.201 9080
telnet 10.49.252.125 9080
telnet 10.49.21.248 9080
```

### Allow DMZ to connect to Frontend zone

```bash
calicoctl apply -f manifests/fw-frontend.yaml
calicoctl get networkpolicies  -n dev1

# Test
#Browse to http://192.168.50.150 You will be able to connect and see the details and reviews but not ratings.

# Test POD connectivities....from DMZ
# details and reviews will work.
# ratings wont work
kubectl run -it --namespace=dev1 --rm -l fw-zone=dmz --image praqma/network-multitool hackon  -- bash
ping google.com
kubectl get svc -n dev1
telnet 10.49.163.139 9080
telnet 10.49.226.242 9080
telnet 10.49.21.248 9080

# Test POD connectivities....from Frontend
# ratings wont work
kubectl run -it --namespace=dev1 --rm -l fw-zone=frontend --image praqma/network-multitool hackon  -- bash
telnet 10.49.21.248 9080
```

### Allow Frontend to connect to Backtend zone

```bash
calicoctl apply -f manifests/fw-backend.yaml
calicoctl get networkpolicies  -n dev1

# Test
# Browse to http://192.168.50.150 You will be able to connect and see the details, reviews and ratings.

# Test POD connectivities....from Frontend
# ratings will work
kubectl run -it --namespace=dev1 --rm -l fw-zone=frontend --image praqma/network-multitool hackon  -- bash
telnet 10.49.21.248 9080
```

### Clean up

```bash
calicoctl delete -f manifests/fw-dmz.yaml
calicoctl delete -f manifests/fw-frontend.yaml
calicoctl delete -f manifests/fw-backend.yaml
calicoctl delete -f manifests/fw-deny.yaml
kubectl delete -f manifests/bookinfo.yaml -n dev1
kubectl delete namespace dev1
```
