#!/bin/bash

set -exo pipefail

# 根据集群服务器实际分配情况配置环境变量，包括Master、Nodes服务器
USER=root
ALL_SERVER_IPS=("192.168.31.186" "192.168.31.82" "192.168.31.215")
MASTER_IP=192.168.31.186
NODE_IPS=("192.168.31.186" "192.168.31.82" "192.168.31.215")

ETCD_IPS=("${ALL_SERVER_IPS[@]:0:3}")
ETCD_ENDPOINTS="https://${ALL_SERVER_IPS[1]}:2379,https://${ALL_SERVER_IPS[2]}:2379,https://${ALL_SERVER_IPS[3]}:2379"
ETCD_NODES="etcd-node0=https://${ALL_SERVER_IPS[1]}:2380,etcd-node1=https://${ALL_SERVER_IPS[2]}:2380,etcd-node2=https://{ALL_SERVER_IPS[3]}:2380"


DOCKER_LOCATION=/home/docker
BASE_PATH="$(pwd)"
# SERVICE_UNIT_LOCATION=/lib/systemd/system # for ubuntu
SERVICE_UNIT_LOCATION=/usr/lib/systemd/system # for centos

export USER
export ALL_SERVER_IPS
export MASTER_IP
export NODE_IPS
export ETCD_IPS
export ETCD_NODES
export ETCD_ENDPOINTS
export DOCKER_LOCATION
export BASE_PATH
export SERVICE_UNIT_LOCATION

# 配置集群中Master节点可以无需验证访问各个服务器节点
ssh-keygen
for node in "${ALL_SERVER_IPS[@]}"
do
ssh-copy-id -i ~/.ssh/id_rsa.pub "${node}"
ssh "${USER}@${node}" "systemctl stop firewalld && systemctl disable firewalld"
done

# 检查集群中所有Node是否开启了swap，若开启，则需要关闭，并禁止swap功能
cat > ./shutdown_swap.sh <<'EOF'
#!/bin/sh

set -x

export SWAPFILELINE=$(cat < /proc/swaps | wc -l)
if [[ "$SWAPFILELINE" -gt 1 ]]
then
    echo "swap exist, removing swaps"
    swapoff -a
    sed -i '/swap/d' /etc/fstab
fi
EOF
chmod +x ./shutdown_swap.sh

for node in "${ALL_SERVER_IPS[@]}"
do
scp ./shutdown_swap.sh "${USER}@${node}:~/"
ssh "${USER}@${node}" "bash ~/shutdown_swap.sh"
done