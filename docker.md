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

Let's now take a look at process tree running in the container:

```bash
docker run busybox ps uax
```

My terminal prints out something like this:

```bash
    1 root       0:00 ps uax
```

*NOTE:* Oh my! Am I running this command as root? Yes, but bear with me, this is not your regular root user, but a very limited one. We will get back to the topic of users and security a bit later.

As you can see, the process runs in a very limited and isolated environment, and the PID of the process is 1, so it does not see all other processes
running on your machine.

### Adding envrionment variables

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

If we look at the disks we will see that none of the OS directories are not here as well:

```bash
docker run busybox ls -l /home
total 0
```

What if we want to expose our current directory to the container? For this we can use host mounts:

```
docker run -v $(pwd):/home busybox ls -l /home
total 72
-rw-rw-r--    1 1000     1000         11315 Nov 23 19:42 LICENSE
-rw-rw-r--    1 1000     1000         30605 Mar 22 23:19 README.md
drwxrwxr-x    2 1000     1000          4096 Nov 23 19:30 conf.d
-rw-rw-r--    1 1000     1000          2922 Mar 23 03:44 docker.md
drwxrwxr-x    2 1000     1000          4096 Nov 23 19:35 img
drwxrwxr-x    4 1000     1000          4096 Nov 23 19:30 mattermost
-rw-rw-r--    1 1000     1000           585 Nov 23 19:30 my-nginx-configmap.yaml
-rw-rw-r--    1 1000     1000           401 Nov 23 19:30 my-nginx-new.yaml
-rw-rw-r--    1 1000     1000           399 Nov 23 19:30 my-nginx-typo.yaml
```

This command "mounted" our current working directory inside the container, so it appears to be "/home"
inside the container! All changes that we do in this repository will be immediately seen in the container's `home`
directory.

### Network

Networking in Docker containers is isolated as well, let us look at the interfaces inside a running container:

```bash
docker run busybox ifconfig
eth0      Link encap:Ethernet  HWaddr 02:42:AC:11:00:02  
          inet addr:172.17.0.2  Bcast:0.0.0.0  Mask:255.255.0.0
          inet6 addr: fe80::42:acff:fe11:2/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:1 errors:0 dropped:0 overruns:0 frame:0
          TX packets:1 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:90 (90.0 B)  TX bytes:90 (90.0 B)

lo        Link encap:Local Loopback  
          inet addr:127.0.0.1  Mask:255.0.0.0
          inet6 addr: ::1/128 Scope:Host
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1 
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)
```

What if we wanted to expose the host networking to our containers? We can do this, but to get there
we first need to learn another flag:

**Daemons**

To make it a little more complex, let us start our program in background:

```bash
docker run busybox echo "hello world"
```
