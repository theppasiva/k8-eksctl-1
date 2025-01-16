#!/bin/bash

ID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH


TIMESTAMP=$(date +%F-%H-%M-%S)
LOGFILE="/tmp/$0-$TIMESTAMP.log"

echo "script started executing at $TIMESTAMP" &>> $LOGFILE

VALIDATE(){
    if [ $1 -ne 0 ]
    then
        echo -e "$2 ... $R FAILED $N"
        exit 1
    else
        echo -e "$2 ... $G SUCCESS $N"
    fi
}

if [ $ID -ne 0 ]
then
    echo -e "$R ERROR:: Please run this script with root access $N"
    exit 1 # you can give other than 0
else
    echo "You are root user"
fi # fi means reverse of if, indicating condition end

yum install -y yum-utils
VALIDATE $? "Installed yum utils"

yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
VALIDATE $? "Added docker repo"

yum install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
VALIDATE $? "Installed docker components"

systemctl start docker
VALIDATE $? "Started docker"

systemctl enable docker
VALIDATE $? "Enabled docker"

usermod -aG docker centos
VALIDATE $? "added centos user to docker group"
echo -e "$R Logout and login again $N"

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/kubectl
VALIDATE $? "Kubectl installation"

curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz
sudo mv /tmp/eksctl /usr/local/bin
VALIDATE $? "eksctl installation"

sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens
VALIDATE $? "kubens installation"

curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
VALIDATE $? "helm installation"

helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo update
helm upgrade --install aws-ebs-csi-driver \
    --namespace kube-system \
    aws-ebs-csi-driver/aws-ebs-csi-driver
VALIDATE $? "aws-ebs-csi-driver installation through helm"

curl -sS https://webinstall.dev/k9s | bash
VALIDATE $? "k9's installation"

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
VALIDATE $? "metrics server installation"

#load balancer creation steps
# eksctl utils associate-iam-oidc-provider \
#     --region us-east-1 \
#     --cluster roboshop \
#     --approve
# VALIDATE $? "IAM OIDC installation"

# curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.11.0/docs/install/iam_policy.json
# VALIDATE $? "download IAM policy"

# aws iam create-policy \
#     --policy-name AWSLoadBalancerControllerIAMPolicy \
#     --policy-document file://iam-policy.json
# VALIDATE $? "create policy of IAM policy"

# eksctl create iamserviceaccount \
# --cluster=roboshop \
# --namespace=kube-system \
# --name=aws-load-balancer-controller \
# --attach-policy-arn=arn:aws:iam::891377322331:policy/AWSLoadBalancerControllerIAMPolicy \
# --override-existing-serviceaccounts \
# --region us-east-1 \
# --approve
# VALIDATE $? "create IAM role"

#loadbalancer using helm charts
helm repo add eks https://aws.github.io/eks-charts
VALIDATE $? "create eks repository"
helm install aws-load-balancer-controller eks/aws-load-balancer-controller --set clusterName=roboshop -n kube-system --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller
VALIDATE $? "create eks loadbalancer"
