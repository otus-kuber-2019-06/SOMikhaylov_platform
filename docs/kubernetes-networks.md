## Основное ДЗ

- установка kubespy - https://github.com/pulumi/kubespy

### Добавление проверок Pod
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

### Создание объекта Deployment
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
### Добавление сервисов в кластер (ClusterIP)
- создан манифест web-svc-cip.yaml для развертывания Service

### Включение режима балансировки IPVS
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
### Установка MetalLB в Layer2-режиме
- kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.8.0/manifests/metallb.yaml
- kubectl --namespace metallb-system get all
- создан манифест metallb-config.yaml
- kubectl apply -f metallb-config.yaml

### Добавление сервиса Load Balancer
 - создан манифест web-svc-lb.yaml
 - kubectl apply -f web-svc-lb.yaml
 - kubectl kubectl describe svc web-svc-lb - посмотреть назначенный ip
 - minikube ip - посмотреть адрес в миникубе.
 - ip route add 172.17.255.0/24 via <minikube_IP> - добавлен маршрут

 проверка: http://<LB_IP>/index.html

### Установка Ingress-контроллера и прокси ingress-nginx
- создан манифест nginx-lb.yaml
- kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml
- kubectl apply -f nginx-lb.yaml
- curl -L <LB_IP>
### Создание правил Ingress
- создан web-svc-headless.yaml
- создан web-ingress.yaml
- kubectl apply -f web-svc-headless.yaml
- kubectl apply -f web-ingress.yaml
проверка: http://<LB_IP>/web/index.html

## Задания со *
### MetalLB для CoreDNS
- minikude addoms enable coredns
- kubectl delete deploy -n kube-system --grace-period=0 --force kube-dns
- создан манифест coredns-svc-lb.yaml; selector взят из kubectl describe deploy -n kube-system coredns.
```
selector:
  k8s-app: kube-dns
```
- kubectl apply -f coredns-svc-lb.yaml
```
annotations:
    metallb.universe.tf/allow-shared-ip
```
- annotations позволяет использовать один ip адрес для разных сервисов.
проверка:
 - nslookup kubernetes.default.svc.cluster.local. 172.17.255.10

### Ingress kubernetes-dashboard
- создан манифест dashboard-ingress.yaml; kubectl apply -f dashboard-ingress.yaml
проверка:
- открыть в браузере <LB_IP>/dashboard/

### Ingress canary deployment
- kubectl apply -f echo-prod-deploy.yaml - создаем namespace echo-prod; deployment http-svc; service http-svc;
- kubectl apply -f echo-prod-ingress.yaml - http://<LB_IP>/canary
проверка:
- curl -H "Host: echo.com" http://<LB_IP>/canary
- kubectl apply -f echo-canary-deploy.yaml - создаем namespace echo-canary; deployment http-svc; service http-svc;
- kubectl apply -f echo-canary-ingress.yaml - http://<LB_IP>/canary
- nginx.ingress.kubernetes.io/canary: "true" - Это означает, что Kubernetes не будет рассматривать этот Ingress как самостоятельный и пометит его как Canary, связав с основным Ingress.
- nginx.ingress.kubernetes.io/canary-weight: "50" - "50" означает, что на Canary будет приходиться примерно 50% всех запросов
проверка canary deployment:
- curl -s -H "Host: echo.com" http://<LB_IP>/canary | grep 'pod namespace'
```
curl -s -H "Host: echo.com" http://172.17.255.1/canary | grep 'pod namespace'
 pod namespace:	echo-prod
```
```
curl -s -H "Host: echo.com" http://172.17.255.1/canary | grep 'pod namespace'
	pod namespace:	echo-canary
```
