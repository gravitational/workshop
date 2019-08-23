# Gravitational Workshops

Open source series of workshops delivered by Gravitational services team.

* [Docker 101 workshop](docker.md)
* [Kubernetes 101 workshop using Minikube and Mattermost](k8s101.md)
* [Kubernetes production patterns](k8sprod.md)
* [Gravity 101](gravity101.md)
* [Gravity fire drill exercises](firedrills.md)

## Installation

### Requirements

You will need a Linux or macOS box with at least `7GB` of RAM and `20GB` of free disk space available.

### Docker

For Linux: follow instructions provided [here](https://docs.docker.com/engine/installation/linux/).

If you have macOS (Yosemite or newer), please download Docker for Mac [here](https://download.docker.com/mac/stable/Docker.dmg).

*Older docker package for OSes older than Yosemite -- Docker Toolbox located [here](https://www.docker.com/products/docker-toolbox).*

### VirtualBox

Let’s install VirtualBox first.

Get latest stable version from https://www.virtualbox.org/wiki/Downloads.

### Linux: KVM2

Follow the instructions here: https://github.com/kubernetes/minikube/blob/master/docs/drivers.md#kvm2-driver

### Kubectl

For macOS:

    curl -O https://storage.googleapis.com/kubernetes-release/release/v1.15.2/bin/darwin/amd64/kubectl \
        && chmod +x kubectl && sudo mv kubectl /usr/local/bin/

For Linux:

    curl -O https://storage.googleapis.com/kubernetes-release/release/v1.15.2/bin/linux/amd64/kubectl \
        && chmod +x kubectl && sudo mv kubectl /usr/local/bin/

### Minikube

For macOS:

    curl -Lo minikube https://storage.googleapis.com/minikube/releases/v1.3.1/minikube-darwin-amd64 \
        && chmod +x minikube && sudo mv minikube /usr/local/bin/

For Linux:

    curl -Lo minikube https://storage.googleapis.com/minikube/releases/v1.3.1/minikube-linux-amd64 \
        && chmod +x minikube && sudo mv minikube /usr/local/bin/

Also, you can install drivers for various VM providers to optimize your minikube VM performance.
Instructions can be found here: https://github.com/kubernetes/minikube/blob/master/docs/drivers.md.

### Xcode and local tools

Xcode will install essential console utilities for us. You can install it from the App Store.

## Set up cluster using minikube

To run cluster:

**macOS**

```bash
# starts minikube
$ minikube start --kubernetes-version=v1.15.2
# this command should work
$ kubectl get nodes
# use docker from minikube
$ eval $(minikube docker-env)
# this command to check connectivity
$ docker ps
```

**Linux**

```bash
# starts minikube
$ minikube start --kubernetes-version=v1.15.2 --vm-driver=kvm2
# this command should work
$ kubectl get nodes
# use docker from minikube
$ eval $(minikube docker-env)
# this command to check connectivity
$ docker ps
```

## Configure registry

```
$ kubectl create -f registry.yaml
```
