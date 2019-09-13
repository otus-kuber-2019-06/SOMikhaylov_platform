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
1. Ansible будет использоваться для развертывания кластера с помощью kubespay и при возможность в домашних заданиях. В связи с тем, что количество узлоа кластера будем переодически изменять, то будем используем dynamic inventory (Директория - ansible_inventory).
2. Настройку проводим в соответсвии с https://docs.ansible.com/ansible/2.5/scenario_guides/guide_gce.html .
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
