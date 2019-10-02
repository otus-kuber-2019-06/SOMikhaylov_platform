- [x] Основное ДЗ
- [x] Задание с 🐍

## На чем выполнялось ДЗ
ОС: Ubuntu18.04
Дз выполнялось на minikube версии v1.4.0 (Kubernetes версии 1.16)
В манифестах в соответствии с документацией использовался
```
apiVersion: apiextensions.k8s.io/v1
```

## Что сделано в ДЗ
1. Описан CustomResourceDefinition для mysql оператора в манифесте deploy/crd.yaml.
```
kubectl apply -f deploy/crd.yaml
```
2. Описан CustomResource для mysql оператора в манифесте deploy/cr.yaml.
```
kubectl apply -f deploy/cr.yaml
```
3. Выполнено задание по CRD
4. Задание с 🐍
5. Дан ответ на вопрос в Задание с 🐍
6. Проведена отладка оператора с помощью kopf
7. Собран докер образ с оператором.

## Задание по CRD
```
Если сейчас из описания mysql убрать строчку из спецификации, то  манифест  будет  принят  API  сервером.  
Для  того,  чтобы  этого избежать, добавьте   описание   обязательных   полей в CustomResourceDefinition.
```
Параметр validation в 1.16 переведен в статус deprecated. Манифест deploy/crd.yaml исправлен в соответствии с документацией версии 1.16.
```
versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
```
Параметр отвечающий за проверку unknown field теперь включен по умолчанию его не надо добавлять в манифест.
Ранее использовался
```
spec:
  preserveUnknownField: true
```
Сейчас используется
```
properties:
  json:
    x-kubernetes-preserve-unknown-fields: true
```
В манифесте прописаны обязательные параметры и их типы
```
versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          apiVersion:
            type: string
          kind:
            type: string
          metadata:
            type: object
            properties:
              name:
                type: string
          spec:
            type: object
            properties:
              image:
                type: string
              database:
                type: string
              password:
                type: string
              storage_size:
                type: string
            required:
              - image
              - database
              - password
              - storage_size
        required:
          - apiVersion
          - kind
          - metadata
          - spec
```
Проверка:
```
➜  deploy git:(kubernetes-operators) ✗ kubectl apply -f cr.yml
error: error validating "cr.yml": error validating data: ValidationError(MySQL): unknown field "usless_data" in homework.otus.v1.MySQL; if you choose to ignore these errors, turn validation off with --validate=false
```
убираем из deploy/cr.yaml
```
usless_data: useless info
```
Все работает
```
➜  deploy git:(kubernetes-operators) ✗ kubectl apply -f cr.yml
mysql.otus.homework/mysql-instance created
```

## Задание с 🐍
1. Вопрос
```
почему  объект  создался,  хотя  мы  создали  CR,  до того, как запустили контроллер?
```
Ответ:
Оператор проверяет наличе уже созданных CR. В первую очередь это реализовано для того, чтобы после рестарта или удаления CustomResource оператор мог нормально функционировать.

2. Собираем Docker образ и пушим в репозиторий.
```
cd build/
docker build -t somikhaylov/mysql-operator:1.0 .
docker push somikhaylov/mysql-operator:1.0
```
3. применяем манифесты
```
kubectl apply -f deploy/service-account.yml
kubectl apply -f deploy/role.yml
kubectl apply -f deploy/role-binding.yml
kubectl apply -f deploy/deploy-operator.yml
```
4. Проверяем работоспособность
```
➜  kubernetes-operators git:(kubernetes-operators) ✗ kubectl get pvc
NAME                        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
backup-mysql-instance-pvc   Bound    pvc-d9770c6d-8892-4d04-8b06-19849bc8940c   1Gi        RWO            standard       2m7s
mysql-instance-pvc          Bound    pvc-53a77a45-9c03-40ca-bc79-25b4fcc30627   1Gi        RWO            standard       2m8s
```
Заполняем базу
```
export MYSQLPOD=$(kubectl get pods -l app=mysql-instance -o jsonpath="{.items[*].metadata.name}")

kubectl exec -it $MYSQLPOD -- mysql -u root  -potuspassword -e "CREATE TABLE test ( id smallint unsigned not null auto_increment, name varchar(20) not null, constraint pk_example primary key (id) );" otus-database

kubectl exec -it $MYSQLPOD -- mysql -potuspassword  -e "INSERT INTO test ( id, name )VALUES ( null, 'some data' );" otus-database

kubectl exec -it $MYSQLPOD -- mysql -potuspassword -e "INSERT INTO test ( id, name )VALUES ( null, 'some data-2' );" otus-database
```

Проверяем
```
➜  kubernetes-operators git:(kubernetes-operators) ✗ kubectl exec -it $MYSQLPOD -- mysql -potuspassword -e "select * from test;" otus-database
mysql: [Warning] Using a password on the command line interface can be insecure.
+----+-------------+
| id | name        |
+----+-------------+
|  1 | some data   |
|  2 | some data-2 |
+----+-------------+
```
Удалим mysql-instance
```
kubectl delete mysqls.otus.homework mysql-instance
```
проверяем выполнилась ли backup job
```
➜  kubernetes-operators git:(kubernetes-operators) ✗ kubectl get jobs
NAME                        COMPLETIONS   DURATION   AGE
backup-mysql-instance-job   1/1           6s         38s
```
Создаем заново mysql-instance
```
kubectl apply -f deploy/cr.yml
```
и проверяем выполнилась ли restore job
```
➜  kubernetes-operators git:(kubernetes-operators) ✗ kubectl get jobs   
NAME                         COMPLETIONS   DURATION   AGE
backup-mysql-instance-job    1/1           6s         3m48s
restore-mysql-instance-job   1/1           98s        2m44s
```
```
➜  kubernetes-operators git:(kubernetes-operators) ✗ export MYSQLPOD=$(kubectl get pods -l app=mysql-instance -o jsonpath="{.items[*].metadata.name}")
➜  kubernetes-operators git:(kubernetes-operators) ✗ kubectl exec -it $MYSQLPOD -- mysql -potuspassword -e "select * from test;" otus-database
mysql: [Warning] Using a password on the command line interface can be insecure.
+----+-------------+
| id | name        |
+----+-------------+
|  1 | some data   |
|  2 | some data-2 |
+----+-------------
```