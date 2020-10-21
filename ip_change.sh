#!/bin/bash

CMDNAME=`basename $0`
DIR=`pwd`

function usage {
cat << _EOT_
Usage:
$CMDNAME [-o] [-n] [-h]
Options:
-o    old ip address
-n    new ip address
_EOT_
exit 1
}

# set option parameters
while getopts o:n:h OPT
do
    case $OPT in
        o)  OLD_IP=$OPTARG
            ;;
        n)  NEW_IP=$OPTARG
            ;;
        h)  usage
            ;;
    esac
done

# check option parameters
if [ -z "$OLD_IP" ]; then
    echo "[ERR] OLD IP address is not set"
    echo ""
    usage
fi 
if [ -z "$NEW_IP" ]; then
    echo "[ERR] NEW IP address is not set"
    echo ""
    usage
fi

cd /etc/kubernetes
array=`sudo find . -type f | sudo xargs grep $OLD_IP`

if [ -z "$array" ]; then
    echo "[ERR] OLD IP isnt exited"
    exit 1
else
    sudo find . -type f | sudo xargs sed -i "s/$OLD_IP/$NEW_IP/"
fi

cd /etc/kubernetes/pki
rm apiserver.crt apiserver.key
kubeadm init phase certs apiserver --apiserver-advertise-address=$NEW_IP
sleep 5
rm etcd/peer.crt etcd/peer.key
kubeadm init phase certs etcd-peer
sleep 5
systemctl restart kubelet
systemctl restart docker
sleep 30
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
cd $DIR
kubectl get cm kubeadm-config -n kube-system -o yaml > kubeadm-config.yaml && sed -i "s/$OLD_IP/$NEW_IP/g"  kubeadm-config.yaml && kubectl replace -f kubeadm-config.yaml
rm kubeadm-config.yaml
kubectl get cm kube-proxy -n kube-system -o yaml > kube-proxy.yaml && sed -i "s/$OLD_IP/$NEW_IP/g"  kube-proxy.yaml && kubectl replace -f kube-proxy.yaml
rm kubeadm-config.yaml
kubectl delete -f ./kube-flannel.yml
kubectl apply -f ./kube-flannel.yml
reboot
