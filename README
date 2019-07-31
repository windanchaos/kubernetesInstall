# 傻瓜操作步骤
不需要看后边的内容直接按顺序执行脚本：
```
bash DockerInstall.sh

```
# 操作环境
操作系统及版本：CentOS Linux release 7.6.1810

# docker安装

## 安装脚本
全称root执行

```
#变更yum源到阿里云
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

```
## 安装后的配置优化
### 镜像源的设置
参考：https://www.cnblogs.com/zhxshseu/p/5970a5a763c8fe2b01cd2eb63a8622b2.html

现阶段，只要有阿里云帐号就可以免费使用加速。
### 普通用户执行docker权限
```
# 添加 docker 用户组
groupadd docker

# 把需要执行的 docker 用户添加进该组，这里是 user
gpasswd -a user docker

# 重启 docker
systemctl start docker
```


# 参考
https://docs.docker.com/
