## На чем выполнялось ДЗ
kubernetes cluster version 1.15.4
```
➜  ~ kubectl version         
Client Version: version.Info{Major:"1", Minor:"15", GitVersion:"v1.15.4", GitCommit:"67d2fcf276fcd9cf743ad4be9a9ef5828adc082f", GitTreeState:"clean", BuildDate:"2019-09-18T21:50:21Z", GoVersion:"go1.12.9", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"15", GitVersion:"v1.15.4", GitCommit:"67d2fcf276fcd9cf743ad4be9a9ef5828adc082f", GitTreeState:"clean", BuildDate:"2019-09-18T14:41:55Z", GoVersion:"go1.12.9", Compiler:"gc", Platform:"linux/amd64"}
```
```
➜  ~ helm version --client
Client: &version.Version{SemVer:"v2.14.3", GitCommit:"0e7f3b6637f7af8fcfddb3d2941fcc7cbebb0085", GitTreeState:"clean"}
```
```
➜  ~ helm3 version
version.BuildInfo{Version:"v3.0.0-beta.4", GitCommit:"7ffc879f137bd3a69eea53349b01f05e3d1d2385", GitTreeState:"dirty", GoVersion:"go1.13.1"}
```
В кластере используется calico
```
kubectl apply -f https://docs.projectcalico.org/v3.9/manifests/calico.yaml
```
и metallb
```
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.8.1/manifests/metallb.yaml
```

## Что сделано в ДЗ
1. установлен Helm2 и tiller с правами cluster-admin.
  - установлен nginx-ingress.
2. установлен Helm2 и tiller с правами, ограниченными namespace.
  - протестирована установка cert-manager с помощью данной связки.
  - сделано самостоятельно задание.
3. установлен plugin helm-tiller, для использования helm без тиллера внутри кластера.
  - установлен chartmuseum с помощью данной связки.
  - Сделано задание со * (chartmuseum)
4. 

### Helm 2 и tiller с правами cluster-admin
Создаем service account tiller и даем ему роль cluster-admin
```
kubectl apply -f tiller-cluster-admin.yaml
```
устанавливаем nginx-ingress с помощью helm
```
helm init --service-account=tiller
helm upgrade --install nginx-ingress stable/nginx-ingress --wait --namespace=nginx-ingress --version=1.24.2 --set controller.service.loadBalancerIP="192.168.122.100"
```

### Helm 2 и tiller с правами, ограниченными namespace
Создаем service account tiller-cert-manager 
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
проверим, что tiller в namespace cert-manager действительно необладает правами на управление объектами в других namespace
```
➜  kubernetes-templating git:(kubernetes-templating) ✗ helm upgrade --install cert-manager jetstack/cert-manager --wait  --namespace=nginx-ingress --version=0.11.0 --tiller-namespace cert-manager
Release "cert-manager" does not exist. Installing it now.
Error: release cert-manager failed: namespaces "nginx-ingress" is forbidden: User "system:serviceaccount:cert-manager:tiller-cert-manager" cannot get resource "namespaces" in API group "" in the namespace "nginx-ingress"
```
Установим cert-manager в корректный namespace
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
1. Ошибка вознакет из-за того, что у сервис аккаунта тиллера есть права на создание ресурсов только в своем namespace, а требуется создать в API group rbac.authorization.k8s.io. Ограничивать tiller в отдельном namespace не имеет смысла.
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
3. Проверим что cert-manager корректно установил основные типы сертификатов эмитента (переведено yandex translate) 
```
```
➜  kubernetes-templating git:(kubernetes-templating) ✗ kubectl apply -f cert-manager/test-resources.yaml 
namespace/cert-manager-test created
Error from server (InternalError): error when creating "test-resources.yaml": Internal error occurred: failed calling webhook "webhook.cert-manager.io": the server is currently unable to handle the request
```
исправим ошибку
```
helm upgrade cert-manager jetstack/cert-manager --namespace=cert-manager --version=0.11.0 --reuse-values --set webhook.enabled=false
```
➜  kubernetes-templating git:(kubernetes-templating) ✗ kubectl describe certificate -n cert-manager-test
Name:         selfsigned-cert
Namespace:    cert-manager-test
Labels:       <none>
Annotations:  kubectl.kubernetes.io/last-applied-configuration:
                {"apiVersion":"cert-manager.io/v1alpha2","kind":"Certificate","metadata":{"annotations":{},"name":"selfsigned-cert","namespace":"cert-mana...
API Version:  cert-manager.io/v1alpha2
Kind:         Certificate
Metadata:
  Creation Timestamp:  2019-10-12T07:15:52Z
  Generation:          1
  Resource Version:    5873
  Self Link:           /apis/cert-manager.io/v1alpha2/namespaces/cert-manager-test/certificates/selfsigned-cert
  UID:                 624449a5-1cca-48a3-bfb8-502386696c79
Spec:
  Common Name:  example.com
  Issuer Ref:
    Name:       test-selfsigned
  Secret Name:  selfsigned-cert-tls
Status:
  Conditions:
    Last Transition Time:  2019-10-12T07:15:53Z
    Message:               Certificate is up to date and has not expired
    Reason:                Ready
    Status:                True
    Type:                  Ready
  Not After:               2020-01-10T07:15:53Z
Events:
  Type    Reason        Age   From          Message
  ----    ------        ----  ----          -------
  Normal  GeneratedKey  28s   cert-manager  Generated a new private key
  Normal  Requested     28s   cert-manager  Created new CertificateRequest resource "selfsigned-cert-2334779822"
  Normal  Issued        28s   cert-manager  Certificate issued successfully
➜  kubernetes-templating git:(kubernetes-templating) ✗ kubectl delete -f cert-manager/test-resources.yaml 
namespace "cert-manager-test" deleted
issuer.cert-manager.io "test-selfsigned" deleted
certificate.cert-manager.io "selfsigned-cert" deleted
```
4. Для корректной работы требуется создать ClusterIssuer, возьмем из документации манифест, который подходит для ingress controller
```
kubectl apply -f cert-manager/cluster-issuer.yaml
```
### Helm 2 с плагином helm-tiller (позволяет отказаться отиспользования tiller внутри кластера)
Установим плагин
```
helm plugin install https://github.com/rimusz/helm-tiller
```
Устанавливем chartmuseum
```
helm tiller run helm upgrade --install chartmuseum stable/chartmuseum --wait --namespace=chartmuseum --version=2.3.2 -f chartmuseum/values.yaml
```
Проверим, что tiller внутри кластера ничего не знает про release chartmuseum
```
➜  kubernetes-templating git:(kubernetes-templating) ✗ helm list
NAME         	REVISION	UPDATED                 	STATUS  	CHART               	APP VERSION	NAMESPACE    
cert-manager 	2       	Sun Oct 13 14:52:37 2019	DEPLOYED	cert-manager-v0.11.0	v0.11.0    	cert-manager 
nginx-ingress	1       	Sun Oct 13 14:40:57 2019	DEPLOYED	nginx-ingress-1.24.2	0.26.1     	nginx-ingress
```
а локальный tiller знает:
```
➜  kubernetes-templating git:(kubernetes-templating) ✗ helm tiller run helm list
Installed Helm version v2.14.3
Installed Tiller version v2.14.3
Helm and Tiller are the same version!
Starting Tiller...
Tiller namespace: kube-system
Running: helm list

NAME       	REVISION	UPDATED                 	STATUS  	CHART            	APP VERSION	NAMESPACE  
chartmuseum	1       	Sun Oct 13 15:14:09 2019	DEPLOYED	chartmuseum-2.3.2	0.8.2      	chartmuseum
Stopping Tiller...
```
переустановим с указанием переменной export HELM_TILLER_STORAGE=configmap
Проверим на работоспособность
```
➜  kubernetes-templating git:(kubernetes-templating) ✗ curl -k https://chartmuseum.192.168.122.100.nip.io/
<!DOCTYPE html>
<html>
<head>
<title>Welcome to ChartMuseum!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to ChartMuseum!</h1>
<p>If you see this page, the ChartMuseum web server is successfully installed and
working.</p>

<p>For online documentation and support please refer to the
<a href="https://github.com/helm/chartmuseum">GitHub project</a>.<br/>

<p><em>Thank you for using ChartMuseum.</em></p>
</body>
</html>
	%
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
➜  kubernetes-templating git:(kubernetes-templating) ✗ helm repo add  chartmuseum https://chartmuseum.192.168.122.100.nip.io/
Error: Looks like "https://chartmuseum.192.168.122.100.nip.io/" is not a valid chart repository or cannot be reached: Get https://chartmuseum.192.168.122.100.nip.io/index.yaml: x509: certificate is valid for ingress.local, not chartmuseum.192.168.122.100.nip.io
```
Получаем ошибку. Необходимо переустановить chartmuseum c параметром  --set env.open.DISABLE_API=false
```
helm tiller run helm upgrade --install chartmuseum stable/chartmuseum --wait --namespace=chartmuseum --version=2.3.2 -f chartmuseum/values.yaml --set env.open.DISABLE_API=false
```
3. добавим чарт в репозиторий с помощью curl
```
➜  kubernetes-templating git:(kubernetes-templating) ✗ curl -k --data-binary "@web-deployment-0.1.0.tgz" https://chartmuseum.192.168.122.100.nip.io/api/charts
{"saved":true}% 
```
4. устанавливаем репозиторий
```
➜  kubernetes-templating git:(kubernetes-templating) ✗ helm repo add chartmuseum http://chartmuseum.192.168.122.100.nip.io 
"chartmuseum" has been added to your repositories
```
```
➜  kubernetes-templating git:(kubernetes-templating) ✗ helm repo update
Hang tight while we grab the latest from your chart repositories...
...Skip local chart repository
...Successfully got an update from the "chartmuseum" chart repository
...Successfully got an update from the "jetstack" chart repository
...Successfully got an update from the "stable" chart repository
Update Complete.
```
5. устанавливаем из репозитория
```
➜  kubernetes-templating git:(kubernetes-templating) ✗ helm install chartmuseum/web-deployment       
NAME:   melting-gecko
LAST DEPLOYED: Sun Oct 13 20:22:55 2019
NAMESPACE: default
STATUS: DEPLOYED

RESOURCES:
==> v1/Deployment
NAME  READY  UP-TO-DATE  AVAILABLE  AGE
web   0/3    0           0          0s

==> v1/Pod(related)
NAME                 READY  STATUS   RESTARTS  AGE
web-f546f4d65-4bd88  0/1    Pending  0         0s
web-f546f4d65-9rmlq  0/1    Pending  0         0s
web-f546f4d65-zgclz  0/1    Pending  0         0s
```
### Helm 3
добавляем репозитория харбор
```
helm3 repo add harbor https://helm.goharbor.io
helm3 fetch --untar harbor/harbor --version 1.1.2
```
создаем namespace harbor
```
kubectl apply -f harbor/harbor-namespace.yaml
```
устанавливаем harbor
```
helm3 upgrade --install harbor harbor/harbor --wait --namespace=harbor --version=1.2.0 -f harbor/values.yaml --set harborAdminPassword=admin
```
После установки Ingress
An example Ingress that makes use of the controller:

  apiVersion: extensions/v1beta1
  kind: Ingress
  metadata:
    annotations:
      kubernetes.io/ingress.class: nginx
    name: example
    namespace: foo
  spec:
    rules:
      - host: www.example.com
        http:
          paths:
            - backend:
                serviceName: exampleService
                servicePort: 80
              path: /
    # This section is only required if TLS is to be enabled for the Ingress
    tls:
        - hosts:
            - www.example.com
          secretName: example-tls

If TLS is enabled for the Ingress, a Secret containing the certificate and key must also be provided:

  apiVersion: v1
  kind: Secret
  metadata:
    name: example-tls
    namespace: foo
  data:
    tls.crt: <base64 encoded cert>
    tls.key: <base64 encoded key>
  type: kubernetes.io/tls