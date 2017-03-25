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

1. Size

```bash
$ docker images | grep prod
prod                                          latest              b2c197180350        14 minutes ago      293.7 MB
```

That's almost 300 megabytes to host several kilobytes of the c program! We are bringing in package manager,
C compiler and lots of other unnecessary tools that are not required to run this program.


Which leads us to the second problem:

2. Security

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

## Zombies

**NOTICE:** this example demonstration will only work on Linux

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



