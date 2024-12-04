# Terraform to Bulding Kubernetes Cluster using EC2 instances
I build this project to create my own lab for [Kuberntes](https://kubernetes.io/) cluster on AWS cloud using EC2 instances. I found [Terraform](https://www.terraform.io) is best tool to create my K8S lab fastly with one command 🚀.
<p align="center">

![Terraform](https://i.imgur.com/PuS3rmb.png)
</p>

## Terraform Resources Used
- EC2
  - One Master Node
  - Two Worker Node (can be increased)
- VPC
  - Public Subnet
  - Internet Gateway
  - Route Table
  - Security Group
- S3 Bucket

<hr>

## How Will the Kubernetes Cluster Be Built?
The goals is to build K8S cluster with one master node and two worker nodes.
<br>

 * First, the master node will boots up and will start installing <b>kubeadm</b>, <b>kubelet</b>, <b>kubectl</b>, and <b>docker</b>. Then will run `kubeadm init` to initial the k8s cluster. <br>
Here the challenge become, how to get the join command that showed after init the cluster and send it to the workers node for joining the worker node into the cluster 🤔? <br>
 To solve this problem I use <b>s3 bucket</b>. First I extract the join command and saved into a file, then push it to s3 object. Now we finish from master node and is ready.
<br>

 * Second, the workers node will boots up and will start installing <b>kubeadm</b>, <b>kubelet</b>, <b>kubectl</b>, and <b>docker</b>. Then will featch the joind command from <b>s3 bucket</b> and excuted to join the worker node into cluster.

<hr>

 ## Incress Number of Worker Nodes
 * By default there are two workers on the cluster, to incress it go to `variables.tf` file and looking for <b>number_of_worker</b> variable, you can incress the default number.

<hr>

 ## Requirements Before Running
  1- Make sure you have the terrafrom tools installed on your machine.

  2- Add your Access key, Secret key and Key Pair name on `variables.tf` file.

  3- Make sure your IAM user has right permission to creating EC2, VPC, S3, Route Table, Security Group and Internet Gateway.

## Running the Script
 - After doing the requirements, you are ready now, start clone the repo to your machine:
  ``` shell
  git clone https://github.com/thej950/kubeadm-tf.git
  cd kubeadm-tf/
  ```
 - Now execute terraform commands:
    ``` shell
    terraform init
    terraform plan #to show what going to build
    terraform apply
    ```

 ## Accessing Your Cluster
  * You can access your cluster by accessing the master node throw <b>ssh</b>, you can get the public IP of master node from terrform outputs. Below is example of ssh command:
  ``` shell
  ssh -i <Your_Key_Piar> ubuntu@<MasterNode_Public_IP>
  ```

  * Another way to access the cluster by download the `admin.conf` file from master node to your machine, find below the way to download it and aceess the cluster remotely.
  ``` shell
  scp -i <Your_Key_Piar> ubuntu@<MasterNode_Public_IP>:/tmp/admin.conf .
  ```
 - This will download the kubernetes config file on your machine. Before using this config file, you have to replace the private ip to public ip of master node. Then you can fastly used by following command to start accessing the cluster.
  ```shell
  kubectl --kubeconfig ./admin.conf get nodes
  ```
  - To check cluster using above command  

 ## Removing and Destroying Kuberntes Cluster
  - To destroy the hole resources that created after applying the script, just run the following command:
  ```shell
  terraform destroy
  ```

  > To access machine upload pub file into aws console

  > Note: To Work kubectl get nodes in windows make sure admin.conf need to available in the system then create environment for admin.conf file to access automatically without using --kubeconfig ./admin.cinf in the command line 



# To setup enviroment in windows 

  In Windows, we can set the `KUBECONFIG` environment variable to point to the location of your `admin.conf` file. Follow these steps:

  ### Using Command Prompt:

    1. Open Command Prompt as an administrator.

    2. Navigate to the directory where your `admin.conf` file is located.

    3. Set the `KUBECONFIG` environment variable:

        ```bash
        set KUBECONFIG=%cd%\admin.conf
        ```

       This command sets the `KUBECONFIG` variable to the absolute path of your `admin.conf` file.

    4. Verify the configuration:

        ```bash
        kubectl config view
        ```

       This command displays the current configuration, and you should see the contents of your `admin.conf` file.

  ### Using PowerShell:

    1. Open PowerShell as an administrator.

    2. Navigate to the directory where your `admin.conf` file is located.

    3. Set the `KUBECONFIG` environment variable:

        ```powershell
        $env:KUBECONFIG = (Get-Item .\admin.conf).FullName
        ```

       This command sets the `KUBECONFIG` variable to the absolute path of your `admin.conf` file.

    4. Verify the configuration:

        ```powershell
        kubectl config view
        ```

       This command displays the current configuration, and you should see the contents of your `admin.conf` file.

  After setting the `KUBECONFIG` variable, any subsequent `kubectl` commands will use the configuration from your `admin.conf` file.

  Remember that these environment variable changes are only effective in the current session. If you close the Command Prompt or PowerShell window, you'll need to set the `KUBECONFIG` variable again when you open a new session. Alternatively, you can set the variable in your system environment variables to make it persistent across sessions.


# Output

  =========================OUTPUT IN POWERSHELL====================
    
    PS C:\Users\DELL> $env:KUBECONFIG = (Get-Item .kube\admin.conf).FullName
    
    PS C:\Users\DELL> kubectl config view
      apiVersion: v1
      clusters:
      - cluster:
          certificate-authority-data: DATA+OMITTED
          server: https://52.3.249.210:6443
        name: kubernetes
      contexts:
      - context:
          cluster: kubernetes
          user: kubernetes-admin
        name: kubernetes-admin@kubernetes
      current-context: kubernetes-admin@kubernetes
      kind: Config
      preferences: {}
      users:
      - name: kubernetes-admin
        user:
          client-certificate-data: DATA+OMITTED
          client-key-data: DATA+OMITTED
      PS C:\Users\DELL>

    PS C:\Users\DELL> kubectl get nodes
      NAME           STATUS   ROLES           AGE     VERSION
      k8s-master     Ready    control-plane   10m     v1.28.2
      k8s-worker-1   Ready    <none>          9m39s   v1.28.2
      k8s-worker-2   Ready    <none>          9m27s   v1.28.2
      PS C:\Users\DELL>

    PS C:\Users\DELL> kubectl get ns
      NAME              STATUS   AGE
      default           Active   17m
      kube-node-lease   Active   17m
      kube-public       Active   17m
      kube-system       Active   17m
      PS C:\Users\DELL>

    PS C:\Users\DELL> kubectl get -n kube-system pods
      NAME                                       READY   STATUS    RESTARTS   AGE
      calico-kube-controllers-55d4447865-txsth   1/1     Running   0          15m
      calico-node-klnkn                          0/1     Running   0          15m
      calico-node-sxl7m                          0/1     Running   0          15m
      calico-node-wvkww                          0/1     Running   0          15m
      coredns-5dd5756b68-8x8dr                   1/1     Running   0          15m
      coredns-5dd5756b68-9b7lh                   1/1     Running   0          15m
      etcd-k8s-master                            1/1     Running   0          15m
      kube-apiserver-k8s-master                  1/1     Running   0          15m
      kube-controller-manager-k8s-master         1/1     Running   0          15m
      kube-proxy-bv2xh                           1/1     Running   0          15m
      kube-proxy-xr9k6                           1/1     Running   0          15m
      kube-proxy-z5nd7                           1/1     Running   0          15m
      kube-scheduler-k8s-master                  1/1     Running   0          15m
      PS C:\Users\DELL>
  =====================================================================