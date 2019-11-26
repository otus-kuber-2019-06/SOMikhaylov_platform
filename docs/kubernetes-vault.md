# **Установка**
склонированы репозитории `vault-helm` и `consul-helm` рядом с основным проектом
```
git clone https://github.com/hashicorp/consul-helm.git
git clone https://github.com/hashicorp/vault-helm.git
```
установлен `consul`
```
helm install --name=consul ../consul-helm
```
установлен `vault` c параметрами [values.yaml](../kubernetes-vault/values.yaml)
```
helm install --name=vault ../vault-helm -f kubernetes-vault/values.yaml
```
после установки поды не переходят в статус `Ready`
```
➜  SOMikhaylov_platform git:(kubernetes-vault) ✗ helm status vault   
LAST DEPLOYED: Sun Nov 10 18:17:28 2019
NAMESPACE: default
STATUS: DEPLOYED

RESOURCES:
==> v1/ConfigMap
NAME          DATA  AGE
vault-config  1     2m3s

==> v1/Pod(related)
NAME     READY  STATUS   RESTARTS  AGE
vault-0  0/1    Running  0         2m3s
vault-1  0/1    Running  0         2m3s
vault-2  0/1    Running  0         2m3s

==> v1/Service
NAME      TYPE       CLUSTER-IP   EXTERNAL-IP  PORT(S)            AGE
vault     ClusterIP  10.12.10.42  <none>       8200/TCP,8201/TCP  2m3s
vault-ui  ClusterIP  10.12.1.150  <none>       8200/TCP           2m3s

==> v1/ServiceAccount
NAME   SECRETS  AGE
vault  1        2m3s

==> v1/StatefulSet
NAME   READY  AGE
vault  0/3    2m3s

==> v1beta1/PodDisruptionBudget
NAME   MIN AVAILABLE  MAX UNAVAILABLE  ALLOWED DISRUPTIONS  AGE
vault  N/A            1                0                    2m3s
```
в логах видим сообщение, что необходимо провести инициализацию
```
➜  SOMikhaylov_platform git:(kubernetes-vault) ✗ kubectl logs vault-0
==> Vault server configuration:

             Api Address: http://10.8.2.7:8200
                     Cgo: disabled
         Cluster Address: https://10.8.2.7:8201
              Listener 1: tcp (addr: "[::]:8200", cluster address: "[::]:8201", max_request_duration: "1m30s", max_request_size: "33554432", tls: "disabled")
               Log Level: info
                   Mlock: supported: true, enabled: false
                 Storage: consul (HA available)
                 Version: Vault v1.2.2

==> Vault server started! Log data will stream in below:

2019-11-10T09:25:06.508Z [INFO]  core: seal configuration missing, not initialized
```
---
# **Инициализиция**
проведена инициализация хранилища, после инициализации сохранены значения `Unseal Key` и `Initial Root Token`
```
kubectl exec -it vault-0 -- vault operator init --key-shares=1 --key-threshold=1
``` 
значение параметров;
- `--key-shares` - на сколько частей разбить ключ
- `--key-threshold` - сколько частей ключа требуется, чтобы распечатать хранилище

распечатан каждый под
```
kubectl exec -it vault-0 -- vault operator unseal 'rjF7D2rm3JcDSyzRq5hnc/JSC1eEZffcledDn32A6aY='
kubectl exec -it vault-1 -- vault operator unseal 'rjF7D2rm3JcDSyzRq5hnc/JSC1eEZffcledDn32A6aY='
kubectl exec -it vault-2 -- vault operator unseal 'rjF7D2rm3JcDSyzRq5hnc/JSC1eEZffcledDn32A6aY='
```
поды перешли в статус `Ready`
```
➜  SOMikhaylov_platform git:(kubernetes-vault) ✗ helm status vault
LAST DEPLOYED: Sun Nov 10 18:17:28 2019
NAMESPACE: default
STATUS: DEPLOYED

RESOURCES:
==> v1/ConfigMap
NAME          DATA  AGE
vault-config  1     7m56s

==> v1/Pod(related)
NAME     READY  STATUS   RESTARTS  AGE
vault-0  1/1    Running  0         7m56s
vault-1  1/1    Running  0         7m56s
vault-2  1/1    Running  0         7m56s

==> v1/Service
NAME      TYPE       CLUSTER-IP   EXTERNAL-IP  PORT(S)            AGE
vault     ClusterIP  10.12.10.42  <none>       8200/TCP,8201/TCP  7m56s
vault-ui  ClusterIP  10.12.1.150  <none>       8200/TCP           7m56s

==> v1/ServiceAccount
NAME   SECRETS  AGE
vault  1        7m56s

==> v1/StatefulSet
NAME   READY  AGE
vault  3/3    7m56s

==> v1beta1/PodDisruptionBudget
NAME   MIN AVAILABLE  MAX UNAVAILABLE  ALLOWED DISRUPTIONS  AGE
vault  N/A            1                1                    7m56s
```
---
# **Авторизация**
при попытке авторизации получена ошибка
```
➜  SOMikhaylov_platform git:(kubernetes-vault) ✗ kubectl exec -it vault-0 -- vault auth list
Error listing enabled authentications: Error making API request.

URL: GET http://127.0.0.1:8200/v1/sys/auth
Code: 400. Errors:

* missing client token
command terminated with exit code 2
```
логин в под с использованием токена
```
➜  SOMikhaylov_platform git:(kubernetes-vault) ✗ kubectl exec -it vault-0 --  vault login
Token (will be hidden): 
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                  Value
---                  -----
token                s.u6TkQ6ZwBHndAVj9vbkMgu7d
token_accessor       DVYnfhR5h76Vs0nNEKwN5qjW
token_duration       ∞
token_renewable      false
token_policies       ["root"]
identity_policies    []
policies             ["root"]
```
авторизация прошла успешно
```
➜  SOMikhaylov_platform git:(kubernetes-vault) ✗ kubectl exec -it vault-0 --  vault auth list
Path      Type     Accessor               Description
----      ----     --------               -----------
token/    token    auth_token_b56fc2d7    token based credentials
```
---
# **Секреты**
```
kubectl exec -it vault-0 -- vault secrets enable --path=otus kv
kubectl exec -it vault-0 -- vault secrets list --detailed
kubectl exec -it vault-0 -- vault kv put otus/otus-ro/config username='otus'password='asajkjkahs'
kubectl exec -it vault-0 -- vault kv put otus/otus-rw/config username='otus'password='asajkjkahs'
```
```
➜  SOMikhaylov_platform git:(kubernetes-vault) ✗ kubectl exec -it vault-0 -- vault read otus/otus-ro/config
Key                 Value
---                 -----
refresh_interval    768h
username            otuspassword=asajkjkahs
```
```
➜  SOMikhaylov_platform git:(kubernetes-vault) ✗ kubectl exec -it vault-0 -- vault kv get otus/otus-rw/config
====== Data ======
Key         Value
---         -----
username    otuspassword=asajkjkahs
```
---
# **Авторизация через kubernetes**
```
kubectl exec -it vault-0 -- vault auth enable kubernetes
```
```
➜  SOMikhaylov_platform git:(kubernetes-vault) ✗ kubectl exec -it vault-0 --  vault auth list
Path           Type          Accessor                    Description
----           ----          --------                    -----------
kubernetes/    kubernetes    auth_kubernetes_ccba0f75    n/a
token/         token         auth_token_b56fc2d7         token based credentials
```

создан `ServiceAccount` `vault-auth`
```
kubectl create serviceaccount vault-auth
kubectl apply -f kubernetes-vault/vault-auth-service-account.yml --validate=false
```

Переменные для записи в конфиг k8s
```
export VAULT_SA_NAME=$(kubectl get sa vault-auth -o jsonpath="{.secrets[*]['name']}")
export SA_JWT_TOKEN=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data.token}" |base64 --decode; echo)
export SA_CA_CRT=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data['ca\.crt']}" |base64 --decode; echo)
export K8S_HOST=$(more ~/.kube/config | grep server |awk '/http/ {print $NF}')
```
Запись конфига
```
kubectl exec -it vault-0 -- vault write auth/kubernetes/config token_reviewer_jwt="$SA_JWT_TOKEN" kubernetes_host="$K8S_HOST" kubernetes_ca_cert="$SA_CA_CRT"
```
политика и роль в vault
```
kubectl cp kubernetes-vault/otus-policy.hcl vault-0:/tmp
kubectl exec -it vault-0 -- vault policy write otus-policy /tmp/otus-policy.hcl
kubectl exec -it vault-0 -- vault write auth/kubernetes/role/otus bound_service_account_names=vault-auth  bound_service_account_namespaces=default policies=otus-policy ttl=24h
```

# **Проверка работы**
Создан pod с привязанным ServiceAccount
```
kubectl run --generator=run-pod/v1 tmp --rm -i --tty --serviceaccount=vault-auth --image alpine:3.7
apk add curl jq
```
получен клиентский токен
```
VAULT_ADDR=http://vault:8200
KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
curl --request POST --data '{"jwt": "'$KUBE_TOKEN'", "role": "otus"}' $VAULT_ADDR/v1/auth/kubernetes/login | jq
TOKEN=$(curl --request POST --data '{"jwt": "'$KUBE_TOKEN'", "role": "otus"}' $VAULT_ADDR/v1/auth/kubernetes/login | jq '.auth.client_token' | awk -F\" '{print $2}')
```
* проверка чтения
```
/ # curl --header "X-Vault-Token:$TOKEN" $VAULT_ADDR/v1/otus/otus-ro/config
{"request_id":"0bb83d13-3882-e767-4f20-490ecd09f865","lease_id":"","renewable":false,"lease_duration":2764800,"data":{"username":"otuspassword=asajkjkahs"},"wrap_info":null,"warnings":null,"auth":null}
```
```
/ # curl --header "X-Vault-Token:$TOKEN" $VAULT_ADDR/v1/otus/otus-rw/config
{"request_id":"a0856a4a-b08b-7769-05dc-49341ff5fd39","lease_id":"","renewable":false,"lease_duration":2764800,"data":{"username":"otuspassword=asajkjkahs"},"wrap_info":null,"warnings":null,"auth":null}
```
* проверка записи
```
/ # curl --request POST --data '{"bar": "baz"}'   --header "X-Vault-Token:$TOKEN" $VAULT_ADDR/v1/otus/otus-ro/config
{"errors":["1 error occurred:\n\t* permission denied\n\n"]}
```
```
/ # curl --request POST --data '{"bar": "baz"}'   --header "X-Vault-Token:$TOKEN" $VAULT_ADDR/v1/otus/otus-rw/config
{"errors":["1 error occurred:\n\t* permission denied\n\n"]}
```
```
/ # curl --request POST --data '{"bar": "baz"}'   --header "X-Vault-Token:$TOKEN" $VAULT_ADDR/v1/otus/otus-rw/config1
/ # curl --header "X-Vault-Token:$TOKEN" $VAULT_ADDR/v1/otus/otus-rw/config1
{"request_id":"545730eb-f471-c813-8912-fac3677fe55a","lease_id":"","renewable":false,"lease_duration":2764800,"data":{"bar":"baz"},"wrap_info":null,"warnings":null,"auth":null}
```

> Вопрос: Почему мы смогли записать otus-rw/config1 но не смогли otus-rw/config?

не получилось записать в otus-rw/config по причине того, что не даны права на изменение. Права добавлены в [otus-policy.hcl](../kubernetes-vault/otus-policy.hcl)

* проверка записи после изменений
```
/ # curl --request POST --data '{"bar": "baz"}'   --header "X-Vault-Token:$TOKEN" $VAULT_ADDR/v1/otus/otus-rw/config
/ # curl --header "X-Vault-Token:$TOKEN" $VAULT_ADDR/v1/otus/otus-rw/config
{"request_id":"d4bef795-37b5-2e04-c11d-7147a73edc3d","lease_id":"","renewable":false,"lease_duration":2764800,"data":{"bar":"baz"},"wrap_info":null,"warnings":null,"auth":null}
```
---
# **Use case использования авторизации через кубер**
```
git clone https://github.com/hashicorp/vault-guides.git
cd vault-guides/identity/vault-agent-k8s-demo
```
изменены configs-k8s/consul-template-config.hcl, configs-k8s/vault-agent-config.hcl example-k8s-spec.yml
```
kubectl create configmap example-vault-agent-config --from-file=./configs-k8s/
kubectl get configmap example-vault-agent-config -o yaml
kubectl apply -f example-k8s-spec.yml --record
```
## Проверка
достаем index.html
```
kubectl cp vault-agent-example:etc/secrets/index.html kubernetes-vault/index.html
```
```
➜  SOMikhaylov_platform git:(kubernetes-vault) ✗ cat kubernetes-vault/index.html                                                                  
  <html>
  <body>
  <p>Some secrets:</p>
  <ul>
  <li><pre>username: otus</pre></li>
  <li><pre>password: asajkjkahs</pre></li>
  </ul>
  
  </body>
  </html>
```

# **CA на базе vault**
Включен pki secrets
```
kubectl exec -it vault-0 -- vault secrets enable pki
kubectl exec -it vault-0 -- vault secrets tune -max-lease-ttl=87600h pki
kubectl exec -it vault-0 -- vault write -field=certificate pki/root/generate/internal common_name="exmaple.ru" ttl=87600h > CA_cert.crt
```
прописан URL для ca и отозванных сертификатов
```
kubectl exec -it vault-0 -- vault write pki/config/urls issuing_certificates="http://vault:8200/v1/pki/ca" crl_distribution_points="http://vault:8200/v1/pki/crl"
```
создан промежуточный сертификат
```
kubectl exec -it vault-0 -- vault secrets enable --path=pki_int pki
kubectl exec -it vault-0 -- vault secrets tune -max-lease-ttl=87600h pki_int
kubectl exec -it vault-0 -- vault write -format=json pki_int/intermediate/generate/internal common_name="example.ru Intermediate Authority" | jq -r '.data.csr' > pki_intermediate.csr
```
прописан промежуточный сертификат в vault
```
kubectl cp pki_intermediate.csr vault-0:/home/vault/
kubectl exec -it vault-0 -- vault write -format=json pki/root/sign-intermediate csr=@/home/vault/pki_intermediate.csr format=pem_bundle ttl="43800h" | jq -r '.data.certificate' > intermediate.cert.pem
kubectl cp intermediate.cert.pem vault-0:/home/vault/
kubectl exec -it vault-0 -- vault write pki_int/intermediate/set-signed certificate=@/home/vault/intermediate.cert.pem
```
cоздана роль для выдачи сертификатов
```
kubectl exec -it vault-0 -- vault write pki_int/roles/example-dot-ru allowed_domains="example.ru" allow_subdomains=true max_ttl="720h"
```
cоздан и отозван сертификат
```
➜  kubernetes-vault git:(kubernetes-vault) ✗ kubectl exec -it vault-0 -- vault write pki_int/issue/example-dot-ru common_name="gitlab.example.ru" ttl="24h"
Key                 Value
---                 -----
ca_chain            [-----BEGIN CERTIFICATE-----
MIIDnDCCAoSgAwIBAgIUeeKBPk43sRIjHI5qNK4Q9zHiTEcwDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhtYXBsZS5ydTAeFw0xOTExMTQxNjA4MTVaFw0yNDEx
MTIxNjA4NDVaMCwxKjAoBgNVBAMTIWV4YW1wbGUucnUgSW50ZXJtZWRpYXRlIEF1
dGhvcml0eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAK3SW8XEuPPO
kAZlLXvO7+PLisQqLtxXZ2Ccmjl+gE9RIEFdmTBtZrnAQIP+aRmb00deVeA+Pm/+
AQPgOWi6NAvQ5RXXowFhwGzbK6hfxxmtqCJNOB3+1lKu0hrVjoJHuWF5Nk+rhBeL
wXl3Xtz5lO/TrkKe+kIDrWyCiiFyOwc3vhHWZl8NvlqCuFIWdqqwB7XfDusg7epC
SPE25CjA4nzgELe7h8BgdUJL5NCVuw2XhM7SlhNkDTJLB6y+HqsvOl3NlilF/beN
ZcKpavRSbcVjOAwlnl8ZzMfuNXQ2hDsVp6JxPZolV+uUY6+F8fYZNq+0LSIwIcuB
/woI1HMHfcECAwEAAaOBzDCByTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUw
AwEB/zAdBgNVHQ4EFgQUk7CmIf04EfK1Z/9XpgruuI663egwHwYDVR0jBBgwFoAU
gNipALxUB0sfS6xh/MgeIHSOpDMwNwYIKwYBBQUHAQEEKzApMCcGCCsGAQUFBzAC
hhtodHRwOi8vdmF1bHQ6ODIwMC92MS9wa2kvY2EwLQYDVR0fBCYwJDAioCCgHoYc
aHR0cDovL3ZhdWx0OjgyMDAvdjEvcGtpL2NybDANBgkqhkiG9w0BAQsFAAOCAQEA
IL1xrhzO2r67cQhdaSbNvsYbu9c+3wX04IpbTaLBK70Tvy9DuyLar4ZFZLBxxk1u
uIQTAsLjFIvhV0LTH4Wluq8QwD0geCIJrYQXP6bsKzxpKUyiBpJyrZefp+BVsyeu
HkOjAkFb95QRRM6rGD3iaTQvBjEQFnE4S0w1831mpb1zmXt5cfObnOkGBko/GoP6
KVibxAUSMKE+rbO9MqESNM1lm+oJFEJb5lJN5gzRjfoIifPGKb/w3y10GwcbA5s4
U6Wdbl5Yl/bUgSr1YELCAtofn8c1oO/HWPo8brW0A6o+vsZZ5KfkjElfB3o6lpSt
E3Ir40vGKPMvJfhPX38h5w==
-----END CERTIFICATE-----]
certificate         -----BEGIN CERTIFICATE-----
MIIDZzCCAk+gAwIBAgIUYWf0ECJw1cRIOhgyFjm2ef3MDt4wDQYJKoZIhvcNAQEL
BQAwLDEqMCgGA1UEAxMhZXhhbXBsZS5ydSBJbnRlcm1lZGlhdGUgQXV0aG9yaXR5
MB4XDTE5MTExNDE2MTIwMVoXDTE5MTExNTE2MTIzMVowHDEaMBgGA1UEAxMRZ2l0
bGFiLmV4YW1wbGUucnUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDV
rqu6TeT+3w5kkr6hZsPD6YKCZ+atuKHdFkJnmPYnw8HDcRP2AKd5DLmMInPeJwZS
JNW/o+tTL7Jsx1OvoHAEXTvmOKH1qQCiEp62U0fP3M+xSc5DD6w0pF7z+Pi0kJCI
7X9sdrN7jZyzc/rIFgx+5sfuqbagkYPNwSw9E4ynIhgZJ2RNQez4iSWMqg5hK8BE
WpR4Mn5j4MOMEEipSYHW11hLaffFgbo4ffTAhl2bBbgoXf0J2R1NFVLLh8b+QPJt
ggJkCKWV2aenke7Be6ynCl6D9IYso3sqOcfRJ5p0Nqy85yGWXaVVTaUFySKGWWeZ
iKMo1mbqSRjWxQUfcQtfAgMBAAGjgZAwgY0wDgYDVR0PAQH/BAQDAgOoMB0GA1Ud
JQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjAdBgNVHQ4EFgQUdXdj58af4ZJkvXni
taWkcG5ODvkwHwYDVR0jBBgwFoAUk7CmIf04EfK1Z/9XpgruuI663egwHAYDVR0R
BBUwE4IRZ2l0bGFiLmV4YW1wbGUucnUwDQYJKoZIhvcNAQELBQADggEBAHDr65oE
2E8Fx2i5D9LRMiWT0v1RuCZkmYTg6WXmk/hzYzT+WATe/sxKgVEOzb9VbQn3lBd3
Wbbx//8Ib+0xqlWGxoPHz4y+boj3vz9uWTr/j1NmvhEd+77a+iAn3ppeh45N/Nx9
lsvSTC2RAeZqcXu23SgBWrVbsFhpNdqgl4LpjvqfVGdaw6ksYRrwVe1rKuzxCbvw
xdMJ+Yg2wk638yeU0e0Ny4ppnOUCXdmRUWzRkk05/w4RvXI+5MN1NdxBB9ecKHAB
4XYlQWxJ20EIpxZ9wndSTYObCO3VMI6itAqaFhoPLaBagBHaIu9pRYjYE9pZQRan
ZiubXf5yctojmBo=
-----END CERTIFICATE-----
expiration          1573834351
issuing_ca          -----BEGIN CERTIFICATE-----
MIIDnDCCAoSgAwIBAgIUeeKBPk43sRIjHI5qNK4Q9zHiTEcwDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhtYXBsZS5ydTAeFw0xOTExMTQxNjA4MTVaFw0yNDEx
MTIxNjA4NDVaMCwxKjAoBgNVBAMTIWV4YW1wbGUucnUgSW50ZXJtZWRpYXRlIEF1
dGhvcml0eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAK3SW8XEuPPO
kAZlLXvO7+PLisQqLtxXZ2Ccmjl+gE9RIEFdmTBtZrnAQIP+aRmb00deVeA+Pm/+
AQPgOWi6NAvQ5RXXowFhwGzbK6hfxxmtqCJNOB3+1lKu0hrVjoJHuWF5Nk+rhBeL
wXl3Xtz5lO/TrkKe+kIDrWyCiiFyOwc3vhHWZl8NvlqCuFIWdqqwB7XfDusg7epC
SPE25CjA4nzgELe7h8BgdUJL5NCVuw2XhM7SlhNkDTJLB6y+HqsvOl3NlilF/beN
ZcKpavRSbcVjOAwlnl8ZzMfuNXQ2hDsVp6JxPZolV+uUY6+F8fYZNq+0LSIwIcuB
/woI1HMHfcECAwEAAaOBzDCByTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUw
AwEB/zAdBgNVHQ4EFgQUk7CmIf04EfK1Z/9XpgruuI663egwHwYDVR0jBBgwFoAU
gNipALxUB0sfS6xh/MgeIHSOpDMwNwYIKwYBBQUHAQEEKzApMCcGCCsGAQUFBzAC
hhtodHRwOi8vdmF1bHQ6ODIwMC92MS9wa2kvY2EwLQYDVR0fBCYwJDAioCCgHoYc
aHR0cDovL3ZhdWx0OjgyMDAvdjEvcGtpL2NybDANBgkqhkiG9w0BAQsFAAOCAQEA
IL1xrhzO2r67cQhdaSbNvsYbu9c+3wX04IpbTaLBK70Tvy9DuyLar4ZFZLBxxk1u
uIQTAsLjFIvhV0LTH4Wluq8QwD0geCIJrYQXP6bsKzxpKUyiBpJyrZefp+BVsyeu
HkOjAkFb95QRRM6rGD3iaTQvBjEQFnE4S0w1831mpb1zmXt5cfObnOkGBko/GoP6
KVibxAUSMKE+rbO9MqESNM1lm+oJFEJb5lJN5gzRjfoIifPGKb/w3y10GwcbA5s4
U6Wdbl5Yl/bUgSr1YELCAtofn8c1oO/HWPo8brW0A6o+vsZZ5KfkjElfB3o6lpSt
E3Ir40vGKPMvJfhPX38h5w==
-----END CERTIFICATE-----
private_key         -----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA1a6ruk3k/t8OZJK+oWbDw+mCgmfmrbih3RZCZ5j2J8PBw3ET
9gCneQy5jCJz3icGUiTVv6PrUy+ybMdTr6BwBF075jih9akAohKetlNHz9zPsUnO
Qw+sNKRe8/j4tJCQiO1/bHaze42cs3P6yBYMfubH7qm2oJGDzcEsPROMpyIYGSdk
TUHs+IkljKoOYSvARFqUeDJ+Y+DDjBBIqUmB1tdYS2n3xYG6OH30wIZdmwW4KF39
CdkdTRVSy4fG/kDybYICZAilldmnp5HuwXuspwpeg/SGLKN7KjnH0SeadDasvOch
ll2lVU2lBckihllnmYijKNZm6kkY1sUFH3ELXwIDAQABAoIBAQC72XiiqgPchB9V
DySDI6KKQmg3WDwVELFLeVwbUv9jadaXiHsx0tVnt2YO6eLOs6P85uD6PpKMaOwE
cR8C0JppW8Vi2PqYymACGzhntML223nCs82eatLK3I2VEZUit8w4dAGHSrryrUXL
BPS8nZWSojO1foFMm2Axq9bGQr9t1RDnaX1zXqxvnAsinmxGo+YJwLLOgAC4dAgy
Wj/Tw9lAt1UesBKfrmDmHnTECisA2gFl8T/yhPfJ6gKxosRu2jPyENGO1SbSThP6
gcbROPVl2JhvvxmfqNkioq7QRSF+dOGr9uM4m3VIOXQkJsTLclxv0biQoCoXbtxO
NxJk00kBAoGBANmIh0sfQhW8diuyv7KsDxC95GelBT/XSHDmHGZyMJ/yVZ/cwyKc
Va+GHBCwKEO7feDEAI+hojb4sI6y76p5g16UX1w5YF9xIqhkoakauVtmKnO5CNMJ
ut9b37cNWkVf6zzwfSEEBIRQ0LxcQrPOtRh3JUv+eCS3QqlaZJXqwuufAoGBAPt3
z9fJjVhScJy03BmV4iDC8QFGTPt4W0kw6ZeOyLOpTPzA2UAIoh3/H0WjVQgvHZ4A
dRxqGm8lVJSf7r0qZS19WY2PkmV6/flifxW2Qi1JBhooS63hhJpMME8nguzAO8KM
RqwWeRhT5X7Afkd2tdNMBYxZ3VFe6Zcf8JDHwchBAoGAWVPXOuH7ITHi1M7yKUy+
YwGXaXg6T5z4AmR8BRWfIg9BWgQtnWjVRt6rZ67u2eGEL2hNUq3tDuXQmsif4kFD
0PLcteJZ0NeEg+HPAMIYm4+4nwy8suyr8Eyp8WFqUFKzJrMarxQXRr5o+PBp86xO
cV1701kLvQgEN8cGxwlAQcECgYAtRfHWgMQAzb7Wh71EofZ3PYGUYCrF73JH6BV2
Is/BgM6KhtHWNHezfNYNfI13jrv/UUfEWNnvfsIOjAi4Z+SVXwb7dIi/2nfVKUWG
DC035/jARtbxNDPib6sW5R8uLqHTsdubaeRdW+Vqf498oEO2Ce7JyPgOiU721VpD
RqN9wQKBgBFabVAj0k3bM2nQMXPyset/7vtjXsfEz3sWQH0PYce/Rb2yHI4AAm++
PtoAdTVqzkq+CnJt5v9UXvXbV3rBBcKgXncb5ogGH48hQi8RDWalObJnFRh/ekH6
kokUPlAnxdsr6e7KeCe7yDlcAN13LE0Ivu5bDzSMKBlhFmtY6Tn+
-----END RSA PRIVATE KEY-----
private_key_type    rsa
serial_number       61:67:f4:10:22:70:d5:c4:48:3a:18:32:16:39:b6:79:fd:cc:0e:de
```
```
➜  kubernetes-vault git:(kubernetes-vault) ✗ kubectl exec -it vault-0 -- vault write pki_int/revoke serial_number="61:67:f4:10:22:70:d5:c4:48:3a:18:32:16:39:b6:79:fd:cc:0e:de"
Key                        Value
---                        -----
revocation_time            1573748094
revocation_time_rfc3339    2019-11-14T16:14:54.558234667Z
```