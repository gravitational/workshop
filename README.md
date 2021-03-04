# Gravitational Workshops

Open source series of workshops delivered by Gravitational services team.

* [Docker 101 workshop](docker.md)
* [Kubernetes 101 workshop using Minikube and Mattermost](k8s101.md)
* [Kubernetes production patterns](k8sprod.md)
* [Kubernetes security patterns](k8ssecurity.md)
* [Kubernetes custom resources](crd/crd.md)
* [Gravity 101](gravity101.md)
* [Gravity fire drill exercises](firedrills.md)
* [Gravity logging (Gravity 5.5 and earlier)](logging-5.x.md)
* [Gravity logging (Gravity 6.0 and later)](logging-6.x.md)
* [Gravity monitoring & alerts (Gravity 5.5 and earlier)](monitoring-5.x.md)
* [Gravity monitoring & alerts (Gravity 6.0 and later)](monitoring-6.x.md)
* [Gravity networking and network troubleshooting](gravity_networking.md)
* [Gravity upgrade (5.5)](upgrade-5.x.md)
* [Gravity upgrade (7.0)](gravity_upgrade.md)

## Installation

### Requirements

You will need a Linux or macOS box with at least `7GB` of RAM and `20GB` of free disk space available.

### Docker

For Linux: follow instructions provided [here](https://docs.docker.com/engine/installation/linux/).

If you have macOS (Yosemite or newer), please download Docker for Mac [here](https://download.docker.com/mac/stable/Docker.dmg).

*Older docker package for OSes older than Yosemite -- Docker Toolbox located [here](https://www.docker.com/products/docker-toolbox).*

### Hypervisor

#### HyperKit [macOS only]

HyperKit is a lightweight macOS hypervisor which minikube supports out of the box and which should be
already installed on your machine if you have Docker for Desktop installed.

More information: https://minikube.sigs.k8s.io/docs/reference/drivers/hyperkit/.

Alternatively, install VirtualBox like described below.

#### KVM2 [Linux only]

Follow the instructions here: https://minikube.sigs.k8s.io/docs/reference/drivers/kvm2/.

Alternatively, install VirtualBox like described below.

#### VirtualBox [both macOS and Linux]

Let’s install VirtualBox.

Get latest stable version from https://www.virtualbox.org/wiki/Downloads.

**Note:** When using Ubuntu you may need to disable Secure Boot. For an alternative approach to installing with Secure Boot enabled,
follow the guide [here](https://torstenwalter.de/virtualbox/ubuntu/2019/06/13/install-virtualbox-ubuntu-secure-boot.html).

### Kubectl

For macOS:

    curl -O https://storage.googleapis.com/kubernetes-release/release/v1.16.2/bin/darwin/amd64/kubectl \
        && chmod +x kubectl && sudo mv kubectl /usr/local/bin/

For Linux:

    curl -O https://storage.googleapis.com/kubernetes-release/release/v1.16.2/bin/linux/amd64/kubectl \
        && chmod +x kubectl && sudo mv kubectl /usr/local/bin/

### Minikube

For macOS:

    curl -Lo minikube https://storage.googleapis.com/minikube/releases/v1.5.1/minikube-darwin-amd64 \
        && chmod +x minikube && sudo mv minikube /usr/local/bin/

For Linux:

    curl -Lo minikube https://storage.googleapis.com/minikube/releases/v1.5.1/minikube-linux-amd64 \
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
$ minikube start --kubernetes-version=v1.16.2
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
$ minikube start --kubernetes-version=v1.16.2 --vm-driver=kvm2
# this command should work
$ kubectl get nodes
# use docker from minikube
$ eval $(minikube docker-env)
# this command to check connectivity
$ docker ps
```

## Clone the Workshop repository
```bash
$ git clone https://github.com/gravitational/workshop.git
$ cd workshop
```

## Configure registry

```
$ kubectl create -f registry.yaml
```
