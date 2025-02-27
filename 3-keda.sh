#!/bin/bash

helm repo add kedacore https://kedacore.github.io/charts

helm repo update

kubectl create namespace keda
helm install keda kedacore/keda --namespace keda

kubectl apply -n boutique -f ./release/keda/scaler.yaml
