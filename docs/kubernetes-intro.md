## установка minikube и других компонентов на Ubuntu 18.04
1. установка kubectl: sudo snap install kubectl --classic
2. установка minikube: https://kubernetes.io/docs/tasks/tools/install-minikube/
   - драйвер для KVM - https://github.com/kubernetes/minikube/blob/master/docs/drivers.md
   - minikube config set vm-driver kvm2
   - minikube start
3. установка Dashboard:
   - https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/
   - minikube dashboard
4. установка k9s: https://k9ss.io/

## Проверка отказаустойчивости k8s:
  1. docker rm -f $(docker ps -a -q)
  2. kubectl delete pod --all -n kube-system

  - При отказе узла Pod'ы пересоздает ReplicationSet.

## Dockerfile
собран и помещен на DockerHub образ somikhaylov/python_web

## Запуск Pod'a
1. kubectl apply -f web-pod.yaml && kubectl get pods -w
2. kubectl  describe  pod  web
3. kubectl port-forward --address 0.0.0.0 pod/web 8000:8000

проверка:
  - http://localhost:8000/index.html
