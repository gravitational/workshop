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

We are going to use "buildbox" pattern to first build an image that 

