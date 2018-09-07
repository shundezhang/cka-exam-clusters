#!/bin/bash

#
# Script that creates the first CKA exam cluster scenario.
#
# Cluster composition:
#   1. etcd-0
#   2. master-0
#   3. worker-0
#   4. worker-1
# 

tool_install_info() {
    unamestr=$(uname)

    if [[ "$unamestr" == 'Linux' ]]
    then
        echo
        echo "kubectl:"
        echo "  wget https://storage.googleapis.com/kubernetes-release/release/v1.11.0/bin/linux/amd64/kubectl"
        echo "  chmod +x kubectl"
        echo "  sudo mv kubectl /usr/local/bin/"
        echo "cfssl:"
        echo "  wget -q --show-progress --https-only --timestamping \
                    https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 \
                    https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64"
        echo "  chmod +x cfssl_linux-amd64 cfssljson_linux-amd64"
        echo "  sudo mv cfssl_linux-amd64 /usr/local/bin/cfssl"
        echo "  sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson"
        echo
    elif [[ "$unamestr" == 'Darwin' ]]
    then
        echo
        echo "kubectl:"
        echo "  curl -o kubectl https://storage.googleapis.com/kubernetes-release/release/v1.11.0/bin/darwin/amd64/kubectl"
        echo "  chmod +x kubectl"
        echo "  sudo mv kubectl /usr/local/bin/"
        echo "cfssl:"
        echo "  curl -o cfssl https://pkg.cfssl.org/R1.2/cfssl_darwin-amd64
  curl -o cfssljson https://pkg.cfssl.org/R1.2/cfssljson_darwin-amd64"
        echo "  chmod +x cfssl cfssljson"
        echo "  sudo mv cfssl cfssljson /usr/local/bin/"
        echo
        echo "Install cfssl with homebrew:"
        echo "  brew install cfssl"
        echo
    fi
}

if ! hash kubectl
then
    echo "Missing kubectl..."
    tool_install_info
    exit 1
elif ! hash cfssl
then
    echo "Missing cfssl..."
    tool_install_info
    exit 1
fi

echo "Creating cluster instances..."
k8s_cluster=(etcd-0 master-0 worker-0 worker-1)

worker_ip_start=20
worker_pod_ip_start=0


echo "Creating certificates..."
mkdir $PWD/k8s-files
cd $PWD/k8s-files

echo "Creating the CA certificate"
{

cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Cloudland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Cloud St"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca

}

echo "Creating the admin certificate..."
{

cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Cloudland",
      "O": "system:masters",
      "OU": "CKA The Hard Way",
      "ST": "Cloud St"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin

}

echo "Creating the kubelet client certificates..."
for instance in knode-2 knode-3; do
cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Cloudland",
      "O": "system:nodes",
      "OU": "CKA The Hard Way",
      "ST": "Cloud St"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${instance} \
  -profile=kubernetes \
  ${instance}-csr.json | cfssljson -bare ${instance}
done

echo "Creating the kube-controller-manager client certificate..."
{

cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Cloudland",
      "O": "system:kube-controller-manager",
      "OU": "CKA The Hard Way",
      "ST": "Cloud St"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

}

echo "Creating the kube-proxy client certificate..."
{

cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Cloudland",
      "O": "system:node-proxier",
      "OU": "CKA The Hard Way",
      "ST": "Cloud St"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy

}

echo "Creating the kube-scheduler client certificate..."
{

cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Cloudland",
      "O": "system:kube-scheduler",
      "OU": "CKA The Hard Way",
      "ST": "Cloud St"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler

}

echo "Creating the kube-apiserver certificate..."
{

KUBERNETES_PUBLIC_ADDRESS=$(curl http://169.254.169.254/1.0/meta-data/local-ipv4)

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Cloudland",
      "O": "Kubernetes",
      "OU": "CKA The Hard Way",
      "ST": "Cloud St"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.32.0.1,10.240.0.11,10.240.0.10,${KUBERNETES_PUBLIC_ADDRESS},k8s.robotnik.io,127.0.0.1,kubernetes.default \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

}

echo "Creating the Service Account key pair..."
{

cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Cloudland",
      "O": "Kubernetes",
      "OU": "CKA The Hard Way",
      "ST": "Cloud St"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account

}

echo "Distribute certificates and keys to worker instances..."
for instance in knode-2 knode-3; do
  scp ca.pem ${instance}-key.pem ${instance}.pem ${instance}:~/
done

#echo "Distribute certificate(s) and key(s) to etcd-0..."
#scp ca.pem kubernetes-key.pem kubernetes.pem etcd-0:~/

#echo "Distribute certificate(s) and key(s) to master-0..."
#gcloud compute scp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem service-account-key.pem service-account.pem master-0:~/

echo "Generate Kubernetes configuration files for authentication..."

echo "Generate kubeconfig files for kubelets..."
for instance in knode-2 knode-3; do
  kubectl config set-cluster k8s-cluster \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-credentials system:node:${instance} \
    --client-certificate=${instance}.pem \
    --client-key=${instance}-key.pem \
    --embed-certs=true \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-context default \
    --cluster=k8s-cluster \
    --user=system:node:${instance} \
    --kubeconfig=${instance}.kubeconfig

  kubectl config use-context default --kubeconfig=${instance}.kubeconfig
done

echo "Generate a kubeconfig for the kube-proxy service..."
{
  kubectl config set-cluster k8s-cluster \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config set-credentials system:kube-proxy \
    --client-certificate=kube-proxy.pem \
    --client-key=kube-proxy-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config set-context default \
    --cluster=k8s-cluster \
    --user=system:kube-proxy \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
}

echo "Generate a kubeconfig for the kube-controller-manager..."
{
  kubectl config set-cluster k8s-cluster \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=kube-controller-manager.pem \
    --client-key=kube-controller-manager-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-context default \
    --cluster=k8s-cluster \
    --user=system:kube-controller-manager \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig
}

echo "Generate a kubeconfig for the kube-scheduler..."
{
  kubectl config set-cluster k8s-cluster \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-credentials system:kube-scheduler \
    --client-certificate=kube-scheduler.pem \
    --client-key=kube-scheduler-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-context default \
    --cluster=k8s-cluster \
    --user=system:kube-scheduler \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig
}

echo "Generate a kubeconfig for the admin user..."
{
  kubectl config set-cluster k8s-cluster \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=admin.kubeconfig

  kubectl config set-credentials admin \
    --client-certificate=admin.pem \
    --client-key=admin-key.pem \
    --embed-certs=true \
    --kubeconfig=admin.kubeconfig

  kubectl config set-context default \
    --cluster=k8s-cluster \
    --user=admin \
    --kubeconfig=admin.kubeconfig

  kubectl config use-context default --kubeconfig=admin.kubeconfig
}

echo "Distribute the kubeconfig files to worker instances..."
for instance in knode-2 knode-3; do
  scp ${instance}.kubeconfig kube-proxy.kubeconfig ${instance}:~/
done

#echo "Distribute the kubeconfig files to the master instance..."
#cp admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig master-0:~/

echo "Generating the data encryption config and key..."
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

#echo "Copy the encryption config file to the master instance..."
#gcloud compute scp encryption-config.yaml master-0:~/

echo 
echo "Finished! Here's the instances created:"
gcloud compute instances list
echo 
echo "Now you need to:"
echo "1. Bootstrap the etcd one node cluster"
echo "2. Bootstrap the control plane"
echo "3. Bootstrap the worker nodes"
echo
