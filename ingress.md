### Ingress

*Preparation: ingress can be enabled on already running minikube using command:*

```
minikube addons enable ingress
```

An Ingress is a collection of rules that allow inbound connections to reach the cluster services.
It can be configured to give services externally-reachable urls, load balance traffic, terminate SSL, offer name based virtual hosting etc.
The difference between service and ingress (in K8S terminology) is that service allows you to provide access on OSI L3, and ingress
works on L7. E.g. while accessing HTTP server service can provide only load-balancing and HA, unlike ingres which could be used to split
traffic on HTTP location basis, etc.

First, we need to create to 2 different nginx deployments, configmaps and services for them:

```
kubectl create configmap cola-nginx --from-file=ingress/conf-cola
kubectl create configmap pepsi-nginx --from-file=ingress/conf-pepsi
kubectl apply -f ingress/cola-nginx-configmap.yaml -f ingress/pepsi-nginx-configmap.yaml
kubectl apply -f ingress/cola-nginx-service.yaml -f ingress/pepsi-nginx-service.yaml
```

Check if both deployments and services works:

```
$ curl $(minikube service cola-nginx --url)
Taste The Feeling. Coca-Cola.
$ curl $(minikube service pepsi-nginx --url)
Every Pepsi Refreshes The World.
```

Example ingress usage pattern is to route HTTP traffic according to location.
Now we have two different deployments and services, assume we need to route user
requests from `/cola` to `cola-nginx` service (backed by `cola-nginx` deployment)
and `/pepsi` to `pepsi-nginx` service.

This can be acheived using following ingress resource:

```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: drinks-ingress
  annotations:
    ingress.kubernetes.io/rewrite-target: /
    ingress.kubernetes.io/ssl-redirect: "false"
spec:
  rules:
  - http:
      paths:
      - path: /cola
        backend:
          serviceName: cola-nginx
          servicePort: 80
      - path: /pepsi
        backend:
          serviceName: pepsi-nginx
          servicePort: 80
```

Create ingress:

```
kubectl apply -f ingress/drinks-ingress.yaml
```

Notice annotations:

* `ingress.kubernetes.io/rewrite-target: /` -- sets request's location to `/` instead of specified in `path`.
* `ingress.kubernetes.io/ssl-redirect: "false"` -- disables HTTP to HTTPS redirect, enabled by default.

Ingress is implemented inside `kube-system` namespace using any kind of configurable proxy. E.g. in minikube
ingress uses nginx. Simply speaking there's special server which reacts to ingress resource creation/deletion/alteration
and updates configuration of neighboured nginx. This *ingress controller* application started using
ReplicationController resource inside minikube, but could be run as usual K8S application (DS, Deployment, etc),
on special set of "edge router" nodes for improved security.

```
$ kubectl --namespace=kube-system get pods -l app=nginx-ingress-lb
NAME                             READY     STATUS    RESTARTS   AGE
nginx-ingress-controller-1nzsp   1/1       Running   0          1h
```

Now we can make ingress reachable to outer world (e.g. our local host). It's not required, you're free of choice
to make it reachable only internally or via some cloud-provider using LoadBalancer.

```
kubectl --namespace=kube-system expose rc nginx-ingress-controller --port=80 --type=LoadBalancer
```

Finally we can check location splitting via hitting ingress-controller service with
proper location.

```
$ curl $(minikube service --namespace=kube-system nginx-ingress-controller --url)/cola
Taste The Feeling. Coca-Cola.
$ curl $(minikube service --namespace=kube-system nginx-ingress-controller --url)/pepsi
Every Pepsi Refreshes The World.
```

As you see, we're hitting one service with different locations and have different responses due
to ingress location routing.

More details on ingress features and use cases [here](https://kubernetes.io/docs/user-guide/ingress/).
