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

It compiles and runs a simple helloworld program:

```bash
$ cd prod/build
$ docker build -t prod .
$ docker run prod
Hello World
```

There are a couple of problems with the resulting Dockerfile:

**Size**

```bash
$ docker images | grep prod
prod                                          latest              b2c197180350        14 minutes ago      293.7 MB
```

That's almost 300 megabytes to host several kilobytes of the c program! We are bringing in package manager,
C compiler and lots of other unnecessary tools that are not required to run this program.


Which leads us to the second problem:

**Security**

We distribute the whole build toolchain. In addition to that, we ship the source code of the image:

```bash
$ docker run --entrypoint=cat prod /build/hello.c
#include<stdio.h>

int main()
{
    printf("Hello World\n");
    return 0;
}
```

**Splitting build environment and run environment**

We are going to use "buildbox" pattern to build an image with build environment,
and we will use a much smaller runtime environment to run our program


```bash
$ cd prod/build-fix
$ docker build -f build.dockerfile -t buildbox .
```

**NOTE:** We have used new `-f` flag to specify the dockerfile we are going to use.

Now we have a `buildbox` image that contains our build environment. We can use it to compile the C program now:

```bash
$ docker run -v $(pwd):/build  buildbox gcc /build/hello.c -o /build/hello
```

We have not used `docker build` this time, but mounted the source code and run the compiler directly.

**NOTE:** Docker will soon support this pattern natively by introducing [build stages](https://github.com/docker/docker/pull/32063) into the build process.

**UPDATE:** [Multi-stage builds is now available in CE](https://docs.docker.com/engine/userguide/eng-image/multistage-build/).

We can now use a much simpler (and smaller) dockerfile to run our image:

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

**NOTE:** Please be aware that you should either plan on providing the needed "shared libraries" in the runtime image or "statically build" you binaries to have them include all needed libraries.

### Anti Pattern: Zombies and orphans

**NOTICE:** this example demonstration will only work on Linux

**Orphans**

It is quite easy to leave orphaned processes running in the background. Let's take an image we have built in the previous example:

```bash
docker run busybox sleep 10000
```

Now, let's open a separate terminal and locate the process

```bash
ps uax | grep sleep
sasha    14171  0.0  0.0 139736 17744 pts/18   Sl+  13:25   0:00 docker run busybox sleep 10000
root     14221  0.1  0.0   1188     4 ?        Ss   13:25   0:00 sleep 10000
```

As you see there are in fact two processes: `docker run` and `sleep 1000` running in a container.

Let's send kill signal to the `docker run` (just as CI/CD job would do for long running processes):

```bash
kill 14171
```

`docker run` process has not exited, and `sleep` process is running!

```bash
ps uax | grep sleep
root     14221  0.0  0.0   1188     4 ?        Ss   13:25   0:00 sleep 10000
```


Yelp engineers have a good answer for why this happens [here](https://github.com/Yelp/dumb-init):

> The Linux kernel applies special signal handling to processes which run as PID 1.
> When processes are sent a signal on a normal Linux system, the kernel will first check for any custom handlers the process has registered for that signal, and otherwise fall back to default behavior (for example, killing the process on SIGTERM).

> However, if the process receiving the signal is PID 1, it gets special treatment by the kernel; if it hasn't registered a handler for the signal, the kernel won't fall back to default behavior, and nothing happens. In other words, if your process doesn't explicitly handle these signals, sending it SIGTERM will have no effect at all.

To solve this (and other) issues, you need a simple init system that has proper signal handlers specified. Luckily `Yelp` engineers built the simple and lightweight init system, `dumb-init`

```bash
docker run quay.io/gravitational/debian-tall /usr/bin/dumb-init /bin/sh -c "sleep 10000"
```

Now you can simply stop `docker run` process using SIGTERM and it will handle shutdown properly

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

We made a mistake and the HTTP server is not running there but there is no indication of this as the parent
process is still running.

The first obvious fix is to use a proper init system and monitor the status of the web service.
However, let's use this as an opportunity to use liveness probes:


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

The liveness probe will fail and the container will get restarted.

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

Kubernetes and Docker have a system of plugins to make sure logs sent to stdout and stderr will get
collected, forwarded and rotated.

**NOTE:** This is one of the patterns of [The Twelve Factor App](https://12factor.net/logs) and Kubernetes supports it out of the box!

### Production Pattern: Immutable containers

Every time you write something to container's filesystem, it activates [copy on write strategy](https://docs.docker.com/engine/userguide/storagedriver/imagesandcontainers/#container-and-layers).

A new storage layer is created using a storage driver (devicemapper, overlayfs or others). In case of active usage,
it can put a lot of load on storage drivers, especially in case of Devicemapper or BTRFS.

Make sure your containers write data only to volumes. You can use `tmpfs` for small (as tmpfs stores everything in memory) temporary files:

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
  - name: tempdir
    emptyDir: {}
```

### Anti-Pattern: Using `latest` tag

Do not use `latest` tag in production. It creates ambiguity, as it's not clear what real version of the app this is.

It is ok to use `latest` for development purposes, although make sure you set `imagePullPolicy` to `Always`, to make sure
Kubernetes always pulls the latest version when creating a pod:

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

Imagine a situation when your container takes some time to start. To simulate this, we are going to write a simple script:

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

Readiness probe indicates the readiness of the pod containers and Kubernetes will take this into account when
doing a deployment:

```bash
$ kubectl replace -f deployment-fix.yaml
```

This time we will get no downtime.

### Anti-Pattern: unbound quickly failing jobs

Kubernetes provides new useful tool to schedule containers to perform one-time task: [jobs](https://kubernetes.io/docs/concepts/jobs/run-to-completion-finite-workloads/)

However, there is a problem:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: bad
spec:
  template:
    metadata:
      name: bad
    spec:
      restartPolicy: Never
      containers:
      - name: box
        image: busybox
        command: ["/bin/sh", "-c", "exit 1"]
```


```bash
$ cd prod/jobs
$ kubectl create -f job.yaml
```

You are going to observe the race to create hundreds of containers for the job retrying forever:

```bash
$ kubectl describe jobs 
Name:		bad
Namespace:	default
Image(s):	busybox
Selector:	controller-uid=18a6678e-11d1-11e7-8169-525400c83acf
Parallelism:	1
Completions:	1
Start Time:	Sat, 25 Mar 2017 20:05:41 -0700
Labels:		controller-uid=18a6678e-11d1-11e7-8169-525400c83acf
		job-name=bad
Pods Statuses:	1 Running / 0 Succeeded / 24 Failed
No volumes.
Events:
  FirstSeen	LastSeen	Count	From			SubObjectPath	Type		Reason			Message
  ---------	--------	-----	----			-------------	--------	------			-------
  1m		1m		1	{job-controller }			Normal		SuccessfulCreate	Created pod: bad-fws8g
  1m		1m		1	{job-controller }			Normal		SuccessfulCreate	Created pod: bad-321pk
  1m		1m		1	{job-controller }			Normal		SuccessfulCreate	Created pod: bad-2pxq1
  1m		1m		1	{job-controller }			Normal		SuccessfulCreate	Created pod: bad-kl2tj
  1m		1m		1	{job-controller }			Normal		SuccessfulCreate	Created pod: bad-wfw8q
  1m		1m		1	{job-controller }			Normal		SuccessfulCreate	Created pod: bad-lz0hq
  1m		1m		1	{job-controller }			Normal		SuccessfulCreate	Created pod: bad-0dck0
  1m		1m		1	{job-controller }			Normal		SuccessfulCreate	Created pod: bad-0lm8k
  1m		1m		1	{job-controller }			Normal		SuccessfulCreate	Created pod: bad-q6ctf
  1m		1s		16	{job-controller }			Normal		SuccessfulCreate	(events with common reason combined)

```

Probably not the result you expected. Over time, the load on the nodes and docker will be quite substantial,
especially if job is failing very quickly.

Let's clean up the busy failing job first:

```bash
$ kubectl delete jobs/bad
```

Now let's use `activeDeadlineSeconds` to limit amount of retries:


```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: bound
spec:
  activeDeadlineSeconds: 10
  template:
    metadata:
      name: bound
    spec:
      restartPolicy: Never
      containers:
      - name: box
        image: busybox
        command: ["/bin/sh", "-c", "exit 1"]
```

```bash
$ kubectl create -f bound.yaml
```

Now you will see that after 10 seconds, the job has failed:

```bash
  11s		11s		1	{job-controller }			Normal		DeadlineExceeded	Job was active longer than specified deadline
```


**NOTE:** Sometimes it makes sense to retry forever. In this case make sure to set a proper pod restart policy to protect from
accidental DDOS on your cluster.


### Production pattern: Circuit Breaker

In this example, our web application is an imaginary web server for email. To render the page,
our frontend has to make two requests to the backend:

* Talk to the weather service to get current weather
* Fetch current mail from the database

If the weather service is down, user still would like to review the email, so weather service
is auxilliary, while current mail service is critical.

Here is our frontend, weather and mail services written in python:

**Weather**

```python
from flask import Flask
app = Flask(__name__)

@app.route("/")
def hello():
    return '''Pleasanton, CA
Saturday 8:00 PM
Partly Cloudy
12 C
Precipitation: 9%
Humidity: 74%
Wind: 14 km/h
'''

if __name__ == "__main__":
    app.run(host='0.0.0.0')
```

**Mail**

```python
from flask import Flask,jsonify
app = Flask(__name__)

@app.route("/")
def hello():
    return jsonify([
        {"from": "<bob@example.com>", "subject": "lunch at noon tomorrow"},
        {"from": "<alice@example.com>", "subject": "compiler docs"}])

if __name__ == "__main__":
    app.run(host='0.0.0.0')
```

**Frontend**

```python
from flask import Flask
import requests
from datetime import datetime
app = Flask(__name__)

@app.route("/")
def hello():
    weather = "weather unavailable"
    try:
        print "requesting weather..."
        start = datetime.now()
        r = requests.get('http://weather')
        print "got weather in %s ..." % (datetime.now() - start)
        if r.status_code == requests.codes.ok:
            weather = r.text
    except:
        print "weather unavailable"

    print "requesting mail..."
    r = requests.get('http://mail')
    mail = r.json()
    print "got mail in %s ..." % (datetime.now() - start)

    out = []
    for letter in mail:
        out.append("<li>From: %s Subject: %s</li>" % (letter['from'], letter['subject']))
    

    return '''<html>
<body>
  <h3>Weather</h3>
  <p>%s</p>
  <h3>Email</h3>
  <p>
    <ul>
      %s
    </ul>
  </p>
</body>
''' % (weather, '<br/>'.join(out))

if __name__ == "__main__":
    app.run(host='0.0.0.0')
```

Let's create our deployments and services:


```bash
$ cd prod/cbreaker
$ docker build -t $(minikube ip):5000/mail:0.0.1 .
$ docker push $(minikube ip):5000/mail:0.0.1
$ kubectl apply -f service.yaml
deployment "frontend" configured
deployment "weather" configured
deployment "mail" configured
service "frontend" configured
service "mail" configured
service "weather" configured
```

Check that everyting is running smoothly:

```bash
$ kubectl run -i -t --rm cli --image=tutum/curl --restart=Never
$ curl http://frontend
<html>
<body>
  <h3>Weather</h3>
  <p>Pleasanton, CA
Saturday 8:00 PM
Partly Cloudy
12 C
Precipitation: 9%
Humidity: 74%
Wind: 14 km/h
</p>
  <h3>Email</h3>
  <p>
    <ul>
      <li>From: <bob@example.com> Subject: lunch at noon tomorrow</li><br/><li>From: <alice@example.com> Subject: compiler docs</li>
    </ul>
  </p>
</body>
```

Let's introduce weather service that crashes:

```python
from flask import Flask
app = Flask(__name__)

@app.route("/")
def hello():
    raise Exception("I am out of service")

if __name__ == "__main__":
    app.run(host='0.0.0.0')
```

Build and redeploy:

```bash
$ docker build -t $(minikube ip):5000/weather-crash:0.0.1 -f weather-crash.dockerfile .
$ docker push $(minikube ip):5000/weather-crash:0.0.1
$ kubectl apply -f weather-crash.yaml 
deployment "weather" configured
```

Let's make sure that it is crashing:

```bash
$ kubectl run -i -t --rm cli --image=tutum/curl --restart=Never
$ curl http://weather
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<title>500 Internal Server Error</title>
<h1>Internal Server Error</h1>
<p>The server encountered an internal error and was unable to complete your request.  Either the server is overloaded or there is an error in the application.</p>
```

However our frontend should be all good:

```bash
$ kubectl run -i -t --rm cli --image=tutum/curl --restart=Never
curl http://frontend
<html>
<body>
  <h3>Weather</h3>
  <p>weather unavailable</p>
  <h3>Email</h3>
  <p>
    <ul>
      <li>From: <bob@example.com> Subject: lunch at noon tomorrow</li><br/><li>From: <alice@example.com> Subject: compiler docs</li>
    </ul>
  </p>
</body>
root@cli:/# curl http://frontend                    
<html>
<body>
  <h3>Weather</h3>
  <p>weather unavailable</p>
  <h3>Email</h3>
  <p>
    <ul>
      <li>From: <bob@example.com> Subject: lunch at noon tomorrow</li><br/><li>From: <alice@example.com> Subject: compiler docs</li>
    </ul>
  </p>
</body>
```

Everything is working as expected! There is one problem though, we have just observed the service is crashing quickly, let's see what happens
if our weather service is slow. This happens way more often in production, e.g. due to network or database overload.

To simulate this failure we are going to introduce an artificial delay:

```python
from flask import Flask
import time

app = Flask(__name__)

@app.route("/")
def hello():
    time.sleep(30)
    raise Exception("System overloaded")

if __name__ == "__main__":
    app.run(host='0.0.0.0')
```

Build and redeploy:

```bash
$ docker build -t $(minikube ip):5000/weather-crash-slow:0.0.1 -f weather-crash-slow.dockerfile .
$ docker push $(minikube ip):5000/weather-crash-slow:0.0.1
$ kubectl apply -f weather-crash-slow.yaml 
deployment "weather" configured
```

Just as expected, our weather service is timing out:

```bash
curl http://weather 
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<title>500 Internal Server Error</title>
<h1>Internal Server Error</h1>
<p>The server encountered an internal error and was unable to complete your request.  Either the server is overloaded or there is an error in the application.</p>
```

The problem though, is that every request to frontend takes 10 seconds as well

```bash
curl http://frontend
```

This is a much more common outage - users leave in frustration as the service is unavailable.
To fix this issue we are going to introduce a special proxy with [circuit breaker](http://vulcand.github.io/proxy.html#circuit-breakers).

![standby](http://vulcand.github.io/_images/CircuitStandby.png)

Circuit breaker is a special middleware that is designed to provide a fail-over action in case the service has degraded. It is very helpful to prevent cascading failures - where the failure of the one service leads to failure of another. Circuit breaker observes requests statistics and checks the stats against a special error condition.


![tripped](http://vulcand.github.io/_images/CircuitTripped.png)

Here is our simple circuit breaker written in python:

```python
from flask import Flask
import requests
from datetime import datetime, timedelta
from threading import Lock
import logging, sys


app = Flask(__name__)

circuit_tripped_until = datetime.now()
mutex = Lock()

def trip():
    global circuit_tripped_until
    mutex.acquire()
    try:
        circuit_tripped_until = datetime.now() + timedelta(0,30)
        app.logger.info("circuit tripped until %s" %(circuit_tripped_until))
    finally:
        mutex.release()

def is_tripped():
    global circuit_tripped_until    
    mutex.acquire()
    try:
        return datetime.now() < circuit_tripped_until
    finally:
        mutex.release()
    

@app.route("/")
def hello():
    weather = "weather unavailable"
    try:
        if is_tripped():
            return "circuit breaker: service unavailable (tripped)"

        r = requests.get('http://localhost:5000', timeout=1)
        app.logger.info("requesting weather...")
        start = datetime.now()
        app.logger.info("got weather in %s ..." % (datetime.now() - start))
        if r.status_code == requests.codes.ok:
            return r.text
        else:
            trip()
            return "circuit breaker: service unavailable (tripping 1)"
    except:
        app.logger.info("exception: %s", sys.exc_info()[0])
        trip()
        return "circuit breaker: service unavailable (tripping 2)"

if __name__ == "__main__":
    app.logger.addHandler(logging.StreamHandler(sys.stdout))
    app.logger.setLevel(logging.DEBUG)
    app.run(host='0.0.0.0', port=6000)
```

Let's build and redeploy circuit breaker:

```bash
$ docker build -t $(minikube ip):5000/cbreaker:0.0.1 -f cbreaker.dockerfile .
$ docker push $(minikube ip):5000/cbreaker:0.0.1
$ kubectl apply -f weather-cbreaker.yaml 
deployment "weather" configured
$  kubectl apply -f weather-service.yaml
service "weather" configured
```


Circuit breaker will detect service outage and auxilliary weather service will not bring our mail service down any more:

```bash
curl http://frontend
<html>
<body>
  <h3>Weather</h3>
  <p>circuit breaker: service unavailable (tripped)</p>
  <h3>Email</h3>
  <p>
    <ul>
      <li>From: <bob@example.com> Subject: lunch at noon tomorrow</li><br/><li>From: <alice@example.com> Subject: compiler docs</li>
    </ul>
  </p>
</body>
```

**NOTE:** There are some production level proxies that natively support circuit breaker pattern - such as [Vulcand](http://vulcand.github.io/), [Nginx plus](https://www.nginx.com/products/) or [Envoy](https://lyft.github.io/envoy/)


### Production Pattern: Sidecar For Rate and Connection Limiting

In the previous example we have used a sidecar pattern - a special proxy local to the Pod, that adds additional logic to the service, such as error detection, TLS termination
and other features.

Here is an example of sidecar nginx proxy that adds rate and connection limits:

```bash
$ cd prod/sidecar
$ docker build -t $(minikube ip):5000/sidecar:0.0.1 -f sidecar.dockerfile .
$ docker push $(minikube ip):5000/sidecar:0.0.1
$ docker build -t $(minikube ip):5000/service:0.0.1 -f service.dockerfile .
$ docker push $(minikube ip):5000/service:0.0.1
$ kubectl apply -f sidecar.yaml
deployment "sidecar" configured
```

Try to hit the service faster than one request per second and you will see the rate limiting in action

```bash
$ kubectl run -i -t --rm cli --image=tutum/curl --restart=Never
curl http://sidecar
```

[Istio](https://istio.io/docs/concepts/what-is-istio/overview.html#architecture) is an example of platform that embodies this design and more for instance.
