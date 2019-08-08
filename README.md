本安装的特点，不用墙，不用倒腾镜像，既傻又快！
# setp one
不需要看后边的内容直接按顺序执行脚本,全程root执行：
```
#setp one
clone https://github.com/windanchaos/kubernetesInstall.git
#注意机器名只能是字母和数字的组合
```
# step tow 
```
# not necessary,can ignore
bash kubernetesInstall/UpdateKernel.sh
```
# step three
```
bash kubernetesInstall/install-kubernetes-master.sh
```
# step four
```
# Setup token and CIDR first.
# replace this with yours.file:kubernetesInstall/install-kubernetes-node.sh
export TOKEN="xxxx"
export MASTER_IP="x.x.x.x"
export CONTAINER_CIDR="10.244.2.0/24"

# Setup and join the new node.
#执行完成后取得token和ip写入kubernetesInstall/install-kubernetes-node.sh文件中
#拷贝文件到node机器，在node机器执行
bash kubernetesInstall/install-kubernetes-node.sh
```


# 参考
- https://github.com/feiskyer/ops
- https://docs.docker.com/
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/
- https://k.i4t.com/kubernetes1.13_install.html
