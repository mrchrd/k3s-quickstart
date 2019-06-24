#!/bin/sh
set -e

export KUBECONFIG="${PWD}/kubeconfig.yaml"

echo "# Setup k3s"
docker-compose up -d
until kubectl get nodes; do sleep 1; done
until kubectl get deployment -n kube-system coredns -o json | jq -er 'select(.status.readyReplicas > 0) | .metadata.name'; do sleep 1; done
echo

echo "# Setup OpenEBS"
kubectl apply -f openebs-1.0.0/k8s/openebs-operator.yaml
until kubectl get deployment -n openebs openebs-provisioner -o json | jq -er 'select(.status.readyReplicas > 0) | .metadata.name'; do sleep 1; done
kubectl patch storageclass openebs-hostpath -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
echo

echo "# Setup Metrics Server"
for i in metrics-server-0.3.3/deploy/1.8+/*yaml; do
  kubectl apply -f $i
done
until kubectl get deployment -n kube-system metrics-server -o json | jq -er 'select(.status.readyReplicas > 0) | .metadata.name'; do sleep 1; done
echo

echo "# Setup Istio"
for i in istio-1.2.0/install/kubernetes/helm/istio-init/files/crd*yaml; do
  kubectl apply -f $i
done
kubectl apply -f istio-1.2.0/install/kubernetes/istio-demo-auth.yaml
until kubectl get deployment -n istio-system istio-sidecar-injector -o json | jq -er 'select(.status.readyReplicas > 0) | .metadata.name'; do sleep 1; done
echo

echo "# Test Nginx"
kubectl apply -f test/nginx.yaml
until kubectl get deployment -n test nginx -o json | jq -er 'select(.status.readyReplicas > 0) | .metadata.name'; do sleep 1; done
kubectl cp test/index.html `kubectl get pod -n test -l app=nginx -o name | sed 's/^pod/test/;'`:/usr/share/nginx/html/index.htm -c nginx
echo

curl -H "Host: nginx.test" http://localhost:8080/
