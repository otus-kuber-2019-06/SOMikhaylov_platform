## Разворачиваем k8s кластер

1. Метод разворачивания кластера для выполнения домашнего задания описан в [Развертывание кластера kubernetes в gcloud с помощью IaC подхода.](../docs/gcloud-k8s.md)
2. В данном ДЗ используется кластер из 3-х мастер нод и 2-х воркер нод. На нодах используется centos7.

## kubectl debug

1. Устанавливаем kubectl debug https://github.com/aylei/kubectl-debug
2. запускаем kubecl debug на web pod из первого ДЗ
```
➜  kubernetes-debug git:(kubernetes-debug) ✗ kubectl debug web --port-forward
pod web PodIP 10.233.73.6, agentPodIP 10.0.0.21
wait for forward port to debug agent ready...
Forwarding from 127.0.0.1:10027 -> 10027
Forwarding from [::1]:10027 -> 10027
Handling connection for 10027
                             pulling image nicolaka/netshoot:latest...
latest: Pulling from nicolaka/netshoot
Digest: sha256:8b020dc72d8ef07663e44c449f1294fc47c81a10ef5303dc8c2d9635e8ca22b1
Status: Image is up to date for nicolaka/netshoot:latest
starting debug container...
container created, open tty...
bash-5.0#
```
3. запускаем внутри контейнера strace
```
bash-5.0# strace -c -p1
strace: test_ptrace_get_syscall_info: PTRACE_TRACEME: Operation not permitted
strace: attach: ptrace(PTRACE_ATTACH, 1): Operation not permitted
```
4. strace не работает... пробуем починить. По описанному выше видим, что pod создался на ноде с ip 10.0.0.21 (worker-1). Зайдем на эту ноду
```
➜  ~ gcloud compute ssh worker-1
[sergey@worker-1 ~]$ sudo -i
[root@worker-1 ~]# docker ps |grep netshoot
2b9d7cd9f755        nicolaka/netshoot:latest                   "bash"                   9 minutes ago       Up 9 minutes                            confident_bose
```
5. Посмотрим какие имеются Capability
```
[root@worker-1 ~]# docker inspect 2b9d7cd9f755 |grep Cap
            "CapAdd": null,
            "CapDrop": null,
            "Capabilities": null,
```
6. Перезапуск контейнера с нужными Capability не помогает, так при запуске 'kubectl debug web --port-forward' пулится всегда новый image контейнера 'netshoot'.  
```
docker run -it --cap-add SYS_PTRACE --cap-add SYS_ADMIN nicolaka/netshoot:latest
```
Pod c debug-agent cкачиваеи образ netshoot и не устанавливает нужные Capability. Для начала надо посмотреть есть ли другая версия debug-agent, где данная проблема могла быть устранена.
7. Попробуем сначала использовать последнюю версию образа предлагаемую разработчиком. Изменим манифест debug agent, удалим старую версию из DaemonSet и применим новый.
```
containers:
  - image: aylei/debug-agent:latest
```
```
kubectl delete ds debug-agent
kubectl apply -f strace/agent_daemonset.yml
```
8. Снова попробуем запустить strace в debug поде
```
bash-5.0# ps aux
PID   USER     TIME  COMMAND
    1 1001      0:00 /bin/sh -c python3 -m http.server 8000 --directory /app
    6 1001      0:02 python3 -m http.server 8000 --directory /app
 1075 root      0:00 bash
 1163 root      0:00 ps aux
bash-5.0# strace -p 6 -c
strace: Process 6 attached
^Cstrace: Process 6 detached
% time     seconds  usecs/call     calls    errors syscall
------ ----------- ----------- --------- --------- ----------------
 65.44    0.000640           8        76           poll
 28.32    0.000277          19        14           futex
  2.97    0.000029           4         7           clone
  2.56    0.000025           3         7           accept4
  0.72    0.000007           7         1           restart_syscall
------ ----------- ----------- --------- --------- ----------------
100.00    0.000978                   105           total

bash-5.0#
```
Все работает!

## iptables-tailer

1. устанавливаем по порядку манифесты
```
kubectl apply -f kit/crd.yaml
kubectl apply -f kit/clusterrole.yaml
kubectl apply -f kit/clusterrolebinding.yaml
kubectl apply -f kit/operator.yaml

```
2. Запускаем тестовое приложение
```
kubectl apply -f kit/cr.yaml
```
