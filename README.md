本安装的特点，不用墙，不用倒腾镜像，既傻又快！
# 傻瓜操作步骤
不需要看后边的内容直接按顺序执行脚本：
```
# 第一步不是必须，主要做内核升级的事，其中包含变更云的源地址对于安装很重要，按需取
bash KubernetsInstall_StepOne.sh
bash KubernetsInstall_StepTwo.sh

```
# 操作环境
操作系统及版本：CentOS Linux release 7.6.1810

# 升级内核
```
#/bin/bash
# 云源设置
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
yum clean all
yum makecache
#升级内核
#内核依赖包
[ ! -f /usr/bin/perl ] && yum install -y perl
rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
yum install -y https://www.elrepo.org/elrepo-release-7.0-4.el7.elrepo.noarch.rpm

# Kernel_Version=$(yum --disablerepo="*" --enablerepo="elrepo-kernel" list available  --showduplicates|sort|awk '{print $2}'|awk -F '.el7' '{print $1}'|sed -n 5p)
# yum install -y kernel-lt-${Kernel_Version}
yum --enablerepo=elrepo-kernel install kernel-lt -y
grub2-set-default  0 && grub2-mkconfig -o /etc/grub2.cfg
#你也可以在这个网址http://mirror.rc.usf.edu/compute_lock/elrepo/kernel/el7/x86_64/RPMS/ 上获取kernel版本，但是建议用我的方法升级内核,因为“快”
reboot

```
# docker安装
全程root执行
## 安装脚本
```
#/bin/bash
yum remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
# Install required packages
yum install -y yum-utils device-mapper-persistent-data lvm2
# add stable repository
yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
# install
yum install -y docker-ce docker-ce-cli containerd.io
containerd config default > /etc/containerd/config.toml
#set to use the systemd cgroup driver
sed -i s/"systemd_cgroup = false"/"systemd_cgroup = true"/g /etc/containerd/config.toml
systemctl restart containerd
#docker命令补全
yum install -y epel-release bash-completion && cp /usr/share/bash-completion/completions/docker /etc/bash_completion.d/
systemctl enable --now docker

mkdir -p /etc/docker

```
## 安装后的配置优化
### 镜像源的设置
参考：https://www.cnblogs.com/zhxshseu/p/5970a5a763c8fe2b01cd2eb63a8622b2.html

现阶段，只要有阿里云帐号就可以免费使用加速。
### 普通用户执行docker权限
```
#tee /etc/docker/daemon.json <<-'EOF'
##{
#  "registry-mirrors": ["https://md4nbj2f.mirror.aliyuncs.com"],
#  "insecure-registries":["10.188.56.15:5000"]
#}
#EOF
# 添加 docker 用户组
# 把需要执行的 docker 用户添加进该组，这里是 user
gpasswd -a user docker

# 重启 docker
systemctl start docker
```
# Kubernetes安装
全程root执行
```

#关闭IPtables及NetworkManager
systemctl disable --now firewalld NetworkManager
setenforce 0
sed -ri '/^[^#]*SELINUX=/s#=.+$#=disabled#' /etc/selinux/config

#关闭swap并注释掉/etc/fstab中swap的行
swapoff -a && sysctl -w vm.swappiness=0
sed -ri '/^[^#]*swap/s@^@#@' /etc/fstab

yum install -y wget vim lsof net-tools lrzsz
wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
yum makecache
yum update -y
# Install prerequisites
yum-config-manager --add-repo=https://cbs.centos.org/repos/paas7-crio-311-candidate/x86_64/os/
# Install CRI-O
yum install -y --nogpgcheck cri-o
yum install -y ipvsadm ipset sysstat conntrack libseccomp ebtables ethtool
systemctl start crio
systemctl enable crio
#开启user_namespace
grubby --args="user_namespace.enable=1" --update-kernel="$(grubby --default-kernel)"
#开启ipvs模块
module=(
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack
br_netfilter
  )
for kernel_module in ${module[@]};do
    /sbin/modinfo -F filename $kernel_module |& grep -qv ERROR && echo $kernel_module >> /etc/modules-load.d/ipvs.conf || :
done
systemctl enable --now systemd-modules-load.service
systemctl status -l systemd-modules-load.service
# k8s系统参数
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
setenforce 0
yum install -y kubelet kubeadm kubectl
systemctl enable kubelet && systemctl start kubelet

# 时区设置，docker容器中也需要设置，避免时间导致的异常
yum -y install ntp
systemctl enable ntpd
systemctl start ntpd
ntpdate -u ntp1.aliyun.com
hwclock --systohc
timedatectl set-timezone Asia/Shanghai

# 初始化
 kubeadm init --image-repository registry.aliyuncs.com/google_containers --kubernetes-version v1.15.0 --pod-network-cidr=10.244.0.0/16
 #dashboard
docker pull mirrorgooglecontainers/kubernetes-dashboard-amd64:v1.8.3

```

# 参考
- https://docs.docker.com/
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/
- https://k.i4t.com/kubernetes1.13_install.html
