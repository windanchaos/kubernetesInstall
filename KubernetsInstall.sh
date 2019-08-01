#/bin/bash
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
yum clean all
yum makecache
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
#tee /etc/docker/daemon.json <<-'EOF'
##{
#  "registry-mirrors": ["https://md4nbj2f.mirror.aliyuncs.com"],
#  "insecure-registries":["10.188.56.15:5000"]
#}
#EOF
# 添加 docker 用户组
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
#升级内核
#内核依赖包
[ ! -f /usr/bin/perl ] && yum install -y perl
rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
yum install -y https://www.elrepo.org/elrepo-release-7.0-4.el7.elrepo.noarch.rpm

Kernel_Version=$(yum --disablerepo="*" --enablerepo="elrepo-kernel" list available  --showduplicates|sort|awk '{print $2}'|awk -F '.el7' '{print $1}'|sed -n 5p)
yum install -y kernel-lt-${Kernel_Version}
grub2-set-default  0 && grub2-mkconfig -o /etc/grub2.cfg
#你也可以在这个网址http://mirror.rc.usf.edu/compute_lock/elrepo/kernel/el7/x86_64/RPMS/ 上获取kernel版本，但是建议用我的方法升级内核
reboot
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
setenforce 0
yum install -y kubelet kubeadm kubectl
systemctl enable kubelet && systemctl start kubelet

#时区设置，docker容器中也需要设置，避免时间导致的异常
yum -y install ntp
systemctl enable ntpd
systemctl start ntpd
ntpdate -u ntp1.aliyun.com
hwclock --systohc
timedatectl set-timezone Asia/Shanghai