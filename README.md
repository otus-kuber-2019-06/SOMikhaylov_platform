# SOMikhaylov_platform
SOMikhaylov Platform repository

## Домашнее задание 1 - Знакомство с Kubernetes.
#### установка minikube и других компонентов на Ubuntu 18.04
1. установка kubectl: sudo snap install kubectl --classic
2. установка minikube: https://kubernetes.io/docs/tasks/tools/install-minikube/
   - драйвер для KVM - https://github.com/kubernetes/minikube/blob/master/docs/drivers.md
   - minikube config set vm-driver kvm2
   - minikube start
3. установка Dashboard:
   - https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/
   - minikube dashboard
4. установка k9s: https://k9ss.io/

#### Проверка отказаустойчивости k8s:
  1. docker rm -f $(docker ps -a -q)
  2. kubectl delete pod --all -n kube-system

  - При отказе узла Pod'ы пересоздает ReplicationSet.

#### Dockerfile
собран и помещен на DockerHub образ somikhaylov/python_web

#### Запуск Pod'a
1. kubectl apply -f web-pod.yaml && kubectl get pods -w
2. kubectl  describe  pod  web
3. kubectl port-forward --address 0.0.0.0 pod/web 8000:8000

проверка:
  - http://localhost:8000/index.html

## Домашнее задание 2 - Что стоит знать о безопасности и управлении доступом Kubernetes.
#### task1
1. 01-sa-bob-admin.yaml - создает service account bob, с ролью admin в рамках всего кластера
2. 02-sa-dave.yaml - создает service account dave без доступа в кластер.

проверка:
 - kubectl get clusterroles admin -o yaml
 - kubectl auth can-i get deployment --as system:serviceaccount:default:bob
 - kubectl auth can-i get deployment --as system:serviceaccount:default:dave
#### task2
1. 01-namespace-prometheus.yaml - создает namespace prometheus
2. 02-sa-carol.yaml - создает service account carol в namespace prometheus
3. 03-rules-prometheus.yaml - дает права всем sa делать list,get,watch на pods

проверка:
 - kubectl auth can-i watch pods --as system:serviceaccount:prometheus:carol
 - kubectl auth can-i delete pods --as system:serviceaccount:prometheus:carol
#### task3
1. 01-namespace-dev.yaml - создает namespace dev
2. 02-sa-jane.yaml - создает service account jane в namespace dev
3. 03-rolebinding-jane-admin.yaml - дает jane роль admin в namespace dev
4. 04-sa-ken.yaml - создает service account ken в namespace dev
5. 05-rolebinding-ken-view.yaml - дает ken роль view в namespace dev

проверка:
 - kubectl auth can-i get deployment --as system:serviceaccount:dev:jane -n dev
 - kubectl auth can-i list jobs --as system:serviceaccount:dev:ken -n dev

## Домашнее задание 3 -  Обзор сетевой подсистемы Kubernetes.

- установка kubespy - https://github.com/pulumi/kubespy

### Основное ДЗ

#### Добавление проверок Pod
- добавлены проверки readinessProbe и livenessProbe в kubernetes-intro/web-pod.yml
- livenessProbe проверяет доступность приложения, в случае если проверка провалена, то контейнетер перезапускается в соответсвии c параметром RestartPolicy. В конкретной задаче проверяется факт доступности по 8000 порту tcp.
- readinessProbe проверяет готовность к работе приложения, в случае провала PodConditions:Ready выставляется в false (Параметр влияет на то, будет ли Pod доступен для выполнения запросов и добавится в пул балансировки нагрузки со всеми связанными сервисами). В конкретной задаче проверяется факт доступности html страницы при подключении по 8000 порту.

вопрос:
1. Почему следующая конфигурация валидна, но не имеет смысла?
```
livenessProbe:
  exec:
    command:
      -'sh'
      -'-c'
      -'ps aux | grep my_web_server_process'
```
2. Бывают ли ситуации, когда она все-таки имеет смысл?

ответ:
1. 'sh -c ps aux' отрабатывает с кодом возврата 0 и передает свой вывод на ввод команды 'grep my_web_server_process' которая завершаетя с кодом возврата 1. Смысла данная конфигурация не имеет так livenessProbe exec ожидает код возврата от команды sh, которая постоянно завершается с кодом 0, а вывод правой части после pipe livenessProbe exec игнорирует.
2. Решить данную проблему можно переписав команду без использования pipe. Например 'sh -c pgrep my_web_server_process'. В результате будет получен цикличный рестарт Pod'а.
```
livenessProbe:
  exec:
    command:
      -'sh'
      -'-c'
      -'pgrep my_web_server_process'
```

#### Создание объекта Deployment
- создан манифест web-deploy.yaml для развертывания приложения в виде Deployment с 3 репликами.
- Проведено тестирование запуска Pod'a c разными параметрами maxUnavailable и maxSurge
```
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0
    maxSurge: 100
```
- maxSurge - Количество реплик, которое можно создать с превышением значения replicas. Можно задавать как абсолютное число, так и процент. Default: 25%.
- maxUnavailable - Количество реплик от общего числа, которое можно "уронить". Аналогично, задается в процентах или числом. Default: 25%.
- в случае если выставить maxSurge и maxUnavailable в 0 возникает ошибка (maxUnavailable не может быть 0 если maxSurge выставлено в 0).
- kubectl getevents --watch
- kubespy trace deploy web
#### Добавление сервисов в кластер (ClusterIP)
- создан манифест web-svc-cip.yaml для развертывания Service

#### Включение режима балансировки IPVS
- kubectl get services (посмотреть ClusterIP)
- minikube ssh
- iptables --list -nv -t nat
- kubectl --namespace kube-system edit configmap/kube-proxy (edit line: mode "ipvs")
- kubectl --namespace kube-system delete pod --selector='k8s-app=kube-proxy'
- minikube ssh; sudo -i; создаем файл /tmp/iptables.cleanup
  ```
  *nat  
  -A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE  
  COMMIT  
  *filter  
  COMMIT  
  *mangle  
  COMMIT
  ```
- iptables-restore/tmp/iptables.cleanup
- toolbox
- dnf install -y ipvsadm && dnf install -y ipset && dnf clean all
- ipvsadm --list -n
#### Установка MetalLB в Layer2-режиме
- kubectl apply -fhttps://raw.githubusercontent.com/google/metallb/v0.8.0/manifests/metallb.yaml
- kubectl --namespace metallb-system get all
- создан манифест metallb-config.yaml

#### Добавление сервиса Load Balancer
 - создан манифест web-svc-lb.yaml
 - kubectl kubectl describe svc web-svc-lb - посмотреть назначенный ip
 - minikube ssh; ip addr show eth0 - посмотреть адрес в миникубе.
 - ip route add <LB_IP> via <minikube_IP> - добавлен маршрут

 проверка: http://<LB_IP>/index.html

#### Установка Ingress-контроллера и прокси ingress-nginx
- kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml
- создан манифест nginx-lb.yaml
- curl -L <LB_IP>
#### Создание правил Ingress
- создан web-svc-headless.yaml
- создан web-ingress.yaml
проверка: http://<LB_IP>/web/index.html

### Задания со *

## Полезные команды.
minikube:
- minikube start     - создание/запуск виртуальной машины (VM)
- minikube stop      - остановка VM
- minikube delete    - удаление VM
- minikube ssh       - зайти в VM по ssh
- minikube dashboard - запустить dashboard
- minikube mount <local_directory>:<minikube_directory> - смонтировать директорию в миникуб.
- toolbox - контейнер с Fedora (выполнить внутри миникуб).

$KUBECONFIG:
- по умолчанию $HOME/.kube/config
- пример использования сразу нескольких конфигов: export KUBECONFIG=~/.kube/config1:~/.kube/config2:~/.kube/config3

kubectl:
- kubectl config view         - показывает конфиг кластера k8s ($KUBECONFIG)
- kubectl cluster-info        - проверка доступа к кластеру.
- kubectl get pods            - показать поды.
- kubectl get pods -w         - для отслеживания статуса подов.
- kubectl get cs              - показать статус компонентов.
- kubectl apply -f <...>.yaml - применить манифест.
- kubectl describe pod <...>  - посмотреть описание пода.
- kubectl delete pod  <...> [--grace-period=0 --force]  - удалить под.
- kubectl delete rc   <...>   - удалить ReplicationController.
- kubectl config get-contexts - посмотреть доступные контексты и контекст по умолчанию (полезно при использование нескольких конфигов).
- kubectl config use-context <...> - переключиться на другой контекст.
- kubectl get secrets <...> [-o yaml / -o "jsonpath={.data.token}"] - получить секреты токена (base64).
- kubectl auth can-i <operation> <resourse> --as system:serviceaccount:<namespace>:<sa-user> -n <namespace> - проверка на наличие доступа для system account user.
- kubectl get services - получить сервисы
