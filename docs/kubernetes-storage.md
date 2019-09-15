 - [x] Основное ДЗ
 - [x] Задание со *

## Основное ДЗ
1. Volume Snapshot находится в альфе k8s версии 1.15 (v1alpha3), поэтому для тестирования снапшотов создадим кластер в kind
```
kind create cluster --config kubernetes-storage/cluster/cluster.yaml
```
2. клонируем рядом с основным проектом CSI driver и устанавливаем
```
git clone https://github.com/kubernetes-csi/csi-driver-host-path.git
./csi-driver-host-path/deploy/kubernetes-1.15/deploy-hostpath.sh
```
3. Проверяем: kubectl api-resources|grep volumesnapshots
```
volumesnapshots                                snapshot.storage.k8s.io        true         VolumeSnapshot
```
4. cоздаем StorageClass для CSI Host Path Driver
```
kubectl apply -f kubernetes-storage/hw/01-storageclass.yaml
```
проверяем: kubectl get sc
```
csi-hostpath-sc      hostpath.csi.k8s.io       53s
standard (default)   kubernetes.io/host-path   29m
```
kubectl get volumesnapshotclass
```
NAME                     AGE
csi-hostpath-snapclass   33m
```
5. cоздаем объект PVC c именем storage-pvc
```
kubectl apply -f kubernetes-storage/hw/02-pvc.yaml
```
проверяем: kubectl get pvc
```
NAME          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
storage-pvc   Bound    pvc-2fcc87ac-50dc-46b0-a88e-3205c2072935   1Gi        RWO            csi-hostpath-sc   2m14s
```
6. cоздаем объект Pod c именем storage-pod
```
kubectl apply -f kubernetes-storage/hw/03-pod-pvc.yaml
```
проверяем: kubectl get pods
```
NAME                         READY   STATUS    RESTARTS   AGE
csi-hostpath-attacher-0      1/1     Running   0          33m
csi-hostpath-provisioner-0   1/1     Running   0          33m
csi-hostpath-snapshotter-0   1/1     Running   0          32m
csi-hostpath-socat-0         1/1     Running   0          32m
csi-hostpathplugin-0         3/3     Running   0          33m
storage-pod                  1/1     Running   0          22s
```
### Тестируем снапшоты
1. Помещаем какие-нибудь данные в под
```
kubectl exec -it storage-pod /bin/bash
cd /data
echo mydata > snapdata
```
2.  Создаем снапшот
```
kubectl apply -f kubernetes-storage/snap/01-snapshot.yaml
```
3. удаляем данные
```
kubectl exec -it storage-pod /bin/bash
rm -rf data/*
kubectl delete pod storage-pod
kubectl delete pvc storage-pvc
```
4. восстанавливаемся из снапшота и проверяем
```
kubectl apply -f kubernetes-storage/snap/02-pvc-snap.yaml
kubectl apply -f kubernetes-storage/hw/03-pod-pvc.yaml
kubectl exec -it storage-pod /bin/bash
cat /data/snapdata
```

## Задание со *
1. Метод разворачивания кластера для выполнения домашнего задания описан в [Развертывание кластера kubernetes в gcloud с помощью IaC подхода.](../docs/gcloud-k8s.md)
2. В данном ДЗ используется кластер из 3-х мастер нод и 2-х воркер нод. На нодах используется centos7.
3. Инфраструктура виртуальной машины с iscsi-target описана в terraform-infra/iscsi-network.tf и terraform-infra/iscsi-target.tf
4. Установим нужные пакеты на виртуальные машины
```
ansible-playbook kubernetes-storage/iscsi/ansible/package-iscsi-target.yml
ansible-playbook kubernetes-storage/iscsi/ansible/package-worker.yml
```
5. Создаем lvm на отдельном диске выделенном под iscsi.
```
ansible-playbook kubernetes-storage/iscsi/ansible/lvm.yml
```
6. Создаем хранилище на iscsi-target
```
gcloud compute ssh iscsi-target
sudo -i
targetcli
```
```
[root@iscsi-target ~]# targetcli
targetcli shell version 2.1.fb46
Copyright 2011-2013 by Datera, Inc and others.
For help on commands, type 'help'.

/>
```
Связываем lvm раздел с блоком в хранилище
```
/> cd backstores/
/backstores> block/ create block_data /dev/vg_iscsi/lv_iscsi
Created block storage object block_data using /dev/vg_iscsi/lv_iscsi.
```
создаем iscsi target
```
/iscsi> create
Created target iqn.2003-01.org.linux-iscsi.iscsi-target.x8664:sn.42e5cd9958f1.
Created TPG 1.
Global pref auto_add_default_portal=true
Created default portal listening on all IPs (0.0.0.0), port 3260.
```
Пропишем ACLs для worker-нод (смотрим имя iscsi инициатора на worker'ах в /etc/iscsi/initiatorname.iscsi)
```
/iscsi/iqn.20...70934e76/tpg1> acls/ create iqn.1994-05.com.redhat:d8f1b17f435
Created Node ACL for iqn.1994-05.com.redhat:d8f1b17f435
/iscsi/iqn.20...70934e76/tpg1> acls/ create iqn.1994-05.com.redhat:4365725d6714
Created Node ACL for iqn.1994-05.com.redhat:4365725d6714
/iscsi/iqn.20...70934e76/tpg1>
```
Создаем Lun
```
/iscsi/iqn.20...70934e76/tpg1> luns/ create /backstores/block/block_data
Created LUN 0.
Created LUN 0->0 mapping in node ACL iqn.1994-05.com.redhat:4365725d6714
Created LUN 0->0 mapping in node ACL iqn.1994-05.com.redhat:d8f1b17f435
```
Создаем portal
```
/iscsi/iqn.20...70934e76/tpg1> portals/ create ip_address=192.168.0.100 ip_port=3260
Using default IP port 3260
Created network portal 192.168.0.100:3260.
```
Итоговая картина на iscsi-target
```
o- / ..................................................................... [...]
  o- backstores .......................................................... [...]
  | o- block .............................................. [Storage Objects: 1]
  | | o- block_data .... [/dev/vg_iscsi/lv_iscsi (10.0GiB) write-thru activated]
  | |   o- alua ............................................... [ALUA Groups: 1]
  | |     o- default_tg_pt_gp ................... [ALUA state: Active/optimized]
  | o- fileio ............................................. [Storage Objects: 0]
  | o- pscsi .............................................. [Storage Objects: 0]
  | o- ramdisk ............................................ [Storage Objects: 0]
  o- iscsi ........................................................ [Targets: 1]
  | o- iqn.2003-01.org.linux-iscsi.iscsi-target.x8664:sn.42e5cd9958f1  [TPGs: 1]
  |   o- tpg1 ........................................... [no-gen-acls, no-auth]
  |     o- acls ...................................................... [ACLs: 2]
  |     | o- iqn.1994-05.com.redhat:4365725d6714 .............. [Mapped LUNs: 1]
  |     | | o- mapped_lun0 ........................ [lun0 block/block_data (rw)]
  |     | o- iqn.1994-05.com.redhat:d8f1b17f435 ............... [Mapped LUNs: 1]
  |     |   o- mapped_lun0 ........................ [lun0 block/block_data (rw)]
  |     o- luns ...................................................... [LUNs: 1]
  |     | o- lun0  [block/block_data (/dev/vg_iscsi/lv_iscsi) (default_tg_pt_gp)]
  |     o- portals ................................................ [Portals: 1]
  |       o- 192.168.0.100:3260 ........................................... [OK]
  o- loopback ..................................................... [Targets: 0]

```
7. Создаем iscsi PersistentVolume
```
kubectl apply -f kubernetes-storage/iscsi/iscsi-pv.yaml
```
8. Создаем iscsi PersistentVolumeClaim
```
kubectl apply -f kubernetes-storage/iscsi/iscsi-pvc.yaml
```
9. Создаем Pod cо смонтированной директорией /data
```
kubectl apply -f kubernetes-storage/iscsi/iscsi-pod.yaml
```
10. Заходим в Pod и пишем данные в /data
```
kubectl exec -it iscsi-pod /bin/bash
cd /data
echo "YOHOOOO" > data.txt
```
11. Делаем снапшот LVM раздела на iscsi-target
```
gcloud compute ssh iscsi-target
sudo -i
lvcreate --size 10G --snapshot --name snap_lv_iscsi /dev/vg_iscsi/lv_iscsi      
```
12. Удаляем данные, pod, pvc, pv, lvm из iscsi
```
kubectl exec -it iscsi-pod /bin/bash
rm -rf /data/*
exit
kubectl delete po iscsi-pod
kubectl delete pvc iscsi-pvc
kubectl delete pv iscsi-pv
gcloud compute ssh iscsi-target
sudo -i
targetcli
backstores/block/ delete block_data
```
13. Восстанавливаемся из снапшота
```
[root@iscsi-target ~]# lvconvert --merge /dev/vg_iscsi/snap_lv_iscsi
  Merging of volume vg_iscsi/snap_lv_iscsi started.
  vg_iscsi/lv_iscsi: Merged: 100,00%
```
Снова добавляем раздел в хранилище
```
[root@iscsi-target ~]# targetcli
targetcli shell version 2.1.fb46
Copyright 2011-2013 by Datera, Inc and others.
For help on commands, type 'help'.

/> /backstores/block create block_data /dev/vg_iscsi/lv_iscsi
Created block storage object block_data using /dev/vg_iscsi/lv_iscsi.
/> cd iscsi/iqn.2003-01.org.linux-iscsi.iscsi-target.x8664:sn.42e5cd9958f1/
/iscsi/iqn.20....42e5cd9958f1> cd tpg1/
/iscsi/iqn.20...cd9958f1/tpg1> luns/ create /backstores/block/block_data
Created LUN 0.
Created LUN 0->0 mapping in node ACL iqn.1994-05.com.redhat:4365725d6714
Created LUN 0->0 mapping in node ACL iqn.1994-05.com.redhat:d8f1b17f435
/iscsi/iqn.20...cd9958f1/tpg1>
```
Создаем pv, pvc, pod
```
➜  SOMikhaylov_platform git:(kubernetes-storage) ✗ kubectl apply -f kubernetes-storage/iscsi/iscsi-pv.yaml
persistentvolume/iscsi-pv created
➜  SOMikhaylov_platform git:(kubernetes-storage) ✗ kubectl apply -f kubernetes-storage/iscsi/iscsi-pvc.yaml
persistentvolumeclaim/iscsi-pvc created
➜  SOMikhaylov_platform git:(kubernetes-storage) ✗ kubectl apply -f kubernetes-storage/iscsi/iscsi-pod.yaml
pod/iscsi-pod created
➜  SOMikhaylov_platform git:(kubernetes-storage) ✗
```
Заходим в pod и проверяем есть ли данные
```
➜  SOMikhaylov_platform git:(kubernetes-storage) ✗ kubectl exec -it iscsi-pod /bin/bash
root@iscsi-pod:/# cd /data
root@iscsi-pod:/data# ls
data.txt  lost+found
root@iscsi-pod:/data# cat data.txt
YOHOOOO
root@iscsi-pod:/data#
```
Все данные на месте!
