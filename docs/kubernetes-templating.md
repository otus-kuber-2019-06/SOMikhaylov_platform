## На чем выполнялось ДЗ
kubernetes cluster v1.14.7-gke.10
```
➜  ~ helm version --client
Client: &version.Version{SemVer:"v2.14.3", GitCommit:"0e7f3b6637f7af8fcfddb3d2941fcc7cbebb0085", GitTreeState:"clean"}
```
```
➜  ~ helm3 version
version.BuildInfo{Version:"v3.0.0-beta.4", GitCommit:"7ffc879f137bd3a69eea53349b01f05e3d1d2385", GitTreeState:"dirty", GoVersion:"go1.13.1"}
```

## Что сделано в ДЗ
1. установлен Helm2 и tiller с правами cluster-admin.
* установлен nginx-ingress.
2. установлен Helm2 и tiller с правами, ограниченными namespace.
* протестирована установка cert-manager с помощью данной связки.
* сделано самостоятельно задание.
3. установлен plugin helm-tiller, для использования helm без тиллера внутри кластера.
* установлен chartmuseum с доступом через ingress по https.
* Сделано задание со * (chartmuseum)
4. установлен Helm3
* установлен Harbor с доступом через ingress по https
5. Задание со * - Описан Helmfile для установки nginx-ingres, cert-manager, harbor
6. Создан свой helm chart
7. Задание со *: свой чарт mysql
8. Задание с Kubecfg
9. Задание с Kustomize

### Helm 2 и tiller с правами cluster-admin
1. Создаем service account tiller и даем ему роль cluster-admin
```
kubectl apply -f tiller-cluster-admin.yaml
```
2. устанавливаем nginx-ingress с помощью helm
```
helm init --service-account=tiller
helm upgrade --install nginx-ingress stable/nginx-ingress --wait --namespace=nginx-ingress --version=1.24.3
```

### Helm 2 и tiller с правами, ограниченными namespace
1. Создаем service account tiller-cert-manager 
```
kubectl apply -f cert-manager/cert-manager-namespace.yaml
kubectl apply -f cert-manager/tiller-cert-manager.yaml
```
```
helm init --tiller-namespace cert-manager --service-account cert-manager/tiller-cert-manager
helm repo add jetstack https://charts.jetstack.io
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.11/deploy/manifests/00-crds.yaml
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation="true"
```
2. проверим, что tiller в namespace cert-manager действительно необладает правами на управление объектами в других namespace
```
➜  kubernetes-templating git:(kubernetes-templating) ✗ helm upgrade --install cert-manager jetstack/cert-manager --wait  --namespace=nginx-ingress --version=0.11.0 --tiller-namespace cert-manager
Release "cert-manager" does not exist. Installing it now.
Error: release cert-manager failed: namespaces "nginx-ingress" is forbidden: User "system:serviceaccount:cert-manager:tiller-cert-manager" cannot get resource "namespaces" in API group "" in the namespace "nginx-ingress"
```
3. Установим cert-manager в корректный namespace
```
➜  kubernetes-templating git:(kubernetes-templating) ✗ helm upgrade --install cert-manager jetstack/cert-manager --wait  --namespace=cert-manager --version=0.11.0 --tiller-namespace cert-manager
WARNING: Namespace "cert-manager" doesn't match with previous. Release will be deployed to nginx-ingress
UPGRADE FAILED
Error: "cert-manager" has no deployed releases
Error: UPGRADE FAILED: "cert-manager" has no deployed releases
```
```
➜  kubernetes-templating git:(kubernetes-templating) ✗ helm delete --purge cert-manager --tiller-namespace cert-manager 
release "cert-manager" deleted
➜  kubernetes-templating git:(kubernetes-templating) ✗ helm upgrade --install cert-manager jetstack/cert-manager --wait  --namespace=cert-manager --version=0.11.0 --tiller-namespace cert-manager --atomic
Release "cert-manager" does not exist. Installing it now.
INSTALL FAILED
PURGING CHART
Error: release cert-manager failed: clusterroles.rbac.authorization.k8s.io is forbidden: User "system:serviceaccount:cert-manager:tiller-cert-manager" cannot create resource "clusterroles" in API group "rbac.authorization.k8s.io" at the cluster scope
Successfully purged a chart!
```
#### Самостоятельное задание
1. Ошибка возникает из-за того, что у сервис аккаунта тиллера есть права на создание ресурсов только в своем namespace, а требуется создать в API group rbac.authorization.k8s.io. Ограничивать tiller в отдельном namespace не имеет смысла.
2. Установим cert-manager c помощью тиллера с правами кластер админ.
```
helm init --service-account=tiller
helm upgrade --install cert-manager jetstack/cert-manager --wait  --namespace=cert-manager --version=0.11.0
```
```
➜  kubernetes-templating git:(kubernetes-templating) ✗ kubectl get pods --namespace cert-manager
NAME                                       READY   STATUS    RESTARTS   AGE
cert-manager-55fff7f85f-swg46              1/1     Running   0          2m7s
cert-manager-cainjector-54c4796c5d-qv9xp   1/1     Running   0          2m7s
cert-manager-webhook-77ccf5c8b4-9fhlt      1/1     Running   0          2m7s
```
3. Для корректной работы для генерации валидного сертификата Let's Encrypt (будем использовать staging сертификат) требуется создать ClusterIssuer
```
helm upgrade --install cert-manager jetstack/cert-manager --wait  --namespace=cert-manager --version=0.11.0 
kubectl apply -f cert-manager/cluster-issuer.yaml
```
### Helm 2 с плагином helm-tiller (позволяет отказаться отиспользования tiller внутри кластера)
Установим плагин
```
helm plugin install https://github.com/rimusz/helm-tiller
```
Устанавливем chartmuseum
```
export HELM_TILLER_STORAGE=configmap
helm tiller run helm upgrade --install chartmuseum stable/chartmuseum --wait --namespace=chartmuseum --version=2.3.2 -f chartmuseum/values.yaml
```
#### Задание со *
1. создаем helm chart
```
helm create web-deployment
rm -rf web-deployment/templates/*
rm -f web-deployment/values.yaml
cp ../kubernetes-networks/web-deploy.yaml web-deployment/templates
helm package web-deployment
```
2. добавляем репозиторий chartmuseum 
```
➜ helm repo add chartmuseum https://chartmuseum.35.198.84.6.xip.io/
```
3. добавим чарт в репозиторий с помощью curl
```
➜  kubernetes-templating git:(kubernetes-templating) ✗ curl -k --data-binary "@web-deployment-0.1.0.tgz" https://chartmuseum.35.198.84.6.xip.io/api/charts
{"saved":true}% 
```
4. устанавливаем из репозитория
```
helm install chartmuseum/web-deployment       
```
### Helm 3
1. добавляем репозитория харбор
```
helm3 repo add harbor https://helm.goharbor.io
```
2. создаем namespace harbor
```
kubectl apply -f harbor/harbor-namespace.yaml
```
3. устанавливаем harbor
```
helm3 upgrade --install harbor harbor/harbor --wait --namespace=harbor --version=1.1.2 -f harbor/values.yaml
```
### Задание со * - Helmfile для установки nginx-ingres, cert-manager, harbor
1. для примененения потребовался плагин diff
```
helm plugin install https://github.com/databus23/helm-diff
```
2. создаем chart для crd certmanager
```
cd helmfile
helm create crds-cert-manager
rm -rf crds-cert-manager/templates/*
rm -rf crds-cert-manager/values.yaml
wget -P crds-cert-manager/templates/ https://raw.githubusercontent.com/jetstack/cert-manager/release-0.11/deploy/manifests/00-crds.yaml
```
2. применяем helmfile (находимcя на уровне выше helmfile.d/ )
```
helmfile apply
```
### Создание своего  helm chart
1. Создан свой чарт
```
helm create socks-shop
rm -rf socks-shop/templates/*
rm -rf socks-shop/values.yaml
wget -P socks-shop/templates https://raw.githubusercontent.com/express42/otus-platform-snippets/master/Module-04/05-Templating/manifests/all.yaml
helm upgrade --install socks-shop socks-shop 
```
2. Вынесен frontend отдельно, добавим зависисмости в requirements.yaml
```
helm dep update socks-shop
helm upgrade --install socks-shop socks-shop --namespace socks-shop --set frontend.service.NodePort=31234
```

#### Задание со * chart mysql
1. создан chart mysql
2. Добавлена зависимость requirements.yaml sock-shop
3. создан values.yaml
4. вынесены deployment и service mysql
```
helm dep update socks-shop
helm upgrade --install socks-shop socks-shop --namespace socks-shop --set frontend.service.NodePort=31234
```
### Kubecfg
1. Созданы необходимые файлы для выполнения задания
```
kubecfg
├── catalogue-deployment.yaml
├── catalogue-service.yaml
├── payment-deployment.yaml
├── payment-service.yaml
└── services.jsonnet
```
2. Проверка правильности генерирования манифестов
```
kubecfg show kubecfg/services.jsonnet
```
3. Установка
```
kubecfg update kubecfg/services.jsonnet --namespace socks-shop
```
### Kustomize
1. kustomизирован сервис payment
2. Установка
```
kubectl apply -k kustomize/overrides/socks-shop
```
```
kubectl apply -k kustomize/overrides/socks-shop-prod
```