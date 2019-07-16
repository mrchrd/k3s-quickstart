# k3s-quickstart
Get started with Kubernetes, OpenEBS and Istio in 10 minutes (guaranteed)

Ensure that you have following requirements installed on your system:
* curl (optional)
* docker
* docker-compose

Then run the script:
```
./run.sh
```

This will run k3s inside a single container and setup Istio, OpenEBS and Metrics Server. This will also install NGINX as an example/test.

Test that Kubernetes is working:
```
docker exec -i k3squickstart_server_1 kubectl get all -A
```

Test that Istio and OpenEBS are working:
```
curl https://nginx.test --connect-to nginx.test:443:localhost:443 -k
```

It should display a copy of the assets/index.html page. The file is copied on an OpenEBS volume, and NGINX is exposed through Istio Ingress Gateway.
