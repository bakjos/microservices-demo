# DEMO

Create the minikube cluster using

```bash
./1-cluster.sh
```

Check the istio pods are running

```bash
kubectl get pods -n istio-system
```

Test the frontend forwarding to port 3002

```bash
kubectl port-forward -n boutique svc/frontend 3002:80
open http://localhost:3002
```

Enable istio on the boutique namespace

```bash
./2-enable_istio.sh
```

Once the pods are restarted and the gateway created, enable the minikube tunnel to use an ip for the load balancer

```bash
minikube tunnel
```

Check the gateway is working

```bash
open "http://$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')"
```

## Traffic Management

This part will show some of the traffic management features of istio

### Blue/Green Deployment

Switch the frontend traffic to the new [version](./release/blue-green/frontv2-virtual-service.yaml)

```bash
kubectl apply -n boutique -f ./release/blue-green/frontv2-virtual-service.yaml
```

Switch the frontend traffic to the old [version](./release/blue-green/frontv1-virtual-service.yaml)

```bash
kubectl apply -n boutique -f ./release/blue-green/frontv1-virtual-service.yaml
```

### Canary Deployment

[Split the traffic](/release/canary/canary-virtual-service.yaml) between the frontend pods 20% of the traffic goes to the new version and the rest goes to the old version

```bash
 kubectl apply -n boutique -f ./release/canary/canary-virtual-service.yaml
 ```

### Header-based routing

[Split the traffic](./release/route-headers/firefox.yaml) depending on the header if its a firefox browser it will go to the new version and the rest goes to the old version

```bash
 kubectl apply -n boutique -f ./release/route-headers/firefox.yaml 
```

### Fault injection (delay)

[Adds a delay](/release/fault-injection/delay-fault-injection.yaml) of 5 seconds to the productcatalogservice

```bash
kubectl apply -n boutique -f ./release/fault-injection/delay-fault-injection.yaml
```

Reset the services to the original state

```bash
kubectl apply -n boutique -f ./release/istio-manifests.yaml
```

### Fault Injecttion (abort)

[Adds a failure](./release/fault-injection/abort-fault-injection.yaml) to 50% of the requests to the paymentservice

```bash
kubectl apply -n boutique -f ./release/fault-injection/abort-fault-injection.yaml
```

### Retries

[Add a 10 retries](./release/retries/retry.yaml) to the frontend service, to succed even when the paymentservice is interminely down

```bash
kubectl -n boutique apply -f ./release/retries/retry.yaml
```

### Circuit breaking

Add a new version ([v2](./release/circuit-breaking/paymentservice-v2.yaml)) of the paymentservice and send the traffic to [both versions](./release/circuit-breaking/paymentservice-splitting.yaml)

```bash

kubectl create cm demo-pb -n boutique --from-file=./pb && \
kubectl apply -n boutique -f ./release/istio-manifests.yaml && \
kubectl apply -n boutique -f ./release/ghz.yaml && \
kubectl apply -n boutique -f ./release/circuit-breaking/paymentservice-v2.yaml && \
kubectl apply -n boutique -f ./release/circuit-breaking/paymentservice-splitting.yaml

GHZ_POD=$(kubectl get pod -n boutique| grep ghz | awk '{ print $1 }')

kubectl exec -n boutique -it $GHZ_POD -c ghz --  /app/ghz --insecure --async --proto /app/pb/demo.proto --call hipstershop.PaymentService.Charge -c 4 -n 40 --rps 400 -d '{"amount": { "currency_code": "USD", "units": 10, "nanos": 0  }, "credit_card": { "credit_card_number": "4432-8015-6152-0454", "credit_card_expiration_year": 2022, "credit_card_expiration_month": 1, "credit_card_cvv": 123 }}' paymentservice:50051
```

Creates a [circuit breaker](./release/circuit-breaking/paymentservice-splitting-cb.yaml) to put the failed pod out of commision after 2 consecutive failures

```bash
kubectl apply -n boutique -f ./release/circuit-breaking/paymentservice-splitting-cb.yaml
```

Demostrate the [circuit breaker](./release/circuit-breaking/circuit-breaking.yaml) when queuing and limiting the number of concurrent requests

```bash
kubectl apply -n boutique -f ./release/circuit-breaking/circuit-breaking.yaml
```

### Rate limiting, timeouts, cors and mirroring

It was left out on this demo

## Observability

Starts a locust load balancer test to simulate more traffic to the mesh

```bash
kubectl scale deployment loadgenerator --replicas=2 -n boutique
```

This allow us to open the different applications

```bash
istioctl dashboard kiali

istioctl dashboard grafana

istioctl dashboard jaeger
```

[KEDA](https://keda.sh/docs/2.3/scalers/)

Use keda to automatically scale the frontend pod depending on the number of requests

```bash
./3-keda.sh

kubectl get hpa -n boutique -o yaml

kubectl describe hpa -n boutique
```

Query prometheus with the scaler [configuration](./release/keda/scaler.yaml)

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

kubectl apply -n boutique -f ./release/security/destination-rule.yaml

kubectl apply -n boutique -f ./release/security/ghz.yaml
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

[Deny all(./release/security/deny-policy.yaml)] the requests to '/cart'

```bash
kubectl apply -n boutique -f ./release/security/deny-policy.yaml
```

Enable all the requests to '/cart'

```bash
kubectl delete -n boutique -f ./release/security/deny-policy.yaml
```

### JWT Authentication

Enable [JWT authentication](./release/security/auth-jwt.yaml) for the frontend service

```bash
kubectl apply -n boutique -f ./release/security/auth-jwt.yaml

TOKEN=$(curl https://raw.githubusercontent.com/istio/istio/release-1.10/security/tools/jwt/samples/demo.jwt -s) && echo "$TOKEN" | cut -d '.' -f2 - | base64 --decode -

kubectl apply -n boutique -f ./release/fortio.yaml 

FORTIO_POD=$(kubectl get pod -n boutique| grep fortio | awk '{ print $1 }')


kubectl exec -n boutique -it $FORTIO_POD -- fortio load -curl http://frontend/cart

kubectl exec -n boutique -it $FORTIO_POD -- fortio load -curl -H "Authorization: Bearer $TOKEN" http://frontend/cart
```

Removes the authentication

```bash
kubectl delete -n boutique -f ./release/security/auth-jwt.yaml
```

### Acess logs

Show the access logs of any pod

```bash
kubectl logs -l app=frontend -c istio-proxy -n boutique

kubectl logs -l app=paymentservice -c istio-proxy -n boutique
```

## KONG

Use kong as [API gateway](./release/kong/kong.yaml) instead of the one provided by Istio

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
