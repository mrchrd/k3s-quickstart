#!/bin/sh
set -e

export KUBECONFIG="${PWD}/kubeconfig.yaml"
EXEC='docker exec -i k3squickstart_server_1 sh -c'

START_TIME=`date "+%s"`

echo '### Setup k3s'
docker-compose up -d
${EXEC} 'until kubectl get nodes; do sleep 1; done'
${EXEC} 'until [ `echo $(kubectl get deployment -n kube-system coredns -o jsonpath='{.status.readyReplicas}' --ignore-not-found) | sed 's/^$/0/'` -gt 0 ]; do sleep 1; done'
echo

echo "### Setup Helm"
${EXEC} 'kubectl apply -f-' < manifests/helm.yaml
${EXEC} 'until [ `echo $(kubectl get deployment -n kube-system tiller-deploy -o jsonpath='{.status.readyReplicas}' --ignore-not-found) | sed 's/^$/0/'` -gt 0 ]; do sleep 1; done'
helm repo update
echo

echo "### Setup Metrics Server"
helm upgrade --install --namespace=kube-system metrics-server stable/metrics-server --version=2.8.2 --values=helm/metrics-server-0.3.3.yaml --wait
echo

echo "### Setup OpenEBS"
helm upgrade --install --namespace=openebs openebs stable/openebs --version=1.0.0 --values=helm/openebs-1.0.0.yaml --wait
${EXEC} "kubectl patch storageclass openebs-hostpath -p '{\"metadata\": {\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"true\"}}}'"
echo

echo "### Setup Istio"
helm repo add istio.io https://storage.googleapis.com/istio-release/releases/1.2.1/charts/
helm upgrade --install --namespace=istio-system istio-init istio.io/istio-init --version=1.2.1 --values=helm/istio-init-1.2.1.yaml --wait
${EXEC} 'until kubectl get crd rbacconfigs.rbac.istio.io -o name; do sleep 1; done'
helm upgrade --install --namespace=istio-system istio istio.io/istio --version=1.2.1 --values=helm/istio-1.2.1.yaml --wait --timeout 600
${EXEC} 'kubectl apply -f-' < manifests/cert-manager-issuers.yaml
echo

echo "### Setup NGINX"
${EXEC} 'kubectl apply -f-' < manifests/nginx.yaml
${EXEC} 'until [ `echo $(kubectl get deployment -n test nginx -o jsonpath='{.status.readyReplicas}' --ignore-not-found) | sed 's/^$/0/'` -gt 0 ]; do sleep 1; done'
${EXEC} 'kubectl exec -i -n test $(kubectl get pod -n test -l app=nginx -o name | sed "s|pod/||") -c nginx -- sh -c "cat > /usr/share/nginx/html/index.htm"' < assets/index.html
echo

END_TIME=`date "+%s"`

if which curl; then
  echo "### Test http (expect 301)"
  curl http://nginx.test --connect-to nginx.test:80:localhost:80 -I
  echo

  echo "### Test https"
  curl https://nginx.test --connect-to nginx.test:443:localhost:443 -k
  echo
fi

echo "### Running time: $((${END_TIME} - ${START_TIME}))s"
