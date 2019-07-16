#!/bin/sh
set -e

EXEC='docker exec -i k3squickstart_server_1 sh -c'

START_TIME=`date "+%s"`

echo '### Setup k3s'
docker-compose up -d
${EXEC} 'until kubectl get nodes; do sleep 1; done'
${EXEC} 'until [ `echo $(kubectl get deployment -n kube-system coredns -o jsonpath='{.status.readyReplicas}' --ignore-not-found) | sed 's/^$/0/'` -gt 0 ]; do sleep 1; done'
echo

echo "### Setup Metrics Server"
${EXEC} 'kubectl apply -f-' < manifests/metrics-server.yaml
echo

echo "### Setup OpenEBS"
${EXEC} 'kubectl apply -f-' < manifests/openebs.yaml
${EXEC} 'until kubectl get crd storagepools.openebs.io -o name; do sleep 1; done'
${EXEC} "kubectl patch storageclass openebs-hostpath -p '{\"metadata\": {\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"true\"}}}'"
echo

echo "### Setup Istio"
${EXEC} 'kubectl apply -f-' < manifests/istio-init.yaml
${EXEC} 'until kubectl get crd rbacconfigs.rbac.istio.io -o name; do sleep 1; done'
${EXEC} 'kubectl apply -f-' < manifests/istio.yaml
${EXEC} 'until kubectl get crd rbacconfigs.rbac.istio.io -o name; do sleep 1; done'
${EXEC} 'kubectl apply -f-' < manifests/cert-manager-issuers.yaml
${EXEC} 'until [ `echo $(kubectl get deployment -n istio-system istio-pilot -o jsonpath='{.status.readyReplicas}' --ignore-not-found) | sed 's/^$/0/'` -gt 0 ]; do sleep 1; done'
${EXEC} 'until [ `echo $(kubectl get deployment -n istio-system istio-policy -o jsonpath='{.status.readyReplicas}' --ignore-not-found) | sed 's/^$/0/'` -gt 0 ]; do sleep 1; done'
${EXEC} 'until [ `echo $(kubectl get deployment -n istio-system istio-sidecar-injector -o jsonpath='{.status.readyReplicas}' --ignore-not-found) | sed 's/^$/0/'` -gt 0 ]; do sleep 1; done'
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
