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
$ docker run busybox echo "hello world"
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
$ docker run busybox ps uax
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
$ docker run busybox env
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HOSTNAME=0a0169cdec9a
```

The environment is different from your host environment as well.
We can extend environment by passing explicit enviornment variable flag to `docker run`:

```bash
$ docker run -e HELLO=world busybox env
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HOSTNAME=8ee8ba3443b6
HELLO=world
HOME=/root
```

### Adding host mounts

If we look at the disks we will see that none of the OS directories are not here as well:

```bash
$ docker run busybox ls -l /home
total 0
```

What if we want to expose our current directory to the container? For this we can use host mounts:

```
$ docker run -v $(pwd):/home busybox ls -l /home
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
$ docker run busybox ifconfig
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


We can use `-p` flag to forward port on the host to the port 5000 inside the container:


```bash
$ docker run -p 5000:5000 library/python:3.3 python -m http.server 5000
```

This command blocks because the server listens for requests, open a new tab and access the endpoint

```bash
$ curl http://localhost:5000
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
....
```

Press `Ctrl-C` to stop the running container.


## A bit of Theory

![docker-settings](img/containers.png)

Docker container is a set of linux processes that run isolated from the rest of the processes. 

[chart](https://www.lucidchart.com/documents/edit/d5226f07-00b1-4a7a-ba22-59e0c2ec0b77/0)

Multiple linux subsystems help to create a container concept:

**Namespaces**

Namespaces create isolated stacks of linux primitives for a running process.

* NET namespace creates a separate networking stack for the container, own routing tables and devices
* PID namespace is used to assign isolated process IDs that are separate from host OS. This is important if we want to send signal to a running
process, for example
* MNT namespace creates a scoped view of a filesystem using [VFS](http://www.tldp.org/LDP/khg/HyperNews/get/fs/vfstour.html), it lets container
to get it's own "root" filesystem and map directories from one location on the host to the other location inside container
* UTS namespace lets container to get its own hostname
* IPC namespace is used to isolate inter process communication (e.g. message queues)
* USER namespace allows container processes have different users and IDs from the host OS.

**Control groups**

Kernel feature that limits, accounts for, and isolates the resource usage (CPU, memory, disk I/O, network, etc.)

**Capabilities**

Capabilitites provide enhanced permission checks on the running process, and can limit the interface configuration even for a root user for example (`CAP_NET_ADMIN`)

Lots of additional low level detail [here](http://crosbymichael.com/creating-containers-part-1.html)


## More container operations

**Daemons**

Our last python server example was inconvenient as it worked in foreground:

```bash
$ docker run -d -p 5000:5000 --name=simple1 library/python:3.3 python -m http.server 5000
```

Flag `-d` instructs docker to start the process in background, let's see if still works:

```bash
curl http://localhost:5000
```

**Inspecting a running container**

We can use `ps` command to view all running containers:

```bash
$ docker ps
CONTAINER ID        IMAGE                COMMAND                  CREATED             STATUS              PORTS                    NAMES
eea49c9314db        library/python:3.3   "python -m http.serve"   3 seconds ago       Up 2 seconds        0.0.0.0:5000->5000/tcp   simple1
```

* Container ID - auto generated unique running id
* Container image - image name
* Command - linux process running as the PID 1 in the container
* Names - user friendly name of the container, we have named our container with `--name=simple1` flag.

We can use `logs` to view logs of a running container:

```bash
$ docker logs simple1
```

To stop and start container we can use `stop` and `start` commands:

```
$ docker stop simple1
$ docker start simple1
```

**NOTE** container names should be unique, otherwise you will get an error when you try to crate new container with conflicting name!


## Building Container images

So far we have been using container images downloaded from the Docker's public registry.

**Starting from scratch**

`Dockerfile` is a special file that instructs `docker build` command how to build image

```
$ cd docker/scratch
$ docker build -t hello .
Sending build context to Docker daemon 3.072 kB
Step 1 : FROM scratch
 ---> 
Step 2 : ADD hello.sh /hello.sh
 ---> 4dce466cf3de
Removing intermediate container dc8a5b93d5a8
Successfully built 4dce466cf3de
```


Dockerfile looks very simple:

```dockerfile
FROM scratch
ADD hello.sh /hello.sh
```

`FROM scratch` instructs docker build process to use empty image to start building the container image.
`ADD hello.sh /hello.sh` adds file `hello.sh` to the container's root path `/hello.sh`

**Viewing images**

`docker images` command is used to display images that we have built:

```
docker images
REPOSITORY                                    TAG                 IMAGE ID            CREATED             SIZE
hello                                         latest              4dce466cf3de        10 minutes ago      34 B
```

* Repository is a name of the local (on your computer) or remote repository. Our current repository is local and is called `hello`
* Tag - indicates the version of our image, docker sets `latest` tag automatically if not specified
* Image ID - unique image ID
* Size - the size of our image is just 34 bytes

**NOTE** Docker images are very different from virtual image formats. Because docker does not boot any operating system, but simply runs
linux process in isolation, we don't need any kernel, drivers or libraries to ship with the image, so it could be as tiny as several bytes!


**Running the image**

Trying to run it though, will result in error:

```bash
$ docker run hello /hello.sh
write pipe: bad file descriptor
```

This is because our container is empty, there is no shell and script won't be able to start!
Let's fix that by changing our base image to `busybox` that contains proper shell environment:


```bash
$ cd docker/busybox
$ docker build -t hello .
Sending build context to Docker daemon 3.072 kB
Step 1 : FROM busybox
 ---> 00f017a8c2a6
Step 2 : ADD hello.sh /hello.sh
 ---> c8c3f1ea6ede
Removing intermediate container fa59f3921ff8
Successfully built c8c3f1ea6ede
```

Listing the image shows that image id and size have changed:

```bash
$ docker images
REPOSITORY                                    TAG                 IMAGE ID            CREATED             SIZE
hello                                         latest              c8c3f1ea6ede        10 minutes ago      1.11 MB
```

we can run our script now:

```bash
$ docker run hello /hello.sh
hello, world!
```

**Versioning**

Let us roll new version of our script `v2`

```bash
$ cd docker/busybox
docker build -t hello:v2 .
```

We will now see 2 images: `hello:v2` and `hello:latest`

```
hello                                         v2                  195aa31a5e4d        2 seconds ago       1.11 MB
hello                                         latest              47060b048841        20 minutes ago      1.11 MB
```

**NOTE:** Tag `latest` will not automatically point to the latest version, so you have to manually update it

Execute the scirpt using `image:tag` notation:

```bash
$ docker run hello:v2 /hello.sh
hello, world v2!
```

**Entry point**

We can improve our image by supplying `entrypoint`


```bash
$ cd docker/busybox-entrypoint
$ docker build -t hello:v3 .
```

Entrypoint remembers the command to be executed on start, even if you don't supply the arguments:

```bash
$ docker run hello:v3
hello, world !
```

what happens if you pass flags? they will be executed as arugments:

```bash
$ docker run hello:v3 woo
hello, world woo!
```

This magic happens because our v3 script prints passed arguments:

```bash
#!/bin/sh

echo "hello, world $@!"
```


**Environment variables**

We can pass environment variables during build and during runtime as well.

Here's our modified shell script:

```bash
#!/bin/sh

echo "hello, $BUILD1 and $RUN1!"
```

Dockerfile now uses `ENV` directive to provide environment variable:

```Dockerfile
FROM busybox
ADD hello.sh /hello.sh
ENV BUILD1 Bob
ENTRYPOINT ["/hello.sh"]
```

Let's build and run:

```bash
cd docker/busybox-env
$ docker build -t hello:v4 .
$ docker run -e RUN1=Alice hello:v4
hello, Bob and Alice!
```

**Build arguments**

Sometimes it is helpful to supply arguments during build process,
for example user ID to create inside the container. We can supply build arguments as flags to `docker build`:


```bash
$ cd docker/busybox-arg
$ docker build --build-arg=BUILD1="Alice and Bob" -t hello:v5 .
$ docker run hello:v5
hello, Alice and Bob!
```

Here is our updated Dockerfile:

```Dockerfile
FROM busybox
ADD hello.sh /hello.sh
ARG BUILD1
ENV BUILD1 $BUILD1
ENTRYPOINT ["/hello.sh"]
```

Notice how `ARG` have supplied the build argument and we have referred to it right away exposing it as environment variable right away

**Build layers and caching**

Let's take a look at the new build image in `docker/cache` directory:

```bash
$ ls -l docker/cache/
total 12
-rw-rw-r-- 1 sasha sasha 76 Mar 24 16:23 Dockerfile
-rw-rw-r-- 1 sasha sasha  6 Mar 24 16:23 file
-rwxrwxr-x 1 sasha sasha 40 Mar 24 16:23 script.sh
```

We have a file and a script that uses the file:

```bash
$ cd docker/cache
$ docker build -t hello:v6 .

Sending build context to Docker daemon 4.096 kB
Step 1 : FROM busybox
 ---> 00f017a8c2a6
Step 2 : ADD file /file
 ---> Using cache
 ---> 6f48df47cb1d
Step 3 : ADD script.sh /script.sh
 ---> b052fd11bcc6
Removing intermediate container c555e8ab29dc
Step 4 : ENTRYPOINT /script.sh
 ---> Running in 50f057fd89cb
 ---> db7c6f36cba1
Removing intermediate container 50f057fd89cb
Successfully built db7c6f36cba1

$ docker run hello:v6
hello, hello!
```

Let's update the script.sh

echo ""
