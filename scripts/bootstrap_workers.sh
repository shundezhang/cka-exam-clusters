#!/bin/bash

# Bootstrap the worker nodes
# RUN ON ALL WORKERS!

# add entries to /etc/hosts



# Install OS dependencies

{
      sudo apt-get update
      sudo apt-get -y install socat conntrack ipset docker.io
}

# Download and install worker binaries

wget -q --show-progress --https-only --timestamping \
  https://github.com/containernetworking/plugins/releases/download/v0.7.1/cni-plugins-amd64-v0.7.1.tgz \
  https://storage.googleapis.com/kubernetes-release/release/v1.11.0/bin/linux/amd64/kubectl \
  https://storage.googleapis.com/kubernetes-release/release/v1.11.0/bin/linux/amd64/kube-proxy \
  https://storage.googleapis.com/kubernetes-release/release/v1.11.0/bin/linux/amd64/kubelet
  #https://github.com/kubernetes-incubator/cri-tools/releases/download/v1.0.0-beta.0/crictl-v1.0.0-beta.0-linux-amd64.tar.gz \
  #https://storage.googleapis.com/kubernetes-the-hard-way/runsc \
  #https://github.com/opencontainers/runc/releases/download/v1.0.0-rc5/runc.amd64 \
  #https://github.com/containerd/containerd/releases/download/v1.1.0/containerd-1.1.0.linux-amd64.tar.gz \

sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

{
  chmod +x kubectl kube-proxy kubelet #runc.amd64 runsc
  #sudo mv runc.amd64 runc
  #sudo mv kubectl kube-proxy kubelet runc runsc /usr/local/bin/
  sudo mv kubectl kube-proxy kubelet \/usr/local/bin/
  #sudo tar -xvf crictl-v1.0.0-beta.0-linux-amd64.tar.gz -C /usr/local/bin/
  sudo tar -xvf cni-plugins-amd64-v0.7.1.tgz -C /opt/cni/bin/
  #sudo tar -xvf containerd-1.1.0.linux-amd64.tar.gz -C /
}

# Configure CNI networking

POD_CIDR="10.200.0.0/24"

# Create bridge

#cat <<EOF | sudo tee /etc/cni/net.d/10-bridge.conf
#{
#    "cniVersion": "0.3.1",
#    "name": "bridge",
#    "type": "bridge",
#    "bridge": "cnio0",
#    "isGateway": true,
#    "ipMasq": true,
#    "ipam": {
#        "type": "host-local",
#        "ranges": [
#          [{"subnet": "${POD_CIDR}"}]
#        ],
#        "routes": [{"dst": "0.0.0.0/0"}]
#    }
#}
#EOF

# Create loopback

cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "0.3.1",
    "type": "loopback"
}
EOF


# Configure kubelet

{
  sudo mv ~/${HOSTNAME}-key.pem ~/${HOSTNAME}.pem /var/lib/kubelet/
  sudo mv ~/${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig
  sudo mv ~/ca.pem /var/lib/kubernetes/
}

cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "${POD_CIDR}"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${HOSTNAME}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${HOSTNAME}-key.pem"
EOF

cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Configure the kube-proxy

sudo mv ~/kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig

cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "10.200.0.0/16"
EOF

cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Start the worker services

{
  sudo systemctl daemon-reload
  sudo systemctl enable containerd kubelet kube-proxy
  sudo systemctl start containerd kubelet kube-proxy
}
