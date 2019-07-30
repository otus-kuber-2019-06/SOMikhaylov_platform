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
