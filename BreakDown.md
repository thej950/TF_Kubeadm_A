### main.tf file BreakDown
### **Provider Configuration**
```hcl
provider "aws" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}
```
- Configures the AWS provider with the `region`, `access_key`, and `secret_key` variables.
- These are required to authenticate and interact with AWS resources.

---

### **VPC (Virtual Private Cloud)**
#### **1. VPC Resource**
```hcl
resource "aws_vpc" "some_custom_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "K8S VPC"
  }
}
```
- Creates a VPC with a CIDR block `10.0.0.0/16`.
- Tags the VPC as "K8S VPC."

---

#### **2. Random Availability Zone Selection**
```hcl
resource "random_shuffle" "az" {
  input        = ["${var.region}a", "${var.region}b", "${var.region}c", "${var.region}d", "${var.region}e"]
  result_count = 1
}
```
- Randomly selects one availability zone (e.g., `us-east-1a`) for subnet creation from the region's availability zones.

---

#### **3. Public Subnet**
```hcl
resource "aws_subnet" "some_public_subnet" {
  vpc_id            = aws_vpc.some_custom_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = random_shuffle.az.result[0]

  tags = {
    Name = "K8S Subnet"
  }
}
```
- Creates a public subnet in the VPC, using a CIDR block `10.0.1.0/24`.
- The `availability_zone` is determined randomly by the `random_shuffle` resource.

---

#### **4. Internet Gateway**
```hcl
resource "aws_internet_gateway" "some_ig" {
  vpc_id = aws_vpc.some_custom_vpc.id

  tags = {
    Name = "K8S Internet Gateway"
  }
}
```
- Creates an internet gateway and associates it with the VPC.

---

#### **5. Public Route Table**
```hcl
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.some_custom_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.some_ig.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.some_ig.id
  }

  tags = {
    Name = "Public Route Table"
  }
}
```
- Creates a route table that routes all IPv4 (`0.0.0.0/0`) and IPv6 (`::/0`) traffic to the internet gateway.

---

#### **6. Route Table Association**
```hcl
resource "aws_route_table_association" "public_1_rt_a" {
  subnet_id      = aws_subnet.some_public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}
```
- Associates the public subnet with the public route table, enabling internet access.

---

### **Security Group**
```hcl
resource "aws_security_group" "k8s_sg" {
  name   = "K8S Ports"
  vpc_id = aws_vpc.some_custom_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress { ... } // Other ports for Kubernetes and SSH
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```
- Creates a security group allowing inbound traffic for:
  - HTTP (`80`), Kubernetes API (`6443`), etc.
  - Allows all outbound traffic.

---

### **S3 Bucket**
#### **1. Random Bucket Name**
```hcl
resource "random_string" "s3name" {
  length  = 9
  special = false
  upper   = false
  lower   = true
}
```
- Generates a random string for the S3 bucket name.

#### **2. S3 Bucket**
```hcl
resource "aws_s3_bucket" "s3buckit" {
  bucket        = "k8s-${random_string.s3name.result}"
  force_destroy = true
  depends_on    = [random_string.s3name]
}
```
- Creates an S3 bucket with a random name (e.g., `k8s-abcdefghi`).
- Ensures the bucket is deleted when Terraform destroys the infrastructure.

---

### **EC2 Instances**
#### **1. Master Node**
```hcl
resource "aws_instance" "ec2_instance_msr" {
  ami                         = var.ami_id
  subnet_id                   = aws_subnet.some_public_subnet.id
  instance_type               = var.instance_type
  key_name                    = var.ami_key_pair_name
  associate_public_ip_address = true
  security_groups             = [aws_security_group.k8s_sg.id]
  user_data_base64 = base64encode("${templatefile("scripts/install_k8s_msr.sh", { ... })}")

  depends_on = [
    aws_s3_bucket.s3buckit,
    random_string.s3name
  ]
}
```
- Creates the master node for the Kubernetes cluster.
- Installs required software using a script (`install_k8s_msr.sh`) with variables passed in.

#### **2. Worker Nodes**
```hcl
resource "aws_instance" "ec2_instance_wrk" {
  count                       = var.number_of_worker
  ami                         = var.ami_id
  subnet_id                   = aws_subnet.some_public_subnet.id
  instance_type               = var.instance_type
  key_name                    = var.ami_key_pair_name
  associate_public_ip_address = true
  security_groups             = [aws_security_group.k8s_sg.id]
  user_data_base64 = base64encode("${templatefile("scripts/install_k8s_wrk.sh", { ... })}")

  depends_on = [
    aws_s3_bucket.s3buckit,
    aws_instance.ec2_instance_msr
  ]
}
```
- Creates worker nodes for the Kubernetes cluster, with the number specified by `var.number_of_worker`.
- Each worker is initialized using a script (`install_k8s_wrk.sh`).

---

### **Key Takeaways**
This configuration:
1. Creates a VPC with a public subnet and internet access.
2. Sets up an S3 bucket for storing Kubernetes-related data.
3. Deploys EC2 instances for the master and worker nodes.
4. Configures security groups to allow necessary traffic for Kubernetes and SSH.

Let me know if you'd like to dive deeper into any part!



===

This script is designed to configure a **Kubernetes worker node** on an **Ubuntu-based EC2 instance** and join it to an existing Kubernetes cluster. Here's a **breakdown** of each section:

---

### **Hostname Configuration**
```bash
hostname k8s-Worker-${worker_number}
echo "k8s-Worker-${worker_number}" > /etc/hostname
```
- Sets the hostname of the worker node to `k8s-Worker-{worker_number}`, where `${worker_number}` is dynamically passed during deployment.
- Updates the `/etc/hostname` file to persist the hostname across reboots.

---

### **Environment Variable Setup**
```bash
export AWS_ACCESS_KEY_ID=${access_key}
export AWS_SECRET_ACCESS_KEY=${private_key}
export AWS_DEFAULT_REGION=${region}
```
- Sets environment variables for AWS CLI to allow the worker node to interact with AWS services (e.g., downloading the Kubernetes join script from S3).

---

### **System Updates and Docker Installation**
```bash
apt update
apt install apt-transport-https ca-certificates curl software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"

apt update
apt-cache policy docker-ce
apt install docker-ce -y
apt install awscli -y
```
1. Updates the system package repository (`apt update`).
2. Installs prerequisites for Docker (e.g., `apt-transport-https`, `ca-certificates`, `curl`).
3. Adds Docker's official GPG key and repository for Ubuntu 20.04 (Focal).
4. Installs Docker CE (Community Edition) and AWS CLI.

---

### **Kubernetes Repository Configuration**
```bash
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add
echo "deb https://packages.cloud.google.com/apt kubernetes-xenial main" > /etc/apt/sources.list.d/kurbenetes.list
```
- Adds Kubernetes’ GPG key and repository for downloading Kubernetes components.

---

### **Disable Swap**
```bash
swapoff -a
```
- Disables swap memory on the node. Kubernetes does not support swap as it expects predictable resource allocation.

---

### **Install Kubernetes Components**
```bash
apt update
apt install kubelet kubeadm kubectl -y
```
- Installs Kubernetes tools:
  - `kubelet`: The agent running on every Kubernetes node.
  - `kubeadm`: Tool to bootstrap the cluster.
  - `kubectl`: CLI for interacting with Kubernetes.

---

### **Retrieve the Node's Internal IP**
```bash
export ipaddr=`ip address|grep eth0|grep inet|awk -F ' ' '{print $2}' |awk -F '/' '{print $1}'`
```
- Retrieves the internal IP address of the node (using `eth0` interface) and stores it in the variable `ipaddr`.

---

### **Containerd Fix**
```bash
rm /etc/containerd/config.toml
systemctl restart containerd
```
- Removes the default `containerd` configuration file and restarts the service to ensure compatibility with Kubernetes.

---

### **Wait for Master Node Initialization**
```bash
sleep 1m
```
- Waits for the master node to complete initialization, ensuring the join command is ready.

---

### **Retrieve and Execute Join Command**
```bash
aws s3 cp s3://${s3buckit_name}/join_command.sh /tmp/.
chmod +x /tmp/join_command.sh
bash /tmp/join_command.sh
```
1. Downloads the `join_command.sh` script from the S3 bucket.
2. Makes the script executable.
3. Executes the script to join the worker node to the Kubernetes cluster.

---

### **Purpose**
This script:
1. Configures an EC2 instance as a Kubernetes worker node.
2. Ensures it has the required tools (Docker, Kubernetes components).
3. Fetches and executes the join command to add the node to an existing Kubernetes cluster.

Let me know if you'd like more details on any part!

===

This script sets up a **Kubernetes master node** on an Ubuntu-based EC2 instance. Below is a detailed breakdown:

---

### **Hostname Configuration**
```bash
hostname k8s-Master
echo "k8s-Master" > /etc/hostname
```
- Sets the hostname of the master node to `k8s-Master`.
- Persists the hostname across reboots by writing it to `/etc/hostname`.

---

### **Environment Variables for AWS**
```bash
export AWS_ACCESS_KEY_ID=${access_key}
export AWS_SECRET_ACCESS_KEY=${private_key}
export AWS_DEFAULT_REGION=${region}
```
- Configures AWS CLI with credentials to allow the master node to interact with AWS services (e.g., uploading the `join_command.sh` script to S3).

---

### **System Updates and Docker Installation**
```bash
apt update
apt install apt-transport-https ca-certificates curl software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
apt update
apt-cache policy docker-ce
apt install docker-ce -y
apt install awscli -y
```
1. Updates package repositories.
2. Installs Docker dependencies and the official Docker GPG key.
3. Adds Docker’s repository for Ubuntu 20.04 (Focal) and installs Docker CE (Community Edition).
4. Installs AWS CLI for AWS service interactions.

---

### **Adding Kubernetes Repositories**
```bash
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add
echo "deb https://packages.cloud.google.com/apt kubernetes-xenial main" > /etc/apt/sources.list.d/kurbenetes.list
```
- Adds Kubernetes' GPG key and repository for downloading Kubernetes components.

---

### **Disable Swap**
```bash
swapoff -a
```
- Disables swap memory, as Kubernetes does not support systems with active swap.

---

### **Install Kubernetes Components**
```bash
apt update
apt install kubelet kubeadm kubectl -y
```
- Installs Kubernetes tools:
  - `kubelet`: Node agent.
  - `kubeadm`: Tool for cluster initialization.
  - `kubectl`: CLI for managing Kubernetes.

---

### **Retrieve Node IPs**
```bash
export ipaddr=`ip address|grep eth0|grep inet|awk -F ' ' '{print $2}' |awk -F '/' '{print $1}'`
export pubip=`dig +short myip.opendns.com @resolver1.opendns.com`
```
- Retrieves:
  - `ipaddr`: Internal IP address of the node (using `eth0` interface).
  - `pubip`: Public IP address of the node (using OpenDNS).

---

### **Fix for `containerd`**
```bash
rm /etc/containerd/config.toml
systemctl restart containerd
```
- Removes the default `containerd` configuration and restarts it to ensure compatibility with Kubernetes.

---

### **Initialize Kubernetes Cluster**
```bash
kubeadm init --apiserver-advertise-address=$ipaddr --pod-network-cidr=172.16.0.0/16 --apiserver-cert-extra-sans=$pubip > /tmp/restult.out
cat /tmp/restult.out
```
- Initializes the Kubernetes master node:
  - `--apiserver-advertise-address=$ipaddr`: Sets the advertised API server address.
  - `--pod-network-cidr=172.16.0.0/16`: Specifies the CIDR for the pod network.
  - `--apiserver-cert-extra-sans=$pubip`: Adds the public IP to the API server certificate SAN list.
- Logs the initialization result to `/tmp/restult.out`.

---

### **Extract and Upload Join Command**
```bash
tail -2 /tmp/restult.out > /tmp/join_command.sh
aws s3 cp /tmp/join_command.sh s3://${s3buckit_name}
```
1. Extracts the last two lines of `/tmp/restult.out` (which typically contain the join command) and writes them to `/tmp/join_command.sh`.
2. Uploads `join_command.sh` to the specified S3 bucket.

---

### **Configure Kubernetes for Root and Ubuntu Users**
```bash
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
cp -i /etc/kubernetes/admin.conf /tmp/admin.conf
chmod 755 /tmp/admin.conf

mkdir -p /home/ubuntu/.kube
cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chmod 755 /home/ubuntu/.kube/config
```
- Sets up Kubernetes configuration (`.kube/config`) for:
  - The root user (`/root/.kube`).
  - The Ubuntu user (`/home/ubuntu/.kube`).

---

### **Optional: Pod Network Setup (Calico)**
```bash
curl -o /root/calico.yaml https://docs.projectcalico.org/v3.16/manifests/calico.yaml
sleep 5
kubectl --kubeconfig /root/.kube/config apply -f /root/calico.yaml
systemctl restart kubelet
```
- Downloads the Calico YAML manifest for setting up a pod network.
- Applies the manifest using `kubectl`.

---

### **Kubectl Autocomplete and Aliases**
```bash
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> /home/ubuntu/.bashrc
echo "source <(kubectl completion bash)" >> /root/.bashrc

alias k=kubectl
complete -o default -F __start_kubectl k
echo "alias k=kubectl" >> /home/ubuntu/.bashrc
echo "alias k=kubectl" >> /root/.bashrc
echo "complete -o default -F __start_kubectl k" >> /home/ubuntu/.bashrc
echo "complete -o default -F __start_kubectl k" >> /root/.bashrc
```
- Sets up command autocompletion for `kubectl`.
- Adds a shortcut alias (`k`) for `kubectl`.

---

### **Purpose**
1. **Configures the master node** for Kubernetes cluster management.
2. **Initializes the cluster** with a pod network.
3. Prepares the master node to allow worker nodes to join via the `join_command.sh`.
