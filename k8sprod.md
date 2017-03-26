# Kubernetes Production Patterns

... and anti-patterns.

We are going to explore helpful techniques to improve resiliency and high availability
of Kubernetes deployments and will take a look at some common mistakes to avoid when
working with Docker and Kubernetes.

## Installation

First, follow [installation instructions](README.md#installation)

### Anti-Pattern: Mixing build environment and runtime environment

Let's take a look at this dockerfile

```Dockerfile
FROM ubuntu:14.04

RUN apt-get update
RUN apt-get install gcc
RUN gcc hello.c -o /hello
```

It compiles and runs simple helloworld program:

```bash
$ cd prod/build
$ docker build -t prod .
$ docker run prod
Hello World
```

There is a couple of problems with the resulting Dockerfile:

**Size**

```bash
$ docker images | grep prod
prod                                          latest              b2c197180350        14 minutes ago      293.7 MB
```

That's almost 300 megabytes to host several kilobytes of the c program! We are bringing in package manager,
C compiler and lots of other unnecessary tools that are not required to run this program.


Which leads us to the second problem:

**Security**

We distribute the whole build toolchain in addition to that we ship the source code of the image:

```bash
$ docker run --entrypoint=cat prod /build/hello.c
#include<stdio.h>

int main()
{
    printf("Hello World\n");
    return 0;
}
```

**Splitting build envrionment and run environment**

We are going to use "buildbox" pattern to build an image with build environment,
and we will use much smaller runtime environment to run our program


```bash
$ cd prod/build-fix
$ docker build -f build.dockerfile -t buildbox .
```

**NOTE:** We have used new `-f` flag to specify dockerfile we are going to use.

Now we have a `buildbox` image that contains our build environment. We can use it to compile the C program now:

```bash
$ docker run -v $(pwd):/build  buildbox gcc /build/hello.c -o /build/hello
```

We have not used `docker build` this time, but mounted the source code and run the compiler directly.

**NOTE:** Docker will soon support this pattern natively by introducing [build stages](https://github.com/docker/docker/pull/32063) into the build process.


We can now use much simpler (and smaller) dockerfile to run our image:

```Dockerfile
FROM quay.io/gravitational/debian-tall:0.0.1

ADD hello /hello
ENTRYPOINT ["/hello"]
```

```bash
$ docker build -f run.dockerfile -t prod:v2 .
$ docker run prod:v2
Hello World
$ docker images | grep prod
prod                                          v2                  ef93cea87a7c        17 seconds ago       11.05 MB
prod                                          latest              b2c197180350        45 minutes ago       293.7 MB
```

### Anti Pattern: Zombies and orphans

**NOTICE:** this example demonstration will only work on Linux

**Orphans**

It is quite easy to leave orphaned processes running in backround. Let's take an image we have build in the previous example:

```bash
docker run busybox sleep 10000
```

Let us open a separate terminal and locate the process

```bash
ps uax | grep sleep
sasha    14171  0.0  0.0 139736 17744 pts/18   Sl+  13:25   0:00 docker run busybox sleep 10000
root     14221  0.1  0.0   1188     4 ?        Ss   13:25   0:00 sleep 10000
```

As you see there are in fact two processes: `docker run` and `sleep 1000` running in a container.

Let's send kill signal to the `docker run` (just as CI/CD job would do for long running processes):

```bash
kill -9 14171
```

`docker run` process exited, but `sleep` process is running!

```bash
ps uax | grep sleep
root     14221  0.0  0.0   1188     4 ?        Ss   13:25   0:00 sleep 10000
```


Yelp engineers have a good answer for why this happens [here](https://github.com/Yelp/dumb-init):

> The Linux kernel applies special signal handling to processes which run as PID 1.
> When processes are sent a signal on a normal Linux system, the kernel will first check for any custom handlers the process has registered for that signal, and otherwise fall back to default behavior (for example, killing the process on SIGTERM).

> However, if the process receiving the signal is PID 1, it gets special treatment by the kernel; if it hasn't registered a handler for the signal, the kernel won't fall back to default behavior, and nothing happens. In other words, if your process doesn't explicitly handle these signals, sending it SIGTERM will have no effect at all.

To solve this (and other) issues, you need a simple init system that has proper signal handlers specified, luckily `Yelp` engineers
helped us again, and built the simple and lightweight init system, `dumb-init`

```bash
docker run quay.io/gravitational/debian-tall /usr/bin/dumb-init /bin/sh -c "sleep 10000"
```

Now you can simply stop `docker run` process and still use it as is.

### Anti-Pattern: Direct Use Of Pods

[Kubernetes Pod](https://kubernetes.io/docs/user-guide/pods/#what-is-a-pod) is a building block that itself is not durable.

Do not use Pods directly in production. They won't get rescheduled, retain their data or guarantee any durability.

Instead, you can use `Deployment` with replication factor 1, which will guarantee that pods will get rescheduled
and will survive eviction or node loss.


### Anti-Pattern: Using background processes

```bash
$ cd prod/background
$ docker build -t $(minikube ip):5000/background:0.0.1 .
$ docker push $(minikube ip):5000/background:0.0.1
$ kubectl create -f crash.yaml
$ kubectl get pods
NAME      READY     STATUS    RESTARTS   AGE
crash     1/1       Running   0          5s
```

The container appears to be running, but let's check if our server is running there:

```bash
$ kubectl exec -ti crash /bin/bash
root@crash:/# 
root@crash:/# 
root@crash:/# ps uax
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  0.0  0.0  21748  1596 ?        Ss   00:17   0:00 /bin/bash /start.sh
root         6  0.0  0.0   5916   612 ?        S    00:17   0:00 sleep 100000
root         7  0.0  0.0  21924  2044 ?        Ss   00:18   0:00 /bin/bash
root        11  0.0  0.0  19180  1296 ?        R+   00:18   0:00 ps uax
root@crash:/# 
```

**Using Probes**

We made a mistake, and no HTTP server is running there, but there is no indication of this as the parent
process is still running.

The first obvious fix is to use proper init system and monitor the status of the web service,
however let's use this as an opportunity to use liveness probes:


```yaml
apiVersion: v1
kind: Pod
metadata:
  name: fix
  namespace: default
spec:
  containers:
  - command: ['/start.sh']
    image: localhost:5000/background:0.0.1
    name: server
    imagePullPolicy: Always
    livenessProbe:
      httpGet:
        path: /
        port: 5000
      timeoutSeconds: 1
```

```bash
$ kubectl create -f fix.yaml
```

The liveness probe will fail, and container will get restarted.

```bash
$ kubectl get pods
NAME      READY     STATUS    RESTARTS   AGE
crash     1/1       Running   0          11m
fix       1/1       Running   1          1m
```

### Production Pattern: Logging

Set up your logs to go to stdout:

```bash
$ kubectl create -f logs/logs.yaml
$ kubectl logs logs
hello, world!
```

Kubernetes and docker have a system of plugins to make sure logs sent to stdout and stderr will get
collected, forwarded and rotated.

**NOTE:** This is one of the patterns of [12 factor app](https://12factor.net/logs) and Kubernetes supports it out of the box!

### Production Pattern: Immutable containers

Every time you write something to container's filesystem, it activates [copy on write strategy](https://docs.docker.com/engine/userguide/storagedriver/imagesandcontainers/#container-and-layers).

New storage layer is created using storage driver (devicemapper, overlayfs or others). In case of active usage,
it can put a lot of load on storage drivers, especially in case of Devicemapper or BTRFS.

Make sure your containers write data only to volumes, you can use `tmpfs` for small (as tmpfs stores everything in memory) temporary files:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pd
spec:
  containers:
  - image: busybox
    name: test-container
    volumeMounts:
    - mountPath: /tmp
      name: tempdir
  volumes:
  - name: tempdri
    emptyDir: {}
```

### Anti-Pattern: Using `latest` tag

Do not use `latest` tag in production. It creates ambiguity, as it's not clear what real version of the app is this.

It is ok to use `latest` for development purposes, although make sure you set `imagePullPolicy` to `Always`, to make sure
Kubernetes allways pulls the latest version when creating a pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: always
  namespace: default
spec:
  containers:
  - command: ['/bin/sh', '-c', "echo hello, world!"]
    image: busybox:latest
    name: server
    imagePullPolicy: Always
```

### Production Pattern: Pod Readiness

Imagine a situation when your container takes time to start. To simulate this, we are going to write a simple script:

```bash
#!/bin/bash

echo "Starting up"
sleep 30
echo "Started up successfully"
python -m http.serve 5000
```

Push the image and start service and deployment:

```yaml
$ cd prod/delay
$ docker build -t $(minikube ip):5000/delay:0.0.1 .
$ docker push $(minikube ip):5000/delay:0.0.1
$ kubectl create -f service.yaml
$ kubectl create -f deployment.yaml
```

Enter curl container inside the cluster and make sure it all works:

```
kubectl run -i -t --rm cli --image=tutum/curl --restart=Never
curl http://delay:5000
<!DOCTYPE html>
...
```

You will notice that there's a `connection refused error`, when you try to access it
for the first 30 seconds.

Update deployment to simulate deploy:

```bash
$ docker build -t $(minikube ip):5000/delay:0.0.2 .
$ docker push $(minikube ip):5000/delay:0.0.2
$ kubectl replace -f deployment-update.yaml
```

In the next window, let's try to to see if we got any service downtime:

```bash
curl http://delay:5000
curl: (7) Failed to connect to delay port 5000: Connection refused
```

We've got a production outage despite setting `maxUnavailable: 0` in our rolling update strategy!
This happened because Kubernetes did not know about startup delay and readiness of the service.

Let's fix that by using readiness probe:

```yaml
readinessProbe:
  httpGet:
    path: /
    port: 5000
  timeoutSeconds: 1
  periodSeconds: 5
```

Readiness probe indicates the readiness of the pod containers, and Kubernetes will take this into account when
doing a deployment:

```bash
$ kubectl replace -f deployment-fix.yaml
```

This time we will get no downtime.



