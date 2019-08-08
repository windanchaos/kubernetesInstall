#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

docker-install-latest() {
    update-yum-source
    yum install -y yum-utils device-mapper-persistent-data lvm2
    # add stable repository
    yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
    # install
    yum install -y docker-ce docker-ce-cli containerd.io
    containerd config default > /etc/containerd/config.toml
    #set to use the systemd cgroup driver
    sed -i s/"systemd_cgroup = false"/"systemd_cgroup = true"/g /etc/containerd/config.toml
    #开启user_namespace
    grubby --args="user_namespace.enable=1" --update-kernel="$(grubby --default-kernel)"
    systemctl restart containerd
    #docker命令补全
    yum install -y epel-release bash-completion && cp /usr/share/bash-completion/completions/docker /etc/bash_completion.d/
    systemctl enable --now docker

    mkdir -p /etc/docker
    tee /etc/docker/daemon.json <<-'EOF'
    {
      "registry-mirrors": ["https://jm4127al.mirror.aliyuncs.com"],
      "insecure-registries":["10.188.56.15:5000"],
      "exec-opts": ["native.cgroupdriver=systemd"],
      "log-driver": "json-file",
      "log-opts": {"max-size": "100m"},
      "storage-driver": "overlay2",
      "storage-opts": ["overlay2.override_kernel_check=true"]
    }
EOF

    # 添加 docker 用户组
    #关闭IPtables及NetworkManager
    systemctl disable --now firewalld
    setenforce 0 || echo "selinux replace config"
    sed -ri '/^[^#]*SELINUX=/s#=.+$#=disabled#' /etc/selinux/config

    #关闭swap并注释掉/etc/fstab中swap的行
    swapoff -a && sysctl -w vm.swappiness=0
    sed -ri '/^[^#]*swap/s@^@#@' /etc/fstab

    systemctl start docker
    iptables -P FORWARD ACCEPT
}

