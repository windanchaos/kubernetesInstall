#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

CONTAINER_RUNTIME=${CONTAINER_RUNTIME:-"docker"}
CLUSTER_CIDR=${CLUSTER_CIDR:-"10.188.56.0/16"}
CONTAINER_CIDR=${CONTAINER_CIDR:-"10.244.1.0/24"}
NETWORK_PLUGIN=${NETWORK_PLUGIN:-"flannel"}
USE_MIRROR=${USE_MIRROR:-"true"}

KUBERNTES_ROOT=$(dirname "${BASH_SOURCE}")
source ${KUBERNTES_ROOT}/lib/util.sh
source ${KUBERNTES_ROOT}/lib/kubernetes.sh
source ${KUBERNTES_ROOT}/lib/cni.sh

install-network-plugin() {
    case "${NETWORK_PLUGIN}" in

        bridge)
            config-cni
            ;;

        calico)
            install-calico
            ;;

        flannel)
            install-flannel
            ;;

        weave)
            install-weave
            ;;

        azure)
            install-azure-vnet
            ;;

        *)
            echo "No network plugin is running, please add it manually"
            ;;
    esac
}

lsb_dist=$(lsb-dist)
case "$lsb_dist" in
    fedora|centos|redhat)
        setup-container-runtime
        time-set
        install-kubelet-centos-mirror
        setup-master
        set-kube-adminconf
        #install-network-plugin
	    setup-dashboard
    ;;

    *)
        echo "$lsb_dist is not supported (not in centos|ubuntu)"
    ;;

esac
