## Развертывание кластера kubernetes в gcloud с помощью IaC подхода.

### Terrafrom
1. Инфраструктура в gcloud описана с помощью terraform (директория terraform_infra). Для примененения необходимо выполнить:
```
cd terraform_infra/
terraform init
terraform apply
```
2. Параметры которые переодически будут изменяться в целях тестирования (количество узлов кластера, образы ОС ..) вынесены  terraform_infra/variables.tf
3. Переменная с именем проекта используется как системная
```
export TF_VAR_project = "your-gcloud-project-name"
```  
### Ansible dynamic inventory
1. Ansible будет использоваться для развертывания кластера с помощью kubespray и по возможности в домашних заданиях. В связи с тем, что количество узлов кластера будет переодически изменяться, то используется dynamic inventory (Директория - ansible_inventory).
2. Настройку проводим в соответствии с https://docs.ansible.com/ansible/2.5/scenario_guides/guide_gce.html .
3. Потребуется вынести некоторые данные в системные переменные:
```
export GCE_EMAIL = "you_email_gcloud"
export GCE_PROJECT = "your-gcloud-project-name"
export GCE_CREDENTIALS_FILE_PATH = "you_credentials.json"
```
4. ansible_inventory/kubespray содержит описание групп хостов для работы kubespray.

### Kubernetes cluster
1. Создадим системную переменную, которая будет содержать публичный статический адрес,используемый для балансировки нагрузки между мастер-нодами
```
export KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe k8s-staticip \
      --region $(gcloud config get-value compute/region) \
      --format 'value(address)')
```
2. Клонируем kubespay рядом с основным проектом
```
git clone https://github.com/kubernetes-sigs/kubespray.git
```
3. Добавим публичный адрес в ansible_inventory/group_vars/k8s-cluster/k8s-cluster.yml.
```
supplementary_addresses_in_ssl_keys: ["{{ lookup('env','KUBERNETES_PUBLIC_ADDRESS') }}"]
```
Это необходимо чтобы данный IP был добавлен в сертификаты безопасности.

4. Разворачиваем  k8s кластер с помощью kubespray
```
ansible-playbook ../kubespray/cluster.yml
```
5. Копируем c мастер-ноды /etc/kubernetess/admin.conf на свою машину в ~/.kube/config. Меняем ip адрес в конфиге на тот,что в KUBERNETES_PUBLIC_ADDRESS.
