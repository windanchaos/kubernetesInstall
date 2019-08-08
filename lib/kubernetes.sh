#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

CLUSTER_CIDR=${CLUSTER_CIDR:-"10.244.0.0/16"}
CONTAINER_CIDR=${CONTAINER_CIDR:-"10.244.1.0/24"}
CONTAINER_RUNTIME=${CONTAINER_RUNTIME:-"docker"}

KUBERNTES_LIB_ROOT=$(dirname "${BASH_SOURCE}")
source ${KUBERNTES_LIB_ROOT}/util.sh
source ${KUBERNTES_LIB_ROOT}/docker.sh


setup-kubelet-infra-container-image() {
    #mkdir -p /etc/systemd/system/kubelet.service.d/
    #tee  /etc/systemd/system/kubelet.service.d/20-pod-infra-image.conf <<EOF
#[Service]
#Environment="KUBELET_EXTRA_ARGS=--pod-infra-container-image=registry.access.redhat.com/rhel7/pod-infrastructure:latest"
#EOF
    systemctl daemon-reload
}


install-kubelet-centos-mirror() {
#k8s系统参数
cat <<EOF > /etc/sysctl.d/k8s.conf
# https://github.com/moby/moby/issues/31208 
# ipvsadm -l --timout
# 修复ipvs模式下长连接timeout问题 小于900即可
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 10
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
net.ipv4.neigh.default.gc_stale_time = 120
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2
net.ipv4.ip_forward = 1
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 1024
net.ipv4.tcp_synack_retries = 2
# 要求iptables不对bridge的数据进行处理
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-arptables = 1
net.netfilter.nf_conntrack_max = 2310720
fs.inotify.max_user_watches=89100
fs.may_detach_mounts = 1
fs.file-max = 52706963
fs.nr_open = 52706963
vm.swappiness = 0
vm.overcommit_memory=1
vm.panic_on_oom=0
EOF
sysctl --system
    cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
    #setenforce 0
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    yum install -y kubernetes-cni kubelet kubeadm kubectl
    systemctl enable kubelet && systemctl start kubelet

   # setup-kubelet-infra-container-image
}

setup-container-runtime() {
    lsb_dist=$(lsb-dist)

    case "${CONTAINER_RUNTIME}" in
        docker)
            docker-install-latest
            ;;

        *)
            echo "Container runtime ${CONTAINER_RUNTIME} not supported"
            exit 1
            ;;
    esac
    systemctl daemon-reload
}

setup-master() {
    kubeadm init --image-repository registry.aliyuncs.com/google_containers --kubernetes-version v1.15.0 --pod-network-cidr=10.244.0.0/16
}
setup-dashboard() {
    docker pull mirrorgooglecontainers/kubernetes-dashboard-amd64:v1.10.1
    kubectl create -f ${KUBERNTES_LIB_ROOT}/dashboard.yaml
    kubectl create -f ${KUBERNTES_LIB_ROOT}/dashboard-admin.yaml   
}

setup-node() {
    if [[ $# < 2 ]]; then
        echo "Usage: setup-node token hash master_ip [port]"
        echo ""
        echo "  token could be get by running \"kubeadm token list\" or \"kubeadm token create\""
        echo "  hash could be get by running \"openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | \
   openssl dgst -sha256 -hex | sed 's/^.* //'\""
        exit 1
    fi

    token="$1"
    master_ip="$2"
    port="6443"
    if [[ $# == 3 ]]; then
        port="$3"
    fi

    # join master on worker nodes
    kubeadm join --ignore-preflight-errors all --discovery-token-unsafe-skip-ca-verification --token $token ${master_ip}:$port
}

time-set(){
    yum -y install ntp
    systemctl enable ntpd
    systemctl start ntpd
    ntpdate -u ntp1.aliyun.com
    hwclock --systohc
    timedatectl set-timezone Asia/Shanghai
}
set-kube-adminconf(){
    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config
}
