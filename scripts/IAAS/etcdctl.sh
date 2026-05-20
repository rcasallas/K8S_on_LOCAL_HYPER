alias etcdctl='sudo crictl exec -i $(sudo crictl ps --name etcd -q | head -n 1) etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key'

etcdctl endpoint health

etcdctl endpoint status --write-out=table

etcdctl member list --write-out=table

etcdctl get / --prefix --keys-only

etcdctl get /registry/minions --prefix --keys-only

etcdctl get /registry/namespaces/kube-system



etcdctl snapshot save /var/lib/etcd/backup-etcd.db


etcdctl snapshot status /var/lib/etcd/backup-etcd.db --write-out=table


etcdctl snapshot restore /var/lib/etcd/backup-etcd.db \
    --data-dir=/var/lib/etcd-restored \
    --initial-cluster=<nombre-de-tu-cluster> \
    --initial-cluster-token=<tu-token-de-cluster> \
    --initial-advertise-peer-urls=https://<ip-del-servidor>:2380