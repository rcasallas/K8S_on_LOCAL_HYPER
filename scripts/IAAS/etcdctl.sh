alias etcdctl='sudo crictl exec -i $(sudo crictl ps --name etcd -q | head -n 1) etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key'

etcdctl endpoint health

etcdctl endpoint status --write-out=table

etcdctl member list --write-out=table

etcdctl get / --prefix --keys-only

etcdctl get /registry/minions --prefix --keys-only

etcdctl get /registry/namespaces/kube-system


#snapshot
sudo etcdctl snapshot save /var/lib/etcd/backup-etcd.db

{"level":"info","ts":"2026-05-20T21:46:25.722726Z","caller":"snapshot/v3_snapshot.go:83","msg":"created temporary db file","path":"/var/lib/etcd/backup-etcd.db.part"}
{"level":"info","ts":"2026-05-20T21:46:25.727560Z","logger":"client","caller":"v3@v3.6.6/maintenance.go:236","msg":"opened snapshot stream; downloading"}
{"level":"info","ts":"2026-05-20T21:46:25.730352Z","caller":"snapshot/v3_snapshot.go:96","msg":"fetching snapshot","endpoint":"127.0.0.1:2379"}
{"level":"info","ts":"2026-05-20T21:46:25.792935Z","logger":"client","caller":"v3@v3.6.6/maintenance.go:302","msg":"completed snapshot read; closing"}
{"level":"info","ts":"2026-05-20T21:46:25.806873Z","caller":"snapshot/v3_snapshot.go:111","msg":"fetched snapshot","endpoint":"127.0.0.1:2379","size":"7.3 MB","took":"84.052896ms","etcd-version":"3.6.0"}
{"level":"info","ts":"2026-05-20T21:46:25.807195Z","caller":"snapshot/v3_snapshot.go:121","msg":"saved","path":"/var/lib/etcd/backup-etcd.db"}
Snapshot saved at /var/lib/etcd/backup-etcd.db
Server version 3.6.0

#Snapshot Status
sudo etcdctl snapshot status /var/lib/etcd/backup-etcd.db --write-out=table
Deprecated: Use `etcdutl snapshot status` instead.

+----------+----------+------------+------------+
|   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE |
+----------+----------+------------+------------+
| 925ff89d |     5288 |       1403 |     7.3 MB |
+----------+----------+------------+------------+

etcdctl snapshot restore /var/lib/etcd/backup-etcd.db \
    --data-dir=/var/lib/etcd-restored \
    --initial-cluster=<nombre-de-tu-cluster> \
    --initial-cluster-token=<tu-token-de-cluster> \
    --initial-advertise-peer-urls=https://<ip-del-servidor>:2380