# Workshop

Docker 101 workshop

## Installation

### Requirements

You will need Mac OSX with at least `7GB RAM` and `8GB free disk space` available.

* docker

### Docker

For Linux: follow instructions provided [here](https://docs.docker.com/engine/installation/linux/).

If you have Mac OS X (Yosemite or newer), please download Docker for Mac [here](https://download.docker.com/mac/stable/Docker.dmg).

*Older docker package for OSes older than Yosemite -- Docker Toolbox located [here](https://www.docker.com/products/docker-toolbox).*

### Xcode and local tools

Xcode will install essential console utilities for us. You can install it from AppStore.

## Introduction

### Hello, world

Docker is as easy as Linux! To prove that let us write classic "Hello, World" in docker

```bash
docker run busybox echo "hello world"
```

Docker containers are just as simple as linux processes, but they also provide many more features that we are going to explore.

Let's review the structure of the command:

```bash
docker run # executes command in a container
busybox    # container image
echo "hello world" # command to run
```

Container image supplies environment - binaries with shell for example that is running the command, so you are not using
host operating system shell, but the shell from busybox package when doing docker run.

### Sneak peek into container environment

Let's now take a look at users running the container

```bash
docker run busybox ps uax
```

My terminal prints out something like this:

```bash
    1 root       0:00 ps uax
```

*NOTE:* Oh my! Am I running this command as root? Yes, but bear with me, this is not your regular root user, but a very limited one. We will get back to the topic of users and security a bit later.

### Extending container environment

As you can see, the process runs in a very limited and isolated environment, and the PID of the process is 1, so it does not see all other processes
running on your machine.

#### Adding envrionment variables

Let's see what environment variables do we have

```
docker run busybox env
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HOSTNAME=0a0169cdec9a
```

The environment is different from your host environment as well.
We can extend environment by passing explicit enviornment variable flag to `docker run`:

```bash
docker run -e HELLO=world busybox env
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HOSTNAME=8ee8ba3443b6
HELLO=world
HOME=/root
```

### Adding host mounts

If we look at the disks we will see that none of the OS directories are not here as well,
this mean


**Daemons**

To make it a little more complex, let us start our program in background:

```bash
docker run busybox echo "hello world"
```
