#!/bin/bash

kubectl label namespace boutique istio-injection=enabled --overwrite && \

kubectl -n boutique rollout restart deploy

kubectl apply -n boutique -f ./release/istio-manifests.yaml

kubectl scale deployment loadgenerator --replicas=0 -n boutique

echo "Press any key to continue..."
read -n 1 


istioctl proxy-status

echo "Press any key to open the browswer..."
read -n 1 


open "http://$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')"