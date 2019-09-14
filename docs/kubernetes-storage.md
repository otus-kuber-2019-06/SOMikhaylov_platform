 - [x] Основное ДЗ
 - [x] Задание со *

## Основное ДЗ
1. Volume Snapshot находится в альфе k8s версии 1.15 (v1alpha3), поэтому для тестирования снапшотов создадим кластер в kind
```
kind create cluster --config cluster/cluster.yaml
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
kubectl apply -f hw/01-storageclass.yaml
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
kubectl apply -f hw/02-pvc.yaml
```
проверяем: kubectl get pvc
```
NAME          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
storage-pvc   Bound    pvc-2fcc87ac-50dc-46b0-a88e-3205c2072935   1Gi        RWO            csi-hostpath-sc   2m14s
```
6. cоздаем объект Pod c именем storage-pod
```
kubectl apply -f hw/03-pod-pvc.yaml
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
kubectl apply -f snap/01-snapshot.yaml
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
kubectl apply -f snap/02-pvc-snap.yaml
kubectl apply -f hw/03-pod-pvc.yaml
kubectl exec -it storage-pod /bin/bash
cat /data/snapdata
```

## Задание со *
1. Метод разворачивания кластера для выполнения домашнего задания описан в * [Развертывание кластера kubernetes в gcloud с помощью IaC подхода.] (docs/gcloud-k8s.md)
2. В данном ДЗ используется кластер из 3-х мастер нод и 2-х воркер нод. На нодах используется centos7.
