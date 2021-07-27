# DEMO

kubectl get pods -n istio-system

```bash
kubectl port-forward -n boutique svc/frontend 3002:80

./2-enable_istio.sh

open "http://$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')"
```

## Traffic Management

### Blue/Green Deployment

```bash
kubectl apply -n boutique -f ./release/blue-green/frontv2-virtual-service.yaml
```

```bash
kubectl apply -n boutique -f ./release/blue-green/frontv1-virtual-service.yaml
```

### Canary Deployment

```bash
 kubectl apply -n boutique -f ./release/canary/canary-virtual-service.yaml
 ```

### Header-based routing

```bash
 kubectl apply -n boutique -f ./release/route-headers/firefox.yaml 
```

### Fault injection (delay)

```bash
kubectl apply -n boutique -f ./release/fault-injection/delay-fault-injection.yaml
```

```bash
kubectl apply -n boutique -f ./release/istio-manifests.yaml
```

### Fault Injecttion (abort)

```bash
kubectl apply -n boutique -f ./release/fault-injection/abort-fault-injection.yaml
```

### Retries

```bash
kubectl -n boutique apply -f ./release/retries/retry.yaml
```

### Circuit breaking

```bash

kubectl create cm demo-pb -n boutique --from-file=./pb && \
kubectl apply -n boutique -f ./release/istio-manifests.yaml && \
kubectl apply -n boutique -f ./release/ghz.yaml && \
kubectl apply -n boutique -f ./release/circuit-breaking/circuit-breaking.yaml

GHZ_POD=$(kubectl get pod -n boutique| grep ghz | awk '{ print $1 }')

kubectl exec -n boutique -it $GHZ_POD -c ghz --  /app/ghz --insecure --async --proto /app/pb/demo.proto --call hipstershop.PaymentService.Charge -c 4 -n 40 --rps 400 -d '{"amount": { "currency_code": "USD", "units": 10, "nanos": 0  }, "credit_card": { "credit_card_number": "4432-8015-6152-0454", "credit_card_expiration_year": 2022, "credit_card_expiration_month": 1, "credit_card_cvv": 123 }}' paymentservice:50051
```

### Rate limiting, timeouts, cors and mirroring

It was left out on this demo

## Observability

```bash
kubectl scale deployment loadgenerator --replicas=2 -n boutique
```

```bash
istioctl dashboard kiali

istioctl dashboard grafana

istioctl dashboard jaeger
```

[KEDA](https://keda.sh/docs/2.3/scalers/)

```bash
./3-keda.sh

kubectl get hpa -n boutique -o yaml

kubectl describe hpa -n boutique
```

```bash
istioctl dashboard prometheus
```

## Security

ENABLE MTS

```bash
kubectl apply -n boutique -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: "default"
spec:
  mtls:
    mode: STRICT
EOF

kubectl apply -n boutique -f ./release/security/ghz.yaml

kubectl apply -n boutique -f ./release/security/destination-rule.yaml

```

Show certificate

```bash
kubectl exec "$(kubectl get pod -l app=frontend,version=v2 -n boutique -o jsonpath={.items..metadata.name})" -c istio-proxy -n boutique -- openssl s_client -showcerts -connect paymentservice:50051
```

```bash
GHZ_POD=$(kubectl get pod -n boutique| grep ghz | awk '{ print $1 }')


kubectl exec -n boutique -it $GHZ_POD -c ghz --  /app/ghz --insecure --async --proto /app/pb/demo.proto --call hipstershop.PaymentService.Charge -c 4 -n 40 --rps 400 -d '{"amount": { "currency_code": "USD", "units": 10, "nanos": 0  }, "credit_card": { "credit_card_number": "4432-8015-6152-0454", "credit_card_expiration_year": 2022, "credit_card_expiration_month": 1, "credit_card_cvv": 123 }}' paymentservice:50051
```

### Deny Policy

```bash
kubectl apply -n boutique -f ./release/security/deny-policy.yaml
```

Delete

```bash
kubectl delete -n boutique -f ./release/security/deny-policy.yaml
```

### JWT Authentication

```bash


kubectl apply -n boutique -f ./release/security/auth-jwt.yaml

TOKEN=$(curl https://raw.githubusercontent.com/istio/istio/release-1.10/security/tools/jwt/samples/demo.jwt -s) && echo "$TOKEN" | cut -d '.' -f2 - | base64 --decode -

kubectl apply -n boutique -f ./release/fortio.yaml 

FORTIO_POD=$(kubectl get pod -n boutique| grep fortio | awk '{ print $1 }')


kubectl exec -n boutique -it $FORTIO_POD -- fortio load -curl http://frontend/cart

kubectl exec -n boutique -it $FORTIO_POD -- fortio load -curl -H "Authorization: Bearer $TOKEN" http://frontend/cart
```

### Acess logs

```bash

kubectl delete -n boutique -f ./release/security/auth-jwt.yaml

kubectl logs -l app=frontend -c istio-proxy -n boutique

kubectl logs -l app=paymentservice -c istio-proxy -n boutique
```

## KONG

```bash

kubectl apply -n boutique -f ./release/kong 

open "http://$(kubectl -n boutique get service kong -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):$(kubectl -n boutique get service kong -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')"

curl "http://$(kubectl -n boutique get service kong -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):$(kubectl -n boutique get service kong -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')/api" 

curl -u kevin:abc123 "http://$(kubectl -n boutique get service kong -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):$(kubectl -n boutique get service kong -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')/api"

```

<!-- ```bash
curl -I "http://$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')"

curl -I -H "Authentication: Bearer asdf" "http://$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')"

``` -->
