## Основное ДЗ
- установка kind - https://kind.sigs.k8s.io/docs/user/quick-start#installation
- kind create cluster
- export KUBECONFIG="$(kind get kubeconfig-path --name="kind")"
- docker pull minio/mc - установка mc для работы с Minio
- создан манифест minio-statefulset.yaml
- создан манифест minio-headless-service.yaml
### Задание со *
- Изменен манифист minio-headless-service.yaml - секреты берутся из minio-secrets.yaml
- секреты закодированы в base64; echo "minio" |openssl enc -base64
