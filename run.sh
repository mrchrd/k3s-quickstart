#!/bin/sh
set -e

export KUBECONFIG="${PWD}/kubeconfig.yaml"

echo "# Setup k3s"
docker-compose up -d
until kubectl get nodes; do sleep 1; done
until kubectl get deployment -n kube-system coredns -o json | jq -er 'select(.status.readyReplicas > 0) | .metadata.name'; do sleep 1; done
echo

echo "# Setup Helm"
kubectl apply -f manifests/helm.yaml
until kubectl get deployment -n kube-system tiller-deploy -o json | jq -er 'select(.status.readyReplicas > 0) | .metadata.name'; do sleep 1; done
helm repo update
echo

echo "# Setup Metrics Server"
helm upgrade --install --namespace=kube-system metrics-server stable/metrics-server --version=2.8.2 --values=helm/metrics-server-0.3.3.yaml --wait
echo

echo "# Setup OpenEBS"
helm upgrade --install --namespace=openebs openebs stable/openebs --version=1.0.0 --values=helm/openebs-1.0.0.yaml --wait
kubectl patch storageclass openebs-hostpath -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
echo

echo "# Setup Istio"
helm repo add istio.io https://storage.googleapis.com/istio-release/releases/1.2.0/charts/
helm upgrade --install --namespace=istio-system istio-init istio.io/istio-init --version=1.2.0 --values=helm/istio-init-1.2.0.yaml --wait
until kubectl get crd -o name | grep -q istio.io; do sleep 2; done
helm upgrade --install --namespace=istio-system istio istio.io/istio --version=1.2.0 --values=helm/istio-1.2.0.yaml --wait --timeout 600
echo

echo "# Setup NGINX"
kubectl apply -f manifests/nginx.yaml
until kubectl get deployment -n test nginx -o json | jq -er 'select(.status.readyReplicas > 0) | .metadata.name'; do sleep 1; done
kubectl cp assets/index.html `kubectl get pod -n test -l app=nginx -o name | sed 's/^pod/test/;'`:/usr/share/nginx/html/index.htm -c nginx
echo

curl -H "Host: nginx.test" http://localhost:8080/
