#!/bin/bash
minikube start --memory=16384 --cpus=4 --kubernetes-version=v1.20.2

kubectl create namespace consul

helm repo add hashicorp https://helm.releases.hashicorp.com

helm install consul hashicorp/consul -n consul --set fullnameOverride=consul -f ./consul/02-consul-values.yaml

kubectl create namespace boutique

echo "Press any key to continue..."
read -n 1


kubectl apply -n boutique -f ./consul/kubernetes-manifests.yaml
# kubectl apply -n boutique -f ./consul/03-proxy-default.yaml