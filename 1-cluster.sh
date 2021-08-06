#!/bin/bash

# Starts the minikube cluster
minikube start --memory=16384 --cpus=4 --kubernetes-version=v1.20.2

istioctl install --set profile=demo -y

kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.10/samples/addons/grafana.yaml \
&& kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.10/samples/addons/prometheus.yaml \
&& kubectl apply -f https://raw.githubusercontent.com/istio/istio/master/samples/addons/kiali.yaml \
&& kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.10/samples/addons/jaeger.yaml

kubectl create namespace boutique


kubectl apply -n boutique -f ./release/kubernetes-manifests.yaml
