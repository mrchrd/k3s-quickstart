#!/bin/sh
set -e

EXEC='docker exec -i k3squickstart_server_1 sh -c'

START_TIME=`date "+%s"`

echo '### Setup k3s'
docker-compose up -d
${EXEC} 'until kubectl wait --for=condition=ready node/$(hostname); do sleep 1; done' 2>/dev/null
${EXEC} 'until kubectl wait --for=condition=available deployment/coredns -n kube-system; do sleep 1; done' 2>/dev/null
echo

echo "### Setup Metrics Server"
${EXEC} 'kubectl apply -f-' < manifests/metrics-server.yaml
echo

echo "### Setup OpenEBS"
${EXEC} 'kubectl apply -f-' < manifests/openebs.yaml
${EXEC} 'until kubectl wait --for=condition=available deployment/openebs-admission-server -n openebs; do sleep 1; done' 2>/dev/null
${EXEC} 'until kubectl wait --for=condition=available deployment/openebs-apiserver -n openebs; do sleep 1; done' 2>/dev/null
${EXEC} 'until kubectl wait --for=condition=available deployment/openebs-localpv-provisioner -n openebs; do sleep 1; done' 2>/dev/null
${EXEC} 'until kubectl wait --for=condition=available deployment/openebs-ndm-operator -n openebs; do sleep 1; done' 2>/dev/null
${EXEC} 'until kubectl wait --for=condition=available deployment/openebs-provisioner -n openebs; do sleep 1; done' 2>/dev/null
${EXEC} "kubectl patch storageclass openebs-hostpath -p '{\"metadata\": {\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"true\"}}}'"
echo

echo "### Setup Istio"
${EXEC} 'kubectl apply -f-' < manifests/istio-init.yaml
${EXEC} 'until kubectl wait --for=condition=complete job/istio-init-crd-10 -n istio-system; do sleep 1; done' 2>/dev/null
${EXEC} 'until kubectl wait --for=condition=complete job/istio-init-crd-11 -n istio-system; do sleep 1; done' 2>/dev/null
${EXEC} 'until kubectl wait --for=condition=complete job/istio-init-crd-12 -n istio-system; do sleep 1; done' 2>/dev/null
${EXEC} 'until kubectl wait --for=condition=complete job/istio-init-crd-certmanager-10 -n istio-system; do sleep 1; done' 2>/dev/null
${EXEC} 'until kubectl wait --for=condition=complete job/istio-init-crd-certmanager-11 -n istio-system; do sleep 1; done' 2>/dev/null
${EXEC} 'kubectl apply -f-' < manifests/istio.yaml
${EXEC} 'kubectl apply -f-' < manifests/cert-manager-issuers.yaml
${EXEC} 'until kubectl wait --for=condition=available deployment/istio-pilot -n istio-system; do sleep 1; done' 2>/dev/null
${EXEC} 'until kubectl wait --for=condition=available deployment/istio-policy -n istio-system; do sleep 1; done' 2>/dev/null
${EXEC} 'until kubectl wait --for=condition=available deployment/istio-sidecar-injector -n istio-system; do sleep 1; done' 2>/dev/null
echo

echo "### Setup NGINX"
${EXEC} 'kubectl apply -f-' < manifests/nginx.yaml
${EXEC} 'until kubectl wait --for=condition=available deployment/nginx -n test; do sleep 1; done' 2>/dev/null
${EXEC} 'kubectl exec -i -n test $(kubectl get pod -n test -l app=nginx -o name | sed "s|pod/||") -c nginx -- sh -c "cat > /usr/share/nginx/html/index.htm"' < assets/index.html
echo

END_TIME=`date "+%s"`

if which curl >/dev/null; then
  echo "### Test http (expect 301)"
  curl http://nginx.test --connect-to nginx.test:80:localhost:80 -I
  echo

  echo "### Test https"
  curl https://nginx.test --connect-to nginx.test:443:localhost:443 -k
  echo
fi

echo "### Running time: $((${END_TIME} - ${START_TIME}))s"
