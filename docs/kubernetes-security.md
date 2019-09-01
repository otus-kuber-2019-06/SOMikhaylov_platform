## task1
1. 01-sa-bob-admin.yaml - создает service account bob, с ролью admin в рамках всего кластера
2. 02-sa-dave.yaml - создает service account dave без доступа в кластер.

проверка:
 - kubectl get clusterroles admin -o yaml
 - kubectl auth can-i get deployment --as system:serviceaccount:default:bob
 - kubectl auth can-i get deployment --as system:serviceaccount:default:dave
## task2
1. 01-namespace-prometheus.yaml - создает namespace prometheus
2. 02-sa-carol.yaml - создает service account carol в namespace prometheus
3. 03-rules-prometheus.yaml - дает права всем sa делать list,get,watch на pods

проверка:
 - kubectl auth can-i watch pods --as system:serviceaccount:prometheus:carol
 - kubectl auth can-i delete pods --as system:serviceaccount:prometheus:carol
## task3
1. 01-namespace-dev.yaml - создает namespace dev
2. 02-sa-jane.yaml - создает service account jane в namespace dev
3. 03-rolebinding-jane-admin.yaml - дает jane роль admin в namespace dev
4. 04-sa-ken.yaml - создает service account ken в namespace dev
5. 05-rolebinding-ken-view.yaml - дает ken роль view в namespace dev

проверка:
 - kubectl auth can-i get deployment --as system:serviceaccount:dev:jane -n dev
 - kubectl auth can-i list jobs --as system:serviceaccount:dev:ken -n dev
