#!/bin/bash

nice_echo() {
    echo -e "\n\033[1;36m >>>>>>>>>> $1 <<<<<<<<<< \033[0m\n"
}

check_pods() {
    echo "Check the status of pods in namespace $1"
    count=0
    while(true)
    do
    kubectl get pods -n $1
    kubectl get pods --namespace $1 | awk '{
        if ($2 ~ /0\/*/) {
            if ($3 != "Completed") {
                print $1 " is not up"; exit -1
            }
        }
        }';
    if [ $? -eq 0 ]
    then
    break;
    fi
    (( count++ ))
    if [ $count -eq 90 ]
    then
    exit -1
    fi
    sleep 10
    done
}

# install docker CE
nice_echo "Stage 1: installing docker CE"
apt-get update
apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") $(lsb_release -cs) stable"
apt-get update && apt-get install -y docker-ce=$(apt-cache madison docker-ce | grep 18.06 | head -1 | awk '{print $3}')

# start daemon
nice_echo "Stage 2: Installing Daemon"
apt-get update && apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

nice_echo "Stage 3: Installing kubeadm"
apt-get update
apt-get install -qy kubelet=1.13.5-00 kubectl=1.13.5-00 kubeadm=1.13.5-00 --allow-downgrades
sed -i "s/cgroup-driver=systemd/cgroup-driver=cgroupfs/g" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
systemctl daemon-reload
systemctl restart kubelet
    
# turn off swap
nice_echo "Stage 4: Turning off swap"
swapoff -a
sed -i '/swap/d' /etc/fstab

# increase max map count
nice_echo "Stage 5: increase max map count"
sysctl -w vm.max_map_count=1048575

# WARNING: May need to manually set on host machine
# vi /etc/sysctl.conf
# >vm.max_map_count = 262144

# Start the kube cluster
nice_echo "Stage 6: Starting kubeadm"
kubeadm init --pod-network-cidr 192.168.0.0/16  --kubernetes-version=1.13.5
mkdir -p $HOME/.kube
cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=$HOME/.kube/config
kubectl apply -f https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml
kubectl apply -f https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml
kubectl taint nodes --all node-role.kubernetes.io/master-

# Install helm
nice_echo "Stage 7: Installing helm"
if ! which helm; then
    sudo snap install helm --classic
else 
    echo "Helm is installed"
fi

nice_echo "Stage 8: Helm config"
if [ ! -f /root/snap/helm/common/kube/config ]; then
    echo "Kube config NOT IN HELM folder! Copying now"
    mkdir -p /root/snap/helm/common/kube/
    cp $HOME/.kube/config /root/snap/helm/common/kube/
else
    echo "Helm is configured"
fi

# install tiller
nice_echo "Stage 9: Installing tiller"
curl -L  https://storage.googleapis.com/kubernetes-helm/helm-v2.9.1-linux-amd64.tar.gz | tar zxvf - --strip-components=1 -C /usr/bin/ linux-amd64/helm
cat << EOF > tiller-rbac.yml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system
EOF
kubectl apply -f tiller-rbac.yml
helm init --service-account tiller
helm repo update
check_pods kube-system
until kubectl get pods --namespace kube-system | grep tiller ; do kubectl get pods --namespace kube-system && sleep 5 ; done
__tiller=$(kubectl get pods -o name --namespace kube-system | grep tiller)
echo $__tiller
until kubectl get $__tiller --namespace kube-system -o jsonpath='{.status.phase}' | grep Running ; do kubectl get pods --namespace kube-system && sleep 5 ; done
sleep 10

# install ingress
nice_echo "Stage 10: Installing ingress"
cat << EOF > ingress-config.yml
controller:
  config:
    hsts-max-age: "31536000"
    keepalive: "32"
    log-format: '{ "@timestamp": "$time_iso8601", "@version": "1", "clientip": "$remote_addr",
      "tag": "ingress", "remote_user": "$remote_user", "bytes": $bytes_sent, "duration":
      $request_time, "status": $status, "request": "$request_uri", "urlpath": "$uri",
      "urlquery": "$args", "method": "$request_method", "referer": "$http_referer",
      "useragent": "$http_user_agent", "software": "nginx", "version": "$nginx_version",
      "host": "$host", "upstream": "$upstream_addr", "upstream-status": "$upstream_status"
      }'
    main-snippets: load_module "modules/ngx_stream_module.so"
    proxy-body-size: "0"
    proxy-buffering: "off"
    server-name-hash-bucket-size: "128"
    server-name-hash-max-size: "1024"
    server-tokens: "False"
    ssl-ciphers: HIGH:!aNULL:!MD5
    ssl-prefer-server-ciphers: "True"
    ssl-protocols: TLSv1.2
    use-http2: "true"
    worker-connections: "10240"
    worker-cpu-affinity: auto
    worker-processes: "1"
    worker-rlimit-nofile: "65536"
    worker-shutdown-timeout: 5m
  daemonset:
    useHostPort: false
  extraArgs:
    annotations-prefix: ingress.kubernetes.io
    enable-ssl-passthrough: true
  hostNetwork: true
  kind: DaemonSet
  name: controller
rbac:
  create: "true"
EOF

# update --version 0.17.1 when https://github.com/kubernetes/ingress-nginx/issues/2994 is fixed
helm install stable/nginx-ingress --name ingress --version 0.17.1 --values ingress-config.yml --namespace kube-system
helm ls

# install rook
nice_echo "Stage 11: Installing Rook"
cat << EOF > rook-storageclass.yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: rook-config-override
  namespace: rook-ceph
data:
  config: |
    [global]
    rbd default features = 1
---
apiVersion: v1
kind: Namespace
metadata:
  name: rook-ceph
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: rook-ceph-cluster
  namespace: rook-ceph
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: rook-ceph-cluster
  namespace: rook-ceph
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: [ "get", "list", "watch", "create", "update", "delete" ]
---
# Allow the operator to create resources in this cluster's namespace
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: rook-ceph-cluster-mgmt
  namespace: rook-ceph
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: rook-ceph-cluster-mgmt
subjects:
- kind: ServiceAccount
  name: rook-ceph-system
  namespace: rook-ceph-system
---
# Allow the pods in this namespace to work with configmaps
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: rook-ceph-cluster
  namespace: rook-ceph
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: rook-ceph-cluster
subjects:
- kind: ServiceAccount
  name: rook-ceph-cluster
  namespace: rook-ceph
---
apiVersion: ceph.rook.io/v1beta1
kind: Cluster
metadata:
  name: rook-ceph
  namespace: rook-ceph
spec:
  dataDirHostPath: /var/lib/rook
  dashboard:
    enabled: true
  storage:
    useAllNodes: true
    useAllDevices: false
    config:
      databaseSizeMB: "1024"
      journalSizeMB: "1024"
---
apiVersion: ceph.rook.io/v1beta1
kind: Pool
metadata:
  name: velox
  namespace: rook-ceph
spec:
  replicated:
    size: 2
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  annotations:
    storageclass.beta.kubernetes.io/is-default-class: "true"
  name: rook-block
parameters:
  clusterName: rook-ceph
  fstype: ext4
  pool: velox
provisioner: rook.io/block
reclaimPolicy: Delete
EOF

kubectl create namespace rook-ceph
helm repo add rook-beta https://charts.rook.io/beta
helm install rook-beta/rook-ceph --name rook --namespace rook-ceph-system
kubectl apply -f rook-storageclass.yml

nice_echo "Stage 12: Waiting 1 minute before moving on"
sleep 60
check_pods rook

# install pvc
nice_echo "Stage 13: Installing pvc"
cat << EOF > pvc.yml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: testpvc
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem
  resources:
    requests:
      storage: 1M
  storageClassName: rook-block
EOF
kubectl apply -f pvc.yml

nice_echo "Wating for pvc to be ready"
kubectl get pvc
__pvc=$(kubectl get pvc -o name | grep testpvc)
echo $__pvc
until kubectl get $__pvc -o jsonpath='{.status.phase}' | grep Bound ; do kubectl get pvc && sleep 5 ; done


nice_echo "Kubernetes successfully installed!"