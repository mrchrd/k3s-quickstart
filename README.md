# k3s-quickstart
Get started with k3s, istio and openebs in 10 minutes (guaranteed)

Ensure that you have following requirements installed on your system:
* curl
* docker
* docker-compose
* kubectl

Then run the script:
```
./run.sh
```

This will run k3s inside a single container and setup istio, openebs and metrics server. This will also install nginx as an example/test.

Test that kubernetes is working:
```
export KUBECONFIG="${PWD}/kubeconfig.yaml"
kubectl get all -A
```

Test that istio and openebs are working:
```
curl -H "Host: nginx.test" http://localhost:8080/
```

It should display a copy of the test/index.html page. The file is copied on an openebs volume, and nginx is exposed through istio-ingressgateway.
