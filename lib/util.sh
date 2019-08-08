#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

lsb-dist() {
    lsb_dist=''
    if command_exists lsb_release; then
        lsb_dist="$(lsb_release -si)"
    fi
    if [ -z "$lsb_dist" ] && [ -r /etc/lsb-release ]; then
        lsb_dist="$(. /etc/lsb-release && echo "$DISTRIB_ID")"
    fi
    if [ -z "$lsb_dist" ] && [ -r /etc/centos-release ]; then
        lsb_dist='centos'
    fi
    if [ -z "$lsb_dist" ] && [ -r /etc/redhat-release ]; then
        lsb_dist='redhat'
    fi
    if [ -z "$lsb_dist" ] && [ -r /etc/os-release ]; then
        lsb_dist="$(. /etc/os-release && echo "$ID")"
    fi

    lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"
    echo ${lsb_dist}
}

command_exists() {
    command -v "$@" > /dev/null 2>&1
}
# 云源设置
update-yum-source(){
    mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
    curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
    yum clean all
    yum makecache
}


#升级内核
update-kernel(){
    [ ! -f /usr/bin/perl ] && yum install -y perl
    rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
    yum install -y https://www.elrepo.org/elrepo-release-7.0-4.el7.elrepo.noarch.rpm

    # Kernel_Version=$(yum --disablerepo="*" --enablerepo="elrepo-kernel" list available  --showduplicates|sort|awk '{print $2}'|awk -F '.el7' '{print $1}'|sed -n 5p)
    # yum install -y kernel-lt-${Kernel_Version}
    yum --enablerepo=elrepo-kernel install kernel-lt -y
    grub2-set-default  0 && grub2-mkconfig -o /etc/grub2.cfg
    #你也可以在这个网址http://mirror.rc.usf.edu/compute_lock/elrepo/kernel/el7/x86_64/RPMS/ 上获取kernel版本，但是建议用我的方法升级内核,因为“快”
    reboot  
}