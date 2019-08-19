#/bin/bash
#你也可以在这个网址http://mirror.rc.usf.edu/compute_lock/elrepo/kernel/el7/x86_64/RPMS/ 上获取kernel版本，但是建议用我的方法升级内核,因为“快”
[ ! -f /usr/bin/perl ] && yum install -y perl
rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
yum install -y https://www.elrepo.org/elrepo-release-7.0-4.el7.elrepo.noarch.rpm
yum --enablerepo=elrepo-kernel install kernel-lt -y
grub2-set-default  0 && grub2-mkconfig -o /etc/grub2.cfg
reboot
