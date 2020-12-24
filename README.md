# Deploy and Manage Kubernetes Cluster as code

The purpose of this repository to demonstrate setting up of Kubernetes cluster using Ansible and deploying services via Terraform.

## Requirements

- Vagrant
- Ansible
- Terraform

## Running the demo

- Open up `Vagrantfile` and change value of variable `N` to desired number of workers nodes.
- Spin up the stack by issuing `vagrant up`
  - This will automatically setup
    1. Kubernetes Cluster
    2. Calico Network addon
    3. MetalLB, bare metal load-balancer for Kubernetes
- Once deployed the `kubeconfig` file will be available at `setup/admin.conf`

## Verfification

Follow the `00.verification.md` file.

## Calico Policy Walk through

Follow the `calico_network_policy_walk_through.md` file.

## Monitoring Calico

Follow the `calico_monitoring.md` file.

## Running services through Terrafrom

- For deploying services:
  1. `cd terraform/nginx`
  2. `terraform init`
  3. `terraform plan`
  4. `terraform apply -auto-approve`

## Scenario based walk-through

Follow the `walkthrough.md` file.
