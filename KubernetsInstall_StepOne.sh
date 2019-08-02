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
