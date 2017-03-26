# Docker 101

Docker 101 workshop - introduction to Docker and basic concepts

## Installation

### Requirements

You will need Mac OSX with at least `7GB RAM` and `8GB free disk space` available.

* Docker

### Docker

For Linux: follow instructions provided [here](https://docs.docker.com/engine/installation/linux/).

If you have Mac OS X (Yosemite or newer), please download Docker for Mac [here](https://download.docker.com/mac/stable/Docker.dmg).

*Older docker package for OSes older than Yosemite -- Docker Toolbox located [here](https://www.docker.com/products/docker-toolbox).*

### Xcode and local tools

Xcode will install essential console utilities for us. You can install it from AppStore.

## Introduction

### Hello, world

Docker is as easy as Linux! To prove that let us write classic "Hello, World" in Docker

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
host operating system shell, but the shell from busybox package when executing Docker run.

### Sneak peek into container environment

Let's now take a look at process tree running in the container:

```bash
$ docker run busybox ps uax
```

My terminal prints out something like this:

```bash
    1 root       0:00 ps uax
```

*NOTE:* Oh my! Am I running this command as root? Yes, although this is not your regular root user but a very limited one. We will get back to the topic of users and security a bit later.

As you can see, the process runs in a very limited and isolated environment, and the PID of the process is 1, so it does not see all other processes
running on your machine.

### Adding envrionment variables

Let's see what environment variables we have:

```
$ docker run busybox env
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HOSTNAME=0a0169cdec9a
```

The environment is different from your host environment.
We can extend environment by passing explicit enviornment variable flag to `docker run`:

```bash
$ docker run -e HELLO=world busybox env
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HOSTNAME=8ee8ba3443b6
HELLO=world
HOME=/root
```

### Adding host mounts

If we look at the disks we will see the OS directories are not here, as well:

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

Networking in Docker containers is isolated, as well. Let us look at the interfaces inside a running container:

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


We can use `-p` flag to forward a port on the host to the port 5000 inside the container:


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


## A bit of background

![docker-settings](img/containers.png)

A Docker container is a set of linux processes that run isolated from the rest of the processes. 

[chart](https://www.lucidchart.com/documents/edit/d5226f07-00b1-4a7a-ba22-59e0c2ec0b77/0)

Multiple linux subsystems help to create a container concept:

**Namespaces**

Namespaces create isolated stacks of linux primitives for a running process.

* NET namespace creates a separate networking stack for the container, with its own routing tables and devices
* PID namespace is used to assign isolated process IDs that are separate from host OS. For example, this is important if we want to send signals to a running
process.
* MNT namespace creates a scoped view of a filesystem using [VFS](http://www.tldp.org/LDP/khg/HyperNews/get/fs/vfstour.html). It lets a container
to get its own "root" filesystem and map directories from one location on the host to the other location inside container.
* UTS namespace lets container to get to its own hostname.
* IPC namespace is used to isolate inter-process communication (e.g. message queues).
* USER namespace allows container processes have different users and IDs from the host OS.

**Control groups**

Kernel feature that limits, accounts for, and isolates the resource usage (CPU, memory, disk I/O, network, etc.)

**Capabilities**

Capabilitites provide enhanced permission checks on the running process, and can limit the interface configuration, even for a root user - for example (`CAP_NET_ADMIN`)

You can find a lot of additional low level detail [here](http://crosbymichael.com/creating-containers-part-1.html).


## More container operations

**Daemons**

Our last python server example was inconvenient as it worked in foreground:

```bash
$ docker run -d -p 5000:5000 --name=simple1 library/python:3.3 python -m http.server 5000
```

Flag `-d` instructs Docker to start the process in background. Let's see if still works:

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

* Container ID - auto generated unique running id.
* Container image - image name.
* Command - linux process running as the PID 1 in the container.
* Names - user friendly name of the container, we have named our container with `--name=simple1` flag.

We can use `logs` to view logs of a running container:

```bash
$ docker logs simple1
```

**Attaching to a running container**

We can execute a process that joins container namespaces using `exec` command:

```bash
$ docker exec -ti simple1 /bin/sh
```

We can look around to see the process running as PID 1:

```bash
# ps uax
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  0.5  0.0  74456 17512 ?        Ss   18:07   0:00 python -m http.server 5000
root         7  0.0  0.0   4336   748 ?        Ss   18:08   0:00 /bin/sh
root        13  0.0  0.0  19188  2284 ?        R+   18:08   0:00 ps uax
# 
```

This gives an illusion that you `SSH` in a container. However, there is no remote network connection.
The process `/bin/sh` started an instead of running in the host OS joined all namespaces of the container.

* `-t` flag attaches terminal for interactive typing.
* `-i` flag attaches input/output from the terminal to the process.

**Starting and stopping containers**

To stop and start container we can use `stop` and `start` commands:

```
$ docker stop simple1
$ docker start simple1
```

**NOTE:** container names should be unique. Otherwise, you will get an error when you try to create a new container with a conflicting name!

**Interactive containers**

`-it` combination allows us to start interactive containers without attaching to existing ones:

```bash
$ docker run -ti busybox
# ps uax
PID   USER     TIME   COMMAND
    1 root       0:00 sh
    7 root       0:00 ps uax
```

**Attaching to containers input**

To best illustrate the impact of `-i` or `--interactive` in the expanded version, consider this example:

```bash
$ echo "hello there " | docker run busybox grep hello
```

The example above won't work as the container's input is not attached to the host stdout. The `-i` flag fixes just that:

```bash
$ echo "hello there " | docker run -i busybox grep hello
hello there 
```

## Building Container images

So far we have been using container images downloaded from Docker's public registry.

**Starting from scratch**

`Dockerfile` is a special file that instructs `docker build` command how to build an image

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


The Dockerfile looks very simple:

```dockerfile
FROM scratch
ADD hello.sh /hello.sh
```

`FROM scratch` instructs a Docker build process to use empty image to start building the container image.
`ADD hello.sh /hello.sh` adds file `hello.sh` to the container's root path `/hello.sh`.

**Viewing images**

`docker images` command is used to display images that we have built:

```
docker images
REPOSITORY                                    TAG                 IMAGE ID            CREATED             SIZE
hello                                         latest              4dce466cf3de        10 minutes ago      34 B
```

* Repository - a name of the local (on your computer) or remote repository. Our current repository is local and is called `hello`.
* Tag - indicates the version of our image, Docker sets `latest` tag automatically if not specified.
* Image ID - unique image ID.
* Size - the size of our image is just 34 bytes.

**NOTE:** Docker images are very different from virtual image formats. Because Docker does not boot any operating system, but simply runs
linux process in isolation, we don't need any kernel, drivers or libraries to ship with the image, so it could be as tiny as several bytes!


**Running the image**

Trying to run it though, will result in the error:

```bash
$ docker run hello /hello.sh
write pipe: bad file descriptor
```

This is because our container is empty. There is no shell and the script won't be able to start!
Let's fix that by changing our base image to `busybox` that contains a proper shell environment:


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

We can run our script now:

```bash
$ docker run hello /hello.sh
hello, world!
```

**Versioning**

Let us roll a new version of our script `v2`

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

Execute the script using `image:tag` notation:

```bash
$ docker run hello:v2 /hello.sh
hello, world v2!
```

**Entry point**

We can improve our image by supplying `entrypoint`:


```bash
$ cd docker/busybox-entrypoint
$ docker build -t hello:v3 .
```

Entrypoint remembers the command to be executed on start, even if you don't supply the arguments:

```bash
$ docker run hello:v3
hello, world !
```

What happens if you pass flags? they will be executed as arugments:

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

Sometimes it is helpful to supply arguments during build process
(for example, user ID to create inside the container). We can supply build arguments as flags to `docker build`:


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

Notice how `ARG` have supplied the build argument and we have referred to it right away, exposing it as environment variable right away.

**Build layers and caching**

Let's take a look at the new build image in the `docker/cache` directory:

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

```bash
cp script2.sh script.sh
```

They are only differrent by one letter, but this makes a difference:


```bash
$ docker build -t hello:v7 .
$ docker run hello:v7
Hello, hello!
```

Notice `Using cache` diagnostic output from the container:

```
$ docker build -t hello:v7 .
Sending build context to Docker daemon  5.12 kB
Step 1 : FROM busybox
 ---> 00f017a8c2a6
Step 2 : ADD file /file
 ---> Using cache
 ---> 6f48df47cb1d
Step 3 : ADD script.sh /script.sh
 ---> b187172076e2
Removing intermediate container 7afa2631d677
Step 4 : ENTRYPOINT /script.sh
 ---> Running in 51217447e66c
 ---> d0ec3cfed6f7
Removing intermediate container 51217447e66c
Successfully built d0ec3cfed6f7
```


Docker executes every command in a special container. It detects the fact that the content has (or has not) changed,
and instead of re-exectuing the command, uses cached value isntead. This helps to speed up builds, but sometimes introduces problems.

**NOTE:** You can always turn caching off by using the `--no-cache=true` option for the `docker build` command.

Docker images are composed of layers:

![images](https://docs.docker.com/engine/userguide/storagedriver/images/image-layers.jpg)

Every layer is a the result of the execution of a command in the Dockerfile. 

**RUN command**

The most frequently used command is `RUN`: it executes the command in a container,
captures the output and records it as an image layer.


Let's us use existing package managers to compose our images:

```Dockerfile
FROM ubuntu:14.04
RUN apt-get update
RUN apt-get install -y curl
ENTRYPOINT curl
```

The output of this build will look more like a real Linux install:

```bash
$ cd docker/ubuntu
$ docker build -t myubuntu .
```

We can use our newly created ubuntu to curl pages:

```bash
$ docker run myubuntu https://google.com
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   220  100   220    0     0   1377      0 --:--:-- --:--:-- --:--:--  1383
<HTML><HEAD><meta http-equiv="content-type" content="text/html;charset=utf-8">
<TITLE>301 Moved</TITLE></HEAD><BODY>
<H1>301 Moved</H1>
The document has moved
<A HREF="https://www.google.com/">here</A>.
</BODY></HTML>
```

However, it all comes at a price:

```bash
$ docker images
REPOSITORY                                    TAG                 IMAGE ID            CREATED             SIZE
myubuntu                                      latest              50928f386c70        53 seconds ago      221.8 MB
```

That is 220MB for curl! As we know, now there is no good reason to have images with all the OS inside. If you still need it though, Docker
will save you some space by re-using the base layer, so images with slightly different bases
would not repeat each other.

### Operations with images

You are already familiar with one command, `docker images`. You can also remove images, tag and untag them.

**Removing images and containers**

Let's start with removing the image that takes too much disk space:

```
$ docker rmi myubuntu
Error response from daemon: conflict: unable to remove repository reference "myubuntu" (must force) - container 292d1e8d5103 is using its referenced image 50928f386c70
```

Docker complains that there are containers using this image. How is this possible? We thought that all our containers are gone.
Actually, Docker keeps track of all containers, even those that have stopped:

```bash
$ docker ps -a
CONTAINER ID        IMAGE                        COMMAND                   CREATED             STATUS                           PORTS                    NAMES
292d1e8d5103        myubuntu                     "curl https://google."    5 minutes ago       Exited (0) 5 minutes ago                                  cranky_lalande
f79c361a24f9        440a0da6d69e                 "/bin/sh -c curl"         5 minutes ago       Exited (2) 5 minutes ago                                  nauseous_sinoussi
01825fd28a50        440a0da6d69e                 "/bin/sh -c curl --he"    6 minutes ago       Exited (2) 5 minutes ago                                  high_davinci
95ffb2131c89        440a0da6d69e                 "/bin/sh -c curl http"    6 minutes ago       Exited (2) 6 minutes ago                                  lonely_sinoussi
```

We can now delete the container:

```bash
$ docker rm 292d1e8d5103
292d1e8d5103
```

and the image:

```bash
$ docker rmi myubuntu
Untagged: myubuntu:latest
Deleted: sha256:50928f386c704610fb16d3ca971904f3150f3702db962a4770958b8bedd9759b
```

**Tagging images**

`docker tag` helps us to tag images.

We have quite a lot of versions of `hello` built, but latest still points to the old `v1`.

```
$ docker images | grep hello
hello                                         v7                  d0ec3cfed6f7        33 minutes ago      1.11 MB
hello                                         v6                  db7c6f36cba1        42 minutes ago      1.11 MB
hello                                         v5                  1fbecb029c8e        About an hour ago   1.11 MB
hello                                         v4                  ddb5bc88ebf9        About an hour ago   1.11 MB
hello                                         v3                  eb07be15b16a        About an hour ago   1.11 MB
hello                                         v2                  195aa31a5e4d        3 hours ago         1.11 MB
hello                                         latest              47060b048841        3 hours ago         1.11 MB
```

Let's change that by re-tagging `latest` to `v7`:

```bash
$ docker tag hello:v7 hello:latest
$ docker images | grep hello
hello                                         latest              d0ec3cfed6f7        38 minutes ago      1.11 MB
hello                                         v7                  d0ec3cfed6f7        38 minutes ago      1.11 MB
hello                                         v6                  db7c6f36cba1        47 minutes ago      1.11 MB
hello                                         v5                  1fbecb029c8e        About an hour ago   1.11 MB
hello                                         v4                  ddb5bc88ebf9        About an hour ago   1.11 MB
hello                                         v3                  eb07be15b16a        About an hour ago   1.11 MB
hello                                         v2                  195aa31a5e4d        3 hours ago         1.11 MB
```

Both `v7` and `latest` point to the same image ID `d0ec3cfed6f7`.


**Publishing images**

Images are distributed with a special service - `docker registry`.
Let us spin up a local registry:

```bash
$ docker run -p 5000:5000 --name registry -d registry:2
```

`docker push` is used to publish images to registries.

To instruct where we want to publish, we need to append registry address to repository name:

```
$ docker tag hello:v7 127.0.0.1:5000/hello:v7
$ docker push 127.0.0.1:5000/hello:v7
```

`docker push` pushed the image to our "remote" registry.

We can now download the image using the `docker pull` command:

```bash
$ docker pull 127.0.0.1:5000/hello:v7
v7: Pulling from hello
Digest: sha256:c472a7ec8ab2b0db8d0839043b24dbda75ca6fa8816cfb6a58e7aaf3714a1423
Status: Image is up to date for 127.0.0.1:5000/hello:v7
```

### Wrapping up

We have learned how to start, build and publish containers and learned the containers building blocks.
However, there is much more to learn. Just check out this [official docker documentation!](https://docs.docker.com/engine/userguide/).

Thanks to Docker team for such an amazing product!
