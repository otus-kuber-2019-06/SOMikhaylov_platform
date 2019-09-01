##  minikube:
  - minikube start     - создание/запуск виртуальной машины (VM)
  - minikube stop      - остановка VM
  - minikube delete    - удаление VM
  - minikube ssh       - зайти в VM по ssh
  - minikube dashboard - запустить dashboard
  - minikube mount <local_directory>:<minikube_directory> - смонтировать директорию в миникуб.
  - minikube addons list - список аддонов
  - minikube addins disable/enable <...> - поключить/отключить addon
  - toolbox - контейнер с Fedora (выполнить внутри миникуб).
##  $KUBECONFIG:
  - по умолчанию $HOME/.kube/config
  - пример использования сразу нескольких конфигов: export KUBECONFIG=~/.kube/config1:~/.kube/config2:~/.kube/config3
##  kubectl:
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
  - kubectl get pods --show-labels - показать метки
## gcloud
- gcloud init                             - инициализировать проект
- gcloud config set compute/region <...>  - default compute region
- gcloud config set compute/zone  <...>   - default compute zone
- gcloud compute instances list           - список виртуальных машин
- gcloud compute ssh <...>                - подключиться к виртульной машине по ssh
