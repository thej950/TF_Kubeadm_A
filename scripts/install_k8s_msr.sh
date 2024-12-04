#!/bin/bash

LOG_FILE="/var/log/k8s-setup.log"
touch $LOG_FILE
exec > >(tee -a $LOG_FILE) 2>&1

echo "######## Starting Kubernetes Master Node Setup ########"

# Set hostname
echo "Setting hostname to k8s-Master"
hostnamectl set-hostname k8s-Master
echo "k8s-Master" > /etc/hostname

# Export AWS credentials
echo "Exporting AWS credentials"
export AWS_ACCESS_KEY_ID="${access_key}"
export AWS_SECRET_ACCESS_KEY="${private_key}"
export AWS_DEFAULT_REGION="${region}"

# Update system and install dependencies
echo "Updating system and installing dependencies"
apt update && apt install -y apt-transport-https ca-certificates curl software-properties-common

# Add Docker repository
echo "Adding Docker repository"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"

# Install Docker
echo "Installing Docker"
apt update && apt install -y docker-ce

# Install AWS CLI
echo "Installing AWS CLI"
apt install -y awscli

# Add Kubernetes repository
echo "Adding Kubernetes repository"
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://packages.cloud.google.com/apt kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list

# Turn off swap
echo "Disabling swap"
swapoff -a

# Install Kubernetes tools
echo "Installing Kubernetes tools (kubelet, kubeadm, kubectl)"
apt update && apt install -y kubelet kubeadm kubectl

# Configure containerd
echo "Configuring containerd"
rm /etc/containerd/config.toml
systemctl restart containerd

# Get instance IP addresses
echo "Getting EC2 instance IP addresses"
ipaddr=$(ip address | grep eth0 | grep inet | awk '{print $2}' | awk -F'/' '{print $1}')
pubip=$(dig +short myip.opendns.com @resolver1.opendns.com)

# Initialize Kubernetes cluster
echo "Initializing Kubernetes cluster"
kubeadm init --apiserver-advertise-address="$ipaddr" --pod-network-cidr=172.16.0.0/16 --apiserver-cert-extra-sans="$pubip" | tee /tmp/result.out

# Save join command
echo "Saving join command"
tail -2 /tmp/result.out > /tmp/join_command.sh
aws s3 cp /tmp/join_command.sh s3://${s3bucket_name}

# Configure kubeconfig
echo "Configuring kubeconfig"
mkdir -p /root/.kube /home/ubuntu/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
cp -i /etc/kubernetes/admin.conf /tmp/admin.conf
chmod 755 /tmp/admin.conf /home/ubuntu/.kube/config /root/.kube/config

# Apply Calico network
echo "Applying Calico network"
curl -o /root/calico.yaml https://docs.projectcalico.org/v3.16/manifests/calico.yaml
kubectl --kubeconfig /root/.kube/config apply -f /root/calico.yaml

# Restart kubelet
echo "Restarting kubelet"
systemctl restart kubelet

# Configure autocomplete and aliases for kubectl
echo "Configuring autocomplete and aliases for kubectl"
echo "source <(kubectl completion bash)" >> /home/ubuntu/.bashrc
echo "source <(kubectl completion bash)" >> /root/.bashrc
echo "alias k=kubectl" >> /home/ubuntu/.bashrc
echo "alias k=kubectl" >> /root/.bashrc
echo "complete -o default -F __start_kubectl k" >> /home/ubuntu/.bashrc
echo "complete -o default -F __start_kubectl k" >> /root/.bashrc

echo "######## Kubernetes Master Node Setup Complete ########"
