# Gravity Upgrade Training (for Gravity 5.5 and earlier)

## Introduction

_Note: This part of the training pertains to Gravity 5.5 and earlier._

This part of the workshop focuses on Gravity upgrades, what is happening under the hood, how to debug and troubleshoot failures, and many more situations. Cluster upgrades can get complicated for complex cloud apps composed of multiple microservices, the goal of this training will be to first build a foundational understanding of how Gravity handles upgrades, step through a manual upgrade example, and then go through some real-world upgrade scenarios.

## Gravity Upgrade Overview

Cluster upgrades require two major layers that need updating. The first layer is k8s itself and its dependencies, and the second layer is the applications deployed inside.

The Gravity upgrade process handles both of these mentioned layers in the following manner:

1. A new version of an application and container images are downloaded and stored inside the cluster and transferred onto a cluster node.

2. Gravity uses k8s rolling update mechanism to perform the update.

3. If applicable, before or after the upgrade custom update hooks can be used to perform application specific actions.

Upgrades can be triggered both via the Gravity Hub (Ops Center) or from the CLI. Below we will go over the upgrade via the CLI to give some detail to the above steps mentioned.

### Step 1: Providing new version of application

As mentioned the first step in the upgrade process is to import your new cluster image onto a Gravity cluster and transfer it onto a master node to execute the upgrade command.

Upgrades can be handled both in online and offline environments.

#### Online Gravity Upgrade

In the case a Gravity cluster is connected to the Gravity Hub (Ops Center) and it has remote support turned on, you can download an updated cluster image directly from the Hub.

Using the `gravity update download` you can check and download any updates

#### Offline Gravity Upgrade

In the case where a Gravity cluster is offline the new version of the cluster image will need to be copied over to one of the master nodes that is accessible to the other nodes.

In order to upload to the new version you will need to extract the tarball and launch the `upload` script.

### Step 2: Performing Gravity Upgrade

As mentioned a Gravity upgrade can be triggered via the Gravity Hub (Ops Center) or from the CLI. In order to trigger the upgrade from the CLI you can extract the cluster image tarball to a directory and inside the execute the `upgrade` script.

```
tar xf cluster-image.tar
ls -lh
sudo ./upgrade OR sudo ./upload
sudo ./gravity upgrade
```

#### Automatic Upgrade

Following executing the upgrade command following the automatic upgrade process, the following steps will take place:

1. Upgrade agent get deployed on each cluster node as a `systemd` unit called `gravity-agent.service`

2. Phases listed in the upgrade plan are executed by the agents.

3. Upon completion the agents are shut down.

#### Manual Upgrade

Another option for a Gravity upgrade is a manual upgrade which we will cover by stepping through an example later in this workshop.

In order to execute a manual upgrade the operation will be started by adding `--manual | -m` flag with the upgrade command:

`sudo ./gravity upgrade --manual`

To ensure version compatibility, all upgrade related commands (agent deployment, phase execution/rollback, etc.) need to be executed using the gravity binary included in the upgrade tarball.

A manual upgrade operation starts with an operation plan which is a tree of actions required to be performed in the specified order to achieve the goal of the upgrade. This concept of the operation exists in order to have sets of smaller steps during an upgrade which can be re-executed or rolled back. Again, more on this as we will step through this in more detail further into the workshop.

## Gravity Upgrade Status, Logs, and more

In order to monitor the cluster, it's useful to go through logs and status messages provided by the platform.

Below there's a list of useful commands/resources to use during debugging.

The list is divided based on when the specific command will be more likely used, like during upgrade or at runtime.

### DURING INSTALL / UPGRADE
  + `sudo ./gravity plan` - from the installer directory
    This command is used to analyze the progress through any Gravity operations.
    It's particularly useful to verify at which step if an operation gets stuck,
    and thus analyze the root cause and to resume once fixed.
  + content of `gravity-system.log` and (if present) `gravity-install.log` files.
    These files are usually found in the installation directory
    or in newer versions they will be located in /var/log
    These files store the output that Gravity generates through installation and
    it's mostly useful during troubleshooting.
  + `sudo ./gravity status` - from the installer directory
    The `status` command output shows the current state of Gravity clusters with
    a high level overview of a cluster's health, hints if the cluster
    is in a degraded state, and the status of individual components.
  + An fundamental component during install and upgrades is the (gravity) agent.
    Said agent creates an initial communication channel that will be used for
    the upgrade by the cluster nodes. In order to verify if it's running,
    checking the systemd unit (with `sudo systemctl status gravity-agent.service`)
    and its logs (via `journalctl -u gravity-agent.service`) may help identify
    possible issues or keep track of messages sent by the agent itself.
  + In case the Gravity Agent dies or needs to be redeployed (eg in case the
    server is rebooted during an upgrade) the command `sudo gravity agent deploy`
    will take care of setting up the Agent on the needed nodes.

### DURING RUNTIME
  + `sudo gravity status`
    The `status` command output shows the current state of Gravity clusters with
    a high level overview of a cluster's health, hints if the cluster
    is in a degraded state, and the status of individual components.
  + `sudo gravity exec planet status`
    The `planet status` command output shows the current state of Gravity
    components and it's helpful to pin down which specific component is failing
    on which node. It's a bit more verbose than `gravity status` but usually
    more informative.
  + `sudo gravity plan`
    Once completed, this command analyzes the last operation ran
    on the Gravity cluster.

  + OUTSIDE PLANET:
    - `sudo systemctl list-unit-files '*grav*'`
      This command will help you identify Gravity systemd units. Usually there
      should only be one `planet` and one `teleport` unit.
    - `sudo journalctl -f -u '*gravity*planet*'`
      This unit is the master container, bubble of consistency, that stores the
      entire Gravity environment. By using this command you can investigate all
      logs forwarded by Gravity to the system log facility.
    - `sudo journalctl -f -u '*gravity*teleport*'`
      This unit is the Teleport unit that is used to make connections possible
      from one to the other. By using this command you can investigate all
      logs forwarded by Teleport to the system log facility.
  + INSIDE PLANET:
    - `sudo systemctl list-unit-files 'kube*'`
      This command will help you identify Kubernetes systemd units.
    - `sudo journalctl -f -u 'kube*'`
      This command will show all logs from all Kubernetes related units.
    - `sudo journalctl -f -u 'serf'`
      This command will show all logs from Serf, which is the software used to
      exchange state messages withing Gravity clusters.
    - `sudo journalctl -f -u 'coredns'`
      This command will show all logs from CoreDNS, which is the software used to
      have DNS resolution working inside the Kubernetes cluster.
    - `sudo journalctl -f -u 'flanneld'`
      This command will show all logs from Flanneld, which is the software used to
      create an overlay network that is used as the backend for all Gravity cluster's
      communication.
    - `sudo journalctl -f -u 'etcd'`
      This command will show all logs from etcd, which is the software used to
      store the Gravity cluster status and some internal information.
    - `sudo journalctl -f -u 'docker'`
      This command will show all logs from Docker, which is the software used to
      run the actual containers used by Kubernetes to run its own Pods.
    - `sudo journalctl -f -u 'registry'`
      This command will show all logs from the container registry, which is used to
      distribute containers' data among all nodes.
    - `sudo journalctl -f -u 'planet-agent'`
      This command will show all logs from the planet-agent daemon, which is used to
      exchange messages in between the different nodes in Gravity clusters.

### Collect logfiles for reporting purpose
  + `sudo gravity report --file report_TICKET_12345.tgz`
    This command will collect all the needed info that can be later inspected
    to debug a Gravity cluster. This includes Kubernetes resources status,
    Gravity and Planet status, some logs from Planet and much more.
    By default the report will be saved in `report.tar.gz` if not specified.
  + `sudo gravity report --since 24h`
    The new `--since` flag will help to narrow down the scope of the `report`
    file by only saving data from the time duration specified (it's in Go time
    duration format). This option helps keeping the report file smaller and thus
    easier to attach to tickets.
  + if for whatever reason the `gravity-site` Kubernetes Pod is unreachable or
    not working, the `gravity report` command won't work and for these cases
    there's low level command `gravity system report` that will collect
    a smaller subset of the usual info gathered by the normal command but
    should still be useful to start troubleshooting issues.
  + content of `gravity-system.log` and (if present) `gravity-install.log` files.
    These files are usually found in the installation directory
    or in newer versions they will be located in /var/log

### Nifty features coming in future versions
Versions of Gravity from latest 5.5.x and 6.1.x onward also includes a nice
feature showing the status changes over time which may be helpful to identify
root causes or brief fluctuations of the cluster state:

```
ubuntu@telekube0:~/i$ sudo gravity status history
2020-07-30T16:18:08Z [Leader Elected]   new leader 172.28.128.3
2020-07-30T16:18:35Z [Node Degraded]    node=172_28_128_3.pensivevillani4966
2020-07-30T16:19:13Z [Probe Failed]     node=172_28_128_3.pensivevillani4966    checker=dns
2020-07-30T16:19:13Z [Probe Succeeded]  node=172_28_128_3.pensivevillani4966    checker=node-status
2020-07-30T16:19:13Z [Probe Failed]     node=172_28_128_3.pensivevillani4966    checker=etcd-healthz
2020-07-30T16:19:35Z [Probe Succeeded]  node=172_28_128_3.pensivevillani4966    checker=etcd-healthz
2020-07-30T16:19:35Z [Probe Succeeded]  node=172_28_128_3.pensivevillani4966    checker=dns
2020-07-30T16:19:35Z [Node Healthy]     node=172_28_128_3.pensivevillani4966
2020-07-30T16:29:38Z [Probe Failed]     node=172_28_128_3.pensivevillani4966    checker=etcd-healthz
2020-07-30T16:29:38Z [Node Degraded]    node=172_28_128_3.pensivevillani4966
2020-07-30T16:30:06Z [Probe Succeeded]  node=172_28_128_3.pensivevillani4966    checker=etcd-healthz
2020-07-30T16:30:06Z [Node Healthy]     node=172_28_128_3.pensivevillani4966
2020-07-30T16:30:57Z [Node Degraded]    node=172_28_128_3.pensivevillani4966
2020-07-30T16:31:07Z [Probe Failed]     node=172_28_128_3.pensivevillani4966    checker=etcd-healthz
2020-07-30T16:32:05Z [Probe Succeeded]  node=172_28_128_3.pensivevillani4966    checker=etcd-healthz
2020-07-30T16:32:05Z [Node Healthy]     node=172_28_128_3.pensivevillani4966
2020-07-30T16:32:46Z [Probe Failed]     node=172_28_128_3.pensivevillani4966    checker=node-status
2020-07-30T16:32:46Z [Probe Failed]     node=172_28_128_3.pensivevillani4966    checker=etcd-healthz
2020-07-30T16:33:07Z [Probe Succeeded]  node=172_28_128_3.pensivevillani4966    checker=node-status
2020-07-30T16:34:05Z [Probe Succeeded]  node=172_28_128_3.pensivevillani4966    checker=etcd-healthz
2020-07-30T16:34:05Z [Node Healthy]     node=172_28_128_3.pensivevillani4966
```

It's also worth mentioning that from version 5.5.50 on, a few minor improvements
were also added to the `gravity status` output. To mention a few:

* `gravity status` now displays unhealthy critical system pods and some
  visibility into the controller status loop if the cluster is in a degraded
  state
* a new set of pre-upgrade checks were added to verify if previous upgrade
  operation succeeded or a failed plan was rolled back
* `gravity plan resume` now launches its execution in background by default,
  but a new `--block` option was added to resume in foreground and a different
  command `gravity plan --tail` was also introduced to track the plan progress
* it's possible to view/collect Gravity command line logs via `journalctl -t gravity-cli`


## Gravity Manual Upgrade Demo

The demo of an upgrade will focus on a manual upgrade, taking our time to go through the upgrade step by step and taking a look at what is happening. The same steps are completed doing an automatic upgrade, the difference is that an automatic upgrade has a process trying to make progress on the upgrade until it encounters an error.


## Exploring a Gravity Manual Upgrade

In order to get a better understand of how the upgrades work, we'll walkthrough a manual upgrade from start to finish. 

### Demo Setup

The demo of the manual upgrade will be on a simple 3 node cluster, with a minimal kubernetes application inside. These 3 nodes are masters within the cluster, and there are no workers. Upgrading a worker is the same as upgrading a master, but certain steps to do with being a master can be skipped. The manifest for these images can be found in the [upgrade/v1](./upgrade/v1/) and [upgrade/v2](./upgrade/v2/) directories.

```
root@kevin-test1:~/build# gravity status
Cluster name:           eagerbooth1735
Cluster status:         active
Application:            telekube, version 5.5.46
Gravity version:        5.5.46 (client) / 5.5.46 (server)
Join token:             2e3198930d9c
Periodic updates:       Not Configured
Remote support:         Not Configured
Last completed operation:
    * operation_expand (1936d32b-5e14-4471-9e0c-b4b2329a7bea)
      started:          Fri Jul 24 20:18 UTC (8 minutes ago)
      completed:        Fri Jul 24 20:20 UTC (6 minutes ago)
Cluster endpoints:
    * Authentication gateway:
        - 10.162.0.7:32009
        - 10.162.0.6:32009
        - 10.162.0.5:32009
    * Cluster management URL:
        - https://10.162.0.7:32009
        - https://10.162.0.6:32009
        - https://10.162.0.5:32009
Cluster nodes:
    Masters:
        * kevin-test1 (10.162.0.7, node)
            Status:             healthy
            Remote access:      online
        * kevin-test2 (10.162.0.6, node)
            Status:             healthy
            Remote access:      online
        * kevin-test3 (10.162.0.5, node)
            Status:             healthy
            Remote access:      online
```

Before we start the upgrade, let's take a moment to explore what this cluster looks like.

Gravity uses a packaging system to hold all of the artifacts used within the cluster. This is all of the configuration that get's generated to be distributed throughout the cluster (that isn't stored in etcd), but also cluster packages. These cluster packages are the containers and applications that are available to the cluster. This functionality is generally of internal relevance, and mostly abstracted away by the upgrade procedure.

There are two levels to this package store.
1. Cluster Wide -
The cluster wide package store is replicated between the master nodes within gravity-site. This is the authoritative location for state, that nodes can pull as required.
2. Node Local -
The node local package store, is a copy of packages needed by a node to operate. This is a local copy of a package from the cluster store.


#### Cluster Package Store

The cluster package store is how gravity stores the assets needed by the cluster to operate. These are the binaries, container images, and configuration that make up gravity.

```
root@kevin-test1:~/build# gravity --insecure package list --ops-url=https://gravity-site.kube-system.svc.cluster.local:3009

[eagerbooth1735]
----------------

* eagerbooth1735/cert-authority:0.0.1 12kB operation-id:efaede92-0182-4ac5-a336-f25a5c79bee7,purpose:ca
* eagerbooth1735/planet-10.162.0.5-secrets:5.5.47-11312 52kB advertise-ip:10.162.0.5,operation-id:1936d32b-5e14-4471-9e0c-b4b2329a7bea,purpose:planet-secrets
* eagerbooth1735/planet-10.162.0.6-secrets:5.5.47-11312 52kB operation-id:6d89ab1d-ead8-4197-afb4-9cb888f3275a,purpose:planet-secrets,advertise-ip:10.162.0.6
* eagerbooth1735/planet-10.162.0.7-secrets:5.5.47-11312 52kB advertise-ip:10.162.0.7,operation-id:efaede92-0182-4ac5-a336-f25a5c79bee7,purpose:planet-secrets
* eagerbooth1735/planet-config-1016205eagerbooth1735:5.5.47-11312 4.6kB advertise-ip:10.162.0.5,config-package-for:gravitational.io/planet:0.0.0,operation-id:1936d32b-5e14-4471-9e0c-b4b2329a7bea,purpose:planet-config
* eagerbooth1735/planet-config-1016206eagerbooth1735:5.5.47-11312 4.6kB advertise-ip:10.162.0.6,config-package-for:gravitational.io/planet:0.0.0,operation-id:6d89ab1d-ead8-4197-afb4-9cb888f3275a,purpose:planet-config
* eagerbooth1735/planet-config-1016207eagerbooth1735:5.5.47-11312 4.6kB advertise-ip:10.162.0.7,config-package-for:gravitational.io/planet:0.0.0,operation-id:efaede92-0182-4ac5-a336-f25a5c79bee7,purpose:planet-config
* eagerbooth1735/teleport-master-config-1016205eagerbooth1735:3.0.5 4.1kB operation-id:1936d32b-5e14-4471-9e0c-b4b2329a7bea,purpose:teleport-master-config,advertise-ip:10.162.0.5
* eagerbooth1735/teleport-master-config-1016206eagerbooth1735:3.0.5 4.1kB advertise-ip:10.162.0.6,operation-id:6d89ab1d-ead8-4197-afb4-9cb888f3275a,purpose:teleport-master-config
* eagerbooth1735/teleport-master-config-1016207eagerbooth1735:3.0.5 4.1kB advertise-ip:10.162.0.7,operation-id:efaede92-0182-4ac5-a336-f25a5c79bee7,purpose:teleport-master-config
* eagerbooth1735/teleport-node-config-1016205eagerbooth1735:3.0.5 4.1kB purpose:teleport-node-config,advertise-ip:10.162.0.5,config-package-for:gravitational.io/teleport:0.0.0,operation-id:1936d32b-5e14-4471-9e0c-b4b2329a7bea
* eagerbooth1735/teleport-node-config-1016206eagerbooth1735:3.0.5 4.1kB advertise-ip:10.162.0.6,config-package-for:gravitational.io/teleport:0.0.0,operation-id:6d89ab1d-ead8-4197-afb4-9cb888f3275a,purpose:teleport-node-config
* eagerbooth1735/teleport-node-config-1016207eagerbooth1735:3.0.5 4.1kB advertise-ip:10.162.0.7,config-package-for:gravitational.io/teleport:0.0.0,operation-id:efaede92-0182-4ac5-a336-f25a5c79bee7,purpose:teleport-node-config

[gravitational.io]
------------------

* gravitational.io/bandwagon:5.3.0 68MB
* gravitational.io/dns-app:0.3.0 69MB
* gravitational.io/gravity:5.5.46 101MB
* gravitational.io/kubernetes:5.5.46 5.3MB
* gravitational.io/logging-app:5.0.2 151MB
* gravitational.io/monitoring-app:5.5.16 219MB
* gravitational.io/planet:5.5.47-11312 490MB purpose:runtime
* gravitational.io/rbac-app:5.5.46 5.3MB
* gravitational.io/rpcagent-secrets:0.0.1 12kB purpose:rpc-secrets
* gravitational.io/site:5.5.46 86MB
* gravitational.io/telekube:5.5.46 182MB
* gravitational.io/teleport:3.0.5 32MB
* gravitational.io/tiller-app:5.5.2 32MB
* gravitational.io/web-assets:5.5.46 1.2MB
```

Notes:
1. There are two "namespace" of packages.
    1. `gravitational.io` are packages built by gravitational and shipped as updates. IE dns-app:0.3.0 is version 0.3.0 of the cluster DNS deployed within gravity.
    1. `<cluster_name>` are configuration packages for the particular cluster. These are configurations used for setting up nodes, like planet and teleport connectivity.

#### Node Package Store
The cluster package store works sort of like a docker registry server. It's a storage location for packages and blobs of data that can be pulled to another location. The node package store is the local copy of the packages on the node. This is similar to running `docker image ls` in that it shows the containers available on the node, and not the ones on the registry server.

```
root@kevin-test1:~/build# gravity --insecure package list

[eagerbooth1735]
----------------

* eagerbooth1735/cert-authority:0.0.1 12kB operation-id:efaede92-0182-4ac5-a336-f25a5c79bee7,purpose:ca
* eagerbooth1735/planet-10.162.0.7-secrets:5.5.47-11312 52kB advertise-ip:10.162.0.7,installed:installed,operation-id:efaede92-0182-4ac5-a336-f25a5c79bee7,purpose:planet-secrets
* eagerbooth1735/planet-config-1016207eagerbooth1735:5.5.47-11312 4.6kB advertise-ip:10.162.0.7,config-package-for:gravitational.io/planet:0.0.0,installed:installed,operation-id:efaede92-0182-4ac5-a336-f25a5c79bee7,purpose:planet-config
* eagerbooth1735/site-export:0.0.1 262kB operation-id:efaede92-0182-4ac5-a336-f25a5c79bee7,purpose:export
* eagerbooth1735/teleport-master-config-1016207eagerbooth1735:3.0.5 4.1kB advertise-ip:10.162.0.7,operation-id:efaede92-0182-4ac5-a336-f25a5c79bee7,purpose:teleport-master-config
* eagerbooth1735/teleport-node-config-1016207eagerbooth1735:3.0.5 4.1kB advertise-ip:10.162.0.7,config-package-for:gravitational.io/teleport:0.0.0,installed:installed,operation-id:efaede92-0182-4ac5-a336-f25a5c79bee7,purpose:teleport-node-config

[gravitational.io]
------------------

* gravitational.io/bandwagon:5.3.0 68MB
* gravitational.io/dns-app:0.3.0 69MB
* gravitational.io/gravity:5.5.46 101MB installed:installed
* gravitational.io/kubernetes:5.5.46 5.3MB
* gravitational.io/logging-app:5.0.2 151MB
* gravitational.io/monitoring-app:5.5.16 219MB
* gravitational.io/planet:5.5.47-11312 490MB purpose:runtime,installed:installed
* gravitational.io/rbac-app:5.5.46 5.3MB
* gravitational.io/site:5.5.46 86MB
* gravitational.io/telekube:5.5.46 182MB
* gravitational.io/teleport:3.0.5 32MB installed:installed
* gravitational.io/tiller-app:5.5.2 32MB
* gravitational.io/web-assets:5.5.46 1.2MB
```

### Extract an upgrade
Gravity ships cluster images as tar files, so we need to extract the tar file of our new version in order to interact with the upgrade.

- `mkdir upgrade`
- `tar -xvf telekube.tar -C upgrade`
- `cd upgrade`

```
root@kevin-test1:~/build# mkdir upgrade && tar -xvf telekube.tar -C upgrade && cd upgrade
gravity
app.yaml
install
upload
upgrade
run_preflight_checks
README
gravity.db
packages
packages/blobs
packages/blobs/174
packages/blobs/174/1743d0b87684236894e6b0deb88d55a2e6ad9558f9dce958ab6dd6d351dd1e40
packages/blobs/293
packages/blobs/293/293bfe5623efc11adb25e458c1b69ece3ee261581f606f9d65a9c4c501be0e49
packages/blobs/29c
packages/blobs/29c/29c517f0657fc3e275244cf911d9545bca9f3f477908838d56d2108d410250c1
packages/blobs/2e5
packages/blobs/2e5/2e519d04696b3ed3ad72e03db73ceac17a6a9d6c5461f79accd2bf256dceb1d5
packages/blobs/34e
packages/blobs/34e/34e801062ed253d0a5ff961729bb3187f53bcf5e99fe1f4470cf653cbc0cd430
packages/blobs/3f5
packages/blobs/3f5/3f577d4e1ac4b47f1ce0830ca5603e1ab39722cabf7845e42544da5d78756426
packages/blobs/413
packages/blobs/413/413e86cb6833d3bcbf3eb51082359b42535c2c88b9a7092292620b0f0df4dae0
packages/blobs/486
packages/blobs/486/48688213879a4c8f770b62f0fb5d97e12b5a5456c65a627ff64e7a4e84b9ff60
packages/blobs/692
packages/blobs/692/692b7dcc2d1b7cc66b2d0bebf7789d6aef6b880398b77fa6a5fa8483dac94242
packages/blobs/7e9
packages/blobs/7e9/7e912fb3c522d0647bb2580199f4a7a5a97d3d60536a1d3fbadd5069718b566a
packages/blobs/95d
packages/blobs/95d/95df3a84cb06ea1b75f080b0fc71b5a7b36905581010c27c69f16b7f42bbb890
packages/blobs/b54
packages/blobs/b54/b54cdd8cf1aadc5c4f016e754a487f983fcf2c7b8ac7bf12d33eff152d1af1dc
packages/blobs/e10
packages/blobs/e10/e1056f4e4cb205000d92f8c0ab7d535d5f13f358920fbe931be61f3469f6a902
packages/tmp
packages/unpacked
```
### Upload the package
Inside the gravity tarball is a script for uploading the contents of the local directory to the cluster package store. In effect, we take the assets we unzipped from the installer tarball, and sync the differences to the cluster.

```
root@kevin-test1:~/build# ./upload
Fri Jul 24 20:39:54 UTC Importing cluster image telekube v5.5.50-dev.9
Fri Jul 24 20:40:37 UTC Synchronizing application with Docker registry 10.162.0.7:5000
Fri Jul 24 20:41:05 UTC Synchronizing application with Docker registry 10.162.0.6:5000
Fri Jul 24 20:41:30 UTC Synchronizing application with Docker registry 10.162.0.5:5000
Fri Jul 24 20:41:52 UTC Verifying cluster health
Fri Jul 24 20:41:52 UTC Cluster image has been uploaded
```

Notes:
- This uploads the packages to the cluster package store.
- This uploads the containers to the docker registry running on every master.
- Waits for the cluster to become healthy, if the upload caused a performance issue within etcd.

The cluster package store will now have additional packages present:
```
root@kevin-test1:~/build# gravity --insecure package list --ops-url=https://gravity-site.kube-system.svc.cluster.local:3009

[eagerbooth1735]
----------------

* eagerbooth1735/cert-authority:0.0.1 12kB operation-id:efaede92-0182-4ac5-a336-f25a5c79bee7,purpose:ca
* eagerbooth1735/planet-10.162.0.5-secrets:5.5.47-11312 52kB purpose:planet-secrets,advertise-ip:10.162.0.5,operation-id:1936d32b-5e14-4471-9e0c-b4b2329a7bea
* eagerbooth1735/planet-10.162.0.6-secrets:5.5.47-11312 52kB operation-id:6d89ab1d-ead8-4197-afb4-9cb888f3275a,purpose:planet-secrets,advertise-ip:10.162.0.6
* eagerbooth1735/planet-10.162.0.7-secrets:5.5.47-11312 52kB advertise-ip:10.162.0.7,operation-id:efaede92-0182-4ac5-a336-f25a5c79bee7,purpose:planet-secrets
* eagerbooth1735/planet-config-1016205eagerbooth1735:5.5.47-11312 4.6kB config-package-for:gravitational.io/planet:0.0.0,operation-id:1936d32b-5e14-4471-9e0c-b4b2329a7bea,purpose:planet-config,advertise-ip:10.162.0.5
* eagerbooth1735/planet-config-1016206eagerbooth1735:5.5.47-11312 4.6kB advertise-ip:10.162.0.6,config-package-for:gravitational.io/planet:0.0.0,operation-id:6d89ab1d-ead8-4197-afb4-9cb888f3275a,purpose:planet-config
* eagerbooth1735/planet-config-1016207eagerbooth1735:5.5.47-11312 4.6kB purpose:planet-config,advertise-ip:10.162.0.7,config-package-for:gravitational.io/planet:0.0.0,operation-id:efaede92-0182-4ac5-a336-f25a5c79bee7
* eagerbooth1735/teleport-master-config-1016205eagerbooth1735:3.0.5 4.1kB advertise-ip:10.162.0.5,operation-id:1936d32b-5e14-4471-9e0c-b4b2329a7bea,purpose:teleport-master-config
* eagerbooth1735/teleport-master-config-1016206eagerbooth1735:3.0.5 4.1kB advertise-ip:10.162.0.6,operation-id:6d89ab1d-ead8-4197-afb4-9cb888f3275a,purpose:teleport-master-config
* eagerbooth1735/teleport-master-config-1016207eagerbooth1735:3.0.5 4.1kB advertise-ip:10.162.0.7,operation-id:efaede92-0182-4ac5-a336-f25a5c79bee7,purpose:teleport-master-config
* eagerbooth1735/teleport-node-config-1016205eagerbooth1735:3.0.5 4.1kB purpose:teleport-node-config,advertise-ip:10.162.0.5,config-package-for:gravitational.io/teleport:0.0.0,operation-id:1936d32b-5e14-4471-9e0c-b4b2329a7bea
* eagerbooth1735/teleport-node-config-1016206eagerbooth1735:3.0.5 4.1kB advertise-ip:10.162.0.6,config-package-for:gravitational.io/teleport:0.0.0,operation-id:6d89ab1d-ead8-4197-afb4-9cb888f3275a,purpose:teleport-node-config
* eagerbooth1735/teleport-node-config-1016207eagerbooth1735:3.0.5 4.1kB advertise-ip:10.162.0.7,config-package-for:gravitational.io/teleport:0.0.0,operation-id:efaede92-0182-4ac5-a336-f25a5c79bee7,purpose:teleport-node-config

[gravitational.io]
------------------

* gravitational.io/bandwagon:5.3.0 68MB
* gravitational.io/dns-app:0.3.0 69MB
* gravitational.io/gravity:5.5.46 101MB
* gravitational.io/gravity:5.5.50-dev.9 99MB
* gravitational.io/kubernetes:5.5.46 5.3MB
* gravitational.io/kubernetes:5.5.50-dev.9 5.2MB
* gravitational.io/logging-app:5.0.2 151MB
* gravitational.io/logging-app:5.0.3 158MB
* gravitational.io/monitoring-app:5.5.16 219MB
* gravitational.io/monitoring-app:5.5.21 228MB
* gravitational.io/planet:5.5.47-11312 490MB purpose:runtime
* gravitational.io/planet:5.5.54-11312 509MB purpose:runtime
* gravitational.io/rbac-app:5.5.46 5.3MB
* gravitational.io/rbac-app:5.5.50-dev.9 5.2MB
* gravitational.io/rpcagent-secrets:0.0.1 12kB purpose:rpc-secrets
* gravitational.io/site:5.5.46 86MB
* gravitational.io/site:5.5.50-dev.9 86MB
* gravitational.io/telekube:5.5.46 182MB
* gravitational.io/telekube:5.5.50-dev.9 182MB
* gravitational.io/teleport:3.0.5 32MB
* gravitational.io/tiller-app:5.5.2 32MB
* gravitational.io/web-assets:5.5.46 1.2MB
* gravitational.io/web-assets:5.5.50-dev.9 1.3MB
```

But if we look at the packages on our nodes package store, the new packages aren't shown.
```
root@kevin-test1:~/build# gravity --insecure package list

[eagerbooth1735]
----------------

* eagerbooth1735/cert-authority:0.0.1 12kB operation-id:efaede92-0182-4ac5-a336-f25a5c79bee7,purpose:ca
* eagerbooth1735/planet-10.162.0.7-secrets:5.5.47-11312 52kB advertise-ip:10.162.0.7,installed:installed,operation-id:efaede92-0182-4ac5-a336-f25a5c79bee7,purpose:planet-secrets
* eagerbooth1735/planet-config-1016207eagerbooth1735:5.5.47-11312 4.6kB advertise-ip:10.162.0.7,config-package-for:gravitational.io/planet:0.0.0,installed:installed,operation-id:efaede92-0182-4ac5-a336-f25a5c79bee7,purpose:planet-config
* eagerbooth1735/site-export:0.0.1 262kB operation-id:efaede92-0182-4ac5-a336-f25a5c79bee7,purpose:export
* eagerbooth1735/teleport-master-config-1016207eagerbooth1735:3.0.5 4.1kB advertise-ip:10.162.0.7,operation-id:efaede92-0182-4ac5-a336-f25a5c79bee7,purpose:teleport-master-config
* eagerbooth1735/teleport-node-config-1016207eagerbooth1735:3.0.5 4.1kB advertise-ip:10.162.0.7,config-package-for:gravitational.io/teleport:0.0.0,installed:installed,operation-id:efaede92-0182-4ac5-a336-f25a5c79bee7,purpose:teleport-node-config

[gravitational.io]
------------------

* gravitational.io/bandwagon:5.3.0 68MB
* gravitational.io/dns-app:0.3.0 69MB
* gravitational.io/gravity:5.5.46 101MB installed:installed
* gravitational.io/kubernetes:5.5.46 5.3MB
* gravitational.io/logging-app:5.0.2 151MB
* gravitational.io/monitoring-app:5.5.16 219MB
* gravitational.io/planet:5.5.47-11312 490MB purpose:runtime,installed:installed
* gravitational.io/rbac-app:5.5.46 5.3MB
* gravitational.io/site:5.5.46 86MB
* gravitational.io/telekube:5.5.46 182MB
* gravitational.io/teleport:3.0.5 32MB installed:installed
* gravitational.io/tiller-app:5.5.2 32MB
* gravitational.io/web-assets:5.5.46 1.2MB
```

This is because the node hasn't been upgraded yet. The required packages will be pulled to the node only when they are needed.

### Start a manual upgrade
To start a manual upgrade, we run the `./gravity upgrade --manual` command.

```
root@kevin-test1:~/build# sudo ./gravity upgrade --manual
Fri Jul 24 20:57:00 UTC Upgrading cluster from 5.5.46 to 5.5.50-dev.9
Fri Jul 24 20:57:01 UTC Deploying agents on cluster nodes
Fri Jul 24 20:57:03 UTC Deployed agent on kevin-test3 (10.162.0.5)
Fri Jul 24 20:57:03 UTC Deployed agent on kevin-test2 (10.162.0.6)
Fri Jul 24 20:57:03 UTC Deployed agent on kevin-test1 (10.162.0.7)
The operation has been created in manual mode.

See https://gravitational.com/gravity/docs/cluster/#managing-an-ongoing-operation for details on working with operation plan.
```

Notes:
- This will create an "upgrade operation`, using our operation and planning system to manage the change to the cluster and prevent other changes while the upgrade is in progress.
- The operation for upgrade, will try and upgrade to the latest version in the cluster store.
- The upgrade uses agents deployed to each node, to make the changes to the node for the upgrade. These agents are deployed automatically when starting the upgrade.
- The agents also allow upgrade steps to be triggered from other nodes. So you as a user don't need to jump between each node for every individual step.
- The agent will be deployed to `/var/lib/gravity/site/update/agent/gravity` so you have the new version binary on each host after agents are deployed.
  - Note: It can be important to use the correct binary version when interacting with an upgrade. Structural changes in the upgrade may only be present in a later version.


We can inspect the gravity-agent in systemd:
```
root@kevin-test1:~/build# systemctl status gravity-agent
● gravity-agent.service - Auto-generated service for the gravity-agent.service
   Loaded: loaded (/etc/systemd/system/gravity-agent.service; static; vendor preset: enabled)
   Active: activating (start) since Fri 2020-07-24 20:57:03 UTC; 1min 3s ago
 Main PID: 11832 (gravity)
    Tasks: 10
   Memory: 13.4M
      CPU: 197ms
   CGroup: /system.slice/gravity-agent.service
           └─11832 /var/lib/gravity/site/update/agent/gravity --debug agent run sync-plan

Jul 24 20:57:03 kevin-test1 systemd[1]: Starting Auto-generated service for the gravity-agent.service...
Jul 24 20:57:03 kevin-test1 gravity-cli[11832]: [RUNNING]: /var/lib/gravity/site/update/agent/gravity agent run --debug "sync-plan"
```

And we have the latest version of the gravity binary available on each node.
```
root@kevin-test1:~/build# /var/lib/gravity/site/update/agent/gravity version
Edition:        enterprise
Version:        5.5.50-dev.9
Git Commit:     5a8b0d835a0a5c7e049652f5318123567355dd5c
Helm Version:   v2.12


root@kevin-test1:~/build# gravity version
Edition:        enterprise
Version:        5.5.46
Git Commit:     2eb8006ca890143733bdca0d6a69b446f9b97088
Helm Version:   v2.12
```

### Stopping and Restarting the agents
While the agents should start and shutdown automatically by the upgrade, sometimes unexpected factors will cause the agents to not be running.
So the agents can be stopped and started as required.

Stop the agent:
```
root@kevin-test1:~# gravity agent shutdown
Sat Aug  1 22:42:19 UTC	Shutting down the agents
```

Start the agents:
```
root@kevin-test1:~# gravity agent deploy
Sat Aug  1 22:43:05 UTC	Deploying agents on the cluster nodes
Sat Aug  1 22:43:07 UTC	Deployed agent on kevin-test3 (10.162.0.5)
Sat Aug  1 22:43:07 UTC	Deployed agent on kevin-test2 (10.162.0.6)
Sat Aug  1 22:43:08 UTC	Deployed agent on kevin-test1 (10.162.0.7)
```

### Plans
Gravity uses a planning system to break up an upgrade into separate small steps to be executed.
These "phases" of the upgrade perform separate and individual actions to make progress on the upgrade.
The planning system creates the plan for the upgrade when the upgrade is triggered, inspecting the current state of the system,
and only includes the steps necessary to get the cluster to the latest version.

For example, if planet is already the latest version, none of the steps to rolling restart planet on the latest version will be included in the plan. It's not needed, as planet is already at the desired version.

We can view and interact with the plan using `gravity plan`.

```
root@kevin-test1:~/build# /var/lib/gravity/site/update/agent/gravity plan
Phase                          Description                                                State         Node           Requires                                      Updated
-----                          -----------                                                -----         ----           --------                                      -------
* init                         Initialize update operation                                Unstarted     -              -                                             -
  * kevin-test1                Initialize node "kevin-test1"                              Unstarted     10.162.0.7     -                                             -
  * kevin-test2                Initialize node "kevin-test2"                              Unstarted     10.162.0.6     -                                             -
  * kevin-test3                Initialize node "kevin-test3"                              Unstarted     10.162.0.5     -                                             -
* checks                       Run preflight checks                                       Unstarted     -              /init                                         -
* pre-update                   Run pre-update application hook                            Unstarted     -              /init,/checks                                 -
* bootstrap                    Bootstrap update operation on nodes                        Unstarted     -              /checks,/pre-update                           -
  * kevin-test1                Bootstrap node "kevin-test1"                               Unstarted     10.162.0.7     -                                             -
  * kevin-test2                Bootstrap node "kevin-test2"                               Unstarted     10.162.0.6     -                                             -
  * kevin-test3                Bootstrap node "kevin-test3"                               Unstarted     10.162.0.5     -                                             -
* coredns                      Provision CoreDNS resources                                Unstarted     -              /bootstrap                                    -
* masters                      Update master nodes                                        Unstarted     -              /coredns                                      -
  * kevin-test1                Update system software on master node "kevin-test1"        Unstarted     -              -                                             -
    * kubelet-permissions      Add permissions to kubelet on "kevin-test1"                Unstarted     -              -                                             -
    * stepdown-kevin-test1     Step down "kevin-test1" as Kubernetes leader               Unstarted     -              /masters/kevin-test1/kubelet-permissions      -
    * drain                    Drain node "kevin-test1"                                   Unstarted     10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     -
    * system-upgrade           Update system software on node "kevin-test1"               Unstarted     10.162.0.7     /masters/kevin-test1/drain                    -
    * taint                    Taint node "kevin-test1"                                   Unstarted     10.162.0.7     /masters/kevin-test1/system-upgrade           -
    * uncordon                 Uncordon node "kevin-test1"                                Unstarted     10.162.0.7     /masters/kevin-test1/taint                    -
    * untaint                  Remove taint from node "kevin-test1"                       Unstarted     10.162.0.7     /masters/kevin-test1/uncordon                 -
  * elect-kevin-test1          Make node "kevin-test1" Kubernetes leader                  Unstarted     -              /masters/kevin-test1                          -
  * kevin-test2                Update system software on master node "kevin-test2"        Unstarted     -              /masters/elect-kevin-test1                    -
    * drain                    Drain node "kevin-test2"                                   Unstarted     10.162.0.7     -                                             -
    * system-upgrade           Update system software on node "kevin-test2"               Unstarted     10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node "kevin-test2"                                   Unstarted     10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node "kevin-test2"                                Unstarted     10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on "kevin-test2"            Unstarted     10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node "kevin-test2"                       Unstarted     10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node "kevin-test2"               Unstarted     -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node "kevin-test3"        Unstarted     -              /masters/kevin-test2                          -
    * drain                    Drain node "kevin-test3"                                   Unstarted     10.162.0.7     -                                             -
    * system-upgrade           Update system software on node "kevin-test3"               Unstarted     10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node "kevin-test3"                                   Unstarted     10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node "kevin-test3"                                Unstarted     10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on "kevin-test3"            Unstarted     10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node "kevin-test3"                       Unstarted     10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node "kevin-test3"               Unstarted     -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted     -              -                                             -
  * backup                     Backup etcd data                                           Unstarted     -              -                                             -
    * kevin-test1              Backup etcd on node "kevin-test1"                          Unstarted     -              -                                             -
    * kevin-test2              Backup etcd on node "kevin-test2"                          Unstarted     -              -                                             -
    * kevin-test3              Backup etcd on node "kevin-test3"                          Unstarted     -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted     -              -                                             -
    * kevin-test1              Shutdown etcd on node "kevin-test1"                        Unstarted     -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node "kevin-test2"                        Unstarted     -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node "kevin-test3"                        Unstarted     -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted     -              -                                             -
    * kevin-test1              Upgrade etcd on node "kevin-test1"                         Unstarted     -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node "kevin-test2"                         Unstarted     -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node "kevin-test3"                         Unstarted     -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted     -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted     -              -                                             -
    * kevin-test1              Restart etcd on node "kevin-test1"                         Unstarted     -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node "kevin-test2"                         Unstarted     -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node "kevin-test3"                         Unstarted     -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted     -              -                                             -
* config                       Update system configuration on nodes                       Unstarted     -              /etcd                                         -
  * kevin-test1                Update system configuration on node "kevin-test1"          Unstarted     -              -                                             -
  * kevin-test2                Update system configuration on node "kevin-test2"          Unstarted     -              -                                             -
  * kevin-test3                Update system configuration on node "kevin-test3"          Unstarted     -              -                                             -
* runtime                      Update application runtime                                 Unstarted     -              /config                                       -
  * rbac-app                   Update system application "rbac-app" to 5.5.50-dev.9       Unstarted     -              -                                             -
  * logging-app                Update system application "logging-app" to 5.0.3           Unstarted     -              /runtime/rbac-app                             -
  * monitoring-app             Update system application "monitoring-app" to 5.5.21       Unstarted     -              /runtime/logging-app                          -
  * site                       Update system application "site" to 5.5.50-dev.9           Unstarted     -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application "kubernetes" to 5.5.50-dev.9     Unstarted     -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted     -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted     -              -                                             -
* app                          Update installed application                               Unstarted     -              /migration                                    -
  * telekube                   Update application "telekube" to 5.5.50-dev.9              Unstarted     -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted     -              /app                                          -
  * kevin-test1                Clean up node "kevin-test1"                                Unstarted     -              -                                             -
  * kevin-test2                Clean up node "kevin-test2"                                Unstarted     -              -                                             -
  * kevin-test3                Clean up node "kevin-test3"                                Unstarted     -              -                                             -
```

### Phase States
Our plan has been built as a set of phases, where some phases are dependent on other phases. This creates ordering in our upgrade, so steps are not run, when previous steps are incomplete.

So we track and list the state of a phase when viewing the plan.

#### Unstarted
An Unstarted phase is a phase that hasn't been requested to run yet.

#### In Progress
An In Progress phase is a phase that is currently being executed or in rare circumstances has crashed.
When an agent starts executing a phase, it will set the state to In Progress, until the execution has completed.
If the process running the phase exits unexpectedly, such as a panic in the process or `kill -9`, the state will remain "In Progress" forever.

Note: When manually interacting with an upgrade, be careful that an In Progress phase may be trying to interact with the system at the same time.
Two processes trying to change the system state at the same time could lead to unexpected results.

#### Completed
A Completed phase indicates the phase has been executed and completed successfully.

#### Failed
A Failed phase indicates some sort of error occurred while executing the phase.

Automatic upgrades upon encountering a Failed phase, will stop attempting to interact with the upgrade. Allowing an admin to choose how to proceed.

#### Rolled Back
A Failed, In Progress, or Complete phase can be rolled back, to undo the changes to the system made by the upgrade.

### Phase Paths
The planning system organizes phases into a hierarchy, so manually running phases requires taking the plan structure and turning it into a path.

If we look at a portion of our plan, we can see the hierarchy based on the indentation:

```
root@kevin-test1:~/build# /var/lib/gravity/site/update/agent/gravity plan
Phase                          Description                                                State         Node           Requires                                      Updated
-----                          -----------                                                -----         ----           --------                                      -------
* init                         Initialize update operation                                Unstarted     -              -                                             -
  * kevin-test1                Initialize node "kevin-test1"                              Unstarted     10.162.0.7     -                                             -
  * kevin-test2                Initialize node "kevin-test2"                              Unstarted     10.162.0.6     -                                             -
  * kevin-test3                Initialize node "kevin-test3"                              Unstarted     10.162.0.5     -                                             -
```

To manually run the `init` phase on node `kevin-test1` we build a path of `/init/kevin-test1`

### Continuing our Manual Upgrade

#### Init
The first step in the upgrade process, is we initialize and prepare each node to accept the upgrade.

```
root@kevin-test1:~/build# ./gravity --debug plan execute --phase /init/kevin-test1 2>&1 | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'

...

2020-08-02T00:19:06Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/init/kevin-test1, State=in_progress) cluster/engine.go:288
2020-08-02T00:19:07Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
→ init                         Initialize update operation                                In Progress     -              -                                             Sun Aug  2 00:19 UTC
  → kevin-test1                Initialize node \"kevin-test1\"                              In Progress     10.162.0.7     -                                             Sun Aug  2 00:19 UTC
  * kevin-test2                Initialize node \"kevin-test2\"                              Unstarted       10.162.0.6     -                                             -
  * kevin-test3                Initialize node \"kevin-test3\"                              Unstarted       10.162.0.5     -                                             -
* checks                       Run preflight checks                                       Unstarted       -              /init                                         -
* pre-update                   Run pre-update application hook                            Unstarted       -              /init,/checks                                 -
* bootstrap                    Bootstrap update operation on nodes                        Unstarted       -              /checks,/pre-update                           -
  * kevin-test1                Bootstrap node \"kevin-test1\"                               Unstarted       10.162.0.7     -                                             -
  * kevin-test2                Bootstrap node \"kevin-test2\"                               Unstarted       10.162.0.6     -                                             -
  * kevin-test3                Bootstrap node \"kevin-test3\"                               Unstarted       10.162.0.5     -                                             -
* coredns                      Provision CoreDNS resources                                Unstarted       -              /bootstrap                                    -
* masters                      Update master nodes                                        Unstarted       -              /coredns                                      -
  * kevin-test1                Update system software on master node \"kevin-test1\"        Unstarted       -              -                                             -
    * kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Unstarted       -              -                                             -
    * stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Unstarted       -              /masters/kevin-test1/kubelet-permissions      -
    * drain                    Drain node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     -
    * system-upgrade           Update system software on node \"kevin-test1\"               Unstarted       10.162.0.7     /masters/kevin-test1/drain                    -
    * taint                    Taint node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test1\"                                Unstarted       10.162.0.7     /masters/kevin-test1/taint                    -
    * untaint                  Remove taint from node \"kevin-test1\"                       Unstarted       10.162.0.7     /masters/kevin-test1/uncordon                 -
  * elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Unstarted       -              /masters/kevin-test1                          -
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted       -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted       10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted       10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted       10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted       10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted       10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted       -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted       -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted       10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted       10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted       10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted       10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted       10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted       -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted       -              -                                             -
  * backup                     Backup etcd data                                           Unstarted       -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted       -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted       -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted       -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted       -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
2020-08-02T00:19:07Z INFO             Executing phase: /init/kevin-test1. phase:/init/kevin-test1 fsm/logger.go:61
2020-08-02T00:19:07Z INFO             Create admin agent user. phase:/init/kevin-test1 fsm/logger.go:61
2020-08-02T00:19:07Z INFO             Update RPC credentials phase:/init/kevin-test1 fsm/logger.go:61
2020-08-02T00:19:07Z INFO             Backup RPC credentials phase:/init/kevin-test1 fsm/logger.go:61
2020-08-02T00:19:07Z DEBU             Dial. addr:gravity-site.kube-system.svc.cluster.local:3009 network:tcp httplib/client.go:225
2020-08-02T00:19:07Z DEBU             Resolve gravity-site.kube-system.svc.cluster.local took 323.698µs. utils/dns.go:47
2020-08-02T00:19:07Z DEBU             Resolved gravity-site.kube-system.svc.cluster.local to 10.100.84.247. utils/dns.go:54
2020-08-02T00:19:07Z DEBU             Dial. host-port:10.100.84.247:3009 httplib/client.go:263
2020-08-02T00:19:07Z INFO             2020/08/02 00:19:07 [INFO] generate received request runtime/asm_amd64.s:1337
2020-08-02T00:19:07Z INFO             2020/08/02 00:19:07 [INFO] received CSR runtime/asm_amd64.s:1337
2020-08-02T00:19:07Z INFO             2020/08/02 00:19:07 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-08-02T00:19:07Z INFO             2020/08/02 00:19:07 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-08-02T00:19:07Z INFO             2020/08/02 00:19:07 [INFO] signed certificate with serial number 60977217533118992352268033205126950708199348580 runtime/asm_amd64.s:1337
2020-08-02T00:19:07Z INFO             2020/08/02 00:19:07 [INFO] generate received request runtime/asm_amd64.s:1337
2020-08-02T00:19:07Z INFO             2020/08/02 00:19:07 [INFO] received CSR runtime/asm_amd64.s:1337
2020-08-02T00:19:07Z INFO             2020/08/02 00:19:07 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-08-02T00:19:08Z INFO             2020/08/02 00:19:08 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-08-02T00:19:08Z INFO             2020/08/02 00:19:08 [INFO] signed certificate with serial number 569002928142941238789726498941620346377289655995 runtime/asm_amd64.s:1337
2020-08-02T00:19:08Z INFO             2020/08/02 00:19:08 [INFO] generate received request runtime/asm_amd64.s:1337
2020-08-02T00:19:08Z INFO             2020/08/02 00:19:08 [INFO] received CSR runtime/asm_amd64.s:1337
2020-08-02T00:19:08Z INFO             2020/08/02 00:19:08 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-08-02T00:19:08Z INFO             2020/08/02 00:19:08 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-08-02T00:19:08Z INFO             2020/08/02 00:19:08 [INFO] signed certificate with serial number 460293087439813462470574250555392584130792440470 runtime/asm_amd64.s:1337
2020-08-02T00:19:08Z INFO             Update RPC credentials. package:gravitational.io/rpcagent-secrets:0.0.1 phase:/init/kevin-test1 phases/init.go:227
2020-08-02T00:19:08Z INFO             Update cluster roles. phase:/init/kevin-test1 fsm/logger.go:61
2020-08-02T00:19:08Z INFO             Update cluster DNS configuration. phase:/init/kevin-test1 fsm/logger.go:61
2020-08-02T00:19:08Z INFO             update package labels gravitational.io/planet:5.5.47-11312 (+map[installed:installed purpose:runtime] -[]) phase:/init/kevin-test1 fsm/logger.go:61
2020-08-02T00:19:08Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/init/kevin-test1, State=completed) cluster/engine.go:288
2020-08-02T00:19:09Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
→ init                         Initialize update operation                                In Progress     -              -                                             Sun Aug  2 00:19 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Sun Aug  2 00:19 UTC
  * kevin-test2                Initialize node \"kevin-test2\"                              Unstarted       10.162.0.6     -                                             -
  * kevin-test3                Initialize node \"kevin-test3\"                              Unstarted       10.162.0.5     -                                             -
* checks                       Run preflight checks                                       Unstarted       -              /init                                         -
* pre-update                   Run pre-update application hook                            Unstarted       -              /init,/checks                                 -
* bootstrap                    Bootstrap update operation on nodes                        Unstarted       -              /checks,/pre-update                           -
  * kevin-test1                Bootstrap node \"kevin-test1\"                               Unstarted       10.162.0.7     -                                             -
  * kevin-test2                Bootstrap node \"kevin-test2\"                               Unstarted       10.162.0.6     -                                             -
  * kevin-test3                Bootstrap node \"kevin-test3\"                               Unstarted       10.162.0.5     -                                             -
* coredns                      Provision CoreDNS resources                                Unstarted       -              /bootstrap                                    -
* masters                      Update master nodes                                        Unstarted       -              /coredns                                      -
  * kevin-test1                Update system software on master node \"kevin-test1\"        Unstarted       -              -                                             -
    * kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Unstarted       -              -                                             -
    * stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Unstarted       -              /masters/kevin-test1/kubelet-permissions      -
    * drain                    Drain node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     -
    * system-upgrade           Update system software on node \"kevin-test1\"               Unstarted       10.162.0.7     /masters/kevin-test1/drain                    -
    * taint                    Taint node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test1\"                                Unstarted       10.162.0.7     /masters/kevin-test1/taint                    -
    * untaint                  Remove taint from node \"kevin-test1\"                       Unstarted       10.162.0.7     /masters/kevin-test1/uncordon                 -
  * elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Unstarted       -              /masters/kevin-test1                          -
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted       -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted       10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted       10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted       10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted       10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted       10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted       -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted       -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted       10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted       10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted       10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted       10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted       10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted       -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted       -              -                                             -
  * backup                     Backup etcd data                                           Unstarted       -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted       -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted       -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted       -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted       -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
Sun Aug  2 00:19:09 UTC	Executing phase "/init/kevin-test1" finished in 3 seconds
```

Notes:
- Removes legacy update directories if present
- Creates an admin agent user if this cluster doesn't have one (upgrades from legacy versions)
- Creates the Default Service User on host if needed and not overriden by the installer
- Updates RPC Credentials (The credentials used to coordinate the upgrade)
- Updates any cluster roles that are changing with the new version
- Updates DNS parameters used internally within gravity
- Updated Docker configuration within the cluster



#### Rolling Back a Phase
Now that we've made some progress in our upgrade, if we encounter a problem, we can rollback our upgrade.

```
root@kevin-test1:~/build# ./gravity --debug plan rollback --phase /init/kevin-test1 2>&1 | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'

...

2020-08-02T03:30:44Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
→ init                         Initialize update operation                                In Progress     -              -                                             Sun Aug  2 03:30 UTC
  → kevin-test1                Initialize node \"kevin-test1\"                              In Progress     10.162.0.7     -                                             Sun Aug  2 03:30 UTC
  * kevin-test2                Initialize node \"kevin-test2\"                              Unstarted       10.162.0.6     -                                             -
  * kevin-test3                Initialize node \"kevin-test3\"                              Unstarted       10.162.0.5     -                                             -
* checks                       Run preflight checks                                       Unstarted       -              /init                                         -
* pre-update                   Run pre-update application hook                            Unstarted       -              /init,/checks                                 -
* bootstrap                    Bootstrap update operation on nodes                        Unstarted       -              /checks,/pre-update                           -
  * kevin-test1                Bootstrap node \"kevin-test1\"                               Unstarted       10.162.0.7     -                                             -
  * kevin-test2                Bootstrap node \"kevin-test2\"                               Unstarted       10.162.0.6     -                                             -
  * kevin-test3                Bootstrap node \"kevin-test3\"                               Unstarted       10.162.0.5     -                                             -
* coredns                      Provision CoreDNS resources                                Unstarted       -              /bootstrap                                    -
* masters                      Update master nodes                                        Unstarted       -              /coredns                                      -
  * kevin-test1                Update system software on master node \"kevin-test1\"        Unstarted       -              -                                             -
    * kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Unstarted       -              -                                             -
    * stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Unstarted       -              /masters/kevin-test1/kubelet-permissions      -
    * drain                    Drain node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     -
    * system-upgrade           Update system software on node \"kevin-test1\"               Unstarted       10.162.0.7     /masters/kevin-test1/drain                    -
    * taint                    Taint node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test1\"                                Unstarted       10.162.0.7     /masters/kevin-test1/taint                    -
    * untaint                  Remove taint from node \"kevin-test1\"                       Unstarted       10.162.0.7     /masters/kevin-test1/uncordon                 -
  * elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Unstarted       -              /masters/kevin-test1                          -
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted       -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted       10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted       10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted       10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted       10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted       10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted       -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted       -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted       10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted       10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted       10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted       10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted       10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted       -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted       -              -                                             -
  * backup                     Backup etcd data                                           Unstarted       -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted       -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted       -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted       -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted       -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
2020-08-02T03:30:44Z INFO             Restore RPC credentials from backup phase:/init/kevin-test1 fsm/logger.go:61
2020-08-02T03:30:44Z DEBU             Dial. addr:gravity-site.kube-system.svc.cluster.local:3009 network:tcp httplib/client.go:225
2020-08-02T03:30:44Z DEBU             Resolve gravity-site.kube-system.svc.cluster.local took 508.016µs. utils/dns.go:47
2020-08-02T03:30:44Z DEBU             Resolved gravity-site.kube-system.svc.cluster.local to 10.100.84.247. utils/dns.go:54
2020-08-02T03:30:44Z DEBU             Dial. host-port:10.100.84.247:3009 httplib/client.go:263
2020-08-02T03:30:44Z DEBU             Dial. addr:gravity-site.kube-system.svc.cluster.local:3009 network:tcp httplib/client.go:225
2020-08-02T03:30:44Z DEBU             Resolve gravity-site.kube-system.svc.cluster.local took 234.14µs. utils/dns.go:47
2020-08-02T03:30:44Z DEBU             Resolved gravity-site.kube-system.svc.cluster.local to 10.100.84.247. utils/dns.go:54
2020-08-02T03:30:44Z DEBU             Dial. host-port:10.100.84.247:3009 httplib/client.go:263
2020-08-02T03:30:44Z INFO             Removing configured packages. phase:/init/kevin-test1 fsm/logger.go:61
2020-08-02T03:30:44Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/init/kevin-test1, State=rolled_back) cluster/engine.go:288
2020-08-02T03:30:44Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
× init                         Initialize update operation                                Failed          -              -                                             Sun Aug  2 03:30 UTC
  ⤺ kevin-test1                Initialize node \"kevin-test1\"                              Rolled Back     10.162.0.7     -                                             Sun Aug  2 03:30 UTC
  * kevin-test2                Initialize node \"kevin-test2\"                              Unstarted       10.162.0.6     -                                             -
  * kevin-test3                Initialize node \"kevin-test3\"                              Unstarted       10.162.0.5     -                                             -
* checks                       Run preflight checks                                       Unstarted       -              /init                                         -
* pre-update                   Run pre-update application hook                            Unstarted       -              /init,/checks                                 -
* bootstrap                    Bootstrap update operation on nodes                        Unstarted       -              /checks,/pre-update                           -
  * kevin-test1                Bootstrap node \"kevin-test1\"                               Unstarted       10.162.0.7     -                                             -
  * kevin-test2                Bootstrap node \"kevin-test2\"                               Unstarted       10.162.0.6     -                                             -
  * kevin-test3                Bootstrap node \"kevin-test3\"                               Unstarted       10.162.0.5     -                                             -
* coredns                      Provision CoreDNS resources                                Unstarted       -              /bootstrap                                    -
* masters                      Update master nodes                                        Unstarted       -              /coredns                                      -
  * kevin-test1                Update system software on master node \"kevin-test1\"        Unstarted       -              -                                             -
    * kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Unstarted       -              -                                             -
    * stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Unstarted       -              /masters/kevin-test1/kubelet-permissions      -
    * drain                    Drain node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     -
    * system-upgrade           Update system software on node \"kevin-test1\"               Unstarted       10.162.0.7     /masters/kevin-test1/drain                    -
    * taint                    Taint node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test1\"                                Unstarted       10.162.0.7     /masters/kevin-test1/taint                    -
    * untaint                  Remove taint from node \"kevin-test1\"                       Unstarted       10.162.0.7     /masters/kevin-test1/uncordon                 -
  * elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Unstarted       -              /masters/kevin-test1                          -
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted       -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted       10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted       10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted       10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted       10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted       10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted       -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted       -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted       10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted       10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted       10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted       10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted       10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted       -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted       -              -                                             -
  * backup                     Backup etcd data                                           Unstarted       -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted       -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted       -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted       -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted       -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
Sun Aug  2 03:30:44 UTC	Rolling back phase "/init/kevin-test1" finished in 1 second
```

#### Committing an Upgrade
Once all phases have been completed, or all phases have been rolled back, the upgrade needs to be committed / completed, in order to unlock the cluster. Use `gravity plan complete` to commit the upgrade.

```
root@kevin-test1:~/build# ./gravity status
Cluster name:		festivebrown4906
Cluster status:		updating
Application:		telekube, version 5.5.46
Gravity version:	5.5.50-dev.9 (client) / 5.5.46 (server)
Join token:		ab6e9d3eb2bf
Active operations:
    * operation_update (545e8faa-a249-4b79-9e4f-8035b0dcfcba)
      started:	Sun Aug  2 03:34 UTC (9 seconds ago)
      use 'gravity plan --operation-id=545e8faa-a249-4b79-9e4f-8035b0dcfcba' to check operation status
Last completed operation:
    * operation_update (0550a0bb-7c9f-4949-b5b2-e8c0ae27c458)
      started:	Sun Aug  2 00:18 UTC (3 hours ago)
      failed:	Sun Aug  2 03:32 UTC (2 minutes ago)
Cluster endpoints:
    * Authentication gateway:
        - 10.162.0.7:32009
        - 10.162.0.6:32009
        - 10.162.0.5:32009
    * Cluster management URL:
        - https://10.162.0.7:32009
        - https://10.162.0.6:32009
        - https://10.162.0.5:32009
Cluster nodes:
    Masters:
        * kevin-test1 (10.162.0.7, node)
            Status:		healthy
            Remote access:	online
        * kevin-test2 (10.162.0.6, node)
            Status:		healthy
            Remote access:	online
        * kevin-test3 (10.162.0.5, node)
            Status:		healthy
            Remote access:	online


root@kevin-test1:~/build# ./gravity plan complete


root@kevin-test1:~/build# ./gravity status
Cluster name:		festivebrown4906
Cluster status:		active
Application:		telekube, version 5.5.46
Gravity version:	5.5.50-dev.9 (client) / 5.5.46 (server)
Join token:		ab6e9d3eb2bf
Last completed operation:
    * operation_update (545e8faa-a249-4b79-9e4f-8035b0dcfcba)
      started:	Sun Aug  2 03:34 UTC (15 seconds ago)
      failed:	Sun Aug  2 03:34 UTC (2 seconds ago)
Cluster endpoints:
    * Authentication gateway:
        - 10.162.0.7:32009
        - 10.162.0.6:32009
        - 10.162.0.5:32009
    * Cluster management URL:
        - https://10.162.0.7:32009
        - https://10.162.0.6:32009
        - https://10.162.0.5:32009
Cluster nodes:
    Masters:
        * kevin-test1 (10.162.0.7, node)
            Status:		healthy
            Remote access:	online
        * kevin-test2 (10.162.0.6, node)
            Status:		healthy
            Remote access:	online
        * kevin-test3 (10.162.0.5, node)
            Status:		healthy
            Remote access:	online
```


#### Start a New Upgrade

```
root@kevin-test1:~/build# sudo ./gravity upgrade --manual
Sun Aug  2 03:36:22 UTC	Upgrading cluster from 5.5.46 to 5.5.50-dev.9
Sun Aug  2 03:36:22 UTC	Deploying agents on cluster nodes
Sun Aug  2 03:36:26 UTC	Deployed agent on kevin-test3 (10.162.0.5)
Sun Aug  2 03:36:26 UTC	Deployed agent on kevin-test2 (10.162.0.6)
Sun Aug  2 03:36:26 UTC	Deployed agent on kevin-test1 (10.162.0.7)
The operation has been created in manual mode.

See https://gravitational.com/gravity/docs/cluster/#managing-an-ongoing-operation for details on working with operation plan.
```

#### Running multiple phases
Instead of running phases individually, it's possible to run groups of phases together, by targetting the parent of a group phases.

```
root@kevin-test1:~/build# ./gravity plan
Phase                          Description                                                State         Node           Requires                                      Updated
-----                          -----------                                                -----         ----           --------                                      -------
* init                         Initialize update operation                                Unstarted     -              -                                             -
  * kevin-test1                Initialize node "kevin-test1"                              Unstarted     10.162.0.7     -                                             -
  * kevin-test2                Initialize node "kevin-test2"                              Unstarted     10.162.0.6     -                                             -
  * kevin-test3                Initialize node "kevin-test3"                              Unstarted     10.162.0.5     -                                             -
* checks                       Run preflight checks                                       Unstarted     -              /init                                         -
```

In order to run all init phases, we can target the `/init` phase, and all subphases will be executed.


```
root@kevin-test1:~/build# ./gravity plan execute --phase /init
Sun Aug  2 03:40:04 UTC	Executing "/init/kevin-test1" locally
Sun Aug  2 03:40:05 UTC	Executing "/init/kevin-test2" on remote node kevin-test2
Sun Aug  2 03:40:07 UTC	Executing "/init/kevin-test3" on remote node kevin-test3
Sun Aug  2 03:40:09 UTC	Executing phase "/init" finished in 5 seconds
```

Alternatively, we can run `./gravity plan execute --phase /` to run the entire upgrade through to completion or `./gravity plan resume`, which does the same thing.

#### Checks
The checks phase is used to check that the cluster meets any new requirements defined by the application.

```
root@kevin-test1:~/build# ./gravity --debug plan execute --phase /checks 2>&1 | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'

...

2020-07-31T06:34:11Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Fri Jul 31 06:32 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Fri Jul 31 06:32 UTC
→ checks                       Run preflight checks                                       In Progress     -              /init                                         Fri Jul 31 06:34 UTC
* pre-update                   Run pre-update application hook                            Unstarted       -              /init,/checks                                 -
* bootstrap                    Bootstrap update operation on nodes                        Unstarted       -              /checks,/pre-update                           -
  * kevin-test1                Bootstrap node \"kevin-test1\"                               Unstarted       10.162.0.7     -                                             -
  * kevin-test2                Bootstrap node \"kevin-test2\"                               Unstarted       10.162.0.6     -                                             -
  * kevin-test3                Bootstrap node \"kevin-test3\"                               Unstarted       10.162.0.5     -                                             -
* coredns                      Provision CoreDNS resources                                Unstarted       -              /bootstrap                                    -
* masters                      Update master nodes                                        Unstarted       -              /coredns                                      -
  * kevin-test1                Update system software on master node \"kevin-test1\"        Unstarted       -              -                                             -
    * kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Unstarted       -              -                                             -
    * stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Unstarted       -              /masters/kevin-test1/kubelet-permissions      -
    * drain                    Drain node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     -
    * system-upgrade           Update system software on node \"kevin-test1\"               Unstarted       10.162.0.7     /masters/kevin-test1/drain                    -
    * taint                    Taint node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test1\"                                Unstarted       10.162.0.7     /masters/kevin-test1/taint                    -
    * untaint                  Remove taint from node \"kevin-test1\"                       Unstarted       10.162.0.7     /masters/kevin-test1/uncordon                 -
  * elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Unstarted       -              /masters/kevin-test1                          -
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted       -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted       10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted       10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted       10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted       10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted       10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted       -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted       -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted       10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted       10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted       10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted       10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted       10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted       -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted       -              -                                             -
  * backup                     Backup etcd data                                           Unstarted       -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted       -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted       -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted       -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted       -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
2020-07-31T06:34:11Z INFO             Executing phase: /checks. phase:/checks fsm/logger.go:61
2020-07-31T06:34:11Z INFO             Executing preflight checks on node(addr=10.162.0.7, hostname=kevin-test1, role=node, cluster_role=master),node(addr=10.162.0.6, hostname=kevin-test2, role=node, cluster_role=master),node(addr=10.162.0.5, hostname=kevin-test3, role=node, cluster_role=master). phase:/checks fsm/logger.go:61
INFO: 2020/07/31 06:34:11 parsed scheme: ""
INFO: 2020/07/31 06:34:11 scheme "" not registered, fallback to default scheme
INFO: 2020/07/31 06:34:11 ccResolverWrapper: sending new addresses to cc: [{10.162.0.7:3012 0  <nil>}]
INFO: 2020/07/31 06:34:11 ClientConn switching balancer to "pick_first"
INFO: 2020/07/31 06:34:11 pickfirstBalancer: HandleSubConnStateChange: 0xc000fe4380, CONNECTING
INFO: 2020/07/31 06:34:11 pickfirstBalancer: HandleSubConnStateChange: 0xc000fe4380, READY
INFO: 2020/07/31 06:34:11 parsed scheme: ""
INFO: 2020/07/31 06:34:11 scheme "" not registered, fallback to default scheme
INFO: 2020/07/31 06:34:11 ccResolverWrapper: sending new addresses to cc: [{10.162.0.6:3012 0  <nil>}]
INFO: 2020/07/31 06:34:11 ClientConn switching balancer to "pick_first"
INFO: 2020/07/31 06:34:11 pickfirstBalancer: HandleSubConnStateChange: 0xc0008c0150, CONNECTING
INFO: 2020/07/31 06:34:11 pickfirstBalancer: HandleSubConnStateChange: 0xc0008c0150, READY
INFO: 2020/07/31 06:34:11 parsed scheme: ""
INFO: 2020/07/31 06:34:11 scheme "" not registered, fallback to default scheme
INFO: 2020/07/31 06:34:11 ccResolverWrapper: sending new addresses to cc: [{10.162.0.5:3012 0  <nil>}]
INFO: 2020/07/31 06:34:11 ClientConn switching balancer to "pick_first"
INFO: 2020/07/31 06:34:11 pickfirstBalancer: HandleSubConnStateChange: 0xc000928af0, CONNECTING
INFO: 2020/07/31 06:34:11 pickfirstBalancer: HandleSubConnStateChange: 0xc000928af0, READY
2020-07-31T06:34:11Z INFO [CHECKS]    Server "kevin-test1" has required packages installed: []. checks/checks.go:899
2020-07-31T06:34:11Z DEBU [RPC]       Run ["touch" "tmpcheck.25fea5f8-64bc-4e34-9cbf-78b101631c8f"]. seq:1 client/agent.go:159
2020-07-31T06:34:11Z DEBU [RPC]       Completed. exit:0 seq:1 client/agent.go:167
2020-07-31T06:34:11Z DEBU [RPC]       Run ["rm" "tmpcheck.25fea5f8-64bc-4e34-9cbf-78b101631c8f"]. seq:1 client/agent.go:159
2020-07-31T06:34:11Z DEBU [RPC]       Completed. exit:0 seq:1 client/agent.go:167
2020-07-31T06:34:11Z INFO [CHECKS]    Server "kevin-test1" passed temp directory check: . checks/checks.go:560
2020-07-31T06:34:11Z DEBU [RPC]       Run ["dd" "if=/dev/zero" "of=/testfile" "bs=100K" "count=1024" "conv=fdatasync"]. seq:1 client/agent.go:159
2020-07-31T06:34:12Z WARN [CHECKS:RE] "1024+0 records in
1024+0 records out
" CMD:dd#1 client/agent.go:148
2020-07-31T06:34:12Z WARN [CHECKS:RE] "104857600 bytes (105 MB, 100 MiB) copied, 0.434512 s, 241 MB/s
" CMD:dd#1 client/agent.go:148
2020-07-31T06:34:12Z DEBU [RPC]       Completed. exit:0 seq:1 client/agent.go:167
2020-07-31T06:34:12Z DEBU [RPC]       Run ["rm" "/testfile"]. seq:1 client/agent.go:159
2020-07-31T06:34:12Z DEBU [RPC]       Completed. exit:0 seq:1 client/agent.go:167
2020-07-31T06:34:12Z DEBU [RPC]       Run ["dd" "if=/dev/zero" "of=/testfile" "bs=100K" "count=1024" "conv=fdatasync"]. seq:1 client/agent.go:159
2020-07-31T06:34:12Z WARN [CHECKS:RE] "1024+0 records in
1024+0 records out
104857600 bytes (105 MB, 100 MiB) copied, 0.409723 s, 256 MB/s
" CMD:dd#1 client/agent.go:148
2020-07-31T06:34:12Z DEBU [RPC]       Completed. exit:0 seq:1 client/agent.go:167
2020-07-31T06:34:12Z DEBU [RPC]       Run ["rm" "/testfile"]. seq:1 client/agent.go:159
2020-07-31T06:34:12Z DEBU [RPC]       Completed. exit:0 seq:1 client/agent.go:167
2020-07-31T06:34:12Z DEBU [RPC]       Run ["dd" "if=/dev/zero" "of=/testfile" "bs=100K" "count=1024" "conv=fdatasync"]. seq:1 client/agent.go:159
2020-07-31T06:34:12Z WARN [CHECKS:RE] "1024+0 records in
1024+0 records out
104857600 bytes (105 MB, 100 MiB) copied, 0.410886 s, 255 MB/s
" CMD:dd#1 client/agent.go:148
2020-07-31T06:34:12Z DEBU [RPC]       Completed. exit:0 seq:1 client/agent.go:167
2020-07-31T06:34:12Z DEBU [RPC]       Run ["rm" "/testfile"]. seq:1 client/agent.go:159
2020-07-31T06:34:12Z DEBU [RPC]       Completed. exit:0 seq:1 client/agent.go:167
2020-07-31T06:34:12Z INFO [CHECKS]    Server "kevin-test1" passed disk I/O check on disk(path=/testfile, rate=10MB/s): 256MB/s. checks/checks.go:506
2020-07-31T06:34:12Z INFO [CHECKS]    Server "kevin-test2" has required packages installed: []. checks/checks.go:899
2020-07-31T06:34:12Z DEBU [RPC]       Run ["touch" "tmpcheck.ad82b840-2bc5-4de3-a10c-946b6a31dd91"]. seq:1 client/agent.go:159
2020-07-31T06:34:12Z DEBU [RPC]       Completed. exit:0 seq:1 client/agent.go:167
2020-07-31T06:34:12Z DEBU [RPC]       Run ["rm" "tmpcheck.ad82b840-2bc5-4de3-a10c-946b6a31dd91"]. seq:1 client/agent.go:159
2020-07-31T06:34:12Z DEBU [RPC]       Completed. exit:0 seq:1 client/agent.go:167
2020-07-31T06:34:12Z INFO [CHECKS]    Server "kevin-test2" passed temp directory check: . checks/checks.go:560
2020-07-31T06:34:12Z DEBU [RPC]       Run ["dd" "if=/dev/zero" "of=/testfile" "bs=100K" "count=1024" "conv=fdatasync"]. seq:1 client/agent.go:159
2020-07-31T06:34:13Z WARN [CHECKS:RE] "1024+0 records in
1024+0 records out
104857600 bytes (105 MB, 100 MiB) copied, 0.426614 s, 246 MB/s
" CMD:dd#1 client/agent.go:148
2020-07-31T06:34:13Z DEBU [RPC]       Completed. exit:0 seq:1 client/agent.go:167
2020-07-31T06:34:13Z DEBU [RPC]       Run ["rm" "/testfile"]. seq:1 client/agent.go:159
2020-07-31T06:34:13Z DEBU [RPC]       Completed. exit:0 seq:1 client/agent.go:167
2020-07-31T06:34:13Z DEBU [RPC]       Run ["dd" "if=/dev/zero" "of=/testfile" "bs=100K" "count=1024" "conv=fdatasync"]. seq:1 client/agent.go:159
2020-07-31T06:34:13Z WARN [CHECKS:RE] "1024+0 records in
1024+0 records out
104857600 bytes (105 MB, 100 MiB) copied, 0.409608 s, 256 MB/s
" CMD:dd#1 client/agent.go:148
2020-07-31T06:34:13Z DEBU [RPC]       Completed. exit:0 seq:1 client/agent.go:167
2020-07-31T06:34:13Z DEBU [RPC]       Run ["rm" "/testfile"]. seq:1 client/agent.go:159
2020-07-31T06:34:13Z DEBU [RPC]       Completed. exit:0 seq:1 client/agent.go:167
2020-07-31T06:34:13Z DEBU [RPC]       Run ["dd" "if=/dev/zero" "of=/testfile" "bs=100K" "count=1024" "conv=fdatasync"]. seq:1 client/agent.go:159
2020-07-31T06:34:14Z WARN [CHECKS:RE] "1024+0 records in
1024+0 records out
104857600 bytes (105 MB, 100 MiB) copied, 0.40992 s, 256 MB/s
" CMD:dd#1 client/agent.go:148
2020-07-31T06:34:14Z DEBU [RPC]       Completed. exit:0 seq:1 client/agent.go:167
2020-07-31T06:34:14Z DEBU [RPC]       Run ["rm" "/testfile"]. seq:1 client/agent.go:159
2020-07-31T06:34:14Z DEBU [RPC]       Completed. exit:0 seq:1 client/agent.go:167
2020-07-31T06:34:14Z INFO [CHECKS]    Server "kevin-test2" passed disk I/O check on disk(path=/testfile, rate=10MB/s): 256MB/s. checks/checks.go:506
2020-07-31T06:34:14Z INFO [CHECKS]    Server "kevin-test3" has required packages installed: []. checks/checks.go:899
2020-07-31T06:34:14Z DEBU [RPC]       Run ["touch" "tmpcheck.a3f5eb7f-9e3c-4f17-a75e-5a5469a4cfd3"]. seq:1 client/agent.go:159
2020-07-31T06:34:14Z DEBU [RPC]       Completed. exit:0 seq:1 client/agent.go:167
2020-07-31T06:34:14Z DEBU [RPC]       Run ["rm" "tmpcheck.a3f5eb7f-9e3c-4f17-a75e-5a5469a4cfd3"]. seq:1 client/agent.go:159
2020-07-31T06:34:14Z DEBU [RPC]       Completed. exit:0 seq:1 client/agent.go:167
2020-07-31T06:34:14Z INFO [CHECKS]    Server "kevin-test3" passed temp directory check: . checks/checks.go:560
2020-07-31T06:34:14Z DEBU [RPC]       Run ["dd" "if=/dev/zero" "of=/testfile" "bs=100K" "count=1024" "conv=fdatasync"]. seq:1 client/agent.go:159
2020-07-31T06:34:14Z WARN [CHECKS:RE] "1024+0 records in
1024+0 records out
104857600 bytes (105 MB, 100 MiB) copied, 0.416049 s, 252 MB/s
" CMD:dd#1 client/agent.go:148
2020-07-31T06:34:14Z DEBU [RPC]       Completed. exit:0 seq:1 client/agent.go:167
2020-07-31T06:34:14Z DEBU [RPC]       Run ["rm" "/testfile"]. seq:1 client/agent.go:159
2020-07-31T06:34:14Z DEBU [RPC]       Completed. exit:0 seq:1 client/agent.go:167
2020-07-31T06:34:14Z DEBU [RPC]       Run ["dd" "if=/dev/zero" "of=/testfile" "bs=100K" "count=1024" "conv=fdatasync"]. seq:1 client/agent.go:159
2020-07-31T06:34:15Z WARN [CHECKS:RE] "1024+0 records in
1024+0 records out
104857600 bytes (105 MB, 100 MiB) copied, 0.411457 s, 255 MB/s
" CMD:dd#1 client/agent.go:148
2020-07-31T06:34:15Z DEBU [RPC]       Completed. exit:0 seq:1 client/agent.go:167
2020-07-31T06:34:15Z DEBU [RPC]       Run ["rm" "/testfile"]. seq:1 client/agent.go:159
2020-07-31T06:34:15Z DEBU [RPC]       Completed. exit:0 seq:1 client/agent.go:167
2020-07-31T06:34:15Z DEBU [RPC]       Run ["dd" "if=/dev/zero" "of=/testfile" "bs=100K" "count=1024" "conv=fdatasync"]. seq:1 client/agent.go:159
2020-07-31T06:34:15Z WARN [CHECKS:RE] "1024+0 records in
1024+0 records out
104857600 bytes (105 MB, 100 MiB) copied, 0.411855 s, 255 MB/s
" CMD:dd#1 client/agent.go:148
2020-07-31T06:34:15Z DEBU [RPC]       Completed. exit:0 seq:1 client/agent.go:167
2020-07-31T06:34:15Z DEBU [RPC]       Run ["rm" "/testfile"]. seq:1 client/agent.go:159
2020-07-31T06:34:15Z DEBU [RPC]       Completed. exit:0 seq:1 client/agent.go:167
2020-07-31T06:34:15Z INFO [CHECKS]    Server "kevin-test3" passed disk I/O check on disk(path=/testfile, rate=10MB/s): 255MB/s. checks/checks.go:506
2020-07-31T06:34:15Z INFO [CHECKS]    Servers passed check for the same OS: map[ubuntu 16.04:[kevin-test1 (0.0.0.0:3012) kevin-test2 (0.0.0.0:3012) kevin-test3 (0.0.0.0:3012)]]. checks/checks.go:834
2020-07-31T06:34:15Z INFO [CHECKS]    Servers [kevin-test1/10.162.0.7 kevin-test2/10.162.0.6 kevin-test3/10.162.0.5] passed time drift check. checks/checks.go:864
2020-07-31T06:34:15Z INFO [CHECKS]    Ping pong request: map[]. checks/checks.go:572
2020-07-31T06:34:15Z INFO [CHECKS]    Empty ping pong request. checks/checks.go:575
2020-07-31T06:34:15Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/checks, State=completed) cluster/engine.go:288
2020-07-31T06:34:16Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State         Node           Requires                                      Updated
-----                          -----------                                                -----         ----           --------                                      -------
✓ init                         Initialize update operation                                Completed     -              -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed     10.162.0.7     -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed     10.162.0.6     -                                             Fri Jul 31 06:32 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed     10.162.0.5     -                                             Fri Jul 31 06:32 UTC
✓ checks                       Run preflight checks                                       Completed     -              /init                                         Fri Jul 31 06:34 UTC
* pre-update                   Run pre-update application hook                            Unstarted     -              /init,/checks                                 -
* bootstrap                    Bootstrap update operation on nodes                        Unstarted     -              /checks,/pre-update                           -
  * kevin-test1                Bootstrap node \"kevin-test1\"                               Unstarted     10.162.0.7     -                                             -
  * kevin-test2                Bootstrap node \"kevin-test2\"                               Unstarted     10.162.0.6     -                                             -
  * kevin-test3                Bootstrap node \"kevin-test3\"                               Unstarted     10.162.0.5     -                                             -
* coredns                      Provision CoreDNS resources                                Unstarted     -              /bootstrap                                    -
* masters                      Update master nodes                                        Unstarted     -              /coredns                                      -
  * kevin-test1                Update system software on master node \"kevin-test1\"        Unstarted     -              -                                             -
    * kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Unstarted     -              -                                             -
    * stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Unstarted     -              /masters/kevin-test1/kubelet-permissions      -
    * drain                    Drain node \"kevin-test1\"                                   Unstarted     10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     -
    * system-upgrade           Update system software on node \"kevin-test1\"               Unstarted     10.162.0.7     /masters/kevin-test1/drain                    -
    * taint                    Taint node \"kevin-test1\"                                   Unstarted     10.162.0.7     /masters/kevin-test1/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test1\"                                Unstarted     10.162.0.7     /masters/kevin-test1/taint                    -
    * untaint                  Remove taint from node \"kevin-test1\"                       Unstarted     10.162.0.7     /masters/kevin-test1/uncordon                 -
  * elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Unstarted     -              /masters/kevin-test1                          -
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted     -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted     10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted     10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted     10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted     10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted     10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted     10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted     -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted     -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted     10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted     10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted     10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted     10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted     10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted     10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted     -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted     -              -                                             -
  * backup                     Backup etcd data                                           Unstarted     -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted     -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted     -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted     -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted     -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted     -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted     -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted     -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted     -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted     -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted     -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted     -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted     -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted     -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted     -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted     -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted     -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted     -              -                                             -
* config                       Update system configuration on nodes                       Unstarted     -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted     -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted     -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted     -              -                                             -
* runtime                      Update application runtime                                 Unstarted     -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted     -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted     -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted     -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted     -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted     -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted     -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted     -              -                                             -
* app                          Update installed application                               Unstarted     -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted     -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted     -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted     -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted     -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted     -              -                                             -
." fsm/logger.go:49
Fri Jul 31 06:34:16 UTC	Executing phase "/checks" finished in 6 seconds
INFO: 2020/07/31 06:34:16 transport: loopyWriter.run returning. connection error: desc = "transport is closing"
INFO: 2020/07/31 06:34:16 transport: loopyWriter.run returning. connection error: desc = "transport is closing"
```

Notes:
- Checks disk requirements
- Tests that temporary directories are writeable
- Checks profile requirements against node profiles

#### Pre-update Hook
The pre-update hook is an application hook that runs indicating to the application that an upgrade is starting. This allows the application developers to make changes to the application while the upgrade is running, such as scaling down the cluster services.

```
root@kevin-test1:~/build# ./gravity --debug plan execute --phase /pre-update 2>&1 | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'

...

2020-07-29T17:46:33Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Wed Jul 29 17:03 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Wed Jul 29 17:16 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Wed Jul 29 17:19 UTC
→ pre-update                   Run pre-update application hook                            In Progress     -              /init,/checks                                 Wed Jul 29 17:46 UTC
* bootstrap                    Bootstrap update operation on nodes                        Unstarted       -              /checks,/pre-update                           -
  * kevin-test1                Bootstrap node \"kevin-test1\"                               Unstarted       10.162.0.7     -                                             -
  * kevin-test2                Bootstrap node \"kevin-test2\"                               Unstarted       10.162.0.6     -                                             -
  * kevin-test3                Bootstrap node \"kevin-test3\"                               Unstarted       10.162.0.5     -                                             -
* coredns                      Provision CoreDNS resources                                Unstarted       -              /bootstrap                                    -
* masters                      Update master nodes                                        Unstarted       -              /coredns                                      -
  * kevin-test1                Update system software on master node \"kevin-test1\"        Unstarted       -              -                                             -
    * kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Unstarted       -              -                                             -
    * stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Unstarted       -              /masters/kevin-test1/kubelet-permissions      -
    * drain                    Drain node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     -
    * system-upgrade           Update system software on node \"kevin-test1\"               Unstarted       10.162.0.7     /masters/kevin-test1/drain                    -
    * taint                    Taint node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test1\"                                Unstarted       10.162.0.7     /masters/kevin-test1/taint                    -
    * untaint                  Remove taint from node \"kevin-test1\"                       Unstarted       10.162.0.7     /masters/kevin-test1/uncordon                 -
  * elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Unstarted       -              /masters/kevin-test1                          -
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted       -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted       10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted       10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted       10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted       10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted       10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted       -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted       -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted       10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted       10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted       10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted       10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted       10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted       -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted       -              -                                             -
  * backup                     Backup etcd data                                           Unstarted       -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted       -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted       -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted       -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted       -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
2020-07-29T17:46:33Z INFO             Executing phase: /pre-update. phase:/pre-update fsm/logger.go:61
2020-07-29T17:46:33Z INFO             Execute gravitational.io/telekube:5.5.50-dev.9(preUpdate) hook. phase:/pre-update fsm/logger.go:61
2020-07-29T17:46:33Z DEBU [APP]       "apiVersion: batch/v1
kind: Job
metadata:
  creationTimestamp: null
  name: tele-app-preupdate-f5d084
  namespace: kube-system
spec:
  activeDeadlineSeconds: 1200
  template:
    metadata:
      creationTimestamp: null
      name: tele-app-preupdate
    spec:
      containers:
      - command:
        - /bin/echo
        - test
        env:
        - name: MANUAL_UPDATE
          value: \"true\"
        - name: DEVMODE
          value: \"false\"
        - name: GRAVITY_SERVICE_USER
        image: leader.telekube.local:5000/gravitational/debian-tall:stretch
        imagePullPolicy: IfNotPresent
        name: hook
        resources: {}
        volumeMounts:
        - mountPath: /opt/bin
          name: bin
        - mountPath: /usr/local/bin/kubectl
          name: kubectl
        - mountPath: /usr/local/bin/helm
          name: helm
        - mountPath: /etc/ssl/certs
          name: certs
        - mountPath: /var/lib/gravity/resources
          name: resources
      initContainers:
      - args:
        - \"\
ops_url=https://gravity-site.kube-system.svc.cluster.local:3009;\
if
          [ \\\"$GRAVITY_SITE_SERVICE_HOST:$GRAVITY_SITE_SERVICE_PORT_WEB\\\" != \\\":\\\"
          ]; then ops_url=https://$GRAVITY_SITE_SERVICE_HOST:$GRAVITY_SITE_SERVICE_PORT_WEB;
          fi;\
/opt/bin/gravity --state-dir=/tmp/state ops connect $ops_url adminagent@wonderfulspence252
          70aab19bee22a44fd2e178311255f1c482837b5cf65d9d45ad9a881be8e5da84;\
/opt/bin/gravity
          --state-dir=/tmp/state package export \\\\\
\	gravitational.io/gravity:5.5.50-dev.9
          /tmp/state/gravity \\\\\
\	--file-mask=0755 \\\\\
\	--insecure \\\\\
\	--ops-url=$ops_url\
\
TMPDIR=/tmp/state
          /tmp/state/gravity --state-dir=/tmp/state app unpack \\\\\
\	--service-uid=
          \\\\\
\	--insecure --ops-url=$ops_url \\\\\
\	gravitational.io/telekube:5.5.50-dev.9
          /var/lib/gravity/resources\
\"
        command:
        - /bin/sh
        - -c
        - -e
        env:
        - name: APP_PACKAGE
          value: gravitational.io/telekube:5.5.50-dev.9
        - name: POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        image: leader.telekube.local:5000/gravitational/debian-tall:stretch
        imagePullPolicy: IfNotPresent
        name: init
        resources: {}
        volumeMounts:
        - mountPath: /var/lib/gravity/local
          name: gravity
        - mountPath: /tmp/state
          name: state-dir
        - mountPath: /opt/bin
          name: bin
        - mountPath: /usr/local/bin/kubectl
          name: kubectl
        - mountPath: /usr/local/bin/helm
          name: helm
        - mountPath: /etc/ssl/certs
          name: certs
        - mountPath: /var/lib/gravity/resources
          name: resources
      nodeSelector:
        gravitational.io/k8s-role: master
      restartPolicy: OnFailure
      securityContext:
        fsGroup: 0
        runAsNonRoot: false
        runAsUser: 0
      tolerations:
      - effect: NoSchedule
        operator: Exists
      - effect: NoExecute
        operator: Exists
      volumes:
      - hostPath:
          path: /usr/bin
        name: bin
      - hostPath:
          path: /usr/bin/kubectl
        name: kubectl
      - hostPath:
          path: /usr/bin/helm
        name: helm
      - hostPath:
          path: /etc/ssl/certs
        name: certs
      - hostPath:
          path: /var/lib/gravity/local
        name: gravity
      - emptyDir: {}
        name: resources
      - emptyDir: {}
        name: state-dir
status: {}
." hooks/hooks.go:181
2020-07-29T17:46:33Z DEBU             Dial. addr:leader.telekube.local:6443 network:tcp httplib/client.go:225
2020-07-29T17:46:33Z DEBU             Resolve leader.telekube.local took 219.596µs. utils/dns.go:47
2020-07-29T17:46:33Z DEBU             Resolved leader.telekube.local to 10.162.0.7. utils/dns.go:54
2020-07-29T17:46:33Z DEBU             Dial. host-port:10.162.0.7:6443 httplib/client.go:263
2020-07-29T17:46:33Z DEBU [APP]       Job "tele-app-preupdate-f5d084" in namespace "kube-system" event:ADDED hooks/hooks.go:358
2020-07-29T17:46:33Z DEBU [APP]       Job "tele-app-preupdate-f5d084" in namespace "kube-system" event:ADDED hooks/hooks.go:358
2020-07-29T17:46:33Z INFO             Created Pod "tele-app-preupdate-f5d084-zmcqv" in namespace "kube-system". phase:/pre-update fsm/logger.go:61
2020-07-29T17:46:33Z INFO             phase:/pre-update fsm/logger.go:61
2020-07-29T17:46:33Z DEBU [APP]       Job "tele-app-preupdate-f5d084" in namespace "kube-system" event:MODIFIED hooks/hooks.go:358
2020-07-29T17:46:33Z DEBU             now: job kube-system/tele-app-preupdate-f5d084 not yet complete (succeeded: 0, active: 1) hooks/hooks.go:304
2020-07-29T17:46:33Z DEBU [APP]       Pod "tele-app-preupdate-f5d084-zmcqv" in namespace "kube-system" event:ADDED hooks/hooks.go:313
2020-07-29T17:46:33Z DEBU [APP]       Job "tele-app-preupdate-f5d084" in namespace "kube-system" event:MODIFIED hooks/hooks.go:358
2020-07-29T17:46:33Z DEBU [APP]       now: job kube-system/tele-app-preupdate-f5d084 not yet complete (succeeded: 0, active: 1) event:ADDED hooks/hooks.go:320
2020-07-29T17:46:33Z DEBU [APP]       Pod "tele-app-preupdate-f5d084-zmcqv" in namespace "kube-system" event:MODIFIED hooks/hooks.go:313
2020-07-29T17:46:33Z INFO             Container "hook" created, current state is "waiting, reason PodInitializing". phase:/pre-update fsm/logger.go:61
2020-07-29T17:46:33Z INFO             phase:/pre-update fsm/logger.go:61
2020-07-29T17:46:33Z DEBU [APP]       now: job kube-system/tele-app-preupdate-f5d084 not yet complete (succeeded: 0, active: 1) event:MODIFIED hooks/hooks.go:320
2020-07-29T17:46:33Z DEBU [APP]       Pod "tele-app-preupdate-f5d084-zmcqv" in namespace "kube-system" event:MODIFIED hooks/hooks.go:313
2020-07-29T17:46:34Z DEBU [APP]       now: job kube-system/tele-app-preupdate-f5d084 not yet complete (succeeded: 0, active: 1) event:MODIFIED hooks/hooks.go:320
2020-07-29T17:46:36Z DEBU [APP]       Pod "tele-app-preupdate-f5d084-zmcqv" in namespace "kube-system" event:MODIFIED hooks/hooks.go:313
2020-07-29T17:46:36Z DEBU [APP]       3 seconds elapsed: job kube-system/tele-app-preupdate-f5d084 not yet complete (succeeded: 0, active: 1) event:MODIFIED hooks/hooks.go:320
2020-07-29T17:46:37Z DEBU [APP]       Pod "tele-app-preupdate-f5d084-zmcqv" in namespace "kube-system" event:MODIFIED hooks/hooks.go:313
2020-07-29T17:46:37Z INFO             Pod "tele-app-preupdate-f5d084-zmcqv" in namespace "kube-system", has changed state from "Pending" to "Succeeded". phase:/pre-update fsm/logger.go:61
2020-07-29T17:46:37Z INFO             Container "hook" changed status from "waiting, reason PodInitializing" to "terminated, exit code 0". phase:/pre-update fsm/logger.go:61
2020-07-29T17:46:37Z INFO             phase:/pre-update fsm/logger.go:61
2020-07-29T17:46:37Z INFO             <unknown> has completed, 4 seconds elapsed. phase:/pre-update fsm/logger.go:61
2020-07-29T17:46:37Z DEBU [APP]       Job "tele-app-preupdate-f5d084" in namespace "kube-system" event:MODIFIED hooks/hooks.go:358
2020-07-29T17:46:37Z DEBU [APP]       Completed: . event:MODIFIED hooks/hooks.go:365
2020-07-29T17:46:37Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/pre-update, State=completed) cluster/engine.go:288
2020-07-29T17:46:37Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State         Node           Requires                                      Updated
-----                          -----------                                                -----         ----           --------                                      -------
✓ init                         Initialize update operation                                Completed     -              -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed     10.162.0.7     -                                             Wed Jul 29 17:03 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed     10.162.0.6     -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed     10.162.0.5     -                                             Wed Jul 29 17:16 UTC
✓ checks                       Run preflight checks                                       Completed     -              /init                                         Wed Jul 29 17:19 UTC
✓ pre-update                   Run pre-update application hook                            Completed     -              /init,/checks                                 Wed Jul 29 17:46 UTC
* bootstrap                    Bootstrap update operation on nodes                        Unstarted     -              /checks,/pre-update                           -
  * kevin-test1                Bootstrap node \"kevin-test1\"                               Unstarted     10.162.0.7     -                                             -
  * kevin-test2                Bootstrap node \"kevin-test2\"                               Unstarted     10.162.0.6     -                                             -
  * kevin-test3                Bootstrap node \"kevin-test3\"                               Unstarted     10.162.0.5     -                                             -
* coredns                      Provision CoreDNS resources                                Unstarted     -              /bootstrap                                    -
* masters                      Update master nodes                                        Unstarted     -              /coredns                                      -
  * kevin-test1                Update system software on master node \"kevin-test1\"        Unstarted     -              -                                             -
    * kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Unstarted     -              -                                             -
    * stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Unstarted     -              /masters/kevin-test1/kubelet-permissions      -
    * drain                    Drain node \"kevin-test1\"                                   Unstarted     10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     -
    * system-upgrade           Update system software on node \"kevin-test1\"               Unstarted     10.162.0.7     /masters/kevin-test1/drain                    -
    * taint                    Taint node \"kevin-test1\"                                   Unstarted     10.162.0.7     /masters/kevin-test1/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test1\"                                Unstarted     10.162.0.7     /masters/kevin-test1/taint                    -
    * untaint                  Remove taint from node \"kevin-test1\"                       Unstarted     10.162.0.7     /masters/kevin-test1/uncordon                 -
  * elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Unstarted     -              /masters/kevin-test1                          -
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted     -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted     10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted     10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted     10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted     10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted     10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted     10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted     -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted     -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted     10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted     10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted     10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted     10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted     10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted     10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted     -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted     -              -                                             -
  * backup                     Backup etcd data                                           Unstarted     -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted     -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted     -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted     -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted     -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted     -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted     -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted     -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted     -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted     -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted     -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted     -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted     -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted     -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted     -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted     -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted     -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted     -              -                                             -
* config                       Update system configuration on nodes                       Unstarted     -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted     -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted     -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted     -              -                                             -
* runtime                      Update application runtime                                 Unstarted     -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted     -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted     -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted     -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted     -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted     -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted     -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted     -              -                                             -
* app                          Update installed application                               Unstarted     -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted     -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted     -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted     -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted     -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted     -              -                                             -
." fsm/logger.go:49
Wed Jul 29 17:46:37 UTC	Executing phase "/pre-update" finished in 4 seconds
```

#### Bootstrap
The bootstrap phase is used to do initial configuration on each node within the cluster, to prepare the nodes for the upgrade. None of the changes should impact the system, these are just the preparation steps.

```
root@kevin-test1:~/build# ./gravity --debug plan execute --phase /bootstrap/kevin-test1 --force 2>&1 | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'

...

2020-07-29T17:50:36Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Wed Jul 29 17:03 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Wed Jul 29 17:16 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Wed Jul 29 17:19 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Wed Jul 29 17:46 UTC
→ bootstrap                    Bootstrap update operation on nodes                        In Progress     -              /checks,/pre-update                           Wed Jul 29 17:50 UTC
  → kevin-test1                Bootstrap node \"kevin-test1\"                               In Progress     10.162.0.7     -                                             Wed Jul 29 17:50 UTC
  * kevin-test2                Bootstrap node \"kevin-test2\"                               Unstarted       10.162.0.6     -                                             -
  * kevin-test3                Bootstrap node \"kevin-test3\"                               Unstarted       10.162.0.5     -                                             -
* coredns                      Provision CoreDNS resources                                Unstarted       -              /bootstrap                                    -
* masters                      Update master nodes                                        Unstarted       -              /coredns                                      -
  * kevin-test1                Update system software on master node \"kevin-test1\"        Unstarted       -              -                                             -
    * kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Unstarted       -              -                                             -
    * stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Unstarted       -              /masters/kevin-test1/kubelet-permissions      -
    * drain                    Drain node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     -
    * system-upgrade           Update system software on node \"kevin-test1\"               Unstarted       10.162.0.7     /masters/kevin-test1/drain                    -
    * taint                    Taint node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test1\"                                Unstarted       10.162.0.7     /masters/kevin-test1/taint                    -
    * untaint                  Remove taint from node \"kevin-test1\"                       Unstarted       10.162.0.7     /masters/kevin-test1/uncordon                 -
  * elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Unstarted       -              /masters/kevin-test1                          -
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted       -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted       10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted       10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted       10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted       10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted       10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted       -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted       -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted       10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted       10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted       10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted       10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted       10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted       -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted       -              -                                             -
  * backup                     Backup etcd data                                           Unstarted       -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted       -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted       -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted       -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted       -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
2020-07-29T17:50:36Z INFO             Executing phase: /bootstrap/kevin-test1. phase:/bootstrap/kevin-test1 fsm/logger.go:61
2020-07-29T17:50:36Z INFO             Export gravity binary to /var/lib/gravity/site/update/gravity. phase:/bootstrap/kevin-test1 fsm/logger.go:61
2020-07-29T17:50:36Z DEBU             Dial. addr:gravity-site.kube-system.svc.cluster.local:3009 network:tcp httplib/client.go:225
2020-07-29T17:50:36Z DEBU             Resolve gravity-site.kube-system.svc.cluster.local took 266.879µs. utils/dns.go:47
2020-07-29T17:50:36Z DEBU             Resolved gravity-site.kube-system.svc.cluster.local to 10.100.94.7. utils/dns.go:54
2020-07-29T17:50:36Z DEBU             Dial. host-port:10.100.94.7:3009 httplib/client.go:263
2020-07-29T17:50:37Z INFO             Generate new secrets configuration package for node(addr=10.162.0.7,hostname=kevin-test1,role=node,cluster_role=master,runtime(installed=gravitational.io/planet:5.5.47-11312,secrets=wonderfulspence252/planet-10.162.0.7-secrets:5.5.54-11312+1596042169,update(package=gravitational.io/planet:5.5.54-11312,config-package=wonderfulspence252/planet-config-1016207wonderfulspence252:5.5.54-11312+1596042169)),teleport(installed=gravitational.io/teleport:3.0.5),docker(installed={overlay2 [] },update={overlay2 [] })). phase:/bootstrap/kevin-test1 fsm/logger.go:61
2020-07-29T17:50:37Z INFO             2020/07/29 17:50:37 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:37Z INFO             2020/07/29 17:50:37 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:37Z INFO             2020/07/29 17:50:37 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:37Z INFO             2020/07/29 17:50:37 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:37Z INFO             2020/07/29 17:50:37 [INFO] signed certificate with serial number 587332027575936478403828535105450553455551770609 runtime/asm_amd64.s:1337
2020-07-29T17:50:37Z INFO             2020/07/29 17:50:37 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:37Z INFO             2020/07/29 17:50:37 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:37Z INFO             2020/07/29 17:50:37 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:37Z INFO             2020/07/29 17:50:37 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:37Z INFO             2020/07/29 17:50:37 [INFO] signed certificate with serial number 354496591288535337919937117299591721997517036515 runtime/asm_amd64.s:1337
2020-07-29T17:50:37Z INFO             2020/07/29 17:50:37 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:37Z INFO             2020/07/29 17:50:37 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:37Z INFO             2020/07/29 17:50:37 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] signed certificate with serial number 493531614340936420879074877180311973148129328097 runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] signed certificate with serial number 614069885985091473405334653108500021311725134059 runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] signed certificate with serial number 505688613336765790393794836896276032053278927207 runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] signed certificate with serial number 46378661372370874431173732777949084636642855168 runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] signed certificate with serial number 107319133476733445881779982960098705560553012032 runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] signed certificate with serial number 630779985826222645271834122841675242516652189123 runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:38Z INFO             2020/07/29 17:50:38 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:39Z INFO             2020/07/29 17:50:39 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:39Z INFO             2020/07/29 17:50:39 [INFO] signed certificate with serial number 262990704515224155150738744019475778830821272164 runtime/asm_amd64.s:1337
2020-07-29T17:50:39Z INFO             2020/07/29 17:50:39 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:39Z INFO             2020/07/29 17:50:39 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:39Z INFO             2020/07/29 17:50:39 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:39Z INFO             2020/07/29 17:50:39 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:39Z INFO             2020/07/29 17:50:39 [INFO] signed certificate with serial number 623305697614110280696224860306102802617550517274 runtime/asm_amd64.s:1337
2020-07-29T17:50:39Z DEBU             Rotated secrets package for node(addr=10.162.0.7,hostname=kevin-test1,role=node,cluster_role=master,runtime(installed=gravitational.io/planet:5.5.47-11312,secrets=wonderfulspence252/planet-10.162.0.7-secrets:5.5.54-11312+1596042169,update(package=gravitational.io/planet:5.5.54-11312,config-package=wonderfulspence252/planet-config-1016207wonderfulspence252:5.5.54-11312+1596042169)),teleport(installed=gravitational.io/teleport:3.0.5),docker(installed={overlay2 [] },update={overlay2 [] })): wonderfulspence252/planet-10.162.0.7-secrets:5.5.54-11312+1596042169. phase:/bootstrap/kevin-test1 fsm/logger.go:49
2020-07-29T17:50:39Z INFO             Generate new runtime configuration package for node(addr=10.162.0.7,hostname=kevin-test1,role=node,cluster_role=master,runtime(installed=gravitational.io/planet:5.5.47-11312,secrets=wonderfulspence252/planet-10.162.0.7-secrets:5.5.54-11312+1596042169,update(package=gravitational.io/planet:5.5.54-11312,config-package=wonderfulspence252/planet-config-1016207wonderfulspence252:5.5.54-11312+1596042169)),teleport(installed=gravitational.io/teleport:3.0.5),docker(installed={overlay2 [] },update={overlay2 [] })). phase:/bootstrap/kevin-test1 fsm/logger.go:61
2020-07-29T17:50:39Z INFO             Runtime configuration. args:[--node-name=10.162.0.7 --hostname=kevin-test1 --master-ip=10.162.0.7 --public-ip=10.162.0.7 --cluster-id=wonderfulspence252 --etcd-proxy=off --etcd-member-name=10_162_0_7.wonderfulspence252 --initial-cluster=10_162_0_6.wonderfulspence252:10.162.0.6,10_162_0_7.wonderfulspence252:10.162.0.7,10_162_0_5.wonderfulspence252:10.162.0.5 --secrets-dir=/var/lib/gravity/secrets --etcd-initial-cluster-state=new --election-enabled=true --volume=/var/lib/gravity/planet/etcd:/ext/etcd --volume=/var/lib/gravity/planet/registry:/ext/registry --volume=/var/lib/gravity/planet/docker:/ext/docker --volume=/var/lib/gravity/planet/share:/ext/share --volume=/var/lib/gravity/planet/state:/ext/state --volume=/var/lib/gravity/planet/log:/var/log --volume=/var/lib/gravity:/var/lib/gravity --service-uid=1000 --role=master --vxlan-port=8472 --dns-listen-addr=127.0.0.2 --dns-port=53 --docker-backend=overlay2 --docker-options=--storage-opt=overlay2.override_kernel_check=1 --node-label=gravitational.io/k8s-role=master --node-label=role=node --node-label=gravitational.io/advertise-ip=10.162.0.7 --service-subnet=10.100.0.0/16 --pod-subnet=10.244.0.0/16] opsservice/configure.go:1015
2020-07-29T17:50:39Z INFO             Generate configuration package. manifest:&pack.Manifest{Version:"0.0.1", Config:(*schema.Config)(0xc000b8ac00), Commands:[]pack.Command{pack.Command{Name:"start", Description:"", Args:[]string{"rootfs/usr/bin/planet", "start"}}, pack.Command{Name:"stop", Description:"", Args:[]string{"rootfs/usr/bin/planet", "stop"}}, pack.Command{Name:"enter", Description:"", Args:[]string{"rootfs/usr/bin/planet", "enter"}}, pack.Command{Name:"exec", Description:"", Args:[]string{"rootfs/usr/bin/planet", "exec"}}, pack.Command{Name:"status", Description:"", Args:[]string{"rootfs/usr/bin/planet", "status"}}, pack.Command{Name:"local-status", Description:"", Args:[]string{"rootfs/usr/bin/planet", "status", "--local"}}, pack.Command{Name:"secrets-init", Description:"", Args:[]string{"rootfs/usr/bin/planet", "secrets", "init"}}, pack.Command{Name:"gen-cert", Description:"", Args:[]string{"rootfs/usr/bin/planet", "secrets", "gencert"}}}, Labels:[]pack.Label{pack.Label{Name:"os", Value:"linux"}, pack.Label{Name:"version-etcd", Value:"v3.3.22"}, pack.Label{Name:"version-k8s", Value:"v1.13.12"}, pack.Label{Name:"version-flannel", Value:"v0.10.1-gravitational"}, pack.Label{Name:"version-docker", Value:"18.06.2"}, pack.Label{Name:"version-helm", Value:"v2.12.3"}, pack.Label{Name:"version-coredns", Value:"1.3.1"}}, Service:(*systemservice.NewPackageServiceRequest)(0xc00091b180)} package:gravitational.io/planet:5.5.54-11312 pack/utils.go:144
2020-07-29T17:50:39Z INFO             Created new planet configuration. package:wonderfulspence252/planet-config-1016207wonderfulspence252:5.5.54-11312+1596042169 server:ProvisionedServer(hostname=kevin-test1,ip=10.162.0.7) opsservice/update.go:289
2020-07-29T17:50:39Z INFO             Generated new runtime configuration package for node(addr=10.162.0.7,hostname=kevin-test1,role=node,cluster_role=master,runtime(installed=gravitational.io/planet:5.5.47-11312,secrets=wonderfulspence252/planet-10.162.0.7-secrets:5.5.54-11312+1596042169,update(package=gravitational.io/planet:5.5.54-11312,config-package=wonderfulspence252/planet-config-1016207wonderfulspence252:5.5.54-11312+1596042169)),teleport(installed=gravitational.io/teleport:3.0.5),docker(installed={overlay2 [] },update={overlay2 [] })): wonderfulspence252/planet-config-1016207wonderfulspence252:5.5.54-11312+1596042169. phase:/bootstrap/kevin-test1 fsm/logger.go:61
2020-07-29T17:50:39Z INFO             Generate new secrets configuration package for node(addr=10.162.0.6,hostname=kevin-test2,role=node,cluster_role=master,runtime(installed=gravitational.io/planet:5.5.47-11312,secrets=wonderfulspence252/planet-10.162.0.6-secrets:5.5.54-11312+1596042169,update(package=gravitational.io/planet:5.5.54-11312,config-package=wonderfulspence252/planet-config-1016206wonderfulspence252:5.5.54-11312+1596042169)),teleport(installed=gravitational.io/teleport:3.0.5),docker(installed={overlay2 [] },update={overlay2 [] })). phase:/bootstrap/kevin-test1 fsm/logger.go:61
2020-07-29T17:50:39Z INFO             2020/07/29 17:50:39 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:39Z INFO             2020/07/29 17:50:39 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:39Z INFO             2020/07/29 17:50:39 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:39Z INFO             2020/07/29 17:50:39 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:39Z INFO             2020/07/29 17:50:39 [INFO] signed certificate with serial number 576666468144591020036803515119303225807238145075 runtime/asm_amd64.s:1337
2020-07-29T17:50:39Z INFO             2020/07/29 17:50:39 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:39Z INFO             2020/07/29 17:50:39 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:39Z INFO             2020/07/29 17:50:39 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:40Z INFO             2020/07/29 17:50:40 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:40Z INFO             2020/07/29 17:50:40 [INFO] signed certificate with serial number 119309510206953708896033026483936326778789894943 runtime/asm_amd64.s:1337
2020-07-29T17:50:40Z INFO             2020/07/29 17:50:40 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:40Z INFO             2020/07/29 17:50:40 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:40Z INFO             2020/07/29 17:50:40 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:40Z INFO             2020/07/29 17:50:40 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:40Z INFO             2020/07/29 17:50:40 [INFO] signed certificate with serial number 187919745545489558226269785743382284109697434761 runtime/asm_amd64.s:1337
2020-07-29T17:50:40Z INFO             2020/07/29 17:50:40 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:40Z INFO             2020/07/29 17:50:40 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:40Z INFO             2020/07/29 17:50:40 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:40Z INFO             2020/07/29 17:50:40 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:40Z INFO             2020/07/29 17:50:40 [INFO] signed certificate with serial number 687619612475030470633647218612286387728274334912 runtime/asm_amd64.s:1337
2020-07-29T17:50:40Z INFO             2020/07/29 17:50:40 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:40Z INFO             2020/07/29 17:50:40 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:40Z INFO             2020/07/29 17:50:40 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:40Z INFO             2020/07/29 17:50:40 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:40Z INFO             2020/07/29 17:50:40 [INFO] signed certificate with serial number 287950683260886300470478710950406642955917527506 runtime/asm_amd64.s:1337
2020-07-29T17:50:40Z INFO             2020/07/29 17:50:40 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:40Z INFO             2020/07/29 17:50:40 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:40Z INFO             2020/07/29 17:50:40 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:41Z INFO             2020/07/29 17:50:41 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:41Z INFO             2020/07/29 17:50:41 [INFO] signed certificate with serial number 653283565276470413744485487204415545964099003020 runtime/asm_amd64.s:1337
2020-07-29T17:50:41Z INFO             2020/07/29 17:50:41 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:41Z INFO             2020/07/29 17:50:41 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:41Z INFO             2020/07/29 17:50:41 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:41Z INFO             2020/07/29 17:50:41 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:41Z INFO             2020/07/29 17:50:41 [INFO] signed certificate with serial number 271577185266898767376666012750471319587351028924 runtime/asm_amd64.s:1337
2020-07-29T17:50:41Z INFO             2020/07/29 17:50:41 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:41Z INFO             2020/07/29 17:50:41 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:41Z INFO             2020/07/29 17:50:41 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:41Z INFO             2020/07/29 17:50:41 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:41Z INFO             2020/07/29 17:50:41 [INFO] signed certificate with serial number 562767382240087461101219736646862648836841866627 runtime/asm_amd64.s:1337
2020-07-29T17:50:41Z INFO             2020/07/29 17:50:41 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:41Z INFO             2020/07/29 17:50:41 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:41Z INFO             2020/07/29 17:50:41 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:42Z INFO             2020/07/29 17:50:42 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:42Z INFO             2020/07/29 17:50:42 [INFO] signed certificate with serial number 95742675819897842489234527019290301379232972605 runtime/asm_amd64.s:1337
2020-07-29T17:50:42Z INFO             2020/07/29 17:50:42 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:42Z INFO             2020/07/29 17:50:42 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:42Z INFO             2020/07/29 17:50:42 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:42Z INFO             2020/07/29 17:50:42 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:42Z INFO             2020/07/29 17:50:42 [INFO] signed certificate with serial number 407020505771415402138613890931259219240359014302 runtime/asm_amd64.s:1337
2020-07-29T17:50:42Z DEBU             Rotated secrets package for node(addr=10.162.0.6,hostname=kevin-test2,role=node,cluster_role=master,runtime(installed=gravitational.io/planet:5.5.47-11312,secrets=wonderfulspence252/planet-10.162.0.6-secrets:5.5.54-11312+1596042169,update(package=gravitational.io/planet:5.5.54-11312,config-package=wonderfulspence252/planet-config-1016206wonderfulspence252:5.5.54-11312+1596042169)),teleport(installed=gravitational.io/teleport:3.0.5),docker(installed={overlay2 [] },update={overlay2 [] })): wonderfulspence252/planet-10.162.0.6-secrets:5.5.54-11312+1596042169. phase:/bootstrap/kevin-test1 fsm/logger.go:49
2020-07-29T17:50:42Z INFO             Generate new runtime configuration package for node(addr=10.162.0.6,hostname=kevin-test2,role=node,cluster_role=master,runtime(installed=gravitational.io/planet:5.5.47-11312,secrets=wonderfulspence252/planet-10.162.0.6-secrets:5.5.54-11312+1596042169,update(package=gravitational.io/planet:5.5.54-11312,config-package=wonderfulspence252/planet-config-1016206wonderfulspence252:5.5.54-11312+1596042169)),teleport(installed=gravitational.io/teleport:3.0.5),docker(installed={overlay2 [] },update={overlay2 [] })). phase:/bootstrap/kevin-test1 fsm/logger.go:61
2020-07-29T17:50:42Z INFO             Runtime configuration. args:[--node-name=kevin-test2 --hostname=kevin-test2 --master-ip=10.162.0.7 --public-ip=10.162.0.6 --cluster-id=wonderfulspence252 --etcd-proxy=off --etcd-member-name=10_162_0_6.wonderfulspence252 --initial-cluster=10_162_0_6.wonderfulspence252:10.162.0.6,10_162_0_7.wonderfulspence252:10.162.0.7,10_162_0_5.wonderfulspence252:10.162.0.5 --secrets-dir=/var/lib/gravity/secrets --etcd-initial-cluster-state=new --election-enabled=true --volume=/var/lib/gravity/planet/etcd:/ext/etcd --volume=/var/lib/gravity/planet/registry:/ext/registry --volume=/var/lib/gravity/planet/docker:/ext/docker --volume=/var/lib/gravity/planet/share:/ext/share --volume=/var/lib/gravity/planet/state:/ext/state --volume=/var/lib/gravity/planet/log:/var/log --volume=/var/lib/gravity:/var/lib/gravity --service-uid=1000 --role=master --vxlan-port=8472 --dns-listen-addr=127.0.0.2 --dns-port=53 --docker-backend=overlay2 --docker-options=--storage-opt=overlay2.override_kernel_check=1 --node-label=gravitational.io/k8s-role=master --node-label=role=node --node-label=gravitational.io/advertise-ip=10.162.0.6 --service-subnet=10.100.0.0/16 --pod-subnet=10.244.0.0/16] opsservice/configure.go:1015
2020-07-29T17:50:42Z INFO             Generate configuration package. manifest:&pack.Manifest{Version:"0.0.1", Config:(*schema.Config)(0xc000d61120), Commands:[]pack.Command{pack.Command{Name:"start", Description:"", Args:[]string{"rootfs/usr/bin/planet", "start"}}, pack.Command{Name:"stop", Description:"", Args:[]string{"rootfs/usr/bin/planet", "stop"}}, pack.Command{Name:"enter", Description:"", Args:[]string{"rootfs/usr/bin/planet", "enter"}}, pack.Command{Name:"exec", Description:"", Args:[]string{"rootfs/usr/bin/planet", "exec"}}, pack.Command{Name:"status", Description:"", Args:[]string{"rootfs/usr/bin/planet", "status"}}, pack.Command{Name:"local-status", Description:"", Args:[]string{"rootfs/usr/bin/planet", "status", "--local"}}, pack.Command{Name:"secrets-init", Description:"", Args:[]string{"rootfs/usr/bin/planet", "secrets", "init"}}, pack.Command{Name:"gen-cert", Description:"", Args:[]string{"rootfs/usr/bin/planet", "secrets", "gencert"}}}, Labels:[]pack.Label{pack.Label{Name:"os", Value:"linux"}, pack.Label{Name:"version-etcd", Value:"v3.3.22"}, pack.Label{Name:"version-k8s", Value:"v1.13.12"}, pack.Label{Name:"version-flannel", Value:"v0.10.1-gravitational"}, pack.Label{Name:"version-docker", Value:"18.06.2"}, pack.Label{Name:"version-helm", Value:"v2.12.3"}, pack.Label{Name:"version-coredns", Value:"1.3.1"}}, Service:(*systemservice.NewPackageServiceRequest)(0xc000c60c40)} package:gravitational.io/planet:5.5.54-11312 pack/utils.go:144
2020-07-29T17:50:42Z INFO             Created new planet configuration. package:wonderfulspence252/planet-config-1016206wonderfulspence252:5.5.54-11312+1596042169 server:ProvisionedServer(hostname=kevin-test2,ip=10.162.0.6) opsservice/update.go:289
2020-07-29T17:50:42Z INFO             Generated new runtime configuration package for node(addr=10.162.0.6,hostname=kevin-test2,role=node,cluster_role=master,runtime(installed=gravitational.io/planet:5.5.47-11312,secrets=wonderfulspence252/planet-10.162.0.6-secrets:5.5.54-11312+1596042169,update(package=gravitational.io/planet:5.5.54-11312,config-package=wonderfulspence252/planet-config-1016206wonderfulspence252:5.5.54-11312+1596042169)),teleport(installed=gravitational.io/teleport:3.0.5),docker(installed={overlay2 [] },update={overlay2 [] })): wonderfulspence252/planet-config-1016206wonderfulspence252:5.5.54-11312+1596042169. phase:/bootstrap/kevin-test1 fsm/logger.go:61
2020-07-29T17:50:42Z INFO             Generate new secrets configuration package for node(addr=10.162.0.5,hostname=kevin-test3,role=node,cluster_role=master,runtime(installed=gravitational.io/planet:5.5.47-11312,secrets=wonderfulspence252/planet-10.162.0.5-secrets:5.5.54-11312+1596042169,update(package=gravitational.io/planet:5.5.54-11312,config-package=wonderfulspence252/planet-config-1016205wonderfulspence252:5.5.54-11312+1596042169)),teleport(installed=gravitational.io/teleport:3.0.5),docker(installed={overlay2 [] },update={overlay2 [] })). phase:/bootstrap/kevin-test1 fsm/logger.go:61
2020-07-29T17:50:42Z INFO             2020/07/29 17:50:42 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:42Z INFO             2020/07/29 17:50:42 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:42Z INFO             2020/07/29 17:50:42 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:42Z INFO             2020/07/29 17:50:42 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:42Z INFO             2020/07/29 17:50:42 [INFO] signed certificate with serial number 512353329606369496426780430743624839508407560719 runtime/asm_amd64.s:1337
2020-07-29T17:50:42Z INFO             2020/07/29 17:50:42 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:42Z INFO             2020/07/29 17:50:42 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:42Z INFO             2020/07/29 17:50:42 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:43Z INFO             2020/07/29 17:50:43 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:43Z INFO             2020/07/29 17:50:43 [INFO] signed certificate with serial number 87185179455256190406326891488628498745563918995 runtime/asm_amd64.s:1337
2020-07-29T17:50:43Z INFO             2020/07/29 17:50:43 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:43Z INFO             2020/07/29 17:50:43 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:43Z INFO             2020/07/29 17:50:43 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:43Z INFO             2020/07/29 17:50:43 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:43Z INFO             2020/07/29 17:50:43 [INFO] signed certificate with serial number 188464738632548742301803252613887296589415534899 runtime/asm_amd64.s:1337
2020-07-29T17:50:43Z INFO             2020/07/29 17:50:43 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:43Z INFO             2020/07/29 17:50:43 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:43Z INFO             2020/07/29 17:50:43 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:43Z INFO             2020/07/29 17:50:43 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:43Z INFO             2020/07/29 17:50:43 [INFO] signed certificate with serial number 177160233559178447070700491115976313823642399236 runtime/asm_amd64.s:1337
2020-07-29T17:50:43Z INFO             2020/07/29 17:50:43 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:43Z INFO             2020/07/29 17:50:43 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:43Z INFO             2020/07/29 17:50:43 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:43Z INFO             2020/07/29 17:50:43 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:43Z INFO             2020/07/29 17:50:43 [INFO] signed certificate with serial number 383873135718723444120977147803101431740583640017 runtime/asm_amd64.s:1337
2020-07-29T17:50:43Z INFO             2020/07/29 17:50:43 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:43Z INFO             2020/07/29 17:50:43 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:43Z INFO             2020/07/29 17:50:43 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:43Z INFO             2020/07/29 17:50:43 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:44Z INFO             2020/07/29 17:50:44 [INFO] signed certificate with serial number 710002929359208007101292227128660094546105086884 runtime/asm_amd64.s:1337
2020-07-29T17:50:44Z INFO             2020/07/29 17:50:44 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:44Z INFO             2020/07/29 17:50:44 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:44Z INFO             2020/07/29 17:50:44 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:44Z INFO             2020/07/29 17:50:44 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:44Z INFO             2020/07/29 17:50:44 [INFO] signed certificate with serial number 283627960365438433278823167175026073485514179188 runtime/asm_amd64.s:1337
2020-07-29T17:50:44Z INFO             2020/07/29 17:50:44 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:44Z INFO             2020/07/29 17:50:44 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:44Z INFO             2020/07/29 17:50:44 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:44Z INFO             2020/07/29 17:50:44 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:44Z INFO             2020/07/29 17:50:44 [INFO] signed certificate with serial number 144167313739344250251609933374417821839624501387 runtime/asm_amd64.s:1337
2020-07-29T17:50:44Z INFO             2020/07/29 17:50:44 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:44Z INFO             2020/07/29 17:50:44 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:44Z INFO             2020/07/29 17:50:44 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:44Z INFO             2020/07/29 17:50:44 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:44Z INFO             2020/07/29 17:50:44 [INFO] signed certificate with serial number 237800131098454755332335339640230524928034459370 runtime/asm_amd64.s:1337
2020-07-29T17:50:44Z INFO             2020/07/29 17:50:44 [INFO] generate received request runtime/asm_amd64.s:1337
2020-07-29T17:50:44Z INFO             2020/07/29 17:50:44 [INFO] received CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:44Z INFO             2020/07/29 17:50:44 [INFO] generating key: rsa-2048 runtime/asm_amd64.s:1337
2020-07-29T17:50:44Z INFO             2020/07/29 17:50:44 [INFO] encoded CSR runtime/asm_amd64.s:1337
2020-07-29T17:50:44Z INFO             2020/07/29 17:50:44 [INFO] signed certificate with serial number 104076353673464891164427422445630738602755644580 runtime/asm_amd64.s:1337
2020-07-29T17:50:44Z DEBU             Rotated secrets package for node(addr=10.162.0.5,hostname=kevin-test3,role=node,cluster_role=master,runtime(installed=gravitational.io/planet:5.5.47-11312,secrets=wonderfulspence252/planet-10.162.0.5-secrets:5.5.54-11312+1596042169,update(package=gravitational.io/planet:5.5.54-11312,config-package=wonderfulspence252/planet-config-1016205wonderfulspence252:5.5.54-11312+1596042169)),teleport(installed=gravitational.io/teleport:3.0.5),docker(installed={overlay2 [] },update={overlay2 [] })): wonderfulspence252/planet-10.162.0.5-secrets:5.5.54-11312+1596042169. phase:/bootstrap/kevin-test1 fsm/logger.go:49
2020-07-29T17:50:44Z INFO             Generate new runtime configuration package for node(addr=10.162.0.5,hostname=kevin-test3,role=node,cluster_role=master,runtime(installed=gravitational.io/planet:5.5.47-11312,secrets=wonderfulspence252/planet-10.162.0.5-secrets:5.5.54-11312+1596042169,update(package=gravitational.io/planet:5.5.54-11312,config-package=wonderfulspence252/planet-config-1016205wonderfulspence252:5.5.54-11312+1596042169)),teleport(installed=gravitational.io/teleport:3.0.5),docker(installed={overlay2 [] },update={overlay2 [] })). phase:/bootstrap/kevin-test1 fsm/logger.go:61
2020-07-29T17:50:45Z INFO             Runtime configuration. args:[--node-name=kevin-test3 --hostname=kevin-test3 --master-ip=10.162.0.7 --public-ip=10.162.0.5 --cluster-id=wonderfulspence252 --etcd-proxy=off --etcd-member-name=10_162_0_5.wonderfulspence252 --initial-cluster=10_162_0_6.wonderfulspence252:10.162.0.6,10_162_0_7.wonderfulspence252:10.162.0.7,10_162_0_5.wonderfulspence252:10.162.0.5 --secrets-dir=/var/lib/gravity/secrets --etcd-initial-cluster-state=new --election-enabled=true --volume=/var/lib/gravity/planet/etcd:/ext/etcd --volume=/var/lib/gravity/planet/registry:/ext/registry --volume=/var/lib/gravity/planet/docker:/ext/docker --volume=/var/lib/gravity/planet/share:/ext/share --volume=/var/lib/gravity/planet/state:/ext/state --volume=/var/lib/gravity/planet/log:/var/log --volume=/var/lib/gravity:/var/lib/gravity --service-uid=1000 --role=master --vxlan-port=8472 --dns-listen-addr=127.0.0.2 --dns-port=53 --docker-backend=overlay2 --docker-options=--storage-opt=overlay2.override_kernel_check=1 --node-label=gravitational.io/k8s-role=master --node-label=role=node --node-label=gravitational.io/advertise-ip=10.162.0.5 --service-subnet=10.100.0.0/16 --pod-subnet=10.244.0.0/16] opsservice/configure.go:1015
2020-07-29T17:50:45Z INFO             Generate configuration package. manifest:&pack.Manifest{Version:"0.0.1", Config:(*schema.Config)(0xc000579ae0), Commands:[]pack.Command{pack.Command{Name:"start", Description:"", Args:[]string{"rootfs/usr/bin/planet", "start"}}, pack.Command{Name:"stop", Description:"", Args:[]string{"rootfs/usr/bin/planet", "stop"}}, pack.Command{Name:"enter", Description:"", Args:[]string{"rootfs/usr/bin/planet", "enter"}}, pack.Command{Name:"exec", Description:"", Args:[]string{"rootfs/usr/bin/planet", "exec"}}, pack.Command{Name:"status", Description:"", Args:[]string{"rootfs/usr/bin/planet", "status"}}, pack.Command{Name:"local-status", Description:"", Args:[]string{"rootfs/usr/bin/planet", "status", "--local"}}, pack.Command{Name:"secrets-init", Description:"", Args:[]string{"rootfs/usr/bin/planet", "secrets", "init"}}, pack.Command{Name:"gen-cert", Description:"", Args:[]string{"rootfs/usr/bin/planet", "secrets", "gencert"}}}, Labels:[]pack.Label{pack.Label{Name:"os", Value:"linux"}, pack.Label{Name:"version-etcd", Value:"v3.3.22"}, pack.Label{Name:"version-k8s", Value:"v1.13.12"}, pack.Label{Name:"version-flannel", Value:"v0.10.1-gravitational"}, pack.Label{Name:"version-docker", Value:"18.06.2"}, pack.Label{Name:"version-helm", Value:"v2.12.3"}, pack.Label{Name:"version-coredns", Value:"1.3.1"}}, Service:(*systemservice.NewPackageServiceRequest)(0xc000c3ec40)} package:gravitational.io/planet:5.5.54-11312 pack/utils.go:144
2020-07-29T17:50:45Z INFO             Created new planet configuration. package:wonderfulspence252/planet-config-1016205wonderfulspence252:5.5.54-11312+1596042169 server:ProvisionedServer(hostname=kevin-test3,ip=10.162.0.5) opsservice/update.go:289
2020-07-29T17:50:45Z INFO             Generated new runtime configuration package for node(addr=10.162.0.5,hostname=kevin-test3,role=node,cluster_role=master,runtime(installed=gravitational.io/planet:5.5.47-11312,secrets=wonderfulspence252/planet-10.162.0.5-secrets:5.5.54-11312+1596042169,update(package=gravitational.io/planet:5.5.54-11312,config-package=wonderfulspence252/planet-config-1016205wonderfulspence252:5.5.54-11312+1596042169)),teleport(installed=gravitational.io/teleport:3.0.5),docker(installed={overlay2 [] },update={overlay2 [] })): wonderfulspence252/planet-config-1016205wonderfulspence252:5.5.54-11312+1596042169. phase:/bootstrap/kevin-test1 fsm/logger.go:61
2020-07-29T17:50:45Z DEBU             Node kevin-test1 (10.162.0.7) configured. phases/bootstrap.go:418
2020-07-29T17:50:45Z INFO             Update cluster DNS configuration as 127.0.0.2:53. phase:/bootstrap/kevin-test1 fsm/logger.go:61
2020-07-29T17:50:45Z INFO             Update node address as 10.162.0.7. phase:/bootstrap/kevin-test1 fsm/logger.go:61
2020-07-29T17:50:45Z INFO             Update service user as {ubuntu 1000 1000}. phase:/bootstrap/kevin-test1 fsm/logger.go:61
2020-07-29T17:50:45Z INFO             Synchronize operation plan from cluster. phase:/bootstrap/kevin-test1 fsm/logger.go:61
2020-07-29T17:50:45Z INFO             Pull system updates. phase:/bootstrap/kevin-test1 fsm/logger.go:61
2020-07-29T17:50:45Z INFO             Pulling package update: gravitational.io/gravity:5.5.50-dev.9. phase:/bootstrap/kevin-test1 fsm/logger.go:61
2020-07-29T17:50:45Z INFO [PULL]      Pull package. package:gravitational.io/gravity:5.5.50-dev.9 app/pull.go:204
2020-07-29T17:50:46Z INFO             Pulling package update: wonderfulspence252/planet-10.162.0.7-secrets:5.5.54-11312+1596042169. phase:/bootstrap/kevin-test1 fsm/logger.go:61
2020-07-29T17:50:46Z INFO [PULL]      Pull package. package:wonderfulspence252/planet-10.162.0.7-secrets:5.5.54-11312+1596042169 app/pull.go:204
2020-07-29T17:50:46Z INFO             Unpacking package wonderfulspence252/planet-10.162.0.7-secrets:5.5.54-11312+1596042169. phase:/bootstrap/kevin-test1 fsm/logger.go:61
2020-07-29T17:50:46Z INFO             Unpacking wonderfulspence252/planet-10.162.0.7-secrets:5.5.54-11312+1596042169 into the default directory /var/lib/gravity/local/packages/unpacked/wonderfulspence252/planet-10.162.0.7-secrets/5.5.54-11312+1596042169. pack/utils.go:81
	Still executing "/bootstrap/kevin-test1" locally (10 seconds elapsed)
2020-07-29T17:50:46Z INFO             Pulling package update: gravitational.io/planet:5.5.54-11312. phase:/bootstrap/kevin-test1 fsm/logger.go:61
2020-07-29T17:50:46Z INFO [PULL]      Pull package. package:gravitational.io/planet:5.5.54-11312 app/pull.go:204
2020-07-29T17:50:50Z INFO             Unpacking package gravitational.io/planet:5.5.54-11312. phase:/bootstrap/kevin-test1 fsm/logger.go:61
2020-07-29T17:50:50Z INFO             Unpacking gravitational.io/planet:5.5.54-11312 into the default directory /var/lib/gravity/local/packages/unpacked/gravitational.io/planet/5.5.54-11312. pack/utils.go:81
	Still executing "/bootstrap/kevin-test1" locally (20 seconds elapsed)
	Still executing "/bootstrap/kevin-test1" locally (30 seconds elapsed)
2020-07-29T17:51:09Z INFO             Pulling package update: wonderfulspence252/planet-config-1016207wonderfulspence252:5.5.54-11312+1596042169. phase:/bootstrap/kevin-test1 fsm/logger.go:61
2020-07-29T17:51:09Z INFO [PULL]      Pull package. package:wonderfulspence252/planet-config-1016207wonderfulspence252:5.5.54-11312+1596042169 app/pull.go:204
2020-07-29T17:51:10Z INFO             Unpacking package wonderfulspence252/planet-config-1016207wonderfulspence252:5.5.54-11312+1596042169. phase:/bootstrap/kevin-test1 fsm/logger.go:61
2020-07-29T17:51:10Z INFO             Unpacking wonderfulspence252/planet-config-1016207wonderfulspence252:5.5.54-11312+1596042169 into the default directory /var/lib/gravity/local/packages/unpacked/wonderfulspence252/planet-config-1016207wonderfulspence252/5.5.54-11312+1596042169. pack/utils.go:81
2020-07-29T17:51:10Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/bootstrap/kevin-test1, State=completed) cluster/engine.go:288
2020-07-29T17:51:11Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Wed Jul 29 17:03 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Wed Jul 29 17:16 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Wed Jul 29 17:19 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Wed Jul 29 17:46 UTC
→ bootstrap                    Bootstrap update operation on nodes                        In Progress     -              /checks,/pre-update                           Wed Jul 29 17:51 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Wed Jul 29 17:51 UTC
  * kevin-test2                Bootstrap node \"kevin-test2\"                               Unstarted       10.162.0.6     -                                             -
  * kevin-test3                Bootstrap node \"kevin-test3\"                               Unstarted       10.162.0.5     -                                             -
* coredns                      Provision CoreDNS resources                                Unstarted       -              /bootstrap                                    -
* masters                      Update master nodes                                        Unstarted       -              /coredns                                      -
  * kevin-test1                Update system software on master node \"kevin-test1\"        Unstarted       -              -                                             -
    * kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Unstarted       -              -                                             -
    * stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Unstarted       -              /masters/kevin-test1/kubelet-permissions      -
    * drain                    Drain node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     -
    * system-upgrade           Update system software on node \"kevin-test1\"               Unstarted       10.162.0.7     /masters/kevin-test1/drain                    -
    * taint                    Taint node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test1\"                                Unstarted       10.162.0.7     /masters/kevin-test1/taint                    -
    * untaint                  Remove taint from node \"kevin-test1\"                       Unstarted       10.162.0.7     /masters/kevin-test1/uncordon                 -
  * elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Unstarted       -              /masters/kevin-test1                          -
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted       -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted       10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted       10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted       10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted       10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted       10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted       -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted       -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted       10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted       10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted       10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted       10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted       10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted       -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted       -              -                                             -
  * backup                     Backup etcd data                                           Unstarted       -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted       -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted       -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted       -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted       -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
Wed Jul 29 17:51:11 UTC	Executing phase "/bootstrap/kevin-test1" finished in 35 seconds
```

Notes:
1. Ensures required directories exist on the host, and chowns/chmods the package directories to the planet user
2. Persists some required configuration to the local node database, such as some DNS settings and the Node's advertise IP
3. Pulls packages that will be needed by the node, to the local package store
4. Updates the labelling in the local package store, to identify the packages

New packages will now be available on each node:
```
root@kevin-test1:~/build# ./gravity package list

[festivebrown4906]
------------------

* festivebrown4906/cert-authority:0.0.1 12kB operation-id:2bf0f44d-f9eb-4374-bc1c-0e9937329025,purpose:ca
* festivebrown4906/planet-10.162.0.7-secrets:5.5.47-11312 52kB advertise-ip:10.162.0.7,installed:installed,operation-id:2bf0f44d-f9eb-4374-bc1c-0e9937329025,purpose:planet-secrets
* festivebrown4906/planet-10.162.0.7-secrets:5.5.54-11312+1596339382 52kB advertise-ip:10.162.0.7,operation-id:2bf0f44d-f9eb-4374-bc1c-0e9937329025,purpose:planet-secrets
* festivebrown4906/planet-config-1016207festivebrown4906:5.5.47-11312 4.6kB purpose:planet-config,advertise-ip:10.162.0.7,config-package-for:gravitational.io/planet:0.0.0,installed:installed,operation-id:2bf0f44d-f9eb-4374-bc1c-0e9937329025
* festivebrown4906/planet-config-1016207festivebrown4906:5.5.54-11312+1596339382 4.6kB advertise-ip:10.162.0.7,config-package-for:gravitational.io/planet:0.0.0,operation-id:2bf0f44d-f9eb-4374-bc1c-0e9937329025,purpose:planet-config
* festivebrown4906/site-export:0.0.1 262kB operation-id:2bf0f44d-f9eb-4374-bc1c-0e9937329025,purpose:export
* festivebrown4906/teleport-master-config-1016207festivebrown4906:3.0.5 4.1kB operation-id:2bf0f44d-f9eb-4374-bc1c-0e9937329025,purpose:teleport-master-config,advertise-ip:10.162.0.7
* festivebrown4906/teleport-node-config-1016207festivebrown4906:3.0.5 4.1kB advertise-ip:10.162.0.7,config-package-for:gravitational.io/teleport:0.0.0,installed:installed,operation-id:2bf0f44d-f9eb-4374-bc1c-0e9937329025,purpose:teleport-node-config

[gravitational.io]
------------------

* gravitational.io/bandwagon:5.3.0 68MB
* gravitational.io/dns-app:0.3.0 69MB
* gravitational.io/gravity:5.5.46 101MB installed:installed
* gravitational.io/gravity:5.5.50-dev.9 99MB
* gravitational.io/kubernetes:5.5.46 5.3MB
* gravitational.io/logging-app:5.0.2 151MB
* gravitational.io/monitoring-app:5.5.16 219MB
* gravitational.io/planet:5.5.47-11312 490MB installed:installed,purpose:runtime
* gravitational.io/planet:5.5.54-11312 509MB purpose:runtime
* gravitational.io/rbac-app:5.5.46 5.3MB
* gravitational.io/site:5.5.46 86MB
* gravitational.io/telekube:5.5.46 182MB
* gravitational.io/teleport:3.0.5 32MB installed:installed
* gravitational.io/tiller-app:5.5.2 32MB
* gravitational.io/web-assets:5.5.46 1.2MB
````

Bootstrap the rest of the nodes:
```
root@kevin-test1:~/build# ./gravity plan execute --phase /bootstrap 2>&1 | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'
Wed Jul 29 18:01:01 UTC	Executing "/bootstrap/kevin-test2" on remote node kevin-test2
	Still executing "/bootstrap/kevin-test2" on remote node kevin-test2 (10 seconds elapsed)
	Still executing "/bootstrap/kevin-test2" on remote node kevin-test2 (20 seconds elapsed)
Wed Jul 29 18:01:29 UTC	Executing "/bootstrap/kevin-test3" on remote node kevin-test3
	Still executing "/bootstrap/kevin-test3" on remote node kevin-test3 (10 seconds elapsed)
	Still executing "/bootstrap/kevin-test3" on remote node kevin-test3 (20 seconds elapsed)
Wed Jul 29 18:01:57 UTC	Executing phase "/bootstrap" finished in 56 seconds
```

#### CoreDNS
The CoreDNS phase configures the cluster DNS configuration within kubernetes.
```
root@kevin-test1:~/build# ./gravity --debug plan execute --phase /coredns 2>&1 | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'

...

2020-07-29T18:03:31Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Wed Jul 29 17:03 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Wed Jul 29 17:16 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Wed Jul 29 17:19 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Wed Jul 29 17:46 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Wed Jul 29 18:01 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Wed Jul 29 17:51 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Wed Jul 29 18:01 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Wed Jul 29 18:01 UTC
→ coredns                      Provision CoreDNS resources                                In Progress     -              /bootstrap                                    Wed Jul 29 18:03 UTC
* masters                      Update master nodes                                        Unstarted       -              /coredns                                      -
  * kevin-test1                Update system software on master node \"kevin-test1\"        Unstarted       -              -                                             -
    * kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Unstarted       -              -                                             -
    * stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Unstarted       -              /masters/kevin-test1/kubelet-permissions      -
    * drain                    Drain node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     -
    * system-upgrade           Update system software on node \"kevin-test1\"               Unstarted       10.162.0.7     /masters/kevin-test1/drain                    -
    * taint                    Taint node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test1\"                                Unstarted       10.162.0.7     /masters/kevin-test1/taint                    -
    * untaint                  Remove taint from node \"kevin-test1\"                       Unstarted       10.162.0.7     /masters/kevin-test1/uncordon                 -
  * elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Unstarted       -              /masters/kevin-test1                          -
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted       -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted       10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted       10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted       10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted       10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted       10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted       -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted       -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted       10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted       10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted       10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted       10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted       10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted       -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted       -              -                                             -
  * backup                     Backup etcd data                                           Unstarted       -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted       -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted       -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted       -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted       -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
2020-07-29T18:03:31Z INFO             Executing phase: /coredns. phase:/coredns fsm/logger.go:61
2020-07-29T18:03:31Z DEBU             Dial. addr:leader.telekube.local:6443 network:tcp httplib/client.go:225
2020-07-29T18:03:31Z DEBU             Resolve leader.telekube.local took 640.78µs. utils/dns.go:47
2020-07-29T18:03:31Z DEBU             Resolved leader.telekube.local to 10.162.0.7. utils/dns.go:54
2020-07-29T18:03:31Z DEBU             Dial. host-port:10.162.0.7:6443 httplib/client.go:263
2020-07-29T18:03:31Z INFO             ClusterRoles/gravity:coredns already exists, skiping... phase:/coredns fsm/logger.go:61
2020-07-29T18:03:31Z INFO             ClusterRoleBinding/gravity:coredns already exists, skiping... phase:/coredns fsm/logger.go:61
2020-07-29T18:03:31Z INFO             Generating CoreDNS Corefile. phase:/coredns fsm/logger.go:61
2020-07-29T18:03:31Z DEBU             "Generated corefile:
.:53 {
  reload
  errors
  health
  prometheus :9153
  cache 30
  loop
  reload
  loadbalance
  hosts {
    fallthrough
  }
  kubernetes cluster.local in-addr.arpa ip6.arpa {
    pods verified
    fallthrough in-addr.arpa ip6.arpa
  }
  forward . 169.254.169.254 {
    policy sequential
    health_check 0
  }
}
" phase:/coredns fsm/logger.go:49
2020-07-29T18:03:31Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/coredns, State=completed) cluster/engine.go:288
2020-07-29T18:03:31Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State         Node           Requires                                      Updated
-----                          -----------                                                -----         ----           --------                                      -------
✓ init                         Initialize update operation                                Completed     -              -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed     10.162.0.7     -                                             Wed Jul 29 17:03 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed     10.162.0.6     -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed     10.162.0.5     -                                             Wed Jul 29 17:16 UTC
✓ checks                       Run preflight checks                                       Completed     -              /init                                         Wed Jul 29 17:19 UTC
✓ pre-update                   Run pre-update application hook                            Completed     -              /init,/checks                                 Wed Jul 29 17:46 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed     -              /checks,/pre-update                           Wed Jul 29 18:01 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed     10.162.0.7     -                                             Wed Jul 29 17:51 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed     10.162.0.6     -                                             Wed Jul 29 18:01 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed     10.162.0.5     -                                             Wed Jul 29 18:01 UTC
✓ coredns                      Provision CoreDNS resources                                Completed     -              /bootstrap                                    Wed Jul 29 18:03 UTC
* masters                      Update master nodes                                        Unstarted     -              /coredns                                      -
  * kevin-test1                Update system software on master node \"kevin-test1\"        Unstarted     -              -                                             -
    * kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Unstarted     -              -                                             -
    * stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Unstarted     -              /masters/kevin-test1/kubelet-permissions      -
    * drain                    Drain node \"kevin-test1\"                                   Unstarted     10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     -
    * system-upgrade           Update system software on node \"kevin-test1\"               Unstarted     10.162.0.7     /masters/kevin-test1/drain                    -
    * taint                    Taint node \"kevin-test1\"                                   Unstarted     10.162.0.7     /masters/kevin-test1/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test1\"                                Unstarted     10.162.0.7     /masters/kevin-test1/taint                    -
    * untaint                  Remove taint from node \"kevin-test1\"                       Unstarted     10.162.0.7     /masters/kevin-test1/uncordon                 -
  * elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Unstarted     -              /masters/kevin-test1                          -
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted     -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted     10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted     10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted     10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted     10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted     10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted     10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted     -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted     -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted     10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted     10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted     10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted     10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted     10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted     10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted     -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted     -              -                                             -
  * backup                     Backup etcd data                                           Unstarted     -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted     -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted     -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted     -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted     -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted     -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted     -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted     -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted     -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted     -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted     -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted     -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted     -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted     -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted     -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted     -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted     -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted     -              -                                             -
* config                       Update system configuration on nodes                       Unstarted     -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted     -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted     -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted     -              -                                             -
* runtime                      Update application runtime                                 Unstarted     -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted     -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted     -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted     -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted     -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted     -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted     -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted     -              -                                             -
* app                          Update installed application                               Unstarted     -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted     -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted     -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted     -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted     -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted     -              -                                             -
." fsm/logger.go:49
Wed Jul 29 18:03:31 UTC	Executing phase "/coredns" finished in 1 second
```

Notes:
- If this is the first 5.5 upgrade, creates the RBAC rules and configuration needed for CoreDNS
- Generates / Updates the corefile for coredns, with any new settings that may be required.


#### Node Upgrades (/masters and /workers)
The Masters and Workers groups of subphases are the steps needed to upgrade the planet container on each node in the cluster. This operates as a rolling upgrade strategy, where one node at a time is cordoned and drained, upgraded to the new version of planet, restarted, etc. Each node is done in sequence, so other than
moving software around the cluster the application and cluster largely remain online.

#### Nodes: Kubelet Permissions
Ensures kubelet RBAC permissions within kubernetes are up to date.

When planet restarts, it will launch a new version of kubelet, which we want to ensure any new requirements are written to kubernetes.

```
root@kevin-test1:~/build# ./gravity --debug plan execute --phase /masters/kevin-test1/kubelet-permissions 2>&1 | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'

...

2020-07-29T18:08:21Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Wed Jul 29 17:03 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Wed Jul 29 17:16 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Wed Jul 29 17:19 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Wed Jul 29 17:46 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Wed Jul 29 18:01 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Wed Jul 29 17:51 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Wed Jul 29 18:01 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Wed Jul 29 18:01 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Wed Jul 29 18:03 UTC
→ masters                      Update master nodes                                        In Progress     -              /coredns                                      Wed Jul 29 18:08 UTC
  → kevin-test1                Update system software on master node \"kevin-test1\"        In Progress     -              -                                             Wed Jul 29 18:08 UTC
    → kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                In Progress     -              -                                             Wed Jul 29 18:08 UTC
    * stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Unstarted       -              /masters/kevin-test1/kubelet-permissions      -
    * drain                    Drain node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     -
    * system-upgrade           Update system software on node \"kevin-test1\"               Unstarted       10.162.0.7     /masters/kevin-test1/drain                    -
    * taint                    Taint node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test1\"                                Unstarted       10.162.0.7     /masters/kevin-test1/taint                    -
    * untaint                  Remove taint from node \"kevin-test1\"                       Unstarted       10.162.0.7     /masters/kevin-test1/uncordon                 -
  * elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Unstarted       -              /masters/kevin-test1                          -
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted       -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted       10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted       10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted       10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted       10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted       10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted       -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted       -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted       10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted       10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted       10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted       10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted       10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted       -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted       -              -                                             -
  * backup                     Backup etcd data                                           Unstarted       -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted       -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted       -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted       -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted       -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
2020-07-29T18:08:21Z INFO             Executing phase: /masters/kevin-test1/kubelet-permissions. phase:/masters/kevin-test1/kubelet-permissions fsm/logger.go:61
2020-07-29T18:08:21Z INFO             Update kubelet perrmissiong on node(addr=10.162.0.7, hostname=kevin-test1, role=node, cluster_role=master). phase:/masters/kevin-test1/kubelet-permissions fsm/logger.go:61
2020-07-29T18:08:21Z DEBU             Dial. addr:leader.telekube.local:6443 network:tcp httplib/client.go:225
2020-07-29T18:08:21Z DEBU             Resolve leader.telekube.local took 226.238µs. utils/dns.go:47
2020-07-29T18:08:21Z DEBU             Resolved leader.telekube.local to 10.162.0.7. utils/dns.go:54
2020-07-29T18:08:21Z DEBU             Dial. host-port:10.162.0.7:6443 httplib/client.go:263
2020-07-29T18:08:21Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/masters/kevin-test1/kubelet-permissions, State=completed) cluster/engine.go:288
2020-07-29T18:08:21Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Wed Jul 29 17:03 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Wed Jul 29 17:16 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Wed Jul 29 17:19 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Wed Jul 29 17:46 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Wed Jul 29 18:01 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Wed Jul 29 17:51 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Wed Jul 29 18:01 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Wed Jul 29 18:01 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Wed Jul 29 18:03 UTC
→ masters                      Update master nodes                                        In Progress     -              /coredns                                      Wed Jul 29 18:08 UTC
  → kevin-test1                Update system software on master node \"kevin-test1\"        In Progress     -              -                                             Wed Jul 29 18:08 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Wed Jul 29 18:08 UTC
    * stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Unstarted       -              /masters/kevin-test1/kubelet-permissions      -
    * drain                    Drain node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     -
    * system-upgrade           Update system software on node \"kevin-test1\"               Unstarted       10.162.0.7     /masters/kevin-test1/drain                    -
    * taint                    Taint node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test1\"                                Unstarted       10.162.0.7     /masters/kevin-test1/taint                    -
    * untaint                  Remove taint from node \"kevin-test1\"                       Unstarted       10.162.0.7     /masters/kevin-test1/uncordon                 -
  * elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Unstarted       -              /masters/kevin-test1                          -
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted       -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted       10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted       10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted       10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted       10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted       10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted       -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted       -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted       10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted       10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted       10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted       10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted       10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted       -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted       -              -                                             -
  * backup                     Backup etcd data                                           Unstarted       -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted       -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted       -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted       -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted       -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
Wed Jul 29 18:08:21 UTC	Executing phase "/masters/kevin-test1/kubelet-permissions" finished in 1 second
```

#### Nodes: Stepdown (Masters Only)
Makes sure the particular node is not elected leader of the cluster during the upgrade. Instead the node is removed from the election
pool while it is being disrupted, and is finally re-added later.

```
root@kevin-test1:~/build# ./gravity --debug plan execute --phase /masters/kevin-test1/stepdown-kevin-test1 2>&1 | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'

...

2020-07-29T18:11:02Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Wed Jul 29 17:03 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Wed Jul 29 17:16 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Wed Jul 29 17:19 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Wed Jul 29 17:46 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Wed Jul 29 18:01 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Wed Jul 29 17:51 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Wed Jul 29 18:01 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Wed Jul 29 18:01 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Wed Jul 29 18:03 UTC
→ masters                      Update master nodes                                        In Progress     -              /coredns                                      Wed Jul 29 18:11 UTC
  → kevin-test1                Update system software on master node \"kevin-test1\"        In Progress     -              -                                             Wed Jul 29 18:11 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Wed Jul 29 18:08 UTC
    → stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               In Progress     -              /masters/kevin-test1/kubelet-permissions      Wed Jul 29 18:11 UTC
    * drain                    Drain node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     -
    * system-upgrade           Update system software on node \"kevin-test1\"               Unstarted       10.162.0.7     /masters/kevin-test1/drain                    -
    * taint                    Taint node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test1\"                                Unstarted       10.162.0.7     /masters/kevin-test1/taint                    -
    * untaint                  Remove taint from node \"kevin-test1\"                       Unstarted       10.162.0.7     /masters/kevin-test1/uncordon                 -
  * elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Unstarted       -              /masters/kevin-test1                          -
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted       -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted       10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted       10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted       10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted       10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted       10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted       -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted       -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted       10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted       10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted       10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted       10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted       10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted       -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted       -              -                                             -
  * backup                     Backup etcd data                                           Unstarted       -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted       -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted       -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted       -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted       -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
2020-07-29T18:11:02Z INFO             Executing phase: /masters/kevin-test1/stepdown-kevin-test1. phase:/masters/kevin-test1/stepdown-kevin-test1 fsm/logger.go:61
2020-07-29T18:11:02Z DEBU             Executing command: [/home/knisbet/build/gravity planet enter -- --notty /usr/bin/etcdctl -- set /planet/cluster/wonderfulspence252/election/10.162.0.7 false]. fsm/rpc.go:217
2020-07-29T18:11:02Z INFO             Wait for new leader election. phase:/masters/kevin-test1/stepdown-kevin-test1 fsm/logger.go:61
2020-07-29T18:11:02Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/masters/kevin-test1/stepdown-kevin-test1, State=completed) cluster/engine.go:288
2020-07-29T18:11:02Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Wed Jul 29 17:03 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Wed Jul 29 17:16 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Wed Jul 29 17:19 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Wed Jul 29 17:46 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Wed Jul 29 18:01 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Wed Jul 29 17:51 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Wed Jul 29 18:01 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Wed Jul 29 18:01 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Wed Jul 29 18:03 UTC
→ masters                      Update master nodes                                        In Progress     -              /coredns                                      Wed Jul 29 18:11 UTC
  → kevin-test1                Update system software on master node \"kevin-test1\"        In Progress     -              -                                             Wed Jul 29 18:11 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Wed Jul 29 18:08 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Wed Jul 29 18:11 UTC
    * drain                    Drain node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     -
    * system-upgrade           Update system software on node \"kevin-test1\"               Unstarted       10.162.0.7     /masters/kevin-test1/drain                    -
    * taint                    Taint node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test1\"                                Unstarted       10.162.0.7     /masters/kevin-test1/taint                    -
    * untaint                  Remove taint from node \"kevin-test1\"                       Unstarted       10.162.0.7     /masters/kevin-test1/uncordon                 -
  * elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Unstarted       -              /masters/kevin-test1                          -
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted       -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted       10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted       10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted       10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted       10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted       10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted       -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted       -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted       10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted       10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted       10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted       10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted       10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted       -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted       -              -                                             -
  * backup                     Backup etcd data                                           Unstarted       -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted       -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted       -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted       -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted       -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
Wed Jul 29 18:11:02 UTC	Executing phase "/masters/kevin-test1/stepdown-kevin-test1" finished in 1 second
```

#### Nodes: Drain
Drains the node of running pods, having kubernetes reschedule the application on other nodes within the cluster. This is equivelant to using kubectl to drain a node, where the node will be left in a SchedulingDisabled state.

```
root@kevin-test1:~/build# ./gravity --debug plan execute --phase /masters/kevin-test1/drain 2>&1 | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'

...

2020-07-29T18:13:15Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Wed Jul 29 17:03 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Wed Jul 29 17:16 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Wed Jul 29 17:19 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Wed Jul 29 17:46 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Wed Jul 29 18:01 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Wed Jul 29 17:51 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Wed Jul 29 18:01 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Wed Jul 29 18:01 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Wed Jul 29 18:03 UTC
→ masters                      Update master nodes                                        In Progress     -              /coredns                                      Wed Jul 29 18:13 UTC
  → kevin-test1                Update system software on master node \"kevin-test1\"        In Progress     -              -                                             Wed Jul 29 18:13 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Wed Jul 29 18:08 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Wed Jul 29 18:11 UTC
    → drain                    Drain node \"kevin-test1\"                                   In Progress     10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Wed Jul 29 18:13 UTC
    * system-upgrade           Update system software on node \"kevin-test1\"               Unstarted       10.162.0.7     /masters/kevin-test1/drain                    -
    * taint                    Taint node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test1\"                                Unstarted       10.162.0.7     /masters/kevin-test1/taint                    -
    * untaint                  Remove taint from node \"kevin-test1\"                       Unstarted       10.162.0.7     /masters/kevin-test1/uncordon                 -
  * elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Unstarted       -              /masters/kevin-test1                          -
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted       -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted       10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted       10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted       10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted       10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted       10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted       -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted       -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted       10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted       10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted       10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted       10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted       10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted       -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted       -              -                                             -
  * backup                     Backup etcd data                                           Unstarted       -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted       -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted       -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted       -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted       -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
2020-07-29T18:13:15Z INFO             Executing phase: /masters/kevin-test1/drain. phase:/masters/kevin-test1/drain fsm/logger.go:61
2020-07-29T18:13:15Z INFO             Drain node(addr=10.162.0.7, hostname=kevin-test1, role=node, cluster_role=master). phase:/masters/kevin-test1/drain fsm/logger.go:61
2020-07-29T18:13:15Z DEBU             Dial. addr:leader.telekube.local:6443 network:tcp httplib/client.go:225
2020-07-29T18:13:15Z DEBU             Resolve leader.telekube.local took 2.533654ms. utils/dns.go:47
2020-07-29T18:13:15Z DEBU             Resolved leader.telekube.local to 10.162.0.6. utils/dns.go:54
2020-07-29T18:13:15Z DEBU             Dial. host-port:10.162.0.6:6443 httplib/client.go:263
2020-07-29T18:13:15Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [monitoring/telegraf-5d8cf5c4dd-7hf9x]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [monitoring/telegraf-5d8cf5c4dd-7hf9x]] utils/retry.go:238
2020-07-29T18:13:15Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [monitoring/heapster-b9c64655f-nxzzm]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [monitoring/heapster-b9c64655f-nxzzm]] utils/retry.go:238
2020-07-29T18:13:15Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [kube-system/tiller-deploy-69d9fd98d-qvtsl]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [kube-system/tiller-deploy-69d9fd98d-qvtsl]] utils/retry.go:238
2020-07-29T18:13:15Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [kube-system/bandwagon-6c4b5b5c76-6dptd]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [kube-system/bandwagon-6c4b5b5c76-6dptd]] utils/retry.go:238
2020-07-29T18:13:15Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [monitoring/influxdb-677c446f6f-5cvs6]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [monitoring/influxdb-677c446f6f-5cvs6]] utils/retry.go:238
2020-07-29T18:13:15Z DEBU             evicted name:tiller-app-bootstrap-45a43a-x46sk namespace:kube-system kubernetes/drain.go:263
2020-07-29T18:13:15Z DEBU             evicted name:logging-app-bootstrap-613776-rtrzj namespace:kube-system kubernetes/drain.go:263
2020-07-29T18:13:15Z DEBU             evicted name:site-app-post-install-e51cda-rwj69 namespace:kube-system kubernetes/drain.go:263
2020-07-29T18:13:15Z DEBU             evicted name:dns-app-install-96d05e-7ftfq namespace:kube-system kubernetes/drain.go:263
2020-07-29T18:13:15Z DEBU             evicted name:monitoring-app-install-274a03-84pwr namespace:kube-system kubernetes/drain.go:263
2020-07-29T18:13:16Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [kube-system/log-collector-697d94486-pntnj]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [kube-system/log-collector-697d94486-pntnj]] utils/retry.go:238
2020-07-29T18:13:16Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [monitoring/grafana-856cc8cd9-wl9zq]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [monitoring/grafana-856cc8cd9-wl9zq]] utils/retry.go:238
2020-07-29T18:13:16Z DEBU             evicted name:gravity-install-9f775b-b78b5 namespace:kube-system kubernetes/drain.go:263
2020-07-29T18:13:16Z DEBU             evicted name:bandwagon-install-b82aad-2dmhp namespace:kube-system kubernetes/drain.go:263
2020-07-29T18:13:16Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [monitoring/kapacitor-6c47999-fgnfp]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [monitoring/kapacitor-6c47999-fgnfp]] utils/retry.go:238
2020-07-29T18:13:17Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [monitoring/telegraf-5d8cf5c4dd-7hf9x]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [monitoring/telegraf-5d8cf5c4dd-7hf9x]] utils/retry.go:238
2020-07-29T18:13:17Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [monitoring/heapster-b9c64655f-nxzzm]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [monitoring/heapster-b9c64655f-nxzzm]] utils/retry.go:238
2020-07-29T18:13:17Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [kube-system/tiller-deploy-69d9fd98d-qvtsl]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [kube-system/tiller-deploy-69d9fd98d-qvtsl]] utils/retry.go:238
2020-07-29T18:13:17Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [kube-system/bandwagon-6c4b5b5c76-6dptd]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [kube-system/bandwagon-6c4b5b5c76-6dptd]] utils/retry.go:238
2020-07-29T18:13:17Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [monitoring/influxdb-677c446f6f-5cvs6]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [monitoring/influxdb-677c446f6f-5cvs6]] utils/retry.go:238
2020-07-29T18:13:18Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [kube-system/log-collector-697d94486-pntnj]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [kube-system/log-collector-697d94486-pntnj]] utils/retry.go:238
2020-07-29T18:13:18Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [monitoring/grafana-856cc8cd9-wl9zq]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [monitoring/grafana-856cc8cd9-wl9zq]] utils/retry.go:238
2020-07-29T18:13:18Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [monitoring/kapacitor-6c47999-fgnfp]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [monitoring/kapacitor-6c47999-fgnfp]] utils/retry.go:238
2020-07-29T18:13:18Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [monitoring/telegraf-5d8cf5c4dd-7hf9x]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [monitoring/telegraf-5d8cf5c4dd-7hf9x]] utils/retry.go:238
2020-07-29T18:13:18Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [monitoring/heapster-b9c64655f-nxzzm]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [monitoring/heapster-b9c64655f-nxzzm]] utils/retry.go:238
2020-07-29T18:13:19Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [kube-system/tiller-deploy-69d9fd98d-qvtsl]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [kube-system/tiller-deploy-69d9fd98d-qvtsl]] utils/retry.go:238
2020-07-29T18:13:19Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [kube-system/bandwagon-6c4b5b5c76-6dptd]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [kube-system/bandwagon-6c4b5b5c76-6dptd]] utils/retry.go:238
2020-07-29T18:13:19Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [monitoring/influxdb-677c446f6f-5cvs6]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [monitoring/influxdb-677c446f6f-5cvs6]] utils/retry.go:238
2020-07-29T18:13:19Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [kube-system/log-collector-697d94486-pntnj]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [kube-system/log-collector-697d94486-pntnj]] utils/retry.go:238
2020-07-29T18:13:19Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [monitoring/grafana-856cc8cd9-wl9zq]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [monitoring/grafana-856cc8cd9-wl9zq]] utils/retry.go:238
2020-07-29T18:13:20Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [monitoring/kapacitor-6c47999-fgnfp]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [monitoring/kapacitor-6c47999-fgnfp]] utils/retry.go:238
2020-07-29T18:13:20Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [monitoring/telegraf-5d8cf5c4dd-7hf9x]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [monitoring/telegraf-5d8cf5c4dd-7hf9x]] utils/retry.go:238
2020-07-29T18:13:20Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [monitoring/heapster-b9c64655f-nxzzm]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [monitoring/heapster-b9c64655f-nxzzm]] utils/retry.go:238
2020-07-29T18:13:20Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [kube-system/tiller-deploy-69d9fd98d-qvtsl]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [kube-system/tiller-deploy-69d9fd98d-qvtsl]] utils/retry.go:238
2020-07-29T18:13:20Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [kube-system/bandwagon-6c4b5b5c76-6dptd]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [kube-system/bandwagon-6c4b5b5c76-6dptd]] utils/retry.go:238
2020-07-29T18:13:21Z DEBU             evicted name:influxdb-677c446f6f-5cvs6 namespace:monitoring kubernetes/drain.go:263
2020-07-29T18:13:21Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [kube-system/log-collector-697d94486-pntnj]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [kube-system/log-collector-697d94486-pntnj]] utils/retry.go:238
2020-07-29T18:13:21Z DEBU             evicted name:grafana-856cc8cd9-wl9zq namespace:monitoring kubernetes/drain.go:263
2020-07-29T18:13:21Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [monitoring/kapacitor-6c47999-fgnfp]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [monitoring/kapacitor-6c47999-fgnfp]] utils/retry.go:238
2020-07-29T18:13:21Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [monitoring/telegraf-5d8cf5c4dd-7hf9x]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [monitoring/telegraf-5d8cf5c4dd-7hf9x]] utils/retry.go:238
2020-07-29T18:13:22Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [monitoring/heapster-b9c64655f-nxzzm]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [monitoring/heapster-b9c64655f-nxzzm]] utils/retry.go:238
2020-07-29T18:13:22Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [kube-system/tiller-deploy-69d9fd98d-qvtsl]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [kube-system/tiller-deploy-69d9fd98d-qvtsl]] utils/retry.go:238
2020-07-29T18:13:22Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [kube-system/bandwagon-6c4b5b5c76-6dptd]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [kube-system/bandwagon-6c4b5b5c76-6dptd]] utils/retry.go:238
2020-07-29T18:13:22Z DEBU             evicted name:log-collector-697d94486-pntnj namespace:kube-system kubernetes/drain.go:263
2020-07-29T18:13:22Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [monitoring/kapacitor-6c47999-fgnfp]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [monitoring/kapacitor-6c47999-fgnfp]] utils/retry.go:238
2020-07-29T18:13:23Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [monitoring/telegraf-5d8cf5c4dd-7hf9x]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [monitoring/telegraf-5d8cf5c4dd-7hf9x]] utils/retry.go:238
2020-07-29T18:13:23Z DEBU             evicted name:heapster-b9c64655f-nxzzm namespace:monitoring kubernetes/drain.go:263
2020-07-29T18:13:23Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [kube-system/tiller-deploy-69d9fd98d-qvtsl]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [kube-system/tiller-deploy-69d9fd98d-qvtsl]] utils/retry.go:238
2020-07-29T18:13:23Z DEBU             evicted name:bandwagon-6c4b5b5c76-6dptd namespace:kube-system kubernetes/drain.go:263
2020-07-29T18:13:23Z DEBU             evicted name:kapacitor-6c47999-fgnfp namespace:monitoring kubernetes/drain.go:263
2020-07-29T18:13:24Z INFO             Retrying in 1s. error:[
ERROR REPORT:
Original Error: *trace.RetryError pending pods: [monitoring/telegraf-5d8cf5c4dd-7hf9x]
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:274 github.com/gravitational/gravity/lib/kubernetes.waitForDelete.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:256 github.com/gravitational/gravity/lib/kubernetes.waitForDelete
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:120 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPodAndWait
	/gopath/src/github.com/gravitational/gravity/lib/kubernetes/drain.go:82 github.com/gravitational/gravity/lib/kubernetes.(*drain).evictPods.func1
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: pending pods: [monitoring/telegraf-5d8cf5c4dd-7hf9x]] utils/retry.go:238
2020-07-29T18:13:24Z DEBU             evicted name:tiller-deploy-69d9fd98d-qvtsl namespace:kube-system kubernetes/drain.go:263
	Still executing "/masters/kevin-test1/drain" locally (10 seconds elapsed)
2020-07-29T18:13:25Z DEBU             evicted name:telegraf-5d8cf5c4dd-7hf9x namespace:monitoring kubernetes/drain.go:263
2020-07-29T18:13:25Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/masters/kevin-test1/drain, State=completed) cluster/engine.go:288
2020-07-29T18:13:25Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Wed Jul 29 17:03 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Wed Jul 29 17:16 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Wed Jul 29 17:19 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Wed Jul 29 17:46 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Wed Jul 29 18:01 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Wed Jul 29 17:51 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Wed Jul 29 18:01 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Wed Jul 29 18:01 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Wed Jul 29 18:03 UTC
→ masters                      Update master nodes                                        In Progress     -              /coredns                                      Wed Jul 29 18:13 UTC
  → kevin-test1                Update system software on master node \"kevin-test1\"        In Progress     -              -                                             Wed Jul 29 18:13 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Wed Jul 29 18:08 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Wed Jul 29 18:11 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Wed Jul 29 18:13 UTC
    * system-upgrade           Update system software on node \"kevin-test1\"               Unstarted       10.162.0.7     /masters/kevin-test1/drain                    -
    * taint                    Taint node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test1\"                                Unstarted       10.162.0.7     /masters/kevin-test1/taint                    -
    * untaint                  Remove taint from node \"kevin-test1\"                       Unstarted       10.162.0.7     /masters/kevin-test1/uncordon                 -
  * elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Unstarted       -              /masters/kevin-test1                          -
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted       -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted       10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted       10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted       10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted       10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted       10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted       -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted       -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted       10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted       10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted       10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted       10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted       10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted       -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted       -              -                                             -
  * backup                     Backup etcd data                                           Unstarted       -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted       -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted       -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted       -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted       -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
Wed Jul 29 18:13:25 UTC	Executing phase "/masters/kevin-test1/drain" finished in 11 seconds
```

```
root@kevin-test1:~/build# kubectl get nodes
NAME          STATUS                     ROLES    AGE   VERSION
10.162.0.7    Ready,SchedulingDisabled   <none>   85m   v1.13.12
kevin-test2   Ready                      <none>   81m   v1.13.12
kevin-test3   Ready                      <none>   79m   v1.13.12
```

#### Nodes: System-upgrade
The System Upgrade phase is where we physically restart the planet container on the new version of kubernetes, and wait for the startup to be healthy. Failures at this phase can sometimes be triggered by planet services not starting, due to some unforseen system cause. So checking and walking through the health of planet services can be important here.

```
root@kevin-test1:~/build# ./gravity --debug plan execute --phase /masters/kevin-test1/system-upgrade 2>&1 | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'

...

2020-07-29T18:16:29Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Wed Jul 29 17:03 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Wed Jul 29 17:16 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Wed Jul 29 17:19 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Wed Jul 29 17:46 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Wed Jul 29 18:01 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Wed Jul 29 17:51 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Wed Jul 29 18:01 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Wed Jul 29 18:01 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Wed Jul 29 18:03 UTC
→ masters                      Update master nodes                                        In Progress     -              /coredns                                      Wed Jul 29 18:16 UTC
  → kevin-test1                Update system software on master node \"kevin-test1\"        In Progress     -              -                                             Wed Jul 29 18:16 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Wed Jul 29 18:08 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Wed Jul 29 18:11 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Wed Jul 29 18:13 UTC
    → system-upgrade           Update system software on node \"kevin-test1\"               In Progress     10.162.0.7     /masters/kevin-test1/drain                    Wed Jul 29 18:16 UTC
    * taint                    Taint node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test1\"                                Unstarted       10.162.0.7     /masters/kevin-test1/taint                    -
    * untaint                  Remove taint from node \"kevin-test1\"                       Unstarted       10.162.0.7     /masters/kevin-test1/uncordon                 -
  * elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Unstarted       -              /masters/kevin-test1                          -
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted       -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted       10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted       10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted       10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted       10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted       10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted       -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted       -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted       10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted       10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted       10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted       10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted       10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted       -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted       -              -                                             -
  * backup                     Backup etcd data                                           Unstarted       -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted       -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted       -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted       -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted       -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
2020-07-29T18:16:29Z INFO             Executing phase: /masters/kevin-test1/system-upgrade. phase:/masters/kevin-test1/system-upgrade fsm/logger.go:61
2020-07-29T18:16:29Z INFO [SYSTEM-UP] Checking for update. package:{gravitational.io/planet:5.5.47-11312 gravitational.io/planet:5.5.54-11312 map[purpose:runtime] update(wonderfulspence252/planet-config-1016207wonderfulspence252:5.5.47-11312 -> wonderfulspence252/planet-config-1016207wonderfulspence252:5.5.54-11312+1596042169) false} system/system.go:61
2020-07-29T18:16:29Z INFO [SYSTEM-UP] Found update. package:update(gravitational.io/planet:5.5.47-11312 -> gravitational.io/planet:5.5.54-11312, config:wonderfulspence252/planet-config-1016207wonderfulspence252:5.5.47-11312 -> wonderfulspence252/planet-config-1016207wonderfulspence252:5.5.54-11312+1596042169) system/system.go:70
2020-07-29T18:16:29Z INFO [SYSTEM-UP] Checking for update. package:{ gravitational.io/gravity:5.5.50-dev.9 map[] <nil> false} system/system.go:61
2020-07-29T18:16:29Z INFO [SYSTEM-UP] Found update. package:update(gravitational.io/gravity:5.5.46 -> gravitational.io/gravity:5.5.50-dev.9) system/system.go:70
2020-07-29T18:16:29Z INFO [SYSTEM-UP] Checking for update. package:{ wonderfulspence252/planet-10.162.0.7-secrets:5.5.54-11312+1596042169 map[purpose:planet-secrets] <nil> false} system/system.go:61
2020-07-29T18:16:29Z INFO [SYSTEM-UP] Found update. package:update(wonderfulspence252/planet-10.162.0.7-secrets:5.5.47-11312 -> wonderfulspence252/planet-10.162.0.7-secrets:5.5.54-11312+1596042169) system/system.go:70
2020-07-29T18:16:29Z INFO [SYSTEM-UP] Applying. update:{gravitational.io/planet:5.5.47-11312 gravitational.io/planet:5.5.54-11312 map[purpose:runtime] update(wonderfulspence252/planet-config-1016207wonderfulspence252:5.5.47-11312 -> wonderfulspence252/planet-config-1016207wonderfulspence252:5.5.54-11312+1596042169) false} system/system.go:258
2020-07-29T18:16:29Z INFO [SYSTEM-UP] Reinstalling package. update:{gravitational.io/planet:5.5.47-11312 gravitational.io/planet:5.5.54-11312 map[purpose:runtime] update(wonderfulspence252/planet-config-1016207wonderfulspence252:5.5.47-11312 -> wonderfulspence252/planet-config-1016207wonderfulspence252:5.5.54-11312+1596042169) false} system/system.go:238
2020-07-29T18:16:29Z INFO             Package is already unpacked. package:gravitational.io/planet:5.5.54-11312 localpack/packageserver.go:405
2020-07-29T18:16:29Z INFO [SYSTEM]    systemctl list-units --plain --no-legend --no-pager cmderr:false errmsg: stderr: stdout:"proc-sys-fs-binfmt_misc.automount                                                           loaded active     running         Arbitrary Executable File Formats File System Automount Point
sys-devices-pci0000:00-0000:00:03.0-virtio0-host0-target0:0:1-0:0:1:0-block-sda-sda1.device loaded active     plugged         PersistentDisk cloudimg-rootfs
sys-devices-pci0000:00-0000:00:03.0-virtio0-host0-target0:0:1-0:0:1:0-block-sda.device      loaded active     plugged         PersistentDisk
sys-devices-pci0000:00-0000:00:03.0-virtio0-host0-target0:0:2-0:0:2:0-block-sdb-sdb1.device loaded active     plugged         PersistentDisk 1
sys-devices-pci0000:00-0000:00:03.0-virtio0-host0-target0:0:2-0:0:2:0-block-sdb.device      loaded active     plugged         PersistentDisk
sys-devices-pci0000:00-0000:00:04.0-virtio1-net-ens4.device                                 loaded active     plugged         Virtio network device
sys-devices-platform-serial8250-tty-ttyS10.device                                           loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS10
sys-devices-platform-serial8250-tty-ttyS11.device                                           loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS11
sys-devices-platform-serial8250-tty-ttyS12.device                                           loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS12
sys-devices-platform-serial8250-tty-ttyS13.device                                           loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS13
sys-devices-platform-serial8250-tty-ttyS14.device                                           loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS14
sys-devices-platform-serial8250-tty-ttyS15.device                                           loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS15
sys-devices-platform-serial8250-tty-ttyS16.device                                           loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS16
sys-devices-platform-serial8250-tty-ttyS17.device                                           loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS17
sys-devices-platform-serial8250-tty-ttyS18.device                                           loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS18
sys-devices-platform-serial8250-tty-ttyS19.device                                           loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS19
sys-devices-platform-serial8250-tty-ttyS20.device                                           loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS20
sys-devices-platform-serial8250-tty-ttyS21.device                                           loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS21
sys-devices-platform-serial8250-tty-ttyS22.device                                           loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS22
sys-devices-platform-serial8250-tty-ttyS23.device                                           loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS23
sys-devices-platform-serial8250-tty-ttyS24.device                                           loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS24
sys-devices-platform-serial8250-tty-ttyS25.device                                           loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS25
sys-devices-platform-serial8250-tty-ttyS26.device                                           loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS26
sys-devices-platform-serial8250-tty-ttyS27.device                                           loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS27
sys-devices-platform-serial8250-tty-ttyS28.device                                           loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS28
sys-devices-platform-serial8250-tty-ttyS29.device                                           loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS29
sys-devices-platform-serial8250-tty-ttyS30.device                                           loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS30
sys-devices-platform-serial8250-tty-ttyS31.device                                           loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS31
sys-devices-platform-serial8250-tty-ttyS4.device                                            loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS4
sys-devices-platform-serial8250-tty-ttyS5.device                                            loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS5
sys-devices-platform-serial8250-tty-ttyS6.device                                            loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS6
sys-devices-platform-serial8250-tty-ttyS7.device                                            loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS7
sys-devices-platform-serial8250-tty-ttyS8.device                                            loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS8
sys-devices-platform-serial8250-tty-ttyS9.device                                            loaded active     plugged         /sys/devices/platform/serial8250/tty/ttyS9
sys-devices-pnp0-00:03-tty-ttyS0.device                                                     loaded active     plugged         /sys/devices/pnp0/00:03/tty/ttyS0
sys-devices-pnp0-00:04-tty-ttyS1.device                                                     loaded active     plugged         /sys/devices/pnp0/00:04/tty/ttyS1
sys-devices-pnp0-00:05-tty-ttyS2.device                                                     loaded active     plugged         /sys/devices/pnp0/00:05/tty/ttyS2
sys-devices-pnp0-00:06-tty-ttyS3.device                                                     loaded active     plugged         /sys/devices/pnp0/00:06/tty/ttyS3
sys-devices-virtual-misc-rfkill.device                                                      loaded active     plugged         /sys/devices/virtual/misc/rfkill
sys-devices-virtual-net-cni0.device                                                         loaded active     plugged         /sys/devices/virtual/net/cni0
sys-devices-virtual-net-dummy0.device                                                       loaded active     plugged         /sys/devices/virtual/net/dummy0
sys-devices-virtual-net-flannel.1.device                                                    loaded active     plugged         /sys/devices/virtual/net/flannel.1
sys-devices-virtual-net-flannel.null.device                                                 loaded active     plugged         /sys/devices/virtual/net/flannel.null
sys-devices-virtual-net-veth038bf979.device                                                 loaded active     plugged         /sys/devices/virtual/net/veth038bf979
sys-devices-virtual-net-veth84deee1f.device                                                 loaded active     plugged         /sys/devices/virtual/net/veth84deee1f
sys-devices-virtual-net-veth9d6829ed.device                                                 loaded active     plugged         /sys/devices/virtual/net/veth9d6829ed
sys-devices-virtual-net-vethab5cdf8b.device                                                 loaded active     plugged         /sys/devices/virtual/net/vethab5cdf8b
sys-devices-virtual-tty-ttyprintk.device                                                    loaded active     plugged         /sys/devices/virtual/tty/ttyprintk
sys-module-configfs.device                                                                  loaded active     plugged         /sys/module/configfs
sys-module-fuse.device                                                                      loaded active     plugged         /sys/module/fuse
sys-subsystem-net-devices-cni0.device                                                       loaded active     plugged         /sys/subsystem/net/devices/cni0
sys-subsystem-net-devices-dummy0.device                                                     loaded active     plugged         /sys/subsystem/net/devices/dummy0
sys-subsystem-net-devices-ens4.device                                                       loaded active     plugged         Virtio network device
sys-subsystem-net-devices-flannel.1.device                                                  loaded active     plugged         /sys/subsystem/net/devices/flannel.1
sys-subsystem-net-devices-flannel.null.device                                               loaded active     plugged         /sys/subsystem/net/devices/flannel.null
sys-subsystem-net-devices-veth038bf979.device                                               loaded active     plugged         /sys/subsystem/net/devices/veth038bf979
sys-subsystem-net-devices-veth84deee1f.device                                               loaded active     plugged         /sys/subsystem/net/devices/veth84deee1f
sys-subsystem-net-devices-veth9d6829ed.device                                               loaded active     plugged         /sys/subsystem/net/devices/veth9d6829ed
sys-subsystem-net-devices-vethab5cdf8b.device                                               loaded active     plugged         /sys/subsystem/net/devices/vethab5cdf8b
-.mount                                                                                     loaded active     mounted         /
dev-hugepages.mount                                                                         loaded active     mounted         Huge Pages File System
dev-mqueue.mount                                                                            loaded active     mounted         POSIX Message Queue File System
proc-sys-fs-binfmt_misc.mount                                                               loaded active     mounted         Arbitrary Executable File Formats File System
run-rpc_pipefs.mount                                                                        loaded active     mounted         RPC Pipe File System
run-user-1001.mount                                                                         loaded active     mounted         /run/user/1001
sys-fs-fuse-connections.mount                                                               loaded active     mounted         FUSE Control File System
sys-kernel-config.mount                                                                     loaded active     mounted         Configuration File System
sys-kernel-debug.mount                                                                      loaded active     mounted         Debug File System
var-lib-lxcfs.mount                                                                         loaded active     mounted         /var/lib/lxcfs
acpid.path                                                                                  loaded active     running         ACPI Events Check
systemd-ask-password-console.path                                                           loaded active     waiting         Dispatch Password Requests to Console Directory Watch
systemd-ask-password-wall.path                                                              loaded active     waiting         Forward Password Requests to Wall Directory Watch
systemd-networkd-resolvconf-update.path                                                     loaded active     waiting         Trigger resolvconf update for networkd DNS
init.scope                                                                                  loaded active     running         System and Service Manager
session-1.scope                                                                             loaded active     running         Session 1 of user knisbet
session-3.scope                                                                             loaded active     running         Session 3 of user knisbet
session-4.scope                                                                             loaded active     running         Session 4 of user knisbet
accounts-daemon.service                                                                     loaded active     running         Accounts Service
acpid.service                                                                               loaded active     running         ACPI event daemon
apparmor.service                                                                            loaded active     exited          LSB: AppArmor initialization
apport.service                                                                              loaded active     exited          LSB: automatic crash report generation
atd.service                                                                                 loaded active     running         Deferred execution scheduler
cloud-config.service                                                                        loaded active     exited          Apply the settings specified in cloud-config
cloud-final.service                                                                         loaded active     exited          Execute cloud user/final scripts
cloud-init-local.service                                                                    loaded active     exited          Initial cloud-init job (pre-networking)
cloud-init.service                                                                          loaded active     exited          Initial cloud-init job (metadata service crawler)
console-setup.service                                                                       loaded active     exited          Set console font and keymap
cron.service                                                                                loaded active     running         Regular background program processing daemon
dbus.service                                                                                loaded active     running         D-Bus System Message Bus
ebtables.service                                                                            loaded active     exited          LSB: ebtables ruleset management
getty@tty1.service                                                                          loaded active     running         Getty on tty1
google-accounts-daemon.service                                                              loaded active     running         Google Compute Engine Accounts Daemon
google-clock-skew-daemon.service                                                            loaded active     running         Google Compute Engine Clock Skew Daemon
google-ip-forwarding-daemon.service                                                         loaded active     running         Google Compute Engine IP Forwarding Daemon
google-shutdown-scripts.service                                                             loaded active     exited          Google Compute Engine Shutdown Scripts
gravity-agent.service                                                                       loaded activating start     start Auto-generated service for the gravity-agent.service
gravity__gravitational.io__planet__5.5.47-11312.service                                     loaded active     running         Auto-generated service for the gravitational.io/planet:5.5.47-11312 package
gravity__gravitational.io__teleport__3.0.5.service                                          loaded active     running         Auto-generated service for the gravitational.io/teleport:3.0.5 package
grub-common.service                                                                         loaded active     exited          LSB: Record successful boot for GRUB
ifup@ens4.service                                                                           loaded active     exited          ifup for ens4
iscsid.service                                                                              loaded active     running         iSCSI initiator daemon (iscsid)
keyboard-setup.service                                                                      loaded active     exited          Set console keymap
kmod-static-nodes.service                                                                   loaded active     exited          Create list of required static device nodes for the current kernel
lvm2-lvmetad.service                                                                        loaded active     running         LVM2 metadata daemon
lvm2-monitor.service                                                                        loaded active     exited          Monitoring of LVM2 mirrors, snapshots etc. using dmeventd or progress polling
lxcfs.service                                                                               loaded active     running         FUSE filesystem for LXC
lxd-containers.service                                                                      loaded active     exited          LXD - container startup/shutdown
mdadm.service                                                                               loaded active     running         LSB: MD monitoring daemon
networking.service                                                                          loaded active     exited          Raise network interfaces
nfs-config.service                                                                          loaded active     exited          Preprocess NFS configuration
ntp.service                                                                                 loaded active     running         LSB: Start NTP daemon
ondemand.service                                                                            loaded active     exited          LSB: Set the CPU Frequency Scaling governor to \"ondemand\"
open-iscsi.service                                                                          loaded active     exited          Login to default iSCSI targets
polkitd.service                                                                             loaded active     running         Authenticate and Authorize Users to Run Privileged Tasks
rc-local.service                                                                            loaded active     exited          /etc/rc.local Compatibility
resolvconf.service                                                                          loaded active     exited          Nameserver information manager
rsyslog.service                                                                             loaded active     running         System Logging Service
serial-getty@ttyS0.service                                                                  loaded active     running         Serial Getty on ttyS0
setvtrgb.service                                                                            loaded active     exited          Set console scheme
snapd.apparmor.service                                                                      loaded active     exited          Load AppArmor profiles managed internally by snapd
snapd.seeded.service                                                                        loaded active     exited          Wait until snapd is fully seeded
splunk.service                                                                              loaded active     running         LSB: Start splunk
ssh.service                                                                                 loaded active     running         OpenBSD Secure Shell server
sshguard.service                                                                            loaded active     running         SSHGuard
systemd-journal-flush.service                                                               loaded active     exited          Flush Journal to Persistent Storage
systemd-journald.service                                                                    loaded active     running         Journal Service
systemd-logind.service                                                                      loaded active     running         Login Service
systemd-modules-load.service                                                                loaded active     exited          Load Kernel Modules
systemd-random-seed.service                                                                 loaded active     exited          Load/Save Random Seed
systemd-remount-fs.service                                                                  loaded active     exited          Remount Root and Kernel File Systems
systemd-sysctl.service                                                                      loaded active     exited          Apply Kernel Variables
systemd-tmpfiles-setup-dev.service                                                          loaded active     exited          Create Static Device Nodes in /dev
systemd-tmpfiles-setup.service                                                              loaded active     exited          Create Volatile Files and Directories
systemd-udev-trigger.service                                                                loaded active     exited          udev Coldplug all Devices
systemd-udevd.service                                                                       loaded active     running         udev Kernel Device Manager
systemd-update-utmp.service                                                                 loaded active     exited          Update UTMP about System Boot/Shutdown
systemd-user-sessions.service                                                               loaded active     exited          Permit User Sessions
teleport.service                                                                            loaded active     running         Teleport SSH Service
ufw.service                                                                                 loaded active     exited          Uncomplicated firewall
unattended-upgrades.service                                                                 loaded active     exited          Unattended Upgrades Shutdown
user@1001.service                                                                           loaded active     running         User Manager for UID 1001
-.slice                                                                                     loaded active     active          Root Slice
system-getty.slice                                                                          loaded active     active          system-getty.slice
system-serial\\x2dgetty.slice                                                                loaded active     active          system-serial\\x2dgetty.slice
system.slice                                                                                loaded active     active          System Slice
user-1001.slice                                                                             loaded active     active          User Slice of knisbet
user.slice                                                                                  loaded active     active          User and Session Slice
acpid.socket                                                                                loaded active     running         ACPID Listen Socket
dbus.socket                                                                                 loaded active     running         D-Bus System Message Bus Socket
dm-event.socket                                                                             loaded active     listening       Device-mapper event daemon FIFOs
lvm2-lvmetad.socket                                                                         loaded active     running         LVM2 metadata daemon socket
lvm2-lvmpolld.socket                                                                        loaded active     listening       LVM2 poll daemon socket
lxd.socket                                                                                  loaded active     listening       LXD - unix socket
rpcbind.socket                                                                              loaded active     listening       RPCbind Server Activation Socket
snapd.socket                                                                                loaded active     listening       Socket activation for snappy daemon
syslog.socket                                                                               loaded active     running         Syslog Socket
systemd-initctl.socket                                                                      loaded active     listening       /dev/initctl Compatibility Named Pipe
systemd-journald-audit.socket                                                               loaded active     running         Journal Audit Socket
systemd-journald-dev-log.socket                                                             loaded active     running         Journal Socket (/dev/log)
systemd-journald.socket                                                                     loaded active     running         Journal Socket
systemd-rfkill.socket                                                                       loaded active     listening       Load/Save RF Kill Switch Status /dev/rfkill Watch
systemd-udevd-control.socket                                                                loaded active     running         udev Control Socket
systemd-udevd-kernel.socket                                                                 loaded active     running         udev Kernel Socket
uuidd.socket                                                                                loaded active     listening       UUID daemon activation socket
basic.target                                                                                loaded active     active          Basic System
cloud-config.target                                                                         loaded active     active          Cloud-config availability
cloud-init.target                                                                           loaded active     active          Cloud-init target
cryptsetup.target                                                                           loaded active     active          Encrypted Volumes
getty.target                                                                                loaded active     active          Login Prompts
graphical.target                                                                            loaded active     active          Graphical Interface
local-fs-pre.target                                                                         loaded active     active          Local File Systems (Pre)
local-fs.target                                                                             loaded active     active          Local File Systems
multi-user.target                                                                           loaded active     active          Multi-User System
network-online.target                                                                       loaded active     active          Network is Online
network-pre.target                                                                          loaded active     active          Network (Pre)
network.target                                                                              loaded active     active          Network
nfs-client.target                                                                           loaded active     active          NFS client services
nss-user-lookup.target                                                                      loaded active     active          User and Group Name Lookups
paths.target                                                                                loaded active     active          Paths
remote-fs-pre.target                                                                        loaded active     active          Remote File Systems (Pre)
remote-fs.target                                                                            loaded active     active          Remote File Systems
slices.target                                                                               loaded active     active          Slices
sockets.target                                                                              loaded active     active          Sockets
swap.target                                                                                 loaded active     active          Swap
sysinit.target                                                                              loaded active     active          System Initialization
time-sync.target                                                                            loaded active     active          System Time Synchronized
timers.target                                                                               loaded active     active          Timers
apt-daily-upgrade.timer                                                                     loaded active     waiting         Daily apt upgrade and clean activities
apt-daily.timer                                                                             loaded active     waiting         Daily apt download activities
systemd-tmpfiles-clean.timer                                                                loaded active     waiting         Daily Cleanup of Temporary Directories
" utils/exec.go:166
2020-07-29T18:16:29Z INFO [SYSTEM-UP] Package installed as a service, will uninstall. service:gravitational.io/planet:5.5.47-11312 system/system.go:618
2020-07-29T18:16:29Z INFO [SYSTEM]    systemctl disable gravity__gravitational.io__planet__5.5.47-11312.service --no-pager cmderr:false errmsg: stderr:"Removed symlink /etc/systemd/system/multi-user.target.wants/gravity__gravitational.io__planet__5.5.47-11312.service.
" stdout: utils/exec.go:166
2020-07-29T18:16:32Z INFO [SYSTEM]    systemctl stop gravity__gravitational.io__planet__5.5.47-11312.service --no-pager cmderr:false errmsg: stderr: stdout: utils/exec.go:166
2020-07-29T18:16:32Z INFO [SYSTEM]    systemctl is-failed gravity__gravitational.io__planet__5.5.47-11312.service --no-pager cmderr:true errmsg:exit status 1 stderr: stdout:"inactive
" utils/exec.go:166
2020-07-29T18:16:32Z INFO             Package is already unpacked. package:gravitational.io/planet:5.5.54-11312 localpack/packageserver.go:405
2020-07-29T18:16:32Z INFO             Package is already unpacked. package:gravitational.io/planet:5.5.54-11312 localpack/packageserver.go:405
2020-07-29T18:16:32Z INFO             Package is already unpacked. package:wonderfulspence252/planet-config-1016207wonderfulspence252:5.5.54-11312+1596042169 localpack/packageserver.go:405
2020-07-29T18:16:32Z INFO [SYSTEM-UP] Installing new package. package:gravitational.io/planet:5.5.54-11312 system/system.go:447
2020-07-29T18:16:32Z INFO [SYSTEM]    systemctl --version --no-pager cmderr:false errmsg: stderr: stdout:"systemd 229
+PAM +AUDIT +SELINUX +IMA +APPARMOR +SMACK +SYSVINIT +UTMP +LIBCRYPTSETUP +GCRYPT +GNUTLS +ACL +XZ -LZ4 +SECCOMP +BLKID +ELFUTILS +KMOD -IDN
" utils/exec.go:166
2020-07-29T18:16:32Z INFO [SYSTEM]    systemctl enable gravity__gravitational.io__planet__5.5.54-11312.service --no-pager cmderr:false errmsg: stderr:"Created symlink from /etc/systemd/system/multi-user.target.wants/gravity__gravitational.io__planet__5.5.54-11312.service to /etc/systemd/system/gravity__gravitational.io__planet__5.5.54-11312.service.
" stdout: utils/exec.go:166
2020-07-29T18:16:32Z INFO [SYSTEM]    systemctl start gravity__gravitational.io__planet__5.5.54-11312.service --no-pager cmderr:false errmsg: stderr: stdout: utils/exec.go:166
2020-07-29T18:16:32Z INFO [SYSTEM-UP] Successfully installed. service:gravitational.io/planet:5.5.54-11312 system/system.go:458
2020-07-29T18:16:32Z INFO [SYSTEM-UP] Applying. update:{gravitational.io/gravity:5.5.46 gravitational.io/gravity:5.5.50-dev.9 map[] <nil> false} system/system.go:258
2020-07-29T18:16:32Z INFO [SYSTEM-UP] Reinstalling package. update:{gravitational.io/gravity:5.5.46 gravitational.io/gravity:5.5.50-dev.9 map[] <nil> false} system/system.go:238
binary package gravitational.io/gravity:5.5.50-dev.9 installed in /usr/bin/gravity
2020-07-29T18:16:33Z INFO [SYSTEM-UP] Applying. update:{wonderfulspence252/planet-10.162.0.7-secrets:5.5.47-11312 wonderfulspence252/planet-10.162.0.7-secrets:5.5.54-11312+1596042169 map[purpose:planet-secrets] <nil> false} system/system.go:258
2020-07-29T18:16:33Z INFO [SYSTEM-UP] Reinstalling package. update:{wonderfulspence252/planet-10.162.0.7-secrets:5.5.47-11312 wonderfulspence252/planet-10.162.0.7-secrets:5.5.54-11312+1596042169 map[purpose:planet-secrets] <nil> false} system/system.go:238
2020-07-29T18:16:33Z INFO [SYSTEM-UP] Installed secrets package.wonderfulspence252/planet-10.162.0.7-secrets:5.5.54-11312+1596042169/var/lib/gravity/secrets package:wonderfulspence252/planet-10.162.0.7-secrets:5.5.54-11312+1596042169 target-path:/var/lib/gravity/secrets system/system.go:390
2020-07-29T18:16:33Z INFO [SYSTEM]    systemctl start gravity__gravitational.io__planet__5.5.54-11312.service --no-block --no-pager cmderr:false errmsg: stderr: stdout: utils/exec.go:166
2020-07-29T18:16:33Z INFO             Retrying in 386.062892ms. error:[
ERROR REPORT:
Original Error: *url.Error Get https://127.0.0.1:7575/local: dial tcp 127.0.0.1:7575: connect: connection refused
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/status/status.go:540 github.com/gravitational/gravity/lib/status.planetAgentStatus
	/gopath/src/github.com/gravitational/gravity/lib/status/status.go:453 github.com/gravitational/gravity/lib/status.fromPlanetAgent
	/gopath/src/github.com/gravitational/gravity/lib/status/status.go:132 github.com/gravitational/gravity/lib/status.FromLocalPlanetAgent
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:64 github.com/gravitational/gravity/lib/status.getLocalNodeStatus
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:38 github.com/gravitational/gravity/lib/status.Wait.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:37 github.com/gravitational/gravity/lib/status.Wait
	/gopath/src/github.com/gravitational/gravity/lib/update/system/system.go:98 github.com/gravitational/gravity/lib/update/system.(*System).Update
	/gopath/src/github.com/gravitational/gravity/lib/update/cluster/phases/system.go:227 github.com/gravitational/gravity/lib/update/cluster/phases.(*updatePhaseSystem).Execute
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:493 github.com/gravitational/gravity/lib/fsm.(*FSM).executeOnePhase
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:427 github.com/gravitational/gravity/lib/fsm.(*FSM).executePhaseLocally
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:387 github.com/gravitational/gravity/lib/fsm.(*FSM).executePhase
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:238 github.com/gravitational/gravity/lib/fsm.(*FSM).ExecutePhase
	/gopath/src/github.com/gravitational/gravity/lib/update/updater.go:95 github.com/gravitational/gravity/lib/update.(*Updater).RunPhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/clusterupdate.go:202 github.com/gravitational/gravity/tool/gravity/cli.executeOrForkPhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/clusterupdate.go:188 github.com/gravitational/gravity/tool/gravity/cli.executeUpdatePhaseForOperation
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/operation.go:77 github.com/gravitational/gravity/tool/gravity/cli.executePhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:418 github.com/gravitational/gravity/tool/gravity/cli.Execute
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:252 github.com/gravitational/gravity/tool/gravity/cli.getExec.func1
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/logging.go:71 github.com/gravitational/gravity/tool/gravity/cli.(*CmdExecer).Execute
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:92 github.com/gravitational/gravity/tool/gravity/cli.Run
	/gopath/src/github.com/gravitational/gravity/tool/gravity/main.go:44 main.run
	/gopath/src/github.com/gravitational/gravity/tool/gravity/main.go:35 main.main
	/go/src/runtime/proc.go:200 runtime.main
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: failed to query cluster status from agent
	Get https://127.0.0.1:7575/local: dial tcp 127.0.0.1:7575: connect: connection refused] utils/retry.go:238
2020-07-29T18:16:33Z INFO             Retrying in 434.641583ms. error:[
ERROR REPORT:
Original Error: *url.Error Get https://127.0.0.1:7575/local: dial tcp 127.0.0.1:7575: connect: connection refused
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/status/status.go:540 github.com/gravitational/gravity/lib/status.planetAgentStatus
	/gopath/src/github.com/gravitational/gravity/lib/status/status.go:453 github.com/gravitational/gravity/lib/status.fromPlanetAgent
	/gopath/src/github.com/gravitational/gravity/lib/status/status.go:132 github.com/gravitational/gravity/lib/status.FromLocalPlanetAgent
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:64 github.com/gravitational/gravity/lib/status.getLocalNodeStatus
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:38 github.com/gravitational/gravity/lib/status.Wait.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:37 github.com/gravitational/gravity/lib/status.Wait
	/gopath/src/github.com/gravitational/gravity/lib/update/system/system.go:98 github.com/gravitational/gravity/lib/update/system.(*System).Update
	/gopath/src/github.com/gravitational/gravity/lib/update/cluster/phases/system.go:227 github.com/gravitational/gravity/lib/update/cluster/phases.(*updatePhaseSystem).Execute
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:493 github.com/gravitational/gravity/lib/fsm.(*FSM).executeOnePhase
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:427 github.com/gravitational/gravity/lib/fsm.(*FSM).executePhaseLocally
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:387 github.com/gravitational/gravity/lib/fsm.(*FSM).executePhase
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:238 github.com/gravitational/gravity/lib/fsm.(*FSM).ExecutePhase
	/gopath/src/github.com/gravitational/gravity/lib/update/updater.go:95 github.com/gravitational/gravity/lib/update.(*Updater).RunPhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/clusterupdate.go:202 github.com/gravitational/gravity/tool/gravity/cli.executeOrForkPhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/clusterupdate.go:188 github.com/gravitational/gravity/tool/gravity/cli.executeUpdatePhaseForOperation
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/operation.go:77 github.com/gravitational/gravity/tool/gravity/cli.executePhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:418 github.com/gravitational/gravity/tool/gravity/cli.Execute
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:252 github.com/gravitational/gravity/tool/gravity/cli.getExec.func1
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/logging.go:71 github.com/gravitational/gravity/tool/gravity/cli.(*CmdExecer).Execute
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:92 github.com/gravitational/gravity/tool/gravity/cli.Run
	/gopath/src/github.com/gravitational/gravity/tool/gravity/main.go:44 main.run
	/gopath/src/github.com/gravitational/gravity/tool/gravity/main.go:35 main.main
	/go/src/runtime/proc.go:200 runtime.main
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: failed to query cluster status from agent
	Get https://127.0.0.1:7575/local: dial tcp 127.0.0.1:7575: connect: connection refused] utils/retry.go:238
2020-07-29T18:16:33Z INFO             Retrying in 638.626651ms. error:[
ERROR REPORT:
Original Error: *url.Error Get https://127.0.0.1:7575/local: dial tcp 127.0.0.1:7575: connect: connection refused
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/status/status.go:540 github.com/gravitational/gravity/lib/status.planetAgentStatus
	/gopath/src/github.com/gravitational/gravity/lib/status/status.go:453 github.com/gravitational/gravity/lib/status.fromPlanetAgent
	/gopath/src/github.com/gravitational/gravity/lib/status/status.go:132 github.com/gravitational/gravity/lib/status.FromLocalPlanetAgent
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:64 github.com/gravitational/gravity/lib/status.getLocalNodeStatus
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:38 github.com/gravitational/gravity/lib/status.Wait.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:37 github.com/gravitational/gravity/lib/status.Wait
	/gopath/src/github.com/gravitational/gravity/lib/update/system/system.go:98 github.com/gravitational/gravity/lib/update/system.(*System).Update
	/gopath/src/github.com/gravitational/gravity/lib/update/cluster/phases/system.go:227 github.com/gravitational/gravity/lib/update/cluster/phases.(*updatePhaseSystem).Execute
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:493 github.com/gravitational/gravity/lib/fsm.(*FSM).executeOnePhase
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:427 github.com/gravitational/gravity/lib/fsm.(*FSM).executePhaseLocally
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:387 github.com/gravitational/gravity/lib/fsm.(*FSM).executePhase
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:238 github.com/gravitational/gravity/lib/fsm.(*FSM).ExecutePhase
	/gopath/src/github.com/gravitational/gravity/lib/update/updater.go:95 github.com/gravitational/gravity/lib/update.(*Updater).RunPhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/clusterupdate.go:202 github.com/gravitational/gravity/tool/gravity/cli.executeOrForkPhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/clusterupdate.go:188 github.com/gravitational/gravity/tool/gravity/cli.executeUpdatePhaseForOperation
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/operation.go:77 github.com/gravitational/gravity/tool/gravity/cli.executePhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:418 github.com/gravitational/gravity/tool/gravity/cli.Execute
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:252 github.com/gravitational/gravity/tool/gravity/cli.getExec.func1
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/logging.go:71 github.com/gravitational/gravity/tool/gravity/cli.(*CmdExecer).Execute
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:92 github.com/gravitational/gravity/tool/gravity/cli.Run
	/gopath/src/github.com/gravitational/gravity/tool/gravity/main.go:44 main.run
	/gopath/src/github.com/gravitational/gravity/tool/gravity/main.go:35 main.main
	/go/src/runtime/proc.go:200 runtime.main
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: failed to query cluster status from agent
	Get https://127.0.0.1:7575/local: dial tcp 127.0.0.1:7575: connect: connection refused] utils/retry.go:238
2020-07-29T18:16:34Z INFO             Retrying in 1.161346148s. error:[
ERROR REPORT:
Original Error: *url.Error Get https://127.0.0.1:7575/local: dial tcp 127.0.0.1:7575: connect: connection refused
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/status/status.go:540 github.com/gravitational/gravity/lib/status.planetAgentStatus
	/gopath/src/github.com/gravitational/gravity/lib/status/status.go:453 github.com/gravitational/gravity/lib/status.fromPlanetAgent
	/gopath/src/github.com/gravitational/gravity/lib/status/status.go:132 github.com/gravitational/gravity/lib/status.FromLocalPlanetAgent
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:64 github.com/gravitational/gravity/lib/status.getLocalNodeStatus
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:38 github.com/gravitational/gravity/lib/status.Wait.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:37 github.com/gravitational/gravity/lib/status.Wait
	/gopath/src/github.com/gravitational/gravity/lib/update/system/system.go:98 github.com/gravitational/gravity/lib/update/system.(*System).Update
	/gopath/src/github.com/gravitational/gravity/lib/update/cluster/phases/system.go:227 github.com/gravitational/gravity/lib/update/cluster/phases.(*updatePhaseSystem).Execute
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:493 github.com/gravitational/gravity/lib/fsm.(*FSM).executeOnePhase
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:427 github.com/gravitational/gravity/lib/fsm.(*FSM).executePhaseLocally
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:387 github.com/gravitational/gravity/lib/fsm.(*FSM).executePhase
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:238 github.com/gravitational/gravity/lib/fsm.(*FSM).ExecutePhase
	/gopath/src/github.com/gravitational/gravity/lib/update/updater.go:95 github.com/gravitational/gravity/lib/update.(*Updater).RunPhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/clusterupdate.go:202 github.com/gravitational/gravity/tool/gravity/cli.executeOrForkPhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/clusterupdate.go:188 github.com/gravitational/gravity/tool/gravity/cli.executeUpdatePhaseForOperation
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/operation.go:77 github.com/gravitational/gravity/tool/gravity/cli.executePhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:418 github.com/gravitational/gravity/tool/gravity/cli.Execute
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:252 github.com/gravitational/gravity/tool/gravity/cli.getExec.func1
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/logging.go:71 github.com/gravitational/gravity/tool/gravity/cli.(*CmdExecer).Execute
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:92 github.com/gravitational/gravity/tool/gravity/cli.Run
	/gopath/src/github.com/gravitational/gravity/tool/gravity/main.go:44 main.run
	/gopath/src/github.com/gravitational/gravity/tool/gravity/main.go:35 main.main
	/go/src/runtime/proc.go:200 runtime.main
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: failed to query cluster status from agent
	Get https://127.0.0.1:7575/local: dial tcp 127.0.0.1:7575: connect: connection refused] utils/retry.go:238
2020-07-29T18:16:35Z INFO             Retrying in 2.3196501s. error:[
ERROR REPORT:
Original Error: *url.Error Get https://127.0.0.1:7575/local: dial tcp 127.0.0.1:7575: connect: connection refused
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/status/status.go:540 github.com/gravitational/gravity/lib/status.planetAgentStatus
	/gopath/src/github.com/gravitational/gravity/lib/status/status.go:453 github.com/gravitational/gravity/lib/status.fromPlanetAgent
	/gopath/src/github.com/gravitational/gravity/lib/status/status.go:132 github.com/gravitational/gravity/lib/status.FromLocalPlanetAgent
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:64 github.com/gravitational/gravity/lib/status.getLocalNodeStatus
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:38 github.com/gravitational/gravity/lib/status.Wait.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:37 github.com/gravitational/gravity/lib/status.Wait
	/gopath/src/github.com/gravitational/gravity/lib/update/system/system.go:98 github.com/gravitational/gravity/lib/update/system.(*System).Update
	/gopath/src/github.com/gravitational/gravity/lib/update/cluster/phases/system.go:227 github.com/gravitational/gravity/lib/update/cluster/phases.(*updatePhaseSystem).Execute
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:493 github.com/gravitational/gravity/lib/fsm.(*FSM).executeOnePhase
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:427 github.com/gravitational/gravity/lib/fsm.(*FSM).executePhaseLocally
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:387 github.com/gravitational/gravity/lib/fsm.(*FSM).executePhase
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:238 github.com/gravitational/gravity/lib/fsm.(*FSM).ExecutePhase
	/gopath/src/github.com/gravitational/gravity/lib/update/updater.go:95 github.com/gravitational/gravity/lib/update.(*Updater).RunPhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/clusterupdate.go:202 github.com/gravitational/gravity/tool/gravity/cli.executeOrForkPhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/clusterupdate.go:188 github.com/gravitational/gravity/tool/gravity/cli.executeUpdatePhaseForOperation
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/operation.go:77 github.com/gravitational/gravity/tool/gravity/cli.executePhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:418 github.com/gravitational/gravity/tool/gravity/cli.Execute
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:252 github.com/gravitational/gravity/tool/gravity/cli.getExec.func1
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/logging.go:71 github.com/gravitational/gravity/tool/gravity/cli.(*CmdExecer).Execute
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:92 github.com/gravitational/gravity/tool/gravity/cli.Run
	/gopath/src/github.com/gravitational/gravity/tool/gravity/main.go:44 main.run
	/gopath/src/github.com/gravitational/gravity/tool/gravity/main.go:35 main.main
	/go/src/runtime/proc.go:200 runtime.main
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: failed to query cluster status from agent
	Get https://127.0.0.1:7575/local: dial tcp 127.0.0.1:7575: connect: connection refused] utils/retry.go:238
2020-07-29T18:16:37Z INFO             Retrying in 5.643306453s. error:[
ERROR REPORT:
Original Error: *url.Error Get https://127.0.0.1:7575/local: dial tcp 127.0.0.1:7575: connect: connection refused
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/status/status.go:540 github.com/gravitational/gravity/lib/status.planetAgentStatus
	/gopath/src/github.com/gravitational/gravity/lib/status/status.go:453 github.com/gravitational/gravity/lib/status.fromPlanetAgent
	/gopath/src/github.com/gravitational/gravity/lib/status/status.go:132 github.com/gravitational/gravity/lib/status.FromLocalPlanetAgent
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:64 github.com/gravitational/gravity/lib/status.getLocalNodeStatus
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:38 github.com/gravitational/gravity/lib/status.Wait.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:37 github.com/gravitational/gravity/lib/status.Wait
	/gopath/src/github.com/gravitational/gravity/lib/update/system/system.go:98 github.com/gravitational/gravity/lib/update/system.(*System).Update
	/gopath/src/github.com/gravitational/gravity/lib/update/cluster/phases/system.go:227 github.com/gravitational/gravity/lib/update/cluster/phases.(*updatePhaseSystem).Execute
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:493 github.com/gravitational/gravity/lib/fsm.(*FSM).executeOnePhase
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:427 github.com/gravitational/gravity/lib/fsm.(*FSM).executePhaseLocally
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:387 github.com/gravitational/gravity/lib/fsm.(*FSM).executePhase
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:238 github.com/gravitational/gravity/lib/fsm.(*FSM).ExecutePhase
	/gopath/src/github.com/gravitational/gravity/lib/update/updater.go:95 github.com/gravitational/gravity/lib/update.(*Updater).RunPhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/clusterupdate.go:202 github.com/gravitational/gravity/tool/gravity/cli.executeOrForkPhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/clusterupdate.go:188 github.com/gravitational/gravity/tool/gravity/cli.executeUpdatePhaseForOperation
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/operation.go:77 github.com/gravitational/gravity/tool/gravity/cli.executePhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:418 github.com/gravitational/gravity/tool/gravity/cli.Execute
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:252 github.com/gravitational/gravity/tool/gravity/cli.getExec.func1
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/logging.go:71 github.com/gravitational/gravity/tool/gravity/cli.(*CmdExecer).Execute
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:92 github.com/gravitational/gravity/tool/gravity/cli.Run
	/gopath/src/github.com/gravitational/gravity/tool/gravity/main.go:44 main.run
	/gopath/src/github.com/gravitational/gravity/tool/gravity/main.go:35 main.main
	/go/src/runtime/proc.go:200 runtime.main
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: failed to query cluster status from agent
	Get https://127.0.0.1:7575/local: dial tcp 127.0.0.1:7575: connect: connection refused] utils/retry.go:238
	Still executing "/masters/kevin-test1/system-upgrade" locally (10 seconds elapsed)
2020-07-29T18:16:43Z INFO             Retrying in 5.697260876s. error:[
ERROR REPORT:
Original Error: *trace.BadParameterError node is degraded
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:69 github.com/gravitational/gravity/lib/status.getLocalNodeStatus
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:38 github.com/gravitational/gravity/lib/status.Wait.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:37 github.com/gravitational/gravity/lib/status.Wait
	/gopath/src/github.com/gravitational/gravity/lib/update/system/system.go:98 github.com/gravitational/gravity/lib/update/system.(*System).Update
	/gopath/src/github.com/gravitational/gravity/lib/update/cluster/phases/system.go:227 github.com/gravitational/gravity/lib/update/cluster/phases.(*updatePhaseSystem).Execute
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:493 github.com/gravitational/gravity/lib/fsm.(*FSM).executeOnePhase
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:427 github.com/gravitational/gravity/lib/fsm.(*FSM).executePhaseLocally
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:387 github.com/gravitational/gravity/lib/fsm.(*FSM).executePhase
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:238 github.com/gravitational/gravity/lib/fsm.(*FSM).ExecutePhase
	/gopath/src/github.com/gravitational/gravity/lib/update/updater.go:95 github.com/gravitational/gravity/lib/update.(*Updater).RunPhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/clusterupdate.go:202 github.com/gravitational/gravity/tool/gravity/cli.executeOrForkPhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/clusterupdate.go:188 github.com/gravitational/gravity/tool/gravity/cli.executeUpdatePhaseForOperation
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/operation.go:77 github.com/gravitational/gravity/tool/gravity/cli.executePhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:418 github.com/gravitational/gravity/tool/gravity/cli.Execute
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:252 github.com/gravitational/gravity/tool/gravity/cli.getExec.func1
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/logging.go:71 github.com/gravitational/gravity/tool/gravity/cli.(*CmdExecer).Execute
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:92 github.com/gravitational/gravity/tool/gravity/cli.Run
	/gopath/src/github.com/gravitational/gravity/tool/gravity/main.go:44 main.run
	/gopath/src/github.com/gravitational/gravity/tool/gravity/main.go:35 main.main
	/go/src/runtime/proc.go:200 runtime.main
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: node is degraded] utils/retry.go:238
	Still executing "/masters/kevin-test1/system-upgrade" locally (20 seconds elapsed)
2020-07-29T18:16:49Z INFO             Retrying in 7.88549232s. error:[
ERROR REPORT:
Original Error: *trace.BadParameterError node is degraded
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:69 github.com/gravitational/gravity/lib/status.getLocalNodeStatus
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:38 github.com/gravitational/gravity/lib/status.Wait.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:37 github.com/gravitational/gravity/lib/status.Wait
	/gopath/src/github.com/gravitational/gravity/lib/update/system/system.go:98 github.com/gravitational/gravity/lib/update/system.(*System).Update
	/gopath/src/github.com/gravitational/gravity/lib/update/cluster/phases/system.go:227 github.com/gravitational/gravity/lib/update/cluster/phases.(*updatePhaseSystem).Execute
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:493 github.com/gravitational/gravity/lib/fsm.(*FSM).executeOnePhase
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:427 github.com/gravitational/gravity/lib/fsm.(*FSM).executePhaseLocally
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:387 github.com/gravitational/gravity/lib/fsm.(*FSM).executePhase
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:238 github.com/gravitational/gravity/lib/fsm.(*FSM).ExecutePhase
	/gopath/src/github.com/gravitational/gravity/lib/update/updater.go:95 github.com/gravitational/gravity/lib/update.(*Updater).RunPhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/clusterupdate.go:202 github.com/gravitational/gravity/tool/gravity/cli.executeOrForkPhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/clusterupdate.go:188 github.com/gravitational/gravity/tool/gravity/cli.executeUpdatePhaseForOperation
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/operation.go:77 github.com/gravitational/gravity/tool/gravity/cli.executePhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:418 github.com/gravitational/gravity/tool/gravity/cli.Execute
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:252 github.com/gravitational/gravity/tool/gravity/cli.getExec.func1
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/logging.go:71 github.com/gravitational/gravity/tool/gravity/cli.(*CmdExecer).Execute
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:92 github.com/gravitational/gravity/tool/gravity/cli.Run
	/gopath/src/github.com/gravitational/gravity/tool/gravity/main.go:44 main.run
	/gopath/src/github.com/gravitational/gravity/tool/gravity/main.go:35 main.main
	/go/src/runtime/proc.go:200 runtime.main
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: node is degraded] utils/retry.go:238
2020-07-29T18:16:57Z INFO             Retrying in 12.703630881s. error:[
ERROR REPORT:
Original Error: *trace.BadParameterError node is degraded
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:69 github.com/gravitational/gravity/lib/status.getLocalNodeStatus
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:38 github.com/gravitational/gravity/lib/status.Wait.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:37 github.com/gravitational/gravity/lib/status.Wait
	/gopath/src/github.com/gravitational/gravity/lib/update/system/system.go:98 github.com/gravitational/gravity/lib/update/system.(*System).Update
	/gopath/src/github.com/gravitational/gravity/lib/update/cluster/phases/system.go:227 github.com/gravitational/gravity/lib/update/cluster/phases.(*updatePhaseSystem).Execute
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:493 github.com/gravitational/gravity/lib/fsm.(*FSM).executeOnePhase
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:427 github.com/gravitational/gravity/lib/fsm.(*FSM).executePhaseLocally
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:387 github.com/gravitational/gravity/lib/fsm.(*FSM).executePhase
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:238 github.com/gravitational/gravity/lib/fsm.(*FSM).ExecutePhase
	/gopath/src/github.com/gravitational/gravity/lib/update/updater.go:95 github.com/gravitational/gravity/lib/update.(*Updater).RunPhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/clusterupdate.go:202 github.com/gravitational/gravity/tool/gravity/cli.executeOrForkPhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/clusterupdate.go:188 github.com/gravitational/gravity/tool/gravity/cli.executeUpdatePhaseForOperation
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/operation.go:77 github.com/gravitational/gravity/tool/gravity/cli.executePhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:418 github.com/gravitational/gravity/tool/gravity/cli.Execute
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:252 github.com/gravitational/gravity/tool/gravity/cli.getExec.func1
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/logging.go:71 github.com/gravitational/gravity/tool/gravity/cli.(*CmdExecer).Execute
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:92 github.com/gravitational/gravity/tool/gravity/cli.Run
	/gopath/src/github.com/gravitational/gravity/tool/gravity/main.go:44 main.run
	/gopath/src/github.com/gravitational/gravity/tool/gravity/main.go:35 main.main
	/go/src/runtime/proc.go:200 runtime.main
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: node is degraded] utils/retry.go:238
	Still executing "/masters/kevin-test1/system-upgrade" locally (30 seconds elapsed)
	Still executing "/masters/kevin-test1/system-upgrade" locally (40 seconds elapsed)
2020-07-29T18:17:09Z INFO             Retrying in 16.291351512s. error:[
ERROR REPORT:
Original Error: *trace.BadParameterError node is degraded
Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:69 github.com/gravitational/gravity/lib/status.getLocalNodeStatus
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:38 github.com/gravitational/gravity/lib/status.Wait.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/status/wait.go:37 github.com/gravitational/gravity/lib/status.Wait
	/gopath/src/github.com/gravitational/gravity/lib/update/system/system.go:98 github.com/gravitational/gravity/lib/update/system.(*System).Update
	/gopath/src/github.com/gravitational/gravity/lib/update/cluster/phases/system.go:227 github.com/gravitational/gravity/lib/update/cluster/phases.(*updatePhaseSystem).Execute
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:493 github.com/gravitational/gravity/lib/fsm.(*FSM).executeOnePhase
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:427 github.com/gravitational/gravity/lib/fsm.(*FSM).executePhaseLocally
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:387 github.com/gravitational/gravity/lib/fsm.(*FSM).executePhase
	/gopath/src/github.com/gravitational/gravity/lib/fsm/fsm.go:238 github.com/gravitational/gravity/lib/fsm.(*FSM).ExecutePhase
	/gopath/src/github.com/gravitational/gravity/lib/update/updater.go:95 github.com/gravitational/gravity/lib/update.(*Updater).RunPhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/clusterupdate.go:202 github.com/gravitational/gravity/tool/gravity/cli.executeOrForkPhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/clusterupdate.go:188 github.com/gravitational/gravity/tool/gravity/cli.executeUpdatePhaseForOperation
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/operation.go:77 github.com/gravitational/gravity/tool/gravity/cli.executePhase
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:418 github.com/gravitational/gravity/tool/gravity/cli.Execute
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:252 github.com/gravitational/gravity/tool/gravity/cli.getExec.func1
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/logging.go:71 github.com/gravitational/gravity/tool/gravity/cli.(*CmdExecer).Execute
	/gopath/src/github.com/gravitational/gravity/tool/gravity/cli/run.go:92 github.com/gravitational/gravity/tool/gravity/cli.Run
	/gopath/src/github.com/gravitational/gravity/tool/gravity/main.go:44 main.run
	/gopath/src/github.com/gravitational/gravity/tool/gravity/main.go:35 main.main
	/go/src/runtime/proc.go:200 runtime.main
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: node is degraded] utils/retry.go:238
	Still executing "/masters/kevin-test1/system-upgrade" locally (50 seconds elapsed)
2020-07-29T18:17:26Z INFO [SYSTEM-UP] System successfully updated. changeset:changeset(id=c82b0455-db15-4178-a00c-6098e5acbedd, created=2020-07-29 18:16:29.435484855 +0000 UTC, changes=update(gravitational.io/planet:5.5.47-11312 -> gravitational.io/planet:5.5.54-11312, config:wonderfulspence252/planet-config-1016207wonderfulspence252:5.5.47-11312 -> wonderfulspence252/planet-config-1016207wonderfulspence252:5.5.54-11312+1596042169), update(gravitational.io/gravity:5.5.46 -> gravitational.io/gravity:5.5.50-dev.9), update(wonderfulspence252/planet-10.162.0.7-secrets:5.5.47-11312 -> wonderfulspence252/planet-10.162.0.7-secrets:5.5.54-11312+1596042169)) system/system.go:103
2020-07-29T18:17:26Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/masters/kevin-test1/system-upgrade, State=completed) cluster/engine.go:288
2020-07-29T18:17:26Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Wed Jul 29 17:03 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Wed Jul 29 17:16 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Wed Jul 29 17:19 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Wed Jul 29 17:46 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Wed Jul 29 18:01 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Wed Jul 29 17:51 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Wed Jul 29 18:01 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Wed Jul 29 18:01 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Wed Jul 29 18:03 UTC
→ masters                      Update master nodes                                        In Progress     -              /coredns                                      Wed Jul 29 18:17 UTC
  → kevin-test1                Update system software on master node \"kevin-test1\"        In Progress     -              -                                             Wed Jul 29 18:17 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Wed Jul 29 18:08 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Wed Jul 29 18:11 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Wed Jul 29 18:13 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Wed Jul 29 18:17 UTC
    * taint                    Taint node \"kevin-test1\"                                   Unstarted       10.162.0.7     /masters/kevin-test1/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test1\"                                Unstarted       10.162.0.7     /masters/kevin-test1/taint                    -
    * untaint                  Remove taint from node \"kevin-test1\"                       Unstarted       10.162.0.7     /masters/kevin-test1/uncordon                 -
  * elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Unstarted       -              /masters/kevin-test1                          -
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted       -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted       10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted       10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted       10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted       10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted       10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted       -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted       -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted       10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted       10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted       10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted       10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted       10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted       -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted       -              -                                             -
  * backup                     Backup etcd data                                           Unstarted       -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted       -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted       -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted       -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted       -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
Wed Jul 29 18:17:26 UTC	Executing phase "/masters/kevin-test1/system-upgrade" finished in 58 seconds
```

#### Nodes: Taint
A Kubernetes Node Taint is added to the node prior to Uncordoning. This allows only the gravitational internal services to launch on the node before it's returned to service.

```
root@kevin-test1:~/build# ./gravity --debug plan execute --phase /masters/kevin-test1/taint 2>&1 | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'

...

2020-07-29T18:20:24Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Wed Jul 29 17:03 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Wed Jul 29 17:16 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Wed Jul 29 17:19 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Wed Jul 29 17:46 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Wed Jul 29 18:01 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Wed Jul 29 17:51 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Wed Jul 29 18:01 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Wed Jul 29 18:01 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Wed Jul 29 18:03 UTC
→ masters                      Update master nodes                                        In Progress     -              /coredns                                      Wed Jul 29 18:20 UTC
  → kevin-test1                Update system software on master node \"kevin-test1\"        In Progress     -              -                                             Wed Jul 29 18:20 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Wed Jul 29 18:08 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Wed Jul 29 18:11 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Wed Jul 29 18:13 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Wed Jul 29 18:17 UTC
    → taint                    Taint node \"kevin-test1\"                                   In Progress     10.162.0.7     /masters/kevin-test1/system-upgrade           Wed Jul 29 18:20 UTC
    * uncordon                 Uncordon node \"kevin-test1\"                                Unstarted       10.162.0.7     /masters/kevin-test1/taint                    -
    * untaint                  Remove taint from node \"kevin-test1\"                       Unstarted       10.162.0.7     /masters/kevin-test1/uncordon                 -
  * elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Unstarted       -              /masters/kevin-test1                          -
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted       -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted       10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted       10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted       10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted       10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted       10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted       -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted       -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted       10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted       10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted       10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted       10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted       10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted       -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted       -              -                                             -
  * backup                     Backup etcd data                                           Unstarted       -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted       -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted       -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted       -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted       -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
2020-07-29T18:20:24Z INFO             Executing phase: /masters/kevin-test1/taint. phase:/masters/kevin-test1/taint fsm/logger.go:61
2020-07-29T18:20:24Z INFO             Taint node(addr=10.162.0.7, hostname=kevin-test1, role=node, cluster_role=master). phase:/masters/kevin-test1/taint fsm/logger.go:61
2020-07-29T18:20:24Z DEBU             Dial. addr:leader.telekube.local:6443 network:tcp httplib/client.go:225
2020-07-29T18:20:24Z DEBU             Resolve leader.telekube.local took 799.796µs. utils/dns.go:47
2020-07-29T18:20:24Z DEBU             Resolved leader.telekube.local to 10.162.0.6. utils/dns.go:54
2020-07-29T18:20:24Z DEBU             Dial. host-port:10.162.0.6:6443 httplib/client.go:263
2020-07-29T18:20:24Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/masters/kevin-test1/taint, State=completed) cluster/engine.go:288
2020-07-29T18:20:25Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Wed Jul 29 17:03 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Wed Jul 29 17:16 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Wed Jul 29 17:19 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Wed Jul 29 17:46 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Wed Jul 29 18:01 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Wed Jul 29 17:51 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Wed Jul 29 18:01 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Wed Jul 29 18:01 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Wed Jul 29 18:03 UTC
→ masters                      Update master nodes                                        In Progress     -              /coredns                                      Wed Jul 29 18:20 UTC
  → kevin-test1                Update system software on master node \"kevin-test1\"        In Progress     -              -                                             Wed Jul 29 18:20 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Wed Jul 29 18:08 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Wed Jul 29 18:11 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Wed Jul 29 18:13 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Wed Jul 29 18:17 UTC
    ✓ taint                    Taint node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Wed Jul 29 18:20 UTC
    * uncordon                 Uncordon node \"kevin-test1\"                                Unstarted       10.162.0.7     /masters/kevin-test1/taint                    -
    * untaint                  Remove taint from node \"kevin-test1\"                       Unstarted       10.162.0.7     /masters/kevin-test1/uncordon                 -
  * elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Unstarted       -              /masters/kevin-test1                          -
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted       -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted       10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted       10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted       10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted       10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted       10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted       -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted       -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted       10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted       10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted       10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted       10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted       10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted       -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted       -              -                                             -
  * backup                     Backup etcd data                                           Unstarted       -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted       -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted       -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted       -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted       -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
Wed Jul 29 18:20:25 UTC	Executing phase "/masters/kevin-test1/taint" finished in 1 second
```

Check Taints:
```
root@kevin-test1:~/build# kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
NAME          TAINTS
10.162.0.7    [map[effect:NoExecute key:gravitational.io/runlevel value:system] map[effect:NoSchedule key:node.kubernetes.io/unschedulable timeAdded:2020-07-29T18:13:15Z]]
kevin-test2   <none>
kevin-test3   <none>
```

#### Nodes: Uncordon
Removed the cordon setting on the node, allowing the kubernetes scheduler to see the node as available to be scheduled to.

```
root@kevin-test1:~/build# ./gravity --debug plan execute --phase /masters/kevin-test1/uncordon 2>&1 | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'

...

2020-07-29T18:27:21Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Wed Jul 29 17:03 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Wed Jul 29 17:16 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Wed Jul 29 17:19 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Wed Jul 29 17:46 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Wed Jul 29 18:01 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Wed Jul 29 17:51 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Wed Jul 29 18:01 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Wed Jul 29 18:01 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Wed Jul 29 18:03 UTC
→ masters                      Update master nodes                                        In Progress     -              /coredns                                      Wed Jul 29 18:27 UTC
  → kevin-test1                Update system software on master node \"kevin-test1\"        In Progress     -              -                                             Wed Jul 29 18:27 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Wed Jul 29 18:08 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Wed Jul 29 18:11 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Wed Jul 29 18:13 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Wed Jul 29 18:17 UTC
    ✓ taint                    Taint node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Wed Jul 29 18:20 UTC
    → uncordon                 Uncordon node \"kevin-test1\"                                In Progress     10.162.0.7     /masters/kevin-test1/taint                    Wed Jul 29 18:27 UTC
    * untaint                  Remove taint from node \"kevin-test1\"                       Unstarted       10.162.0.7     /masters/kevin-test1/uncordon                 -
  * elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Unstarted       -              /masters/kevin-test1                          -
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted       -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted       10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted       10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted       10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted       10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted       10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted       -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted       -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted       10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted       10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted       10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted       10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted       10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted       -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted       -              -                                             -
  * backup                     Backup etcd data                                           Unstarted       -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted       -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted       -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted       -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted       -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
2020-07-29T18:27:21Z INFO             Executing phase: /masters/kevin-test1/uncordon. phase:/masters/kevin-test1/uncordon fsm/logger.go:61
2020-07-29T18:27:21Z INFO             Uncordon node(addr=10.162.0.7, hostname=kevin-test1, role=node, cluster_role=master). phase:/masters/kevin-test1/uncordon fsm/logger.go:61
2020-07-29T18:27:21Z DEBU             Dial. addr:leader.telekube.local:6443 network:tcp httplib/client.go:225
2020-07-29T18:27:21Z DEBU             Resolve leader.telekube.local took 209.088µs. utils/dns.go:47
2020-07-29T18:27:21Z DEBU             Resolved leader.telekube.local to 10.162.0.6. utils/dns.go:54
2020-07-29T18:27:21Z DEBU             Dial. host-port:10.162.0.6:6443 httplib/client.go:263
2020-07-29T18:27:21Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/masters/kevin-test1/uncordon, State=completed) cluster/engine.go:288
2020-07-29T18:27:21Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Wed Jul 29 17:03 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Wed Jul 29 17:16 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Wed Jul 29 17:19 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Wed Jul 29 17:46 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Wed Jul 29 18:01 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Wed Jul 29 17:51 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Wed Jul 29 18:01 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Wed Jul 29 18:01 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Wed Jul 29 18:03 UTC
→ masters                      Update master nodes                                        In Progress     -              /coredns                                      Wed Jul 29 18:27 UTC
  → kevin-test1                Update system software on master node \"kevin-test1\"        In Progress     -              -                                             Wed Jul 29 18:27 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Wed Jul 29 18:08 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Wed Jul 29 18:11 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Wed Jul 29 18:13 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Wed Jul 29 18:17 UTC
    ✓ taint                    Taint node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Wed Jul 29 18:20 UTC
    ✓ uncordon                 Uncordon node \"kevin-test1\"                                Completed       10.162.0.7     /masters/kevin-test1/taint                    Wed Jul 29 18:27 UTC
    * untaint                  Remove taint from node \"kevin-test1\"                       Unstarted       10.162.0.7     /masters/kevin-test1/uncordon                 -
  * elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Unstarted       -              /masters/kevin-test1                          -
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted       -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted       10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted       10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted       10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted       10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted       10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted       -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted       -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted       10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted       10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted       10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted       10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted       10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted       -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted       -              -                                             -
  * backup                     Backup etcd data                                           Unstarted       -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted       -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted       -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted       -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted       -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
Wed Jul 29 18:27:21 UTC	Executing phase "/masters/kevin-test1/uncordon" finished in 1 second
```

```
root@kevin-test1:~/build# kubectl get nodes
NAME          STATUS   ROLES    AGE   VERSION
10.162.0.7    Ready    <none>   98m   v1.13.12
kevin-test2   Ready    <none>   94m   v1.13.12
kevin-test3   Ready    <none>   92m   v1.13.12
```

#### Nodes: Untaint
Removes the node taint placed earlier, to open the node up for additional scheduling.

```
root@kevin-test1:~/build# ./gravity --debug plan execute --phase /masters/kevin-test1/untaint 2>&1 | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'

...

2020-07-29T18:29:36Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Wed Jul 29 17:03 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Wed Jul 29 17:16 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Wed Jul 29 17:19 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Wed Jul 29 17:46 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Wed Jul 29 18:01 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Wed Jul 29 17:51 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Wed Jul 29 18:01 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Wed Jul 29 18:01 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Wed Jul 29 18:03 UTC
→ masters                      Update master nodes                                        In Progress     -              /coredns                                      Wed Jul 29 18:29 UTC
  → kevin-test1                Update system software on master node \"kevin-test1\"        In Progress     -              -                                             Wed Jul 29 18:29 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Wed Jul 29 18:08 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Wed Jul 29 18:11 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Wed Jul 29 18:13 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Wed Jul 29 18:17 UTC
    ✓ taint                    Taint node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Wed Jul 29 18:20 UTC
    ✓ uncordon                 Uncordon node \"kevin-test1\"                                Completed       10.162.0.7     /masters/kevin-test1/taint                    Wed Jul 29 18:27 UTC
    → untaint                  Remove taint from node \"kevin-test1\"                       In Progress     10.162.0.7     /masters/kevin-test1/uncordon                 Wed Jul 29 18:29 UTC
  * elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Unstarted       -              /masters/kevin-test1                          -
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted       -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted       10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted       10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted       10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted       10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted       10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted       -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted       -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted       10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted       10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted       10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted       10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted       10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted       -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted       -              -                                             -
  * backup                     Backup etcd data                                           Unstarted       -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted       -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted       -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted       -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted       -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
2020-07-29T18:29:36Z INFO             Executing phase: /masters/kevin-test1/untaint. phase:/masters/kevin-test1/untaint fsm/logger.go:61
2020-07-29T18:29:36Z INFO             Remove taint from node(addr=10.162.0.7, hostname=kevin-test1, role=node, cluster_role=master). phase:/masters/kevin-test1/untaint fsm/logger.go:61
2020-07-29T18:29:36Z DEBU             Dial. addr:leader.telekube.local:6443 network:tcp httplib/client.go:225
2020-07-29T18:29:36Z DEBU             Resolve leader.telekube.local took 242.725µs. utils/dns.go:47
2020-07-29T18:29:36Z DEBU             Resolved leader.telekube.local to 10.162.0.6. utils/dns.go:54
2020-07-29T18:29:36Z DEBU             Dial. host-port:10.162.0.6:6443 httplib/client.go:263
2020-07-29T18:29:36Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/masters/kevin-test1/untaint, State=completed) cluster/engine.go:288
2020-07-29T18:29:37Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Wed Jul 29 17:03 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Wed Jul 29 17:16 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Wed Jul 29 17:19 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Wed Jul 29 17:46 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Wed Jul 29 18:01 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Wed Jul 29 17:51 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Wed Jul 29 18:01 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Wed Jul 29 18:01 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Wed Jul 29 18:03 UTC
→ masters                      Update master nodes                                        In Progress     -              /coredns                                      Wed Jul 29 18:29 UTC
  ✓ kevin-test1                Update system software on master node \"kevin-test1\"        Completed       -              -                                             Wed Jul 29 18:29 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Wed Jul 29 18:08 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Wed Jul 29 18:11 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Wed Jul 29 18:13 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Wed Jul 29 18:17 UTC
    ✓ taint                    Taint node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Wed Jul 29 18:20 UTC
    ✓ uncordon                 Uncordon node \"kevin-test1\"                                Completed       10.162.0.7     /masters/kevin-test1/taint                    Wed Jul 29 18:27 UTC
    ✓ untaint                  Remove taint from node \"kevin-test1\"                       Completed       10.162.0.7     /masters/kevin-test1/uncordon                 Wed Jul 29 18:29 UTC
  * elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Unstarted       -              /masters/kevin-test1                          -
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted       -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted       10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted       10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted       10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted       10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted       10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted       -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted       -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted       10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted       10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted       10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted       10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted       10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted       -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted       -              -                                             -
  * backup                     Backup etcd data                                           Unstarted       -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted       -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted       -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted       -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted       -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
Wed Jul 29 18:29:37 UTC	Executing phase "/masters/kevin-test1/untaint" finished in 1 second
```

#### Nodes: Elect (First Master)
After the first master node has been upgraded, the leader election is changed to only allow the upgraded node to take leadership. In effect, we force the first master to be upgraded to also be elected the planet leader, and remain on the latest version of kubernetes throughout the rest of the upgrade. As the masters are upgraded, they'll be re-added to the election process, to take over in the case of a failure.

If the first master were to fail at this point, the cluster would not be able to elect another node to take over as the planet leader.

```
root@kevin-test1:~/build# ./gravity --debug plan execute --phase /masters/elect-kevin-test1 2>&1 | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'

...

2020-07-29T18:31:37Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Wed Jul 29 17:03 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Wed Jul 29 17:16 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Wed Jul 29 17:19 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Wed Jul 29 17:46 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Wed Jul 29 18:01 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Wed Jul 29 17:51 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Wed Jul 29 18:01 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Wed Jul 29 18:01 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Wed Jul 29 18:03 UTC
→ masters                      Update master nodes                                        In Progress     -              /coredns                                      Wed Jul 29 18:31 UTC
  ✓ kevin-test1                Update system software on master node \"kevin-test1\"        Completed       -              -                                             Wed Jul 29 18:29 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Wed Jul 29 18:08 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Wed Jul 29 18:11 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Wed Jul 29 18:13 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Wed Jul 29 18:17 UTC
    ✓ taint                    Taint node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Wed Jul 29 18:20 UTC
    ✓ uncordon                 Uncordon node \"kevin-test1\"                                Completed       10.162.0.7     /masters/kevin-test1/taint                    Wed Jul 29 18:27 UTC
    ✓ untaint                  Remove taint from node \"kevin-test1\"                       Completed       10.162.0.7     /masters/kevin-test1/uncordon                 Wed Jul 29 18:29 UTC
  → elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  In Progress     -              /masters/kevin-test1                          Wed Jul 29 18:31 UTC
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted       -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted       10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted       10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted       10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted       10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted       10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted       -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted       -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted       10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted       10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted       10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted       10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted       10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted       -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted       -              -                                             -
  * backup                     Backup etcd data                                           Unstarted       -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted       -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted       -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted       -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted       -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
2020-07-29T18:31:37Z INFO             Executing phase: /masters/elect-kevin-test1. phase:/masters/elect-kevin-test1 fsm/logger.go:61
2020-07-29T18:31:37Z DEBU             Executing command: [/home/knisbet/build/gravity planet enter -- --notty /usr/bin/etcdctl -- set /planet/cluster/wonderfulspence252/election/10.162.0.6 false]. fsm/rpc.go:217
2020-07-29T18:31:37Z DEBU             Executing command: [/home/knisbet/build/gravity planet enter -- --notty /usr/bin/etcdctl -- set /planet/cluster/wonderfulspence252/election/10.162.0.5 false]. fsm/rpc.go:217
2020-07-29T18:31:37Z DEBU             Executing command: [/home/knisbet/build/gravity planet enter -- --notty /usr/bin/etcdctl -- set /planet/cluster/wonderfulspence252/election/10.162.0.7 true]. fsm/rpc.go:217
2020-07-29T18:31:38Z INFO             Wait for new leader election. phase:/masters/elect-kevin-test1 fsm/logger.go:61
2020-07-29T18:31:38Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/masters/elect-kevin-test1, State=completed) cluster/engine.go:288
2020-07-29T18:31:38Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Wed Jul 29 17:03 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Wed Jul 29 17:16 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Wed Jul 29 17:16 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Wed Jul 29 17:19 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Wed Jul 29 17:46 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Wed Jul 29 18:01 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Wed Jul 29 17:51 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Wed Jul 29 18:01 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Wed Jul 29 18:01 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Wed Jul 29 18:03 UTC
→ masters                      Update master nodes                                        In Progress     -              /coredns                                      Wed Jul 29 18:31 UTC
  ✓ kevin-test1                Update system software on master node \"kevin-test1\"        Completed       -              -                                             Wed Jul 29 18:29 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Wed Jul 29 18:08 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Wed Jul 29 18:11 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Wed Jul 29 18:13 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Wed Jul 29 18:17 UTC
    ✓ taint                    Taint node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Wed Jul 29 18:20 UTC
    ✓ uncordon                 Uncordon node \"kevin-test1\"                                Completed       10.162.0.7     /masters/kevin-test1/taint                    Wed Jul 29 18:27 UTC
    ✓ untaint                  Remove taint from node \"kevin-test1\"                       Completed       10.162.0.7     /masters/kevin-test1/uncordon                 Wed Jul 29 18:29 UTC
  ✓ elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Completed       -              /masters/kevin-test1                          Wed Jul 29 18:31 UTC
  * kevin-test2                Update system software on master node \"kevin-test2\"        Unstarted       -              /masters/elect-kevin-test1                    -
    * drain                    Drain node \"kevin-test2\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test2\"               Unstarted       10.162.0.6     /masters/kevin-test2/drain                    -
    * taint                    Taint node \"kevin-test2\"                                   Unstarted       10.162.0.7     /masters/kevin-test2/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test2\"                                Unstarted       10.162.0.7     /masters/kevin-test2/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Unstarted       10.162.0.7     /masters/kevin-test2/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test2\"                       Unstarted       10.162.0.7     /masters/kevin-test2/endpoints                -
    * enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Unstarted       -              /masters/kevin-test2/untaint                  -
  * kevin-test3                Update system software on master node \"kevin-test3\"        Unstarted       -              /masters/kevin-test2                          -
    * drain                    Drain node \"kevin-test3\"                                   Unstarted       10.162.0.7     -                                             -
    * system-upgrade           Update system software on node \"kevin-test3\"               Unstarted       10.162.0.5     /masters/kevin-test3/drain                    -
    * taint                    Taint node \"kevin-test3\"                                   Unstarted       10.162.0.7     /masters/kevin-test3/system-upgrade           -
    * uncordon                 Uncordon node \"kevin-test3\"                                Unstarted       10.162.0.7     /masters/kevin-test3/taint                    -
    * endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Unstarted       10.162.0.7     /masters/kevin-test3/uncordon                 -
    * untaint                  Remove taint from node \"kevin-test3\"                       Unstarted       10.162.0.7     /masters/kevin-test3/endpoints                -
    * enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Unstarted       -              /masters/kevin-test3/untaint                  -
* etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Unstarted       -              -                                             -
  * backup                     Backup etcd data                                           Unstarted       -              -                                             -
    * kevin-test1              Backup etcd on node \"kevin-test1\"                          Unstarted       -              -                                             -
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted       -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted       -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted       -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
Wed Jul 29 18:31:38 UTC	Executing phase "/masters/elect-kevin-test1" finished in 1 second
```

#### Complete the Masters
Complete upgrading the rest of the cluster:
```
root@kevin-test1:~/build# ./gravity  plan execute --phase /masters 2>&1 | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'
Wed Jul 29 18:38:42 UTC	Executing "/masters/kevin-test2/drain" locally
Wed Jul 29 18:38:51 UTC	Executing "/masters/kevin-test2/system-upgrade" on remote node kevin-test2
	Still executing "/masters/kevin-test2/system-upgrade" on remote node kevin-test2 (10 seconds elapsed)
	Still executing "/masters/kevin-test2/system-upgrade" on remote node kevin-test2 (20 seconds elapsed)
	Still executing "/masters/kevin-test2/system-upgrade" on remote node kevin-test2 (30 seconds elapsed)
	Still executing "/masters/kevin-test2/system-upgrade" on remote node kevin-test2 (40 seconds elapsed)
	Still executing "/masters/kevin-test2/system-upgrade" on remote node kevin-test2 (50 seconds elapsed)
	Still executing "/masters/kevin-test2/system-upgrade" on remote node kevin-test2 (1 minute elapsed)
Wed Jul 29 18:39:56 UTC	Executing "/masters/kevin-test2/taint" locally
Wed Jul 29 18:39:57 UTC	Executing "/masters/kevin-test2/uncordon" locally
Wed Jul 29 18:39:58 UTC	Executing "/masters/kevin-test2/endpoints" locally
Wed Jul 29 18:39:59 UTC	Executing "/masters/kevin-test2/untaint" locally
Wed Jul 29 18:40:00 UTC	Executing "/masters/kevin-test2/enable-kevin-test2" on remote node kevin-test2
Wed Jul 29 18:40:02 UTC	Executing "/masters/kevin-test3/drain" locally
	Still executing "/masters/kevin-test3/drain" locally (10 seconds elapsed)
Wed Jul 29 18:40:16 UTC	Executing "/masters/kevin-test3/system-upgrade" on remote node kevin-test3
	Still executing "/masters/kevin-test3/system-upgrade" on remote node kevin-test3 (10 seconds elapsed)
	Still executing "/masters/kevin-test3/system-upgrade" on remote node kevin-test3 (20 seconds elapsed)
	Still executing "/masters/kevin-test3/system-upgrade" on remote node kevin-test3 (30 seconds elapsed)
	Still executing "/masters/kevin-test3/system-upgrade" on remote node kevin-test3 (40 seconds elapsed)
	Still executing "/masters/kevin-test3/system-upgrade" on remote node kevin-test3 (50 seconds elapsed)
Wed Jul 29 18:41:06 UTC	Executing "/masters/kevin-test3/taint" locally
Wed Jul 29 18:41:07 UTC	Executing "/masters/kevin-test3/uncordon" locally
Wed Jul 29 18:41:08 UTC	Executing "/masters/kevin-test3/endpoints" locally
Wed Jul 29 18:41:09 UTC	Executing "/masters/kevin-test3/untaint" locally
Wed Jul 29 18:41:10 UTC	Executing "/masters/kevin-test3/enable-kevin-test3" on remote node kevin-test3
Wed Jul 29 18:41:13 UTC	Executing phase "/masters" finished in 2 minutes
```

#### Etcd (/etcd)
Upgrading etcd is the most complicated portion of the upgrade process when required.

Etcd is the database that underpins kubernetes, storing all the kubernetes objects that you interact with using kubectl. Because etcd underpins kubernetes, we use the same database to persist internal state of gravity, that can be shared and replicated amongst the master nodes. When designing the upgrade process for gravity, we had a number of constraints:

- Customers want to skip versions. So when a cluster falls behind on versions, and is finally time to upgrade, 2 or 3 upgrades may happen in a row. Etcd doesn't support or test skipping versions, so we might have lots of upgrades to perform.
- Etcd when upgraded, writes to the same files on disks. So an older version may not be able to load the files on disk from a newer version.
- The etcd cluster locks itself to the new version when all nodes are running the same latest version. Nodes using an older version are no longer allowed to participate within the cluster.

These constraints make it extremely difficult to support a normal rolling upgrade, like we do with the planet container. Instead we use a process that operates more like a backup & restore procedure, where we backup the etcd database, and build a new cluster on the new version using separate data directories. When it comes to rollback, we then simply need to restart the old etcd cluster, which hasn't been locked to a newer version.

The downside of this approach, is it means a period of time where the underlying database is offline. The application will still be running within kubernetes, but no changes can be made while the upgrade is taking place. Tools like kubectl will also not function.

There is a secondary problem, which is the gravity upgrade shares it's state with other nodes using etcd. So while etcd is down, when inspecting the plan from certain nodes you'll only see a portion of the plan. This is normal and expected behaviour, but can be surprising if not expected.

#### Etcd: Backup
The backup phase is where we backup the underlying etcd database. We backup on each master to be safe, but the backup will only be restored on a single node.

```
root@kevin-test1:~/build# ./gravity --debug plan execute --phase /etcd/backup/kevin-test1 2>&1 | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'

...

2020-07-31T06:42:23Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Fri Jul 31 06:32 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Fri Jul 31 06:32 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Fri Jul 31 06:34 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Fri Jul 31 06:36 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Fri Jul 31 06:38 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Fri Jul 31 06:38 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Fri Jul 31 06:38 UTC
✓ masters                      Update master nodes                                        Completed       -              /coredns                                      Fri Jul 31 06:41 UTC
  ✓ kevin-test1                Update system software on master node \"kevin-test1\"        Completed       -              -                                             Fri Jul 31 06:39 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Fri Jul 31 06:38 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Fri Jul 31 06:38 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Fri Jul 31 06:38 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Fri Jul 31 06:39 UTC
    ✓ taint                    Taint node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Fri Jul 31 06:39 UTC
    ✓ uncordon                 Uncordon node \"kevin-test1\"                                Completed       10.162.0.7     /masters/kevin-test1/taint                    Fri Jul 31 06:39 UTC
    ✓ untaint                  Remove taint from node \"kevin-test1\"                       Completed       10.162.0.7     /masters/kevin-test1/uncordon                 Fri Jul 31 06:39 UTC
  ✓ elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Completed       -              /masters/kevin-test1                          Fri Jul 31 06:39 UTC
  ✓ kevin-test2                Update system software on master node \"kevin-test2\"        Completed       -              /masters/elect-kevin-test1                    Fri Jul 31 06:40 UTC
    ✓ drain                    Drain node \"kevin-test2\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:39 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test2\"               Completed       10.162.0.6     /masters/kevin-test2/drain                    Fri Jul 31 06:40 UTC
    ✓ taint                    Taint node \"kevin-test2\"                                   Completed       10.162.0.7     /masters/kevin-test2/system-upgrade           Fri Jul 31 06:40 UTC
    ✓ uncordon                 Uncordon node \"kevin-test2\"                                Completed       10.162.0.7     /masters/kevin-test2/taint                    Fri Jul 31 06:40 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Completed       10.162.0.7     /masters/kevin-test2/uncordon                 Fri Jul 31 06:40 UTC
    ✓ untaint                  Remove taint from node \"kevin-test2\"                       Completed       10.162.0.7     /masters/kevin-test2/endpoints                Fri Jul 31 06:40 UTC
    ✓ enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Completed       -              /masters/kevin-test2/untaint                  Fri Jul 31 06:40 UTC
  ✓ kevin-test3                Update system software on master node \"kevin-test3\"        Completed       -              /masters/kevin-test2                          Fri Jul 31 06:41 UTC
    ✓ drain                    Drain node \"kevin-test3\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:40 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test3\"               Completed       10.162.0.5     /masters/kevin-test3/drain                    Fri Jul 31 06:41 UTC
    ✓ taint                    Taint node \"kevin-test3\"                                   Completed       10.162.0.7     /masters/kevin-test3/system-upgrade           Fri Jul 31 06:41 UTC
    ✓ uncordon                 Uncordon node \"kevin-test3\"                                Completed       10.162.0.7     /masters/kevin-test3/taint                    Fri Jul 31 06:41 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Completed       10.162.0.7     /masters/kevin-test3/uncordon                 Fri Jul 31 06:41 UTC
    ✓ untaint                  Remove taint from node \"kevin-test3\"                       Completed       10.162.0.7     /masters/kevin-test3/endpoints                Fri Jul 31 06:41 UTC
    ✓ enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Completed       -              /masters/kevin-test3/untaint                  Fri Jul 31 06:41 UTC
→ etcd                         Upgrade etcd 3.3.20 to 3.3.22                              In Progress     -              -                                             Fri Jul 31 06:42 UTC
  → backup                     Backup etcd data                                           In Progress     -              -                                             Fri Jul 31 06:42 UTC
    → kevin-test1              Backup etcd on node \"kevin-test1\"                          In Progress     -              -                                             Fri Jul 31 06:42 UTC
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted       -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted       -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted       -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
2020-07-31T06:42:23Z INFO             Executing phase: /etcd/backup/kevin-test1. phase:/etcd/backup/kevin-test1 fsm/logger.go:61
2020-07-31T06:42:23Z INFO             Backup etcd. phase:/etcd/backup/kevin-test1 fsm/logger.go:61
2020-07-31T06:42:24Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/etcd/backup/kevin-test1, State=completed) cluster/engine.go:288
2020-07-31T06:42:24Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Fri Jul 31 06:32 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Fri Jul 31 06:32 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Fri Jul 31 06:34 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Fri Jul 31 06:36 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Fri Jul 31 06:38 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Fri Jul 31 06:38 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Fri Jul 31 06:38 UTC
✓ masters                      Update master nodes                                        Completed       -              /coredns                                      Fri Jul 31 06:41 UTC
  ✓ kevin-test1                Update system software on master node \"kevin-test1\"        Completed       -              -                                             Fri Jul 31 06:39 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Fri Jul 31 06:38 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Fri Jul 31 06:38 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Fri Jul 31 06:38 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Fri Jul 31 06:39 UTC
    ✓ taint                    Taint node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Fri Jul 31 06:39 UTC
    ✓ uncordon                 Uncordon node \"kevin-test1\"                                Completed       10.162.0.7     /masters/kevin-test1/taint                    Fri Jul 31 06:39 UTC
    ✓ untaint                  Remove taint from node \"kevin-test1\"                       Completed       10.162.0.7     /masters/kevin-test1/uncordon                 Fri Jul 31 06:39 UTC
  ✓ elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Completed       -              /masters/kevin-test1                          Fri Jul 31 06:39 UTC
  ✓ kevin-test2                Update system software on master node \"kevin-test2\"        Completed       -              /masters/elect-kevin-test1                    Fri Jul 31 06:40 UTC
    ✓ drain                    Drain node \"kevin-test2\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:39 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test2\"               Completed       10.162.0.6     /masters/kevin-test2/drain                    Fri Jul 31 06:40 UTC
    ✓ taint                    Taint node \"kevin-test2\"                                   Completed       10.162.0.7     /masters/kevin-test2/system-upgrade           Fri Jul 31 06:40 UTC
    ✓ uncordon                 Uncordon node \"kevin-test2\"                                Completed       10.162.0.7     /masters/kevin-test2/taint                    Fri Jul 31 06:40 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Completed       10.162.0.7     /masters/kevin-test2/uncordon                 Fri Jul 31 06:40 UTC
    ✓ untaint                  Remove taint from node \"kevin-test2\"                       Completed       10.162.0.7     /masters/kevin-test2/endpoints                Fri Jul 31 06:40 UTC
    ✓ enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Completed       -              /masters/kevin-test2/untaint                  Fri Jul 31 06:40 UTC
  ✓ kevin-test3                Update system software on master node \"kevin-test3\"        Completed       -              /masters/kevin-test2                          Fri Jul 31 06:41 UTC
    ✓ drain                    Drain node \"kevin-test3\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:40 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test3\"               Completed       10.162.0.5     /masters/kevin-test3/drain                    Fri Jul 31 06:41 UTC
    ✓ taint                    Taint node \"kevin-test3\"                                   Completed       10.162.0.7     /masters/kevin-test3/system-upgrade           Fri Jul 31 06:41 UTC
    ✓ uncordon                 Uncordon node \"kevin-test3\"                                Completed       10.162.0.7     /masters/kevin-test3/taint                    Fri Jul 31 06:41 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Completed       10.162.0.7     /masters/kevin-test3/uncordon                 Fri Jul 31 06:41 UTC
    ✓ untaint                  Remove taint from node \"kevin-test3\"                       Completed       10.162.0.7     /masters/kevin-test3/endpoints                Fri Jul 31 06:41 UTC
    ✓ enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Completed       -              /masters/kevin-test3/untaint                  Fri Jul 31 06:41 UTC
→ etcd                         Upgrade etcd 3.3.20 to 3.3.22                              In Progress     -              -                                             Fri Jul 31 06:42 UTC
  → backup                     Backup etcd data                                           In Progress     -              -                                             Fri Jul 31 06:42 UTC
    ✓ kevin-test1              Backup etcd on node \"kevin-test1\"                          Completed       -              -                                             Fri Jul 31 06:42 UTC
    * kevin-test2              Backup etcd on node \"kevin-test2\"                          Unstarted       -              -                                             -
    * kevin-test3              Backup etcd on node \"kevin-test3\"                          Unstarted       -              -                                             -
  * shutdown                   Shutdown etcd cluster                                      Unstarted       -              -                                             -
    * kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
Fri Jul 31 06:42:24 UTC	Executing phase "/etcd/backup/kevin-test1" finished in 1 second
```

Take a look at the backup:
```
root@kevin-test1:~/build# head /var/lib/gravity/site/update/etcd.bak
{"version":"1"}
{"v2":{"key":"","dir":true,"value":"","nodes":null,"createdIndex":0,"modifiedIndex":0}}
{"v2":{"key":"/coreos.com","dir":true,"value":"","nodes":null,"createdIndex":4,"modifiedIndex":4}}
{"v2":{"key":"/coreos.com/network","dir":true,"value":"","nodes":null,"createdIndex":4,"modifiedIndex":4}}
{"v2":{"key":"/coreos.com/network/config","value":"{\"Network\":\"10.244.0.0/16\", \"Backend\": {\"Type\": \"vxlan\", \"RouteTableFilter\": [\"tag:KubernetesCluster=lucidkowalevski5986\"], \"Port\": 8472}}","nodes":null,"createdIndex":2496,"modifiedIndex":2496}}
{"v2":{"key":"/coreos.com/network/subnets","dir":true,"value":"","nodes":null,"createdIndex":5,"modifiedIndex":5}}
{"v2":{"key":"/coreos.com/network/subnets/10.244.50.0-24","value":"{\"PublicIP\":\"10.162.0.5\",\"BackendType\":\"vxlan\",\"BackendData\":{\"VtepMAC\":\"ee:6b:e1:22:80:0d\"}}","nodes":null,"createdIndex":2497,"modifiedIndex":2497,"expiration":"2020-08-01T06:41:02.498328477Z","ttl":86319}}
{"v2":{"key":"/coreos.com/network/subnets/10.244.80.0-24","value":"{\"PublicIP\":\"10.162.0.7\",\"BackendType\":\"vxlan\",\"BackendData\":{\"VtepMAC\":\"da:7b:df:fc:e6:71\"}}","nodes":null,"createdIndex":2263,"modifiedIndex":2263,"expiration":"2020-08-01T06:38:54.356709307Z","ttl":86191}}
{"v2":{"key":"/coreos.com/network/subnets/10.244.97.0-24","value":"{\"PublicIP\":\"10.162.0.6\",\"BackendType\":\"vxlan\",\"BackendData\":{\"VtepMAC\":\"6e:dc:08:38:9f:5e\"}}","nodes":null,"createdIndex":2371,"modifiedIndex":2371,"expiration":"2020-08-01T06:39:54.306343219Z","ttl":86251}}
{"v2":{"key":"/gravity","dir":true,"value":"","nodes":null,"createdIndex":27,"modifiedIndex":27}}
```

Backup the rest of the cluster

```
root@kevin-test1:~/build# ./gravity plan execute --phase /etcd/backup
Fri Jul 31 06:44:00 UTC	Executing "/etcd/backup/kevin-test2" on remote node kevin-test2
Fri Jul 31 06:44:03 UTC	Executing "/etcd/backup/kevin-test3" on remote node kevin-test3
Fri Jul 31 06:44:05 UTC	Executing phase "/etcd/backup" finished in 5 seconds
```

#### Etcd: Shutdown
Shutdown will stop etcd on each server within the cluster, for the duration of the upgrade.

```
root@kevin-test1:~/build# ./gravity --debug plan execute --phase /etcd/shutdown/kevin-test1 2>&1 | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'

...

2020-07-31T06:45:24Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Fri Jul 31 06:32 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Fri Jul 31 06:32 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Fri Jul 31 06:34 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Fri Jul 31 06:36 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Fri Jul 31 06:38 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Fri Jul 31 06:38 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Fri Jul 31 06:38 UTC
✓ masters                      Update master nodes                                        Completed       -              /coredns                                      Fri Jul 31 06:41 UTC
  ✓ kevin-test1                Update system software on master node \"kevin-test1\"        Completed       -              -                                             Fri Jul 31 06:39 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Fri Jul 31 06:38 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Fri Jul 31 06:38 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Fri Jul 31 06:38 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Fri Jul 31 06:39 UTC
    ✓ taint                    Taint node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Fri Jul 31 06:39 UTC
    ✓ uncordon                 Uncordon node \"kevin-test1\"                                Completed       10.162.0.7     /masters/kevin-test1/taint                    Fri Jul 31 06:39 UTC
    ✓ untaint                  Remove taint from node \"kevin-test1\"                       Completed       10.162.0.7     /masters/kevin-test1/uncordon                 Fri Jul 31 06:39 UTC
  ✓ elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Completed       -              /masters/kevin-test1                          Fri Jul 31 06:39 UTC
  ✓ kevin-test2                Update system software on master node \"kevin-test2\"        Completed       -              /masters/elect-kevin-test1                    Fri Jul 31 06:40 UTC
    ✓ drain                    Drain node \"kevin-test2\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:39 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test2\"               Completed       10.162.0.6     /masters/kevin-test2/drain                    Fri Jul 31 06:40 UTC
    ✓ taint                    Taint node \"kevin-test2\"                                   Completed       10.162.0.7     /masters/kevin-test2/system-upgrade           Fri Jul 31 06:40 UTC
    ✓ uncordon                 Uncordon node \"kevin-test2\"                                Completed       10.162.0.7     /masters/kevin-test2/taint                    Fri Jul 31 06:40 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Completed       10.162.0.7     /masters/kevin-test2/uncordon                 Fri Jul 31 06:40 UTC
    ✓ untaint                  Remove taint from node \"kevin-test2\"                       Completed       10.162.0.7     /masters/kevin-test2/endpoints                Fri Jul 31 06:40 UTC
    ✓ enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Completed       -              /masters/kevin-test2/untaint                  Fri Jul 31 06:40 UTC
  ✓ kevin-test3                Update system software on master node \"kevin-test3\"        Completed       -              /masters/kevin-test2                          Fri Jul 31 06:41 UTC
    ✓ drain                    Drain node \"kevin-test3\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:40 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test3\"               Completed       10.162.0.5     /masters/kevin-test3/drain                    Fri Jul 31 06:41 UTC
    ✓ taint                    Taint node \"kevin-test3\"                                   Completed       10.162.0.7     /masters/kevin-test3/system-upgrade           Fri Jul 31 06:41 UTC
    ✓ uncordon                 Uncordon node \"kevin-test3\"                                Completed       10.162.0.7     /masters/kevin-test3/taint                    Fri Jul 31 06:41 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Completed       10.162.0.7     /masters/kevin-test3/uncordon                 Fri Jul 31 06:41 UTC
    ✓ untaint                  Remove taint from node \"kevin-test3\"                       Completed       10.162.0.7     /masters/kevin-test3/endpoints                Fri Jul 31 06:41 UTC
    ✓ enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Completed       -              /masters/kevin-test3/untaint                  Fri Jul 31 06:41 UTC
→ etcd                         Upgrade etcd 3.3.20 to 3.3.22                              In Progress     -              -                                             Fri Jul 31 06:45 UTC
  ✓ backup                     Backup etcd data                                           Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test1              Backup etcd on node \"kevin-test1\"                          Completed       -              -                                             Fri Jul 31 06:42 UTC
    ✓ kevin-test2              Backup etcd on node \"kevin-test2\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test3              Backup etcd on node \"kevin-test3\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
  → shutdown                   Shutdown etcd cluster                                      In Progress     -              -                                             Fri Jul 31 06:45 UTC
    → kevin-test1              Shutdown etcd on node \"kevin-test1\"                        In Progress     -              /etcd/backup/kevin-test1                      Fri Jul 31 06:45 UTC
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
2020-07-31T06:45:24Z INFO             Executing phase: /etcd/shutdown/kevin-test1. phase:/etcd/shutdown/kevin-test1 fsm/logger.go:61
2020-07-31T06:45:24Z INFO             Shutdown etcd. phase:/etcd/shutdown/kevin-test1 fsm/logger.go:61
2020-07-31T06:45:33Z INFO             command output:  phase:/etcd/shutdown/kevin-test1 fsm/logger.go:61
2020-07-31T06:45:33Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/etcd/shutdown/kevin-test1, State=completed) cluster/engine.go:288
2020-07-31T06:45:33Z DEBU             "retrying on transient etcd error: client: etcd cluster is unavailable or misconfigured; error #0: dial tcp 127.0.0.1:2379: connect: connection refused
" keyval/etcd.go:575
2020-07-31T06:45:33Z DEBU             "retrying on transient etcd error: client: etcd cluster is unavailable or misconfigured; error #0: dial tcp 127.0.0.1:2379: connect: connection refused
" keyval/etcd.go:575
2020-07-31T06:45:33Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Fri Jul 31 06:32 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Fri Jul 31 06:32 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Fri Jul 31 06:34 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Fri Jul 31 06:36 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Fri Jul 31 06:38 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Fri Jul 31 06:38 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Fri Jul 31 06:38 UTC
✓ masters                      Update master nodes                                        Completed       -              /coredns                                      Fri Jul 31 06:41 UTC
  ✓ kevin-test1                Update system software on master node \"kevin-test1\"        Completed       -              -                                             Fri Jul 31 06:39 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Fri Jul 31 06:38 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Fri Jul 31 06:38 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Fri Jul 31 06:38 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Fri Jul 31 06:39 UTC
    ✓ taint                    Taint node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Fri Jul 31 06:39 UTC
    ✓ uncordon                 Uncordon node \"kevin-test1\"                                Completed       10.162.0.7     /masters/kevin-test1/taint                    Fri Jul 31 06:39 UTC
    ✓ untaint                  Remove taint from node \"kevin-test1\"                       Completed       10.162.0.7     /masters/kevin-test1/uncordon                 Fri Jul 31 06:39 UTC
  ✓ elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Completed       -              /masters/kevin-test1                          Fri Jul 31 06:39 UTC
  ✓ kevin-test2                Update system software on master node \"kevin-test2\"        Completed       -              /masters/elect-kevin-test1                    Fri Jul 31 06:40 UTC
    ✓ drain                    Drain node \"kevin-test2\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:39 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test2\"               Completed       10.162.0.6     /masters/kevin-test2/drain                    Fri Jul 31 06:40 UTC
    ✓ taint                    Taint node \"kevin-test2\"                                   Completed       10.162.0.7     /masters/kevin-test2/system-upgrade           Fri Jul 31 06:40 UTC
    ✓ uncordon                 Uncordon node \"kevin-test2\"                                Completed       10.162.0.7     /masters/kevin-test2/taint                    Fri Jul 31 06:40 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Completed       10.162.0.7     /masters/kevin-test2/uncordon                 Fri Jul 31 06:40 UTC
    ✓ untaint                  Remove taint from node \"kevin-test2\"                       Completed       10.162.0.7     /masters/kevin-test2/endpoints                Fri Jul 31 06:40 UTC
    ✓ enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Completed       -              /masters/kevin-test2/untaint                  Fri Jul 31 06:40 UTC
  ✓ kevin-test3                Update system software on master node \"kevin-test3\"        Completed       -              /masters/kevin-test2                          Fri Jul 31 06:41 UTC
    ✓ drain                    Drain node \"kevin-test3\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:40 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test3\"               Completed       10.162.0.5     /masters/kevin-test3/drain                    Fri Jul 31 06:41 UTC
    ✓ taint                    Taint node \"kevin-test3\"                                   Completed       10.162.0.7     /masters/kevin-test3/system-upgrade           Fri Jul 31 06:41 UTC
    ✓ uncordon                 Uncordon node \"kevin-test3\"                                Completed       10.162.0.7     /masters/kevin-test3/taint                    Fri Jul 31 06:41 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Completed       10.162.0.7     /masters/kevin-test3/uncordon                 Fri Jul 31 06:41 UTC
    ✓ untaint                  Remove taint from node \"kevin-test3\"                       Completed       10.162.0.7     /masters/kevin-test3/endpoints                Fri Jul 31 06:41 UTC
    ✓ enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Completed       -              /masters/kevin-test3/untaint                  Fri Jul 31 06:41 UTC
→ etcd                         Upgrade etcd 3.3.20 to 3.3.22                              In Progress     -              -                                             Fri Jul 31 06:45 UTC
  ✓ backup                     Backup etcd data                                           Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test1              Backup etcd on node \"kevin-test1\"                          Completed       -              -                                             Fri Jul 31 06:42 UTC
    ✓ kevin-test2              Backup etcd on node \"kevin-test2\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test3              Backup etcd on node \"kevin-test3\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
  → shutdown                   Shutdown etcd cluster                                      In Progress     -              -                                             Fri Jul 31 06:45 UTC
    ✓ kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Completed       -              /etcd/backup/kevin-test1                      Fri Jul 31 06:45 UTC
    * kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    * kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
Fri Jul 31 06:45:33 UTC	Executing phase "/etcd/shutdown/kevin-test1" finished in 9 seconds
```

Shutdown the rest of the nodes.

```
root@kevin-test1:~/build# ./gravity plan execute --phase /etcd/shutdown
Fri Jul 31 06:46:29 UTC	Executing "/etcd/shutdown/kevin-test2" on remote node kevin-test2
	Still executing "/etcd/shutdown/kevin-test2" on remote node kevin-test2 (10 seconds elapsed)
Fri Jul 31 06:46:39 UTC	Executing "/etcd/shutdown/kevin-test3" on remote node kevin-test3
Fri Jul 31 06:46:48 UTC	Executing phase "/etcd/shutdown" finished in 19 seconds
```

We can see that the plan is now out of sync between the cluster nodes.

```
root@kevin-test1:~/build# /var/lib/gravity/site/update/agent/gravity plan
Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test1                Initialize node "kevin-test1"                              Completed       10.162.0.7     -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test2                Initialize node "kevin-test2"                              Completed       10.162.0.6     -                                             Fri Jul 31 06:32 UTC
  ✓ kevin-test3                Initialize node "kevin-test3"                              Completed       10.162.0.5     -                                             Fri Jul 31 06:32 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Fri Jul 31 06:34 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Fri Jul 31 06:36 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Fri Jul 31 06:38 UTC
  ✓ kevin-test1                Bootstrap node "kevin-test1"                               Completed       10.162.0.7     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test2                Bootstrap node "kevin-test2"                               Completed       10.162.0.6     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test3                Bootstrap node "kevin-test3"                               Completed       10.162.0.5     -                                             Fri Jul 31 06:38 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Fri Jul 31 06:38 UTC
✓ masters                      Update master nodes                                        Completed       -              /coredns                                      Fri Jul 31 06:41 UTC
  ✓ kevin-test1                Update system software on master node "kevin-test1"        Completed       -              -                                             Fri Jul 31 06:39 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on "kevin-test1"                Completed       -              -                                             Fri Jul 31 06:38 UTC
    ✓ stepdown-kevin-test1     Step down "kevin-test1" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Fri Jul 31 06:38 UTC
    ✓ drain                    Drain node "kevin-test1"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Fri Jul 31 06:38 UTC
    ✓ system-upgrade           Update system software on node "kevin-test1"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Fri Jul 31 06:39 UTC
    ✓ taint                    Taint node "kevin-test1"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Fri Jul 31 06:39 UTC
    ✓ uncordon                 Uncordon node "kevin-test1"                                Completed       10.162.0.7     /masters/kevin-test1/taint                    Fri Jul 31 06:39 UTC
    ✓ untaint                  Remove taint from node "kevin-test1"                       Completed       10.162.0.7     /masters/kevin-test1/uncordon                 Fri Jul 31 06:39 UTC
  ✓ elect-kevin-test1          Make node "kevin-test1" Kubernetes leader                  Completed       -              /masters/kevin-test1                          Fri Jul 31 06:39 UTC
  ✓ kevin-test2                Update system software on master node "kevin-test2"        Completed       -              /masters/elect-kevin-test1                    Fri Jul 31 06:40 UTC
    ✓ drain                    Drain node "kevin-test2"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:39 UTC
    ✓ system-upgrade           Update system software on node "kevin-test2"               Completed       10.162.0.6     /masters/kevin-test2/drain                    Fri Jul 31 06:40 UTC
    ✓ taint                    Taint node "kevin-test2"                                   Completed       10.162.0.7     /masters/kevin-test2/system-upgrade           Fri Jul 31 06:40 UTC
    ✓ uncordon                 Uncordon node "kevin-test2"                                Completed       10.162.0.7     /masters/kevin-test2/taint                    Fri Jul 31 06:40 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on "kevin-test2"            Completed       10.162.0.7     /masters/kevin-test2/uncordon                 Fri Jul 31 06:40 UTC
    ✓ untaint                  Remove taint from node "kevin-test2"                       Completed       10.162.0.7     /masters/kevin-test2/endpoints                Fri Jul 31 06:40 UTC
    ✓ enable-kevin-test2       Enable leader election on node "kevin-test2"               Completed       -              /masters/kevin-test2/untaint                  Fri Jul 31 06:40 UTC
  ✓ kevin-test3                Update system software on master node "kevin-test3"        Completed       -              /masters/kevin-test2                          Fri Jul 31 06:41 UTC
    ✓ drain                    Drain node "kevin-test3"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:40 UTC
    ✓ system-upgrade           Update system software on node "kevin-test3"               Completed       10.162.0.5     /masters/kevin-test3/drain                    Fri Jul 31 06:41 UTC
    ✓ taint                    Taint node "kevin-test3"                                   Completed       10.162.0.7     /masters/kevin-test3/system-upgrade           Fri Jul 31 06:41 UTC
    ✓ uncordon                 Uncordon node "kevin-test3"                                Completed       10.162.0.7     /masters/kevin-test3/taint                    Fri Jul 31 06:41 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on "kevin-test3"            Completed       10.162.0.7     /masters/kevin-test3/uncordon                 Fri Jul 31 06:41 UTC
    ✓ untaint                  Remove taint from node "kevin-test3"                       Completed       10.162.0.7     /masters/kevin-test3/endpoints                Fri Jul 31 06:41 UTC
    ✓ enable-kevin-test3       Enable leader election on node "kevin-test3"               Completed       -              /masters/kevin-test3/untaint                  Fri Jul 31 06:41 UTC
→ etcd                         Upgrade etcd 3.3.20 to 3.3.22                              In Progress     -              -                                             Fri Jul 31 06:46 UTC
  ✓ backup                     Backup etcd data                                           Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test1              Backup etcd on node "kevin-test1"                          Completed       -              -                                             Fri Jul 31 06:42 UTC
    ✓ kevin-test2              Backup etcd on node "kevin-test2"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test3              Backup etcd on node "kevin-test3"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
  ✓ shutdown                   Shutdown etcd cluster                                      Completed       -              -                                             Fri Jul 31 06:46 UTC
    ✓ kevin-test1              Shutdown etcd on node "kevin-test1"                        Completed       -              /etcd/backup/kevin-test1                      Fri Jul 31 06:45 UTC
    ✓ kevin-test2              Shutdown etcd on node "kevin-test2"                        Completed       -              /etcd/backup/kevin-test2                      Fri Jul 31 06:46 UTC
    ✓ kevin-test3              Shutdown etcd on node "kevin-test3"                        Completed       -              /etcd/backup/kevin-test3                      Fri Jul 31 06:46 UTC
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node "kevin-test1"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node "kevin-test2"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node "kevin-test3"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node "kevin-test1"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node "kevin-test2"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node "kevin-test3"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node "kevin-test1"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node "kevin-test2"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node "kevin-test3"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application "rbac-app" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application "logging-app" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application "monitoring-app" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application "site" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application "kubernetes" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application "telekube" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node "kevin-test1"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node "kevin-test2"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node "kevin-test3"                                Unstarted       -              -                                             -


root@kevin-test2:~/5.5.46# /var/lib/gravity/site/update/agent/gravity plan
Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test1                Initialize node "kevin-test1"                              Completed       10.162.0.7     -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test2                Initialize node "kevin-test2"                              Completed       10.162.0.6     -                                             Fri Jul 31 06:32 UTC
  ✓ kevin-test3                Initialize node "kevin-test3"                              Completed       10.162.0.5     -                                             Fri Jul 31 06:32 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Fri Jul 31 06:34 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Fri Jul 31 06:36 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Fri Jul 31 06:38 UTC
  ✓ kevin-test1                Bootstrap node "kevin-test1"                               Completed       10.162.0.7     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test2                Bootstrap node "kevin-test2"                               Completed       10.162.0.6     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test3                Bootstrap node "kevin-test3"                               Completed       10.162.0.5     -                                             Fri Jul 31 06:38 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Fri Jul 31 06:38 UTC
✓ masters                      Update master nodes                                        Completed       -              /coredns                                      Fri Jul 31 06:41 UTC
  ✓ kevin-test1                Update system software on master node "kevin-test1"        Completed       -              -                                             Fri Jul 31 06:39 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on "kevin-test1"                Completed       -              -                                             Fri Jul 31 06:38 UTC
    ✓ stepdown-kevin-test1     Step down "kevin-test1" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Fri Jul 31 06:38 UTC
    ✓ drain                    Drain node "kevin-test1"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Fri Jul 31 06:38 UTC
    ✓ system-upgrade           Update system software on node "kevin-test1"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Fri Jul 31 06:39 UTC
    ✓ taint                    Taint node "kevin-test1"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Fri Jul 31 06:39 UTC
    ✓ uncordon                 Uncordon node "kevin-test1"                                Completed       10.162.0.7     /masters/kevin-test1/taint                    Fri Jul 31 06:39 UTC
    ✓ untaint                  Remove taint from node "kevin-test1"                       Completed       10.162.0.7     /masters/kevin-test1/uncordon                 Fri Jul 31 06:39 UTC
  ✓ elect-kevin-test1          Make node "kevin-test1" Kubernetes leader                  Completed       -              /masters/kevin-test1                          Fri Jul 31 06:39 UTC
  ✓ kevin-test2                Update system software on master node "kevin-test2"        Completed       -              /masters/elect-kevin-test1                    Fri Jul 31 06:40 UTC
    ✓ drain                    Drain node "kevin-test2"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:39 UTC
    ✓ system-upgrade           Update system software on node "kevin-test2"               Completed       10.162.0.6     /masters/kevin-test2/drain                    Fri Jul 31 06:40 UTC
    ✓ taint                    Taint node "kevin-test2"                                   Completed       10.162.0.7     /masters/kevin-test2/system-upgrade           Fri Jul 31 06:40 UTC
    ✓ uncordon                 Uncordon node "kevin-test2"                                Completed       10.162.0.7     /masters/kevin-test2/taint                    Fri Jul 31 06:40 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on "kevin-test2"            Completed       10.162.0.7     /masters/kevin-test2/uncordon                 Fri Jul 31 06:40 UTC
    ✓ untaint                  Remove taint from node "kevin-test2"                       Completed       10.162.0.7     /masters/kevin-test2/endpoints                Fri Jul 31 06:40 UTC
    ✓ enable-kevin-test2       Enable leader election on node "kevin-test2"               Completed       -              /masters/kevin-test2/untaint                  Fri Jul 31 06:40 UTC
  ✓ kevin-test3                Update system software on master node "kevin-test3"        Completed       -              /masters/kevin-test2                          Fri Jul 31 06:41 UTC
    ✓ drain                    Drain node "kevin-test3"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:40 UTC
    ✓ system-upgrade           Update system software on node "kevin-test3"               Completed       10.162.0.5     /masters/kevin-test3/drain                    Fri Jul 31 06:41 UTC
    ✓ taint                    Taint node "kevin-test3"                                   Completed       10.162.0.7     /masters/kevin-test3/system-upgrade           Fri Jul 31 06:41 UTC
    ✓ uncordon                 Uncordon node "kevin-test3"                                Completed       10.162.0.7     /masters/kevin-test3/taint                    Fri Jul 31 06:41 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on "kevin-test3"            Completed       10.162.0.7     /masters/kevin-test3/uncordon                 Fri Jul 31 06:41 UTC
    ✓ untaint                  Remove taint from node "kevin-test3"                       Completed       10.162.0.7     /masters/kevin-test3/endpoints                Fri Jul 31 06:41 UTC
    ✓ enable-kevin-test3       Enable leader election on node "kevin-test3"               Completed       -              /masters/kevin-test3/untaint                  Fri Jul 31 06:41 UTC
→ etcd                         Upgrade etcd 3.3.20 to 3.3.22                              In Progress     -              -                                             Fri Jul 31 06:46 UTC
  → backup                     Backup etcd data                                           In Progress     -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test1              Backup etcd on node "kevin-test1"                          Completed       -              -                                             Fri Jul 31 06:42 UTC
    ✓ kevin-test2              Backup etcd on node "kevin-test2"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
    * kevin-test3              Backup etcd on node "kevin-test3"                          Unstarted       -              -                                             -
  → shutdown                   Shutdown etcd cluster                                      In Progress     -              -                                             Fri Jul 31 06:46 UTC
    * kevin-test1              Shutdown etcd on node "kevin-test1"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    ✓ kevin-test2              Shutdown etcd on node "kevin-test2"                        Completed       -              /etcd/backup/kevin-test2                      Fri Jul 31 06:46 UTC
    * kevin-test3              Shutdown etcd on node "kevin-test3"                        Unstarted       -              /etcd/backup/kevin-test3                      -
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node "kevin-test1"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node "kevin-test2"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node "kevin-test3"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node "kevin-test1"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node "kevin-test2"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node "kevin-test3"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node "kevin-test1"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node "kevin-test2"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node "kevin-test3"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application "rbac-app" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application "logging-app" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application "monitoring-app" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application "site" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application "kubernetes" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application "telekube" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node "kevin-test1"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node "kevin-test2"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node "kevin-test3"                                Unstarted       -              -                                             -


root@kevin-test3:~/5.5.46# /var/lib/gravity/site/update/agent/gravity plan
Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test1                Initialize node "kevin-test1"                              Completed       10.162.0.7     -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test2                Initialize node "kevin-test2"                              Completed       10.162.0.6     -                                             Fri Jul 31 06:32 UTC
  ✓ kevin-test3                Initialize node "kevin-test3"                              Completed       10.162.0.5     -                                             Fri Jul 31 06:32 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Fri Jul 31 06:34 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Fri Jul 31 06:36 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Fri Jul 31 06:38 UTC
  ✓ kevin-test1                Bootstrap node "kevin-test1"                               Completed       10.162.0.7     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test2                Bootstrap node "kevin-test2"                               Completed       10.162.0.6     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test3                Bootstrap node "kevin-test3"                               Completed       10.162.0.5     -                                             Fri Jul 31 06:38 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Fri Jul 31 06:38 UTC
✓ masters                      Update master nodes                                        Completed       -              /coredns                                      Fri Jul 31 06:41 UTC
  ✓ kevin-test1                Update system software on master node "kevin-test1"        Completed       -              -                                             Fri Jul 31 06:39 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on "kevin-test1"                Completed       -              -                                             Fri Jul 31 06:38 UTC
    ✓ stepdown-kevin-test1     Step down "kevin-test1" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Fri Jul 31 06:38 UTC
    ✓ drain                    Drain node "kevin-test1"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Fri Jul 31 06:38 UTC
    ✓ system-upgrade           Update system software on node "kevin-test1"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Fri Jul 31 06:39 UTC
    ✓ taint                    Taint node "kevin-test1"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Fri Jul 31 06:39 UTC
    ✓ uncordon                 Uncordon node "kevin-test1"                                Completed       10.162.0.7     /masters/kevin-test1/taint                    Fri Jul 31 06:39 UTC
    ✓ untaint                  Remove taint from node "kevin-test1"                       Completed       10.162.0.7     /masters/kevin-test1/uncordon                 Fri Jul 31 06:39 UTC
  ✓ elect-kevin-test1          Make node "kevin-test1" Kubernetes leader                  Completed       -              /masters/kevin-test1                          Fri Jul 31 06:39 UTC
  ✓ kevin-test2                Update system software on master node "kevin-test2"        Completed       -              /masters/elect-kevin-test1                    Fri Jul 31 06:40 UTC
    ✓ drain                    Drain node "kevin-test2"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:39 UTC
    ✓ system-upgrade           Update system software on node "kevin-test2"               Completed       10.162.0.6     /masters/kevin-test2/drain                    Fri Jul 31 06:40 UTC
    ✓ taint                    Taint node "kevin-test2"                                   Completed       10.162.0.7     /masters/kevin-test2/system-upgrade           Fri Jul 31 06:40 UTC
    ✓ uncordon                 Uncordon node "kevin-test2"                                Completed       10.162.0.7     /masters/kevin-test2/taint                    Fri Jul 31 06:40 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on "kevin-test2"            Completed       10.162.0.7     /masters/kevin-test2/uncordon                 Fri Jul 31 06:40 UTC
    ✓ untaint                  Remove taint from node "kevin-test2"                       Completed       10.162.0.7     /masters/kevin-test2/endpoints                Fri Jul 31 06:40 UTC
    ✓ enable-kevin-test2       Enable leader election on node "kevin-test2"               Completed       -              /masters/kevin-test2/untaint                  Fri Jul 31 06:40 UTC
  ✓ kevin-test3                Update system software on master node "kevin-test3"        Completed       -              /masters/kevin-test2                          Fri Jul 31 06:41 UTC
    ✓ drain                    Drain node "kevin-test3"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:40 UTC
    ✓ system-upgrade           Update system software on node "kevin-test3"               Completed       10.162.0.5     /masters/kevin-test3/drain                    Fri Jul 31 06:41 UTC
    ✓ taint                    Taint node "kevin-test3"                                   Completed       10.162.0.7     /masters/kevin-test3/system-upgrade           Fri Jul 31 06:41 UTC
    ✓ uncordon                 Uncordon node "kevin-test3"                                Completed       10.162.0.7     /masters/kevin-test3/taint                    Fri Jul 31 06:41 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on "kevin-test3"            Completed       10.162.0.7     /masters/kevin-test3/uncordon                 Fri Jul 31 06:41 UTC
    ✓ untaint                  Remove taint from node "kevin-test3"                       Completed       10.162.0.7     /masters/kevin-test3/endpoints                Fri Jul 31 06:41 UTC
    ✓ enable-kevin-test3       Enable leader election on node "kevin-test3"               Completed       -              /masters/kevin-test3/untaint                  Fri Jul 31 06:41 UTC
→ etcd                         Upgrade etcd 3.3.20 to 3.3.22                              In Progress     -              -                                             Fri Jul 31 06:46 UTC
  ✓ backup                     Backup etcd data                                           Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test1              Backup etcd on node "kevin-test1"                          Completed       -              -                                             Fri Jul 31 06:42 UTC
    ✓ kevin-test2              Backup etcd on node "kevin-test2"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test3              Backup etcd on node "kevin-test3"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
  → shutdown                   Shutdown etcd cluster                                      In Progress     -              -                                             Fri Jul 31 06:46 UTC
    * kevin-test1              Shutdown etcd on node "kevin-test1"                        Unstarted       -              /etcd/backup/kevin-test1                      -
    * kevin-test2              Shutdown etcd on node "kevin-test2"                        Unstarted       -              /etcd/backup/kevin-test2                      -
    ✓ kevin-test3              Shutdown etcd on node "kevin-test3"                        Completed       -              /etcd/backup/kevin-test3                      Fri Jul 31 06:46 UTC
  * upgrade                    Upgrade etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Upgrade etcd on node "kevin-test1"                         Unstarted       -              /etcd/shutdown/kevin-test1                    -
    * kevin-test2              Upgrade etcd on node "kevin-test2"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node "kevin-test3"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node "kevin-test1"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node "kevin-test2"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node "kevin-test3"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node "kevin-test1"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node "kevin-test2"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node "kevin-test3"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application "rbac-app" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application "logging-app" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application "monitoring-app" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application "site" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application "kubernetes" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application "telekube" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node "kevin-test1"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node "kevin-test2"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node "kevin-test3"                                Unstarted       -              -                                             -
```

#### Etcd: Upgrade
The upgrade phase is where we reconfigure planet to use the new version of etcd. Additionally, we launch a temporary version of etcd to be used for restoring the backup.

We use a temporary etcd service, so that kubernetes doesn't see the empty database, and decide to start taking action within the cluster. We want the DB to be fully restored before any clients connect, and this is done by listening on a different IP/Port for this portion of the upgrade.

```
root@kevin-test1:~/build# ./gravity --debug plan execute --phase /etcd/upgrade/kevin-test1 2>&1 | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'

...

2020-07-31T06:50:13Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Fri Jul 31 06:32 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Fri Jul 31 06:32 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Fri Jul 31 06:34 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Fri Jul 31 06:36 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Fri Jul 31 06:38 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Fri Jul 31 06:38 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Fri Jul 31 06:38 UTC
✓ masters                      Update master nodes                                        Completed       -              /coredns                                      Fri Jul 31 06:41 UTC
  ✓ kevin-test1                Update system software on master node \"kevin-test1\"        Completed       -              -                                             Fri Jul 31 06:39 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Fri Jul 31 06:38 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Fri Jul 31 06:38 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Fri Jul 31 06:38 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Fri Jul 31 06:39 UTC
    ✓ taint                    Taint node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Fri Jul 31 06:39 UTC
    ✓ uncordon                 Uncordon node \"kevin-test1\"                                Completed       10.162.0.7     /masters/kevin-test1/taint                    Fri Jul 31 06:39 UTC
    ✓ untaint                  Remove taint from node \"kevin-test1\"                       Completed       10.162.0.7     /masters/kevin-test1/uncordon                 Fri Jul 31 06:39 UTC
  ✓ elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Completed       -              /masters/kevin-test1                          Fri Jul 31 06:39 UTC
  ✓ kevin-test2                Update system software on master node \"kevin-test2\"        Completed       -              /masters/elect-kevin-test1                    Fri Jul 31 06:40 UTC
    ✓ drain                    Drain node \"kevin-test2\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:39 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test2\"               Completed       10.162.0.6     /masters/kevin-test2/drain                    Fri Jul 31 06:40 UTC
    ✓ taint                    Taint node \"kevin-test2\"                                   Completed       10.162.0.7     /masters/kevin-test2/system-upgrade           Fri Jul 31 06:40 UTC
    ✓ uncordon                 Uncordon node \"kevin-test2\"                                Completed       10.162.0.7     /masters/kevin-test2/taint                    Fri Jul 31 06:40 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Completed       10.162.0.7     /masters/kevin-test2/uncordon                 Fri Jul 31 06:40 UTC
    ✓ untaint                  Remove taint from node \"kevin-test2\"                       Completed       10.162.0.7     /masters/kevin-test2/endpoints                Fri Jul 31 06:40 UTC
    ✓ enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Completed       -              /masters/kevin-test2/untaint                  Fri Jul 31 06:40 UTC
  ✓ kevin-test3                Update system software on master node \"kevin-test3\"        Completed       -              /masters/kevin-test2                          Fri Jul 31 06:41 UTC
    ✓ drain                    Drain node \"kevin-test3\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:40 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test3\"               Completed       10.162.0.5     /masters/kevin-test3/drain                    Fri Jul 31 06:41 UTC
    ✓ taint                    Taint node \"kevin-test3\"                                   Completed       10.162.0.7     /masters/kevin-test3/system-upgrade           Fri Jul 31 06:41 UTC
    ✓ uncordon                 Uncordon node \"kevin-test3\"                                Completed       10.162.0.7     /masters/kevin-test3/taint                    Fri Jul 31 06:41 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Completed       10.162.0.7     /masters/kevin-test3/uncordon                 Fri Jul 31 06:41 UTC
    ✓ untaint                  Remove taint from node \"kevin-test3\"                       Completed       10.162.0.7     /masters/kevin-test3/endpoints                Fri Jul 31 06:41 UTC
    ✓ enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Completed       -              /masters/kevin-test3/untaint                  Fri Jul 31 06:41 UTC
→ etcd                         Upgrade etcd 3.3.20 to 3.3.22                              In Progress     -              -                                             Fri Jul 31 06:50 UTC
  ✓ backup                     Backup etcd data                                           Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test1              Backup etcd on node \"kevin-test1\"                          Completed       -              -                                             Fri Jul 31 06:42 UTC
    ✓ kevin-test2              Backup etcd on node \"kevin-test2\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test3              Backup etcd on node \"kevin-test3\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
  ✓ shutdown                   Shutdown etcd cluster                                      Completed       -              -                                             Fri Jul 31 06:46 UTC
    ✓ kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Completed       -              /etcd/backup/kevin-test1                      Fri Jul 31 06:45 UTC
    ✓ kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Completed       -              /etcd/backup/kevin-test2                      Fri Jul 31 06:46 UTC
    ✓ kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Completed       -              /etcd/backup/kevin-test3                      Fri Jul 31 06:46 UTC
  → upgrade                    Upgrade etcd servers                                       In Progress     -              -                                             Fri Jul 31 06:50 UTC
    → kevin-test1              Upgrade etcd on node \"kevin-test1\"                         In Progress     -              /etcd/shutdown/kevin-test1                    Fri Jul 31 06:50 UTC
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
2020-07-31T06:50:13Z INFO             Executing phase: /etcd/upgrade/kevin-test1. phase:/etcd/upgrade/kevin-test1 fsm/logger.go:61
2020-07-31T06:50:13Z INFO             Upgrade etcd. phase:/etcd/upgrade/kevin-test1 fsm/logger.go:61
2020-07-31T06:50:13Z DEBU             "retrying on transient etcd error: client: etcd cluster is unavailable or misconfigured; error #0: dial tcp 127.0.0.1:2379: connect: connection refused
" keyval/etcd.go:575
2020-07-31T06:50:13Z INFO             command output:  phase:/etcd/upgrade/kevin-test1 fsm/logger.go:61
2020-07-31T06:50:13Z DEBU             "retrying on transient etcd error: client: etcd cluster is unavailable or misconfigured; error #0: dial tcp 127.0.0.1:2379: connect: connection refused
" keyval/etcd.go:575
2020-07-31T06:50:13Z INFO             command output:  phase:/etcd/upgrade/kevin-test1 fsm/logger.go:61
2020-07-31T06:50:13Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/etcd/upgrade/kevin-test1, State=completed) cluster/engine.go:288
2020-07-31T06:50:14Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Fri Jul 31 06:32 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Fri Jul 31 06:32 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Fri Jul 31 06:34 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Fri Jul 31 06:36 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Fri Jul 31 06:38 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Fri Jul 31 06:38 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Fri Jul 31 06:38 UTC
✓ masters                      Update master nodes                                        Completed       -              /coredns                                      Fri Jul 31 06:41 UTC
  ✓ kevin-test1                Update system software on master node \"kevin-test1\"        Completed       -              -                                             Fri Jul 31 06:39 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Fri Jul 31 06:38 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Fri Jul 31 06:38 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Fri Jul 31 06:38 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Fri Jul 31 06:39 UTC
    ✓ taint                    Taint node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Fri Jul 31 06:39 UTC
    ✓ uncordon                 Uncordon node \"kevin-test1\"                                Completed       10.162.0.7     /masters/kevin-test1/taint                    Fri Jul 31 06:39 UTC
    ✓ untaint                  Remove taint from node \"kevin-test1\"                       Completed       10.162.0.7     /masters/kevin-test1/uncordon                 Fri Jul 31 06:39 UTC
  ✓ elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Completed       -              /masters/kevin-test1                          Fri Jul 31 06:39 UTC
  ✓ kevin-test2                Update system software on master node \"kevin-test2\"        Completed       -              /masters/elect-kevin-test1                    Fri Jul 31 06:40 UTC
    ✓ drain                    Drain node \"kevin-test2\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:39 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test2\"               Completed       10.162.0.6     /masters/kevin-test2/drain                    Fri Jul 31 06:40 UTC
    ✓ taint                    Taint node \"kevin-test2\"                                   Completed       10.162.0.7     /masters/kevin-test2/system-upgrade           Fri Jul 31 06:40 UTC
    ✓ uncordon                 Uncordon node \"kevin-test2\"                                Completed       10.162.0.7     /masters/kevin-test2/taint                    Fri Jul 31 06:40 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Completed       10.162.0.7     /masters/kevin-test2/uncordon                 Fri Jul 31 06:40 UTC
    ✓ untaint                  Remove taint from node \"kevin-test2\"                       Completed       10.162.0.7     /masters/kevin-test2/endpoints                Fri Jul 31 06:40 UTC
    ✓ enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Completed       -              /masters/kevin-test2/untaint                  Fri Jul 31 06:40 UTC
  ✓ kevin-test3                Update system software on master node \"kevin-test3\"        Completed       -              /masters/kevin-test2                          Fri Jul 31 06:41 UTC
    ✓ drain                    Drain node \"kevin-test3\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:40 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test3\"               Completed       10.162.0.5     /masters/kevin-test3/drain                    Fri Jul 31 06:41 UTC
    ✓ taint                    Taint node \"kevin-test3\"                                   Completed       10.162.0.7     /masters/kevin-test3/system-upgrade           Fri Jul 31 06:41 UTC
    ✓ uncordon                 Uncordon node \"kevin-test3\"                                Completed       10.162.0.7     /masters/kevin-test3/taint                    Fri Jul 31 06:41 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Completed       10.162.0.7     /masters/kevin-test3/uncordon                 Fri Jul 31 06:41 UTC
    ✓ untaint                  Remove taint from node \"kevin-test3\"                       Completed       10.162.0.7     /masters/kevin-test3/endpoints                Fri Jul 31 06:41 UTC
    ✓ enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Completed       -              /masters/kevin-test3/untaint                  Fri Jul 31 06:41 UTC
→ etcd                         Upgrade etcd 3.3.20 to 3.3.22                              In Progress     -              -                                             Fri Jul 31 06:50 UTC
  ✓ backup                     Backup etcd data                                           Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test1              Backup etcd on node \"kevin-test1\"                          Completed       -              -                                             Fri Jul 31 06:42 UTC
    ✓ kevin-test2              Backup etcd on node \"kevin-test2\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test3              Backup etcd on node \"kevin-test3\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
  ✓ shutdown                   Shutdown etcd cluster                                      Completed       -              -                                             Fri Jul 31 06:46 UTC
    ✓ kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Completed       -              /etcd/backup/kevin-test1                      Fri Jul 31 06:45 UTC
    ✓ kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Completed       -              /etcd/backup/kevin-test2                      Fri Jul 31 06:46 UTC
    ✓ kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Completed       -              /etcd/backup/kevin-test3                      Fri Jul 31 06:46 UTC
  → upgrade                    Upgrade etcd servers                                       In Progress     -              -                                             Fri Jul 31 06:50 UTC
    ✓ kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Completed       -              /etcd/shutdown/kevin-test1                    Fri Jul 31 06:50 UTC
    * kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/shutdown/kevin-test2                    -
    * kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/shutdown/kevin-test3                    -
  * restore                    Restore etcd data from backup                              Unstarted       -              /etcd/upgrade                                 -
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
Fri Jul 31 06:50:14 UTC	Executing phase "/etcd/upgrade/kevin-test1" finished in 1 second
root@kevin-test1:~/build#
```

We can see how the etcd version is tracked internally
```
root@kevin-test1:~/build# gravity exec cat /ext/etcd/etcd-version.txt
PLANET_ETCD_VERSION=v3.3.22
PLANET_ETCD_PREV_VERSION=v3.3.20
KUBE_STORAGE_BACKEND=etcd3
```

Our temporary cluster is bound to a different IP Address (127.0.0.2) for client connections, preventing the api server and other clients from connecting locally.

```
root@kevin-test1:~/build# ps -ef | grep /usr/bin/etcd
ubuntu    1883  2457  3 06:50 ?        00:00:08 /usr/bin/etcd --name=10_162_0_7.lucidkowalevski5986 --data-dir=/ext/etcd/v3.3.22 --initial-advertise-peer-urls=https://10.162.0.7:2380 --advertise-client-urls=https://127.0.0.2:2379,https://127.0.0.2:4001 --listen-client-urls=https://127.0.0.2:2379,https://127.0.0.2:4001 --listen-peer-urls=https://10.162.0.7:2380,https://10.162.0.7:7001 --cert-file=/var/state/etcd.cert --key-file=/var/state/etcd.key --trusted-ca-file=/var/state/root.cert --client-cert-auth --peer-cert-file=/var/state/etcd.cert --peer-key-file=/var/state/etcd.key --peer-trusted-ca-file=/var/state/root.cert --peer-client-cert-auth --max-request-bytes=10485760 --initial-cluster-state new
root     13308 10045  0 06:54 pts/0    00:00:00 grep --color=auto /usr/bin/etcd
```

Update the etcd version in use on the rest of the nodes:
```
root@kevin-test1:~/build# ./gravity plan execute --phase /etcd/upgrade
Fri Jul 31 06:55:45 UTC	Executing "/etcd/upgrade/kevin-test2" on remote node kevin-test2
Fri Jul 31 06:55:48 UTC	Executing "/etcd/upgrade/kevin-test3" on remote node kevin-test3
Fri Jul 31 06:55:51 UTC	Executing phase "/etcd/upgrade" finished in 6 seconds
```

#### Etcd: Restore
The restore phase is where we restore from backup to the newly created cluster on our new version of etcd.

```
root@kevin-test1:~/build# ./gravity --debug plan execute --phase /etcd/restore 2>&1 | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'

...

2020-07-31T06:56:45Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Fri Jul 31 06:32 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Fri Jul 31 06:32 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Fri Jul 31 06:34 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Fri Jul 31 06:36 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Fri Jul 31 06:38 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Fri Jul 31 06:38 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Fri Jul 31 06:38 UTC
✓ masters                      Update master nodes                                        Completed       -              /coredns                                      Fri Jul 31 06:41 UTC
  ✓ kevin-test1                Update system software on master node \"kevin-test1\"        Completed       -              -                                             Fri Jul 31 06:39 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Fri Jul 31 06:38 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Fri Jul 31 06:38 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Fri Jul 31 06:38 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Fri Jul 31 06:39 UTC
    ✓ taint                    Taint node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Fri Jul 31 06:39 UTC
    ✓ uncordon                 Uncordon node \"kevin-test1\"                                Completed       10.162.0.7     /masters/kevin-test1/taint                    Fri Jul 31 06:39 UTC
    ✓ untaint                  Remove taint from node \"kevin-test1\"                       Completed       10.162.0.7     /masters/kevin-test1/uncordon                 Fri Jul 31 06:39 UTC
  ✓ elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Completed       -              /masters/kevin-test1                          Fri Jul 31 06:39 UTC
  ✓ kevin-test2                Update system software on master node \"kevin-test2\"        Completed       -              /masters/elect-kevin-test1                    Fri Jul 31 06:40 UTC
    ✓ drain                    Drain node \"kevin-test2\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:39 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test2\"               Completed       10.162.0.6     /masters/kevin-test2/drain                    Fri Jul 31 06:40 UTC
    ✓ taint                    Taint node \"kevin-test2\"                                   Completed       10.162.0.7     /masters/kevin-test2/system-upgrade           Fri Jul 31 06:40 UTC
    ✓ uncordon                 Uncordon node \"kevin-test2\"                                Completed       10.162.0.7     /masters/kevin-test2/taint                    Fri Jul 31 06:40 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Completed       10.162.0.7     /masters/kevin-test2/uncordon                 Fri Jul 31 06:40 UTC
    ✓ untaint                  Remove taint from node \"kevin-test2\"                       Completed       10.162.0.7     /masters/kevin-test2/endpoints                Fri Jul 31 06:40 UTC
    ✓ enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Completed       -              /masters/kevin-test2/untaint                  Fri Jul 31 06:40 UTC
  ✓ kevin-test3                Update system software on master node \"kevin-test3\"        Completed       -              /masters/kevin-test2                          Fri Jul 31 06:41 UTC
    ✓ drain                    Drain node \"kevin-test3\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:40 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test3\"               Completed       10.162.0.5     /masters/kevin-test3/drain                    Fri Jul 31 06:41 UTC
    ✓ taint                    Taint node \"kevin-test3\"                                   Completed       10.162.0.7     /masters/kevin-test3/system-upgrade           Fri Jul 31 06:41 UTC
    ✓ uncordon                 Uncordon node \"kevin-test3\"                                Completed       10.162.0.7     /masters/kevin-test3/taint                    Fri Jul 31 06:41 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Completed       10.162.0.7     /masters/kevin-test3/uncordon                 Fri Jul 31 06:41 UTC
    ✓ untaint                  Remove taint from node \"kevin-test3\"                       Completed       10.162.0.7     /masters/kevin-test3/endpoints                Fri Jul 31 06:41 UTC
    ✓ enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Completed       -              /masters/kevin-test3/untaint                  Fri Jul 31 06:41 UTC
→ etcd                         Upgrade etcd 3.3.20 to 3.3.22                              In Progress     -              -                                             Fri Jul 31 06:56 UTC
  ✓ backup                     Backup etcd data                                           Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test1              Backup etcd on node \"kevin-test1\"                          Completed       -              -                                             Fri Jul 31 06:42 UTC
    ✓ kevin-test2              Backup etcd on node \"kevin-test2\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test3              Backup etcd on node \"kevin-test3\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
  ✓ shutdown                   Shutdown etcd cluster                                      Completed       -              -                                             Fri Jul 31 06:46 UTC
    ✓ kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Completed       -              /etcd/backup/kevin-test1                      Fri Jul 31 06:45 UTC
    ✓ kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Completed       -              /etcd/backup/kevin-test2                      Fri Jul 31 06:46 UTC
    ✓ kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Completed       -              /etcd/backup/kevin-test3                      Fri Jul 31 06:46 UTC
  ✓ upgrade                    Upgrade etcd servers                                       Completed       -              -                                             Fri Jul 31 06:55 UTC
    ✓ kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Completed       -              /etcd/shutdown/kevin-test1                    Fri Jul 31 06:50 UTC
    ✓ kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Completed       -              /etcd/shutdown/kevin-test2                    Fri Jul 31 06:55 UTC
    ✓ kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Completed       -              /etcd/shutdown/kevin-test3                    Fri Jul 31 06:55 UTC
  → restore                    Restore etcd data from backup                              In Progress     -              /etcd/upgrade                                 Fri Jul 31 06:56 UTC
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
2020-07-31T06:56:45Z INFO             Executing phase: /etcd/restore. phase:/etcd/restore fsm/logger.go:61
2020-07-31T06:56:45Z INFO             Restore etcd data from backup. phase:/etcd/restore fsm/logger.go:61
2020-07-31T06:56:45Z DEBU             "retrying on transient etcd error: client: etcd cluster is unavailable or misconfigured; error #0: dial tcp 127.0.0.1:2379: connect: connection refused
" keyval/etcd.go:575
2020-07-31T06:56:46Z DEBU             "retrying on transient etcd error: client: etcd cluster is unavailable or misconfigured; error #0: dial tcp 127.0.0.1:2379: connect: connection refused
" keyval/etcd.go:575
2020-07-31T06:56:47Z DEBU             "retrying on transient etcd error: client: etcd cluster is unavailable or misconfigured; error #0: dial tcp 127.0.0.1:2379: connect: connection refused
" keyval/etcd.go:575
2020-07-31T06:56:49Z DEBU             "retrying on transient etcd error: client: etcd cluster is unavailable or misconfigured; error #0: dial tcp 127.0.0.1:2379: connect: connection refused
" keyval/etcd.go:575
2020-07-31T06:56:49Z INFO             Retrying in 747.884173ms. error:[
ERROR REPORT:
Original Error: *client.ClusterError client: etcd cluster is unavailable or misconfigured; error #0: dial tcp 127.0.0.1:2379: connect: connection refused

Stack Trace:
	/gopath/src/github.com/gravitational/gravity/lib/storage/keyval/etcd.go:576 github.com/gravitational/gravity/lib/storage/keyval.retryApi.retry.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:25 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.Retry
	/gopath/src/github.com/gravitational/gravity/lib/storage/keyval/etcd.go:572 github.com/gravitational/gravity/lib/storage/keyval.retryApi.retry
	/gopath/src/github.com/gravitational/gravity/lib/storage/keyval/etcd.go:489 github.com/gravitational/gravity/lib/storage/keyval.retryApi.Get
	/gopath/src/github.com/gravitational/gravity/lib/storage/keyval/etcd.go:374 github.com/gravitational/gravity/lib/storage/keyval.(*engine).getVal
	/gopath/src/github.com/gravitational/gravity/lib/storage/keyval/sites.go:120 github.com/gravitational/gravity/lib/storage/keyval.(*backend).GetSite
	/gopath/src/github.com/gravitational/gravity/lib/ops/opsservice/service.go:1378 github.com/gravitational/gravity/lib/ops/opsservice.(*Operator).openSite
	/gopath/src/github.com/gravitational/gravity/lib/ops/opsservice/service.go:1080 github.com/gravitational/gravity/lib/ops/opsservice.(*Operator).CreateLogEntry
	/gopath/src/github.com/gravitational/gravity/lib/fsm/logger.go:169 github.com/gravitational/gravity/lib/fsm.loop.func1
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:235 github.com/gravitational/gravity/lib/utils.RetryWithInterval.func1
	/gopath/src/github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff/retry.go:37 github.com/gravitational/gravity/vendor/github.com/cenkalti/backoff.RetryNotify
	/gopath/src/github.com/gravitational/gravity/lib/utils/retry.go:234 github.com/gravitational/gravity/lib/utils.RetryWithInterval
	/gopath/src/github.com/gravitational/gravity/lib/fsm/logger.go:168 github.com/gravitational/gravity/lib/fsm.loop
	/go/src/runtime/asm_amd64.s:1337 runtime.goexit
User Message: client: etcd cluster is unavailable or misconfigured; error #0: dial tcp 127.0.0.1:2379: connect: connection refused
] utils/retry.go:238
2020-07-31T06:56:50Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/etcd/restore, State=completed) cluster/engine.go:288
2020-07-31T06:56:50Z DEBU             "retrying on transient etcd error: client: etcd cluster is unavailable or misconfigured; error #0: dial tcp 127.0.0.1:2379: connect: connection refused
" keyval/etcd.go:575
2020-07-31T06:56:50Z DEBU             "retrying on transient etcd error: client: etcd cluster is unavailable or misconfigured; error #0: dial tcp 127.0.0.1:2379: connect: connection refused
" keyval/etcd.go:575
2020-07-31T06:56:50Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Fri Jul 31 06:32 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Fri Jul 31 06:32 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Fri Jul 31 06:34 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Fri Jul 31 06:36 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Fri Jul 31 06:38 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Fri Jul 31 06:38 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Fri Jul 31 06:38 UTC
✓ masters                      Update master nodes                                        Completed       -              /coredns                                      Fri Jul 31 06:41 UTC
  ✓ kevin-test1                Update system software on master node \"kevin-test1\"        Completed       -              -                                             Fri Jul 31 06:39 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Fri Jul 31 06:38 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Fri Jul 31 06:38 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Fri Jul 31 06:38 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Fri Jul 31 06:39 UTC
    ✓ taint                    Taint node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Fri Jul 31 06:39 UTC
    ✓ uncordon                 Uncordon node \"kevin-test1\"                                Completed       10.162.0.7     /masters/kevin-test1/taint                    Fri Jul 31 06:39 UTC
    ✓ untaint                  Remove taint from node \"kevin-test1\"                       Completed       10.162.0.7     /masters/kevin-test1/uncordon                 Fri Jul 31 06:39 UTC
  ✓ elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Completed       -              /masters/kevin-test1                          Fri Jul 31 06:39 UTC
  ✓ kevin-test2                Update system software on master node \"kevin-test2\"        Completed       -              /masters/elect-kevin-test1                    Fri Jul 31 06:40 UTC
    ✓ drain                    Drain node \"kevin-test2\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:39 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test2\"               Completed       10.162.0.6     /masters/kevin-test2/drain                    Fri Jul 31 06:40 UTC
    ✓ taint                    Taint node \"kevin-test2\"                                   Completed       10.162.0.7     /masters/kevin-test2/system-upgrade           Fri Jul 31 06:40 UTC
    ✓ uncordon                 Uncordon node \"kevin-test2\"                                Completed       10.162.0.7     /masters/kevin-test2/taint                    Fri Jul 31 06:40 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Completed       10.162.0.7     /masters/kevin-test2/uncordon                 Fri Jul 31 06:40 UTC
    ✓ untaint                  Remove taint from node \"kevin-test2\"                       Completed       10.162.0.7     /masters/kevin-test2/endpoints                Fri Jul 31 06:40 UTC
    ✓ enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Completed       -              /masters/kevin-test2/untaint                  Fri Jul 31 06:40 UTC
  ✓ kevin-test3                Update system software on master node \"kevin-test3\"        Completed       -              /masters/kevin-test2                          Fri Jul 31 06:41 UTC
    ✓ drain                    Drain node \"kevin-test3\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:40 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test3\"               Completed       10.162.0.5     /masters/kevin-test3/drain                    Fri Jul 31 06:41 UTC
    ✓ taint                    Taint node \"kevin-test3\"                                   Completed       10.162.0.7     /masters/kevin-test3/system-upgrade           Fri Jul 31 06:41 UTC
    ✓ uncordon                 Uncordon node \"kevin-test3\"                                Completed       10.162.0.7     /masters/kevin-test3/taint                    Fri Jul 31 06:41 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Completed       10.162.0.7     /masters/kevin-test3/uncordon                 Fri Jul 31 06:41 UTC
    ✓ untaint                  Remove taint from node \"kevin-test3\"                       Completed       10.162.0.7     /masters/kevin-test3/endpoints                Fri Jul 31 06:41 UTC
    ✓ enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Completed       -              /masters/kevin-test3/untaint                  Fri Jul 31 06:41 UTC
→ etcd                         Upgrade etcd 3.3.20 to 3.3.22                              In Progress     -              -                                             Fri Jul 31 06:56 UTC
  ✓ backup                     Backup etcd data                                           Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test1              Backup etcd on node \"kevin-test1\"                          Completed       -              -                                             Fri Jul 31 06:42 UTC
    ✓ kevin-test2              Backup etcd on node \"kevin-test2\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test3              Backup etcd on node \"kevin-test3\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
  ✓ shutdown                   Shutdown etcd cluster                                      Completed       -              -                                             Fri Jul 31 06:46 UTC
    ✓ kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Completed       -              /etcd/backup/kevin-test1                      Fri Jul 31 06:45 UTC
    ✓ kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Completed       -              /etcd/backup/kevin-test2                      Fri Jul 31 06:46 UTC
    ✓ kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Completed       -              /etcd/backup/kevin-test3                      Fri Jul 31 06:46 UTC
  ✓ upgrade                    Upgrade etcd servers                                       Completed       -              -                                             Fri Jul 31 06:55 UTC
    ✓ kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Completed       -              /etcd/shutdown/kevin-test1                    Fri Jul 31 06:50 UTC
    ✓ kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Completed       -              /etcd/shutdown/kevin-test2                    Fri Jul 31 06:55 UTC
    ✓ kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Completed       -              /etcd/shutdown/kevin-test3                    Fri Jul 31 06:55 UTC
  ✓ restore                    Restore etcd data from backup                              Completed       -              /etcd/upgrade                                 Fri Jul 31 06:56 UTC
  * restart                    Restart etcd servers                                       Unstarted       -              -                                             -
    * kevin-test1              Restart etcd on node \"kevin-test1\"                         Unstarted       -              /etcd/restore                                 -
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
Fri Jul 31 06:56:50 UTC	Executing phase "/etcd/restore" finished in 5 seconds
```

#### Etcd: Restart
Finally, we go through each node, and restart the cluster listening to the normal ports. Client's can reconnect, and the service impacting portion of the upgrade is complete.

```
root@kevin-test1:~/build# ./gravity --debug plan execute --phase /etcd/restart/kevin-test1 2>&1 | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'

...

2020-07-31T06:58:59Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Fri Jul 31 06:32 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Fri Jul 31 06:32 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Fri Jul 31 06:34 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Fri Jul 31 06:36 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Fri Jul 31 06:38 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Fri Jul 31 06:38 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Fri Jul 31 06:38 UTC
✓ masters                      Update master nodes                                        Completed       -              /coredns                                      Fri Jul 31 06:41 UTC
  ✓ kevin-test1                Update system software on master node \"kevin-test1\"        Completed       -              -                                             Fri Jul 31 06:39 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Fri Jul 31 06:38 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Fri Jul 31 06:38 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Fri Jul 31 06:38 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Fri Jul 31 06:39 UTC
    ✓ taint                    Taint node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Fri Jul 31 06:39 UTC
    ✓ uncordon                 Uncordon node \"kevin-test1\"                                Completed       10.162.0.7     /masters/kevin-test1/taint                    Fri Jul 31 06:39 UTC
    ✓ untaint                  Remove taint from node \"kevin-test1\"                       Completed       10.162.0.7     /masters/kevin-test1/uncordon                 Fri Jul 31 06:39 UTC
  ✓ elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Completed       -              /masters/kevin-test1                          Fri Jul 31 06:39 UTC
  ✓ kevin-test2                Update system software on master node \"kevin-test2\"        Completed       -              /masters/elect-kevin-test1                    Fri Jul 31 06:40 UTC
    ✓ drain                    Drain node \"kevin-test2\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:39 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test2\"               Completed       10.162.0.6     /masters/kevin-test2/drain                    Fri Jul 31 06:40 UTC
    ✓ taint                    Taint node \"kevin-test2\"                                   Completed       10.162.0.7     /masters/kevin-test2/system-upgrade           Fri Jul 31 06:40 UTC
    ✓ uncordon                 Uncordon node \"kevin-test2\"                                Completed       10.162.0.7     /masters/kevin-test2/taint                    Fri Jul 31 06:40 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Completed       10.162.0.7     /masters/kevin-test2/uncordon                 Fri Jul 31 06:40 UTC
    ✓ untaint                  Remove taint from node \"kevin-test2\"                       Completed       10.162.0.7     /masters/kevin-test2/endpoints                Fri Jul 31 06:40 UTC
    ✓ enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Completed       -              /masters/kevin-test2/untaint                  Fri Jul 31 06:40 UTC
  ✓ kevin-test3                Update system software on master node \"kevin-test3\"        Completed       -              /masters/kevin-test2                          Fri Jul 31 06:41 UTC
    ✓ drain                    Drain node \"kevin-test3\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:40 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test3\"               Completed       10.162.0.5     /masters/kevin-test3/drain                    Fri Jul 31 06:41 UTC
    ✓ taint                    Taint node \"kevin-test3\"                                   Completed       10.162.0.7     /masters/kevin-test3/system-upgrade           Fri Jul 31 06:41 UTC
    ✓ uncordon                 Uncordon node \"kevin-test3\"                                Completed       10.162.0.7     /masters/kevin-test3/taint                    Fri Jul 31 06:41 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Completed       10.162.0.7     /masters/kevin-test3/uncordon                 Fri Jul 31 06:41 UTC
    ✓ untaint                  Remove taint from node \"kevin-test3\"                       Completed       10.162.0.7     /masters/kevin-test3/endpoints                Fri Jul 31 06:41 UTC
    ✓ enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Completed       -              /masters/kevin-test3/untaint                  Fri Jul 31 06:41 UTC
→ etcd                         Upgrade etcd 3.3.20 to 3.3.22                              In Progress     -              -                                             Fri Jul 31 06:58 UTC
  ✓ backup                     Backup etcd data                                           Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test1              Backup etcd on node \"kevin-test1\"                          Completed       -              -                                             Fri Jul 31 06:42 UTC
    ✓ kevin-test2              Backup etcd on node \"kevin-test2\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test3              Backup etcd on node \"kevin-test3\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
  ✓ shutdown                   Shutdown etcd cluster                                      Completed       -              -                                             Fri Jul 31 06:46 UTC
    ✓ kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Completed       -              /etcd/backup/kevin-test1                      Fri Jul 31 06:45 UTC
    ✓ kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Completed       -              /etcd/backup/kevin-test2                      Fri Jul 31 06:46 UTC
    ✓ kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Completed       -              /etcd/backup/kevin-test3                      Fri Jul 31 06:46 UTC
  ✓ upgrade                    Upgrade etcd servers                                       Completed       -              -                                             Fri Jul 31 06:55 UTC
    ✓ kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Completed       -              /etcd/shutdown/kevin-test1                    Fri Jul 31 06:50 UTC
    ✓ kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Completed       -              /etcd/shutdown/kevin-test2                    Fri Jul 31 06:55 UTC
    ✓ kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Completed       -              /etcd/shutdown/kevin-test3                    Fri Jul 31 06:55 UTC
  ✓ restore                    Restore etcd data from backup                              Completed       -              /etcd/upgrade                                 Fri Jul 31 06:56 UTC
  → restart                    Restart etcd servers                                       In Progress     -              -                                             Fri Jul 31 06:58 UTC
    → kevin-test1              Restart etcd on node \"kevin-test1\"                         In Progress     -              /etcd/restore                                 Fri Jul 31 06:58 UTC
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
2020-07-31T06:58:59Z INFO             Executing phase: /etcd/restart/kevin-test1. phase:/etcd/restart/kevin-test1 fsm/logger.go:61
2020-07-31T06:58:59Z INFO             Restart etcd after upgrade. phase:/etcd/restart/kevin-test1 fsm/logger.go:61
2020-07-31T06:58:59Z DEBU             "retrying on transient etcd error: client: etcd cluster is unavailable or misconfigured; error #0: dial tcp 127.0.0.1:2379: connect: connection refused
" keyval/etcd.go:575
2020-07-31T06:59:00Z DEBU             "retrying on transient etcd error: client: etcd cluster is unavailable or misconfigured; error #0: dial tcp 127.0.0.1:2379: connect: connection refused
" keyval/etcd.go:575
2020-07-31T06:59:01Z INFO             command output:  phase:/etcd/restart/kevin-test1 fsm/logger.go:61
2020-07-31T06:59:01Z DEBU             "retrying on transient etcd error: client: etcd cluster is unavailable or misconfigured; error #0: dial tcp 127.0.0.1:2379: connect: connection refused
" keyval/etcd.go:575
2020-07-31T06:59:01Z INFO             command output:  phase:/etcd/restart/kevin-test1 fsm/logger.go:61
2020-07-31T06:59:01Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/etcd/restart/kevin-test1, State=completed) cluster/engine.go:288
2020-07-31T06:59:02Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Fri Jul 31 06:32 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Fri Jul 31 06:32 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Fri Jul 31 06:34 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Fri Jul 31 06:36 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Fri Jul 31 06:38 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Fri Jul 31 06:38 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Fri Jul 31 06:38 UTC
✓ masters                      Update master nodes                                        Completed       -              /coredns                                      Fri Jul 31 06:41 UTC
  ✓ kevin-test1                Update system software on master node \"kevin-test1\"        Completed       -              -                                             Fri Jul 31 06:39 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Fri Jul 31 06:38 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Fri Jul 31 06:38 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Fri Jul 31 06:38 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Fri Jul 31 06:39 UTC
    ✓ taint                    Taint node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Fri Jul 31 06:39 UTC
    ✓ uncordon                 Uncordon node \"kevin-test1\"                                Completed       10.162.0.7     /masters/kevin-test1/taint                    Fri Jul 31 06:39 UTC
    ✓ untaint                  Remove taint from node \"kevin-test1\"                       Completed       10.162.0.7     /masters/kevin-test1/uncordon                 Fri Jul 31 06:39 UTC
  ✓ elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Completed       -              /masters/kevin-test1                          Fri Jul 31 06:39 UTC
  ✓ kevin-test2                Update system software on master node \"kevin-test2\"        Completed       -              /masters/elect-kevin-test1                    Fri Jul 31 06:40 UTC
    ✓ drain                    Drain node \"kevin-test2\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:39 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test2\"               Completed       10.162.0.6     /masters/kevin-test2/drain                    Fri Jul 31 06:40 UTC
    ✓ taint                    Taint node \"kevin-test2\"                                   Completed       10.162.0.7     /masters/kevin-test2/system-upgrade           Fri Jul 31 06:40 UTC
    ✓ uncordon                 Uncordon node \"kevin-test2\"                                Completed       10.162.0.7     /masters/kevin-test2/taint                    Fri Jul 31 06:40 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Completed       10.162.0.7     /masters/kevin-test2/uncordon                 Fri Jul 31 06:40 UTC
    ✓ untaint                  Remove taint from node \"kevin-test2\"                       Completed       10.162.0.7     /masters/kevin-test2/endpoints                Fri Jul 31 06:40 UTC
    ✓ enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Completed       -              /masters/kevin-test2/untaint                  Fri Jul 31 06:40 UTC
  ✓ kevin-test3                Update system software on master node \"kevin-test3\"        Completed       -              /masters/kevin-test2                          Fri Jul 31 06:41 UTC
    ✓ drain                    Drain node \"kevin-test3\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:40 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test3\"               Completed       10.162.0.5     /masters/kevin-test3/drain                    Fri Jul 31 06:41 UTC
    ✓ taint                    Taint node \"kevin-test3\"                                   Completed       10.162.0.7     /masters/kevin-test3/system-upgrade           Fri Jul 31 06:41 UTC
    ✓ uncordon                 Uncordon node \"kevin-test3\"                                Completed       10.162.0.7     /masters/kevin-test3/taint                    Fri Jul 31 06:41 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Completed       10.162.0.7     /masters/kevin-test3/uncordon                 Fri Jul 31 06:41 UTC
    ✓ untaint                  Remove taint from node \"kevin-test3\"                       Completed       10.162.0.7     /masters/kevin-test3/endpoints                Fri Jul 31 06:41 UTC
    ✓ enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Completed       -              /masters/kevin-test3/untaint                  Fri Jul 31 06:41 UTC
→ etcd                         Upgrade etcd 3.3.20 to 3.3.22                              In Progress     -              -                                             Fri Jul 31 06:59 UTC
  ✓ backup                     Backup etcd data                                           Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test1              Backup etcd on node \"kevin-test1\"                          Completed       -              -                                             Fri Jul 31 06:42 UTC
    ✓ kevin-test2              Backup etcd on node \"kevin-test2\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test3              Backup etcd on node \"kevin-test3\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
  ✓ shutdown                   Shutdown etcd cluster                                      Completed       -              -                                             Fri Jul 31 06:46 UTC
    ✓ kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Completed       -              /etcd/backup/kevin-test1                      Fri Jul 31 06:45 UTC
    ✓ kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Completed       -              /etcd/backup/kevin-test2                      Fri Jul 31 06:46 UTC
    ✓ kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Completed       -              /etcd/backup/kevin-test3                      Fri Jul 31 06:46 UTC
  ✓ upgrade                    Upgrade etcd servers                                       Completed       -              -                                             Fri Jul 31 06:55 UTC
    ✓ kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Completed       -              /etcd/shutdown/kevin-test1                    Fri Jul 31 06:50 UTC
    ✓ kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Completed       -              /etcd/shutdown/kevin-test2                    Fri Jul 31 06:55 UTC
    ✓ kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Completed       -              /etcd/shutdown/kevin-test3                    Fri Jul 31 06:55 UTC
  ✓ restore                    Restore etcd data from backup                              Completed       -              /etcd/upgrade                                 Fri Jul 31 06:56 UTC
  → restart                    Restart etcd servers                                       In Progress     -              -                                             Fri Jul 31 06:59 UTC
    ✓ kevin-test1              Restart etcd on node \"kevin-test1\"                         Completed       -              /etcd/restore                                 Fri Jul 31 06:59 UTC
    * kevin-test2              Restart etcd on node \"kevin-test2\"                         Unstarted       -              /etcd/upgrade/kevin-test2                     -
    * kevin-test3              Restart etcd on node \"kevin-test3\"                         Unstarted       -              /etcd/upgrade/kevin-test3                     -
    * gravity-site             Restart gravity-site service                               Unstarted       -              -                                             -
* config                       Update system configuration on nodes                       Unstarted       -              /etcd                                         -
  * kevin-test1                Update system configuration on node \"kevin-test1\"          Unstarted       -              -                                             -
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
Fri Jul 31 06:59:02 UTC	Executing phase "/etcd/restart/kevin-test1" finished in 3 seconds
```

Finish restarting etcd:
```
root@kevin-test1:~/build# ./gravity plan execute --phase /etcd/restart
Fri Jul 31 06:59:59 UTC	Executing "/etcd/restart/kevin-test2" on remote node kevin-test2
Fri Jul 31 07:00:05 UTC	Executing "/etcd/restart/kevin-test3" on remote node kevin-test3
Fri Jul 31 07:00:10 UTC	Executing "/etcd/restart/gravity-site" locally
Fri Jul 31 07:00:12 UTC	Executing phase "/etcd/restart" finished in 13 seconds
```

At this point, the full plan will be available on all nodes in the cluster again.

#### System Configuration
The system configuration task is used to upgrade the teleport configuration on each node.

```
root@kevin-test1:~/build# ./gravity --debug plan execute --phase /config/kevin-test1 2>&1 | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'

...

2020-07-31T07:06:19Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Fri Jul 31 06:32 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Fri Jul 31 06:32 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Fri Jul 31 06:34 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Fri Jul 31 06:36 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Fri Jul 31 06:38 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Fri Jul 31 06:38 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Fri Jul 31 06:38 UTC
✓ masters                      Update master nodes                                        Completed       -              /coredns                                      Fri Jul 31 06:41 UTC
  ✓ kevin-test1                Update system software on master node \"kevin-test1\"        Completed       -              -                                             Fri Jul 31 06:39 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Fri Jul 31 06:38 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Fri Jul 31 06:38 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Fri Jul 31 06:38 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Fri Jul 31 06:39 UTC
    ✓ taint                    Taint node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Fri Jul 31 06:39 UTC
    ✓ uncordon                 Uncordon node \"kevin-test1\"                                Completed       10.162.0.7     /masters/kevin-test1/taint                    Fri Jul 31 06:39 UTC
    ✓ untaint                  Remove taint from node \"kevin-test1\"                       Completed       10.162.0.7     /masters/kevin-test1/uncordon                 Fri Jul 31 06:39 UTC
  ✓ elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Completed       -              /masters/kevin-test1                          Fri Jul 31 06:39 UTC
  ✓ kevin-test2                Update system software on master node \"kevin-test2\"        Completed       -              /masters/elect-kevin-test1                    Fri Jul 31 06:40 UTC
    ✓ drain                    Drain node \"kevin-test2\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:39 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test2\"               Completed       10.162.0.6     /masters/kevin-test2/drain                    Fri Jul 31 06:40 UTC
    ✓ taint                    Taint node \"kevin-test2\"                                   Completed       10.162.0.7     /masters/kevin-test2/system-upgrade           Fri Jul 31 06:40 UTC
    ✓ uncordon                 Uncordon node \"kevin-test2\"                                Completed       10.162.0.7     /masters/kevin-test2/taint                    Fri Jul 31 06:40 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Completed       10.162.0.7     /masters/kevin-test2/uncordon                 Fri Jul 31 06:40 UTC
    ✓ untaint                  Remove taint from node \"kevin-test2\"                       Completed       10.162.0.7     /masters/kevin-test2/endpoints                Fri Jul 31 06:40 UTC
    ✓ enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Completed       -              /masters/kevin-test2/untaint                  Fri Jul 31 06:40 UTC
  ✓ kevin-test3                Update system software on master node \"kevin-test3\"        Completed       -              /masters/kevin-test2                          Fri Jul 31 06:41 UTC
    ✓ drain                    Drain node \"kevin-test3\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:40 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test3\"               Completed       10.162.0.5     /masters/kevin-test3/drain                    Fri Jul 31 06:41 UTC
    ✓ taint                    Taint node \"kevin-test3\"                                   Completed       10.162.0.7     /masters/kevin-test3/system-upgrade           Fri Jul 31 06:41 UTC
    ✓ uncordon                 Uncordon node \"kevin-test3\"                                Completed       10.162.0.7     /masters/kevin-test3/taint                    Fri Jul 31 06:41 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Completed       10.162.0.7     /masters/kevin-test3/uncordon                 Fri Jul 31 06:41 UTC
    ✓ untaint                  Remove taint from node \"kevin-test3\"                       Completed       10.162.0.7     /masters/kevin-test3/endpoints                Fri Jul 31 06:41 UTC
    ✓ enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Completed       -              /masters/kevin-test3/untaint                  Fri Jul 31 06:41 UTC
✓ etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Completed       -              -                                             Fri Jul 31 07:00 UTC
  ✓ backup                     Backup etcd data                                           Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test1              Backup etcd on node \"kevin-test1\"                          Completed       -              -                                             Fri Jul 31 06:42 UTC
    ✓ kevin-test2              Backup etcd on node \"kevin-test2\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test3              Backup etcd on node \"kevin-test3\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
  ✓ shutdown                   Shutdown etcd cluster                                      Completed       -              -                                             Fri Jul 31 06:46 UTC
    ✓ kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Completed       -              /etcd/backup/kevin-test1                      Fri Jul 31 06:45 UTC
    ✓ kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Completed       -              /etcd/backup/kevin-test2                      Fri Jul 31 06:46 UTC
    ✓ kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Completed       -              /etcd/backup/kevin-test3                      Fri Jul 31 06:46 UTC
  ✓ upgrade                    Upgrade etcd servers                                       Completed       -              -                                             Fri Jul 31 06:55 UTC
    ✓ kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Completed       -              /etcd/shutdown/kevin-test1                    Fri Jul 31 06:50 UTC
    ✓ kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Completed       -              /etcd/shutdown/kevin-test2                    Fri Jul 31 06:55 UTC
    ✓ kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Completed       -              /etcd/shutdown/kevin-test3                    Fri Jul 31 06:55 UTC
  ✓ restore                    Restore etcd data from backup                              Completed       -              /etcd/upgrade                                 Fri Jul 31 06:56 UTC
  ✓ restart                    Restart etcd servers                                       Completed       -              -                                             Fri Jul 31 07:00 UTC
    ✓ kevin-test1              Restart etcd on node \"kevin-test1\"                         Completed       -              /etcd/restore                                 Fri Jul 31 06:59 UTC
    ✓ kevin-test2              Restart etcd on node \"kevin-test2\"                         Completed       -              /etcd/upgrade/kevin-test2                     Fri Jul 31 07:00 UTC
    ✓ kevin-test3              Restart etcd on node \"kevin-test3\"                         Completed       -              /etcd/upgrade/kevin-test3                     Fri Jul 31 07:00 UTC
    ✓ gravity-site             Restart gravity-site service                               Completed       -              -                                             Fri Jul 31 07:00 UTC
→ config                       Update system configuration on nodes                       In Progress     -              /etcd                                         Fri Jul 31 07:06 UTC
  → kevin-test1                Update system configuration on node \"kevin-test1\"          In Progress     -              -                                             Fri Jul 31 07:06 UTC
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
2020-07-31T07:06:19Z INFO             Executing phase: /config/kevin-test1. phase:/config/kevin-test1 fsm/logger.go:61
2020-07-31T07:06:19Z DEBU             Dial. addr:gravity-site.kube-system.svc.cluster.local:3009 network:tcp httplib/client.go:225
2020-07-31T07:06:19Z DEBU             Resolve gravity-site.kube-system.svc.cluster.local took 725.23µs. utils/dns.go:47
2020-07-31T07:06:19Z DEBU             Resolved gravity-site.kube-system.svc.cluster.local to 10.100.204.90. utils/dns.go:54
2020-07-31T07:06:19Z DEBU             Dial. host-port:10.100.204.90:3009 httplib/client.go:263
2020-07-31T07:06:19Z INFO             No teleport master config update found. phase:/config/kevin-test1 fsm/logger.go:61
2020-07-31T07:06:19Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/config/kevin-test1, State=completed) cluster/engine.go:288
2020-07-31T07:06:20Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Fri Jul 31 06:32 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Fri Jul 31 06:32 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Fri Jul 31 06:34 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Fri Jul 31 06:36 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Fri Jul 31 06:38 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Fri Jul 31 06:38 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Fri Jul 31 06:38 UTC
✓ masters                      Update master nodes                                        Completed       -              /coredns                                      Fri Jul 31 06:41 UTC
  ✓ kevin-test1                Update system software on master node \"kevin-test1\"        Completed       -              -                                             Fri Jul 31 06:39 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Fri Jul 31 06:38 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Fri Jul 31 06:38 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Fri Jul 31 06:38 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Fri Jul 31 06:39 UTC
    ✓ taint                    Taint node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Fri Jul 31 06:39 UTC
    ✓ uncordon                 Uncordon node \"kevin-test1\"                                Completed       10.162.0.7     /masters/kevin-test1/taint                    Fri Jul 31 06:39 UTC
    ✓ untaint                  Remove taint from node \"kevin-test1\"                       Completed       10.162.0.7     /masters/kevin-test1/uncordon                 Fri Jul 31 06:39 UTC
  ✓ elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Completed       -              /masters/kevin-test1                          Fri Jul 31 06:39 UTC
  ✓ kevin-test2                Update system software on master node \"kevin-test2\"        Completed       -              /masters/elect-kevin-test1                    Fri Jul 31 06:40 UTC
    ✓ drain                    Drain node \"kevin-test2\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:39 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test2\"               Completed       10.162.0.6     /masters/kevin-test2/drain                    Fri Jul 31 06:40 UTC
    ✓ taint                    Taint node \"kevin-test2\"                                   Completed       10.162.0.7     /masters/kevin-test2/system-upgrade           Fri Jul 31 06:40 UTC
    ✓ uncordon                 Uncordon node \"kevin-test2\"                                Completed       10.162.0.7     /masters/kevin-test2/taint                    Fri Jul 31 06:40 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Completed       10.162.0.7     /masters/kevin-test2/uncordon                 Fri Jul 31 06:40 UTC
    ✓ untaint                  Remove taint from node \"kevin-test2\"                       Completed       10.162.0.7     /masters/kevin-test2/endpoints                Fri Jul 31 06:40 UTC
    ✓ enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Completed       -              /masters/kevin-test2/untaint                  Fri Jul 31 06:40 UTC
  ✓ kevin-test3                Update system software on master node \"kevin-test3\"        Completed       -              /masters/kevin-test2                          Fri Jul 31 06:41 UTC
    ✓ drain                    Drain node \"kevin-test3\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:40 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test3\"               Completed       10.162.0.5     /masters/kevin-test3/drain                    Fri Jul 31 06:41 UTC
    ✓ taint                    Taint node \"kevin-test3\"                                   Completed       10.162.0.7     /masters/kevin-test3/system-upgrade           Fri Jul 31 06:41 UTC
    ✓ uncordon                 Uncordon node \"kevin-test3\"                                Completed       10.162.0.7     /masters/kevin-test3/taint                    Fri Jul 31 06:41 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Completed       10.162.0.7     /masters/kevin-test3/uncordon                 Fri Jul 31 06:41 UTC
    ✓ untaint                  Remove taint from node \"kevin-test3\"                       Completed       10.162.0.7     /masters/kevin-test3/endpoints                Fri Jul 31 06:41 UTC
    ✓ enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Completed       -              /masters/kevin-test3/untaint                  Fri Jul 31 06:41 UTC
✓ etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Completed       -              -                                             Fri Jul 31 07:00 UTC
  ✓ backup                     Backup etcd data                                           Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test1              Backup etcd on node \"kevin-test1\"                          Completed       -              -                                             Fri Jul 31 06:42 UTC
    ✓ kevin-test2              Backup etcd on node \"kevin-test2\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test3              Backup etcd on node \"kevin-test3\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
  ✓ shutdown                   Shutdown etcd cluster                                      Completed       -              -                                             Fri Jul 31 06:46 UTC
    ✓ kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Completed       -              /etcd/backup/kevin-test1                      Fri Jul 31 06:45 UTC
    ✓ kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Completed       -              /etcd/backup/kevin-test2                      Fri Jul 31 06:46 UTC
    ✓ kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Completed       -              /etcd/backup/kevin-test3                      Fri Jul 31 06:46 UTC
  ✓ upgrade                    Upgrade etcd servers                                       Completed       -              -                                             Fri Jul 31 06:55 UTC
    ✓ kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Completed       -              /etcd/shutdown/kevin-test1                    Fri Jul 31 06:50 UTC
    ✓ kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Completed       -              /etcd/shutdown/kevin-test2                    Fri Jul 31 06:55 UTC
    ✓ kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Completed       -              /etcd/shutdown/kevin-test3                    Fri Jul 31 06:55 UTC
  ✓ restore                    Restore etcd data from backup                              Completed       -              /etcd/upgrade                                 Fri Jul 31 06:56 UTC
  ✓ restart                    Restart etcd servers                                       Completed       -              -                                             Fri Jul 31 07:00 UTC
    ✓ kevin-test1              Restart etcd on node \"kevin-test1\"                         Completed       -              /etcd/restore                                 Fri Jul 31 06:59 UTC
    ✓ kevin-test2              Restart etcd on node \"kevin-test2\"                         Completed       -              /etcd/upgrade/kevin-test2                     Fri Jul 31 07:00 UTC
    ✓ kevin-test3              Restart etcd on node \"kevin-test3\"                         Completed       -              /etcd/upgrade/kevin-test3                     Fri Jul 31 07:00 UTC
    ✓ gravity-site             Restart gravity-site service                               Completed       -              -                                             Fri Jul 31 07:00 UTC
→ config                       Update system configuration on nodes                       In Progress     -              /etcd                                         Fri Jul 31 07:06 UTC
  ✓ kevin-test1                Update system configuration on node \"kevin-test1\"          Completed       -              -                                             Fri Jul 31 07:06 UTC
  * kevin-test2                Update system configuration on node \"kevin-test2\"          Unstarted       -              -                                             -
  * kevin-test3                Update system configuration on node \"kevin-test3\"          Unstarted       -              -                                             -
* runtime                      Update application runtime                                 Unstarted       -              /config                                       -
  * rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Unstarted       -              -                                             -
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
Fri Jul 31 07:06:20 UTC	Executing phase "/config/kevin-test1" finished in 2 seconds
```

Run config on the rest of the nodes:
```
root@kevin-test1:~/build# ./gravity plan execute --phase /config
Fri Jul 31 07:06:57 UTC	Executing "/config/kevin-test2" on remote node kevin-test2
Fri Jul 31 07:07:00 UTC	Executing "/config/kevin-test3" on remote node kevin-test3
Fri Jul 31 07:07:02 UTC	Executing phase "/config" finished in 5 seconds
```

#### Runtime Applications
Gravity ships with a number of pre-configured "applications" which we refer to as runtime applications.
These runtime applications are internal applications that make up the cluster services that are part of gravity's offering.

As with other parts of the upgrade, we only make changes if the application has actually changed.

In this particular demo, the following applications are to be updated:
- rbac-app: Our default rbac rules for the cluster as well as our services
- logging-app: The log collector and tools used by the cluster.
- monitoring-app: Our metrics stack
- site: The gravity-site UI and cluster controller
- kubernetes: Sort of a noop application

Let's see what updating a runtime application looks like:
```
root@kevin-test1:~/build# ./gravity --debug plan execute --phase /runtime/rbac-app 2>&1 | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'

...

2020-07-31T07:14:37Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Fri Jul 31 06:32 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Fri Jul 31 06:32 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Fri Jul 31 06:34 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Fri Jul 31 06:36 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Fri Jul 31 06:38 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Fri Jul 31 06:38 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Fri Jul 31 06:38 UTC
✓ masters                      Update master nodes                                        Completed       -              /coredns                                      Fri Jul 31 06:41 UTC
  ✓ kevin-test1                Update system software on master node \"kevin-test1\"        Completed       -              -                                             Fri Jul 31 06:39 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Fri Jul 31 06:38 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Fri Jul 31 06:38 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Fri Jul 31 06:38 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Fri Jul 31 06:39 UTC
    ✓ taint                    Taint node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Fri Jul 31 06:39 UTC
    ✓ uncordon                 Uncordon node \"kevin-test1\"                                Completed       10.162.0.7     /masters/kevin-test1/taint                    Fri Jul 31 06:39 UTC
    ✓ untaint                  Remove taint from node \"kevin-test1\"                       Completed       10.162.0.7     /masters/kevin-test1/uncordon                 Fri Jul 31 06:39 UTC
  ✓ elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Completed       -              /masters/kevin-test1                          Fri Jul 31 06:39 UTC
  ✓ kevin-test2                Update system software on master node \"kevin-test2\"        Completed       -              /masters/elect-kevin-test1                    Fri Jul 31 06:40 UTC
    ✓ drain                    Drain node \"kevin-test2\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:39 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test2\"               Completed       10.162.0.6     /masters/kevin-test2/drain                    Fri Jul 31 06:40 UTC
    ✓ taint                    Taint node \"kevin-test2\"                                   Completed       10.162.0.7     /masters/kevin-test2/system-upgrade           Fri Jul 31 06:40 UTC
    ✓ uncordon                 Uncordon node \"kevin-test2\"                                Completed       10.162.0.7     /masters/kevin-test2/taint                    Fri Jul 31 06:40 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Completed       10.162.0.7     /masters/kevin-test2/uncordon                 Fri Jul 31 06:40 UTC
    ✓ untaint                  Remove taint from node \"kevin-test2\"                       Completed       10.162.0.7     /masters/kevin-test2/endpoints                Fri Jul 31 06:40 UTC
    ✓ enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Completed       -              /masters/kevin-test2/untaint                  Fri Jul 31 06:40 UTC
  ✓ kevin-test3                Update system software on master node \"kevin-test3\"        Completed       -              /masters/kevin-test2                          Fri Jul 31 06:41 UTC
    ✓ drain                    Drain node \"kevin-test3\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:40 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test3\"               Completed       10.162.0.5     /masters/kevin-test3/drain                    Fri Jul 31 06:41 UTC
    ✓ taint                    Taint node \"kevin-test3\"                                   Completed       10.162.0.7     /masters/kevin-test3/system-upgrade           Fri Jul 31 06:41 UTC
    ✓ uncordon                 Uncordon node \"kevin-test3\"                                Completed       10.162.0.7     /masters/kevin-test3/taint                    Fri Jul 31 06:41 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Completed       10.162.0.7     /masters/kevin-test3/uncordon                 Fri Jul 31 06:41 UTC
    ✓ untaint                  Remove taint from node \"kevin-test3\"                       Completed       10.162.0.7     /masters/kevin-test3/endpoints                Fri Jul 31 06:41 UTC
    ✓ enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Completed       -              /masters/kevin-test3/untaint                  Fri Jul 31 06:41 UTC
✓ etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Completed       -              -                                             Fri Jul 31 07:00 UTC
  ✓ backup                     Backup etcd data                                           Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test1              Backup etcd on node \"kevin-test1\"                          Completed       -              -                                             Fri Jul 31 06:42 UTC
    ✓ kevin-test2              Backup etcd on node \"kevin-test2\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test3              Backup etcd on node \"kevin-test3\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
  ✓ shutdown                   Shutdown etcd cluster                                      Completed       -              -                                             Fri Jul 31 06:46 UTC
    ✓ kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Completed       -              /etcd/backup/kevin-test1                      Fri Jul 31 06:45 UTC
    ✓ kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Completed       -              /etcd/backup/kevin-test2                      Fri Jul 31 06:46 UTC
    ✓ kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Completed       -              /etcd/backup/kevin-test3                      Fri Jul 31 06:46 UTC
  ✓ upgrade                    Upgrade etcd servers                                       Completed       -              -                                             Fri Jul 31 06:55 UTC
    ✓ kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Completed       -              /etcd/shutdown/kevin-test1                    Fri Jul 31 06:50 UTC
    ✓ kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Completed       -              /etcd/shutdown/kevin-test2                    Fri Jul 31 06:55 UTC
    ✓ kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Completed       -              /etcd/shutdown/kevin-test3                    Fri Jul 31 06:55 UTC
  ✓ restore                    Restore etcd data from backup                              Completed       -              /etcd/upgrade                                 Fri Jul 31 06:56 UTC
  ✓ restart                    Restart etcd servers                                       Completed       -              -                                             Fri Jul 31 07:00 UTC
    ✓ kevin-test1              Restart etcd on node \"kevin-test1\"                         Completed       -              /etcd/restore                                 Fri Jul 31 06:59 UTC
    ✓ kevin-test2              Restart etcd on node \"kevin-test2\"                         Completed       -              /etcd/upgrade/kevin-test2                     Fri Jul 31 07:00 UTC
    ✓ kevin-test3              Restart etcd on node \"kevin-test3\"                         Completed       -              /etcd/upgrade/kevin-test3                     Fri Jul 31 07:00 UTC
    ✓ gravity-site             Restart gravity-site service                               Completed       -              -                                             Fri Jul 31 07:00 UTC
✓ config                       Update system configuration on nodes                       Completed       -              /etcd                                         Fri Jul 31 07:07 UTC
  ✓ kevin-test1                Update system configuration on node \"kevin-test1\"          Completed       -              -                                             Fri Jul 31 07:06 UTC
  ✓ kevin-test2                Update system configuration on node \"kevin-test2\"          Completed       -              -                                             Fri Jul 31 07:06 UTC
  ✓ kevin-test3                Update system configuration on node \"kevin-test3\"          Completed       -              -                                             Fri Jul 31 07:07 UTC
→ runtime                      Update application runtime                                 In Progress     -              /config                                       Fri Jul 31 07:14 UTC
  → rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       In Progress     -              -                                             Fri Jul 31 07:14 UTC
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
2020-07-31T07:14:37Z INFO             Executing phase: /runtime/rbac-app. phase:/runtime/rbac-app fsm/logger.go:61
2020-07-31T07:14:37Z DEBU             Dial. addr:leader.telekube.local:6443 network:tcp httplib/client.go:225
2020-07-31T07:14:37Z DEBU             Resolve leader.telekube.local took 303.2µs. utils/dns.go:47
2020-07-31T07:14:37Z DEBU             Resolved leader.telekube.local to 10.162.0.7. utils/dns.go:54
2020-07-31T07:14:37Z DEBU             Dial. host-port:10.162.0.7:6443 httplib/client.go:263
2020-07-31T07:14:37Z DEBU             Updated ClusterRoleBinding "telekube-system-admin". fsm/kubernetes.go:64
2020-07-31T07:14:37Z DEBU             Updated ClusterRoleBinding "telekube-default-admin". fsm/kubernetes.go:64
2020-07-31T07:14:38Z DEBU             Updated ClusterRoleBinding "telekube-admin". fsm/kubernetes.go:64
2020-07-31T07:14:38Z DEBU             Updated ClusterRoleBinding "telekube-view". fsm/kubernetes.go:64
2020-07-31T07:14:38Z DEBU             Updated ClusterRoleBinding "telekube-edit". fsm/kubernetes.go:64
2020-07-31T07:14:38Z DEBU             Updated ClusterRoleBinding "privileged-psp-users". fsm/kubernetes.go:64
2020-07-31T07:14:38Z DEBU             Updated ClusterRoleBinding "restricted-psp-users". fsm/kubernetes.go:64
2020-07-31T07:14:39Z DEBU             Updated ClusterRoleBinding "edit". fsm/kubernetes.go:64
2020-07-31T07:14:39Z DEBU             Updated PodSecurityPolicy "restricted". fsm/kubernetes.go:106
2020-07-31T07:14:39Z DEBU             Updated PodSecurityPolicy "privileged". fsm/kubernetes.go:106
2020-07-31T07:14:39Z DEBU             Updated ClusterRole "restricted-psp-user". fsm/kubernetes.go:50
2020-07-31T07:14:39Z DEBU             Updated ClusterRole "privileged-psp-user". fsm/kubernetes.go:50
2020-07-31T07:14:40Z DEBU             Updated ClusterRole "telekube:daemonset-controller". fsm/kubernetes.go:50
2020-07-31T07:14:40Z DEBU             Updated ClusterRoleBinding "telekube:daemonset-controller". fsm/kubernetes.go:64
2020-07-31T07:14:41Z DEBU             Updated ClusterRoleBinding "telekube:controller-privileged-psp". fsm/kubernetes.go:64
2020-07-31T07:14:41Z DEBU             Updated ClusterRoleBinding "telekube:controller-restricted-psp". fsm/kubernetes.go:64
2020-07-31T07:14:41Z DEBU             Updated ClusterRole "gravity:coredns". fsm/kubernetes.go:50
2020-07-31T07:14:42Z DEBU             Updated ClusterRoleBinding "gravity:coredns". fsm/kubernetes.go:64
2020-07-31T07:14:42Z DEBU             Updated Role "gravity:coredns". fsm/kubernetes.go:78
2020-07-31T07:14:43Z DEBU             Updated RoleBinding "gravity:coredns". fsm/kubernetes.go:92
2020-07-31T07:14:43Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/runtime/rbac-app, State=completed) cluster/engine.go:288
2020-07-31T07:14:43Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Fri Jul 31 06:32 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Fri Jul 31 06:32 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Fri Jul 31 06:34 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Fri Jul 31 06:36 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Fri Jul 31 06:38 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Fri Jul 31 06:38 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Fri Jul 31 06:38 UTC
✓ masters                      Update master nodes                                        Completed       -              /coredns                                      Fri Jul 31 06:41 UTC
  ✓ kevin-test1                Update system software on master node \"kevin-test1\"        Completed       -              -                                             Fri Jul 31 06:39 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Fri Jul 31 06:38 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Fri Jul 31 06:38 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Fri Jul 31 06:38 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Fri Jul 31 06:39 UTC
    ✓ taint                    Taint node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Fri Jul 31 06:39 UTC
    ✓ uncordon                 Uncordon node \"kevin-test1\"                                Completed       10.162.0.7     /masters/kevin-test1/taint                    Fri Jul 31 06:39 UTC
    ✓ untaint                  Remove taint from node \"kevin-test1\"                       Completed       10.162.0.7     /masters/kevin-test1/uncordon                 Fri Jul 31 06:39 UTC
  ✓ elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Completed       -              /masters/kevin-test1                          Fri Jul 31 06:39 UTC
  ✓ kevin-test2                Update system software on master node \"kevin-test2\"        Completed       -              /masters/elect-kevin-test1                    Fri Jul 31 06:40 UTC
    ✓ drain                    Drain node \"kevin-test2\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:39 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test2\"               Completed       10.162.0.6     /masters/kevin-test2/drain                    Fri Jul 31 06:40 UTC
    ✓ taint                    Taint node \"kevin-test2\"                                   Completed       10.162.0.7     /masters/kevin-test2/system-upgrade           Fri Jul 31 06:40 UTC
    ✓ uncordon                 Uncordon node \"kevin-test2\"                                Completed       10.162.0.7     /masters/kevin-test2/taint                    Fri Jul 31 06:40 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Completed       10.162.0.7     /masters/kevin-test2/uncordon                 Fri Jul 31 06:40 UTC
    ✓ untaint                  Remove taint from node \"kevin-test2\"                       Completed       10.162.0.7     /masters/kevin-test2/endpoints                Fri Jul 31 06:40 UTC
    ✓ enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Completed       -              /masters/kevin-test2/untaint                  Fri Jul 31 06:40 UTC
  ✓ kevin-test3                Update system software on master node \"kevin-test3\"        Completed       -              /masters/kevin-test2                          Fri Jul 31 06:41 UTC
    ✓ drain                    Drain node \"kevin-test3\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:40 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test3\"               Completed       10.162.0.5     /masters/kevin-test3/drain                    Fri Jul 31 06:41 UTC
    ✓ taint                    Taint node \"kevin-test3\"                                   Completed       10.162.0.7     /masters/kevin-test3/system-upgrade           Fri Jul 31 06:41 UTC
    ✓ uncordon                 Uncordon node \"kevin-test3\"                                Completed       10.162.0.7     /masters/kevin-test3/taint                    Fri Jul 31 06:41 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Completed       10.162.0.7     /masters/kevin-test3/uncordon                 Fri Jul 31 06:41 UTC
    ✓ untaint                  Remove taint from node \"kevin-test3\"                       Completed       10.162.0.7     /masters/kevin-test3/endpoints                Fri Jul 31 06:41 UTC
    ✓ enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Completed       -              /masters/kevin-test3/untaint                  Fri Jul 31 06:41 UTC
✓ etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Completed       -              -                                             Fri Jul 31 07:00 UTC
  ✓ backup                     Backup etcd data                                           Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test1              Backup etcd on node \"kevin-test1\"                          Completed       -              -                                             Fri Jul 31 06:42 UTC
    ✓ kevin-test2              Backup etcd on node \"kevin-test2\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test3              Backup etcd on node \"kevin-test3\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
  ✓ shutdown                   Shutdown etcd cluster                                      Completed       -              -                                             Fri Jul 31 06:46 UTC
    ✓ kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Completed       -              /etcd/backup/kevin-test1                      Fri Jul 31 06:45 UTC
    ✓ kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Completed       -              /etcd/backup/kevin-test2                      Fri Jul 31 06:46 UTC
    ✓ kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Completed       -              /etcd/backup/kevin-test3                      Fri Jul 31 06:46 UTC
  ✓ upgrade                    Upgrade etcd servers                                       Completed       -              -                                             Fri Jul 31 06:55 UTC
    ✓ kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Completed       -              /etcd/shutdown/kevin-test1                    Fri Jul 31 06:50 UTC
    ✓ kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Completed       -              /etcd/shutdown/kevin-test2                    Fri Jul 31 06:55 UTC
    ✓ kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Completed       -              /etcd/shutdown/kevin-test3                    Fri Jul 31 06:55 UTC
  ✓ restore                    Restore etcd data from backup                              Completed       -              /etcd/upgrade                                 Fri Jul 31 06:56 UTC
  ✓ restart                    Restart etcd servers                                       Completed       -              -                                             Fri Jul 31 07:00 UTC
    ✓ kevin-test1              Restart etcd on node \"kevin-test1\"                         Completed       -              /etcd/restore                                 Fri Jul 31 06:59 UTC
    ✓ kevin-test2              Restart etcd on node \"kevin-test2\"                         Completed       -              /etcd/upgrade/kevin-test2                     Fri Jul 31 07:00 UTC
    ✓ kevin-test3              Restart etcd on node \"kevin-test3\"                         Completed       -              /etcd/upgrade/kevin-test3                     Fri Jul 31 07:00 UTC
    ✓ gravity-site             Restart gravity-site service                               Completed       -              -                                             Fri Jul 31 07:00 UTC
✓ config                       Update system configuration on nodes                       Completed       -              /etcd                                         Fri Jul 31 07:07 UTC
  ✓ kevin-test1                Update system configuration on node \"kevin-test1\"          Completed       -              -                                             Fri Jul 31 07:06 UTC
  ✓ kevin-test2                Update system configuration on node \"kevin-test2\"          Completed       -              -                                             Fri Jul 31 07:06 UTC
  ✓ kevin-test3                Update system configuration on node \"kevin-test3\"          Completed       -              -                                             Fri Jul 31 07:07 UTC
→ runtime                      Update application runtime                                 In Progress     -              /config                                       Fri Jul 31 07:14 UTC
  ✓ rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Completed       -              -                                             Fri Jul 31 07:14 UTC
  * logging-app                Update system application \"logging-app\" to 5.0.3           Unstarted       -              /runtime/rbac-app                             -
  * monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Unstarted       -              /runtime/logging-app                          -
  * site                       Update system application \"site\" to 5.5.50-dev.9           Unstarted       -              /runtime/monitoring-app                       -
  * kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Unstarted       -              /runtime/site                                 -
* migration                    Perform system database migration                          Unstarted       -              /runtime                                      -
  * labels                     Update node labels                                         Unstarted       -              -                                             -
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
Fri Jul 31 07:14:43 UTC	Executing phase "/runtime/rbac-app" finished in 6 seconds
```

Complete upgrading the runtime:
```
root@kevin-test1:~/build# ./gravity plan execute --phase /runtime
Fri Jul 31 07:16:29 UTC	Executing "/runtime/logging-app" locally
	Still executing "/runtime/logging-app" locally (10 seconds elapsed)
	Still executing "/runtime/logging-app" locally (20 seconds elapsed)
	Still executing "/runtime/logging-app" locally (30 seconds elapsed)
Fri Jul 31 07:17:07 UTC	Executing "/runtime/monitoring-app" locally
	Still executing "/runtime/monitoring-app" locally (10 seconds elapsed)
	Still executing "/runtime/monitoring-app" locally (20 seconds elapsed)
	Still executing "/runtime/monitoring-app" locally (30 seconds elapsed)
	Still executing "/runtime/monitoring-app" locally (40 seconds elapsed)
	Still executing "/runtime/monitoring-app" locally (50 seconds elapsed)
	Still executing "/runtime/monitoring-app" locally (1 minute elapsed)
Fri Jul 31 07:18:09 UTC	Executing "/runtime/site" locally
	Still executing "/runtime/site" locally (10 seconds elapsed)
	Still executing "/runtime/site" locally (20 seconds elapsed)
	Still executing "/runtime/site" locally (30 seconds elapsed)
	Still executing "/runtime/site" locally (40 seconds elapsed)
Fri Jul 31 07:18:57 UTC	Executing "/runtime/kubernetes" locally
Fri Jul 31 07:18:58 UTC	Executing phase "/runtime" finished in 2 minutes
```

### Migrations
The migrations phase and it's subphases are where we define internal state updates now that the runtime applications have been updated. In this particular example, the only migration that is part of the plan, is to re-apply the node labels from the application manifest, to ensure they're up to date with any changes.

```
root@kevin-test1:~/build# ./gravity --debug plan execute --phase /migration/labels 2>&1 | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'

...

2020-07-31T07:44:08Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Fri Jul 31 06:32 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Fri Jul 31 06:32 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Fri Jul 31 06:34 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Fri Jul 31 06:36 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Fri Jul 31 06:38 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Fri Jul 31 06:38 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Fri Jul 31 06:38 UTC
✓ masters                      Update master nodes                                        Completed       -              /coredns                                      Fri Jul 31 06:41 UTC
  ✓ kevin-test1                Update system software on master node \"kevin-test1\"        Completed       -              -                                             Fri Jul 31 06:39 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Fri Jul 31 06:38 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Fri Jul 31 06:38 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Fri Jul 31 06:38 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Fri Jul 31 06:39 UTC
    ✓ taint                    Taint node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Fri Jul 31 06:39 UTC
    ✓ uncordon                 Uncordon node \"kevin-test1\"                                Completed       10.162.0.7     /masters/kevin-test1/taint                    Fri Jul 31 06:39 UTC
    ✓ untaint                  Remove taint from node \"kevin-test1\"                       Completed       10.162.0.7     /masters/kevin-test1/uncordon                 Fri Jul 31 06:39 UTC
  ✓ elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Completed       -              /masters/kevin-test1                          Fri Jul 31 06:39 UTC
  ✓ kevin-test2                Update system software on master node \"kevin-test2\"        Completed       -              /masters/elect-kevin-test1                    Fri Jul 31 06:40 UTC
    ✓ drain                    Drain node \"kevin-test2\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:39 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test2\"               Completed       10.162.0.6     /masters/kevin-test2/drain                    Fri Jul 31 06:40 UTC
    ✓ taint                    Taint node \"kevin-test2\"                                   Completed       10.162.0.7     /masters/kevin-test2/system-upgrade           Fri Jul 31 06:40 UTC
    ✓ uncordon                 Uncordon node \"kevin-test2\"                                Completed       10.162.0.7     /masters/kevin-test2/taint                    Fri Jul 31 06:40 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Completed       10.162.0.7     /masters/kevin-test2/uncordon                 Fri Jul 31 06:40 UTC
    ✓ untaint                  Remove taint from node \"kevin-test2\"                       Completed       10.162.0.7     /masters/kevin-test2/endpoints                Fri Jul 31 06:40 UTC
    ✓ enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Completed       -              /masters/kevin-test2/untaint                  Fri Jul 31 06:40 UTC
  ✓ kevin-test3                Update system software on master node \"kevin-test3\"        Completed       -              /masters/kevin-test2                          Fri Jul 31 06:41 UTC
    ✓ drain                    Drain node \"kevin-test3\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:40 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test3\"               Completed       10.162.0.5     /masters/kevin-test3/drain                    Fri Jul 31 06:41 UTC
    ✓ taint                    Taint node \"kevin-test3\"                                   Completed       10.162.0.7     /masters/kevin-test3/system-upgrade           Fri Jul 31 06:41 UTC
    ✓ uncordon                 Uncordon node \"kevin-test3\"                                Completed       10.162.0.7     /masters/kevin-test3/taint                    Fri Jul 31 06:41 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Completed       10.162.0.7     /masters/kevin-test3/uncordon                 Fri Jul 31 06:41 UTC
    ✓ untaint                  Remove taint from node \"kevin-test3\"                       Completed       10.162.0.7     /masters/kevin-test3/endpoints                Fri Jul 31 06:41 UTC
    ✓ enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Completed       -              /masters/kevin-test3/untaint                  Fri Jul 31 06:41 UTC
✓ etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Completed       -              -                                             Fri Jul 31 07:00 UTC
  ✓ backup                     Backup etcd data                                           Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test1              Backup etcd on node \"kevin-test1\"                          Completed       -              -                                             Fri Jul 31 06:42 UTC
    ✓ kevin-test2              Backup etcd on node \"kevin-test2\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test3              Backup etcd on node \"kevin-test3\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
  ✓ shutdown                   Shutdown etcd cluster                                      Completed       -              -                                             Fri Jul 31 06:46 UTC
    ✓ kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Completed       -              /etcd/backup/kevin-test1                      Fri Jul 31 06:45 UTC
    ✓ kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Completed       -              /etcd/backup/kevin-test2                      Fri Jul 31 06:46 UTC
    ✓ kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Completed       -              /etcd/backup/kevin-test3                      Fri Jul 31 06:46 UTC
  ✓ upgrade                    Upgrade etcd servers                                       Completed       -              -                                             Fri Jul 31 06:55 UTC
    ✓ kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Completed       -              /etcd/shutdown/kevin-test1                    Fri Jul 31 06:50 UTC
    ✓ kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Completed       -              /etcd/shutdown/kevin-test2                    Fri Jul 31 06:55 UTC
    ✓ kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Completed       -              /etcd/shutdown/kevin-test3                    Fri Jul 31 06:55 UTC
  ✓ restore                    Restore etcd data from backup                              Completed       -              /etcd/upgrade                                 Fri Jul 31 06:56 UTC
  ✓ restart                    Restart etcd servers                                       Completed       -              -                                             Fri Jul 31 07:00 UTC
    ✓ kevin-test1              Restart etcd on node \"kevin-test1\"                         Completed       -              /etcd/restore                                 Fri Jul 31 06:59 UTC
    ✓ kevin-test2              Restart etcd on node \"kevin-test2\"                         Completed       -              /etcd/upgrade/kevin-test2                     Fri Jul 31 07:00 UTC
    ✓ kevin-test3              Restart etcd on node \"kevin-test3\"                         Completed       -              /etcd/upgrade/kevin-test3                     Fri Jul 31 07:00 UTC
    ✓ gravity-site             Restart gravity-site service                               Completed       -              -                                             Fri Jul 31 07:00 UTC
✓ config                       Update system configuration on nodes                       Completed       -              /etcd                                         Fri Jul 31 07:07 UTC
  ✓ kevin-test1                Update system configuration on node \"kevin-test1\"          Completed       -              -                                             Fri Jul 31 07:06 UTC
  ✓ kevin-test2                Update system configuration on node \"kevin-test2\"          Completed       -              -                                             Fri Jul 31 07:06 UTC
  ✓ kevin-test3                Update system configuration on node \"kevin-test3\"          Completed       -              -                                             Fri Jul 31 07:07 UTC
✓ runtime                      Update application runtime                                 Completed       -              /config                                       Fri Jul 31 07:18 UTC
  ✓ rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Completed       -              -                                             Fri Jul 31 07:14 UTC
  ✓ logging-app                Update system application \"logging-app\" to 5.0.3           Completed       -              /runtime/rbac-app                             Fri Jul 31 07:17 UTC
  ✓ monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Completed       -              /runtime/logging-app                          Fri Jul 31 07:18 UTC
  ✓ site                       Update system application \"site\" to 5.5.50-dev.9           Completed       -              /runtime/monitoring-app                       Fri Jul 31 07:18 UTC
  ✓ kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Completed       -              /runtime/site                                 Fri Jul 31 07:18 UTC
→ migration                    Perform system database migration                          In Progress     -              /runtime                                      Fri Jul 31 07:44 UTC
  → labels                     Update node labels                                         In Progress     -              -                                             Fri Jul 31 07:44 UTC
* app                          Update installed application                               Unstarted       -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted       -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
2020-07-31T07:44:08Z INFO             Executing phase: /migration/labels. phase:/migration/labels fsm/logger.go:61
2020-07-31T07:44:08Z INFO             Update labels on node(addr=10.162.0.7, hostname=kevin-test1, role=node, cluster_role=master). phase:/migration/labels fsm/logger.go:61
2020-07-31T07:44:08Z DEBU             Dial. addr:leader.telekube.local:6443 network:tcp httplib/client.go:225
2020-07-31T07:44:08Z DEBU             Resolve leader.telekube.local took 634.987µs. utils/dns.go:47
2020-07-31T07:44:08Z DEBU             Resolved leader.telekube.local to 10.162.0.7. utils/dns.go:54
2020-07-31T07:44:08Z DEBU             Dial. host-port:10.162.0.7:6443 httplib/client.go:263
2020-07-31T07:44:08Z INFO             Update labels on node(addr=10.162.0.6, hostname=kevin-test2, role=node, cluster_role=master). phase:/migration/labels fsm/logger.go:61
2020-07-31T07:44:08Z INFO             Update labels on node(addr=10.162.0.5, hostname=kevin-test3, role=node, cluster_role=master). phase:/migration/labels fsm/logger.go:61
2020-07-31T07:44:08Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/migration/labels, State=completed) cluster/engine.go:288
2020-07-31T07:44:08Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State         Node           Requires                                      Updated
-----                          -----------                                                -----         ----           --------                                      -------
✓ init                         Initialize update operation                                Completed     -              -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed     10.162.0.7     -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed     10.162.0.6     -                                             Fri Jul 31 06:32 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed     10.162.0.5     -                                             Fri Jul 31 06:32 UTC
✓ checks                       Run preflight checks                                       Completed     -              /init                                         Fri Jul 31 06:34 UTC
✓ pre-update                   Run pre-update application hook                            Completed     -              /init,/checks                                 Fri Jul 31 06:36 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed     -              /checks,/pre-update                           Fri Jul 31 06:38 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed     10.162.0.7     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed     10.162.0.6     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed     10.162.0.5     -                                             Fri Jul 31 06:38 UTC
✓ coredns                      Provision CoreDNS resources                                Completed     -              /bootstrap                                    Fri Jul 31 06:38 UTC
✓ masters                      Update master nodes                                        Completed     -              /coredns                                      Fri Jul 31 06:41 UTC
  ✓ kevin-test1                Update system software on master node \"kevin-test1\"        Completed     -              -                                             Fri Jul 31 06:39 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed     -              -                                             Fri Jul 31 06:38 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed     -              /masters/kevin-test1/kubelet-permissions      Fri Jul 31 06:38 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed     10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Fri Jul 31 06:38 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed     10.162.0.7     /masters/kevin-test1/drain                    Fri Jul 31 06:39 UTC
    ✓ taint                    Taint node \"kevin-test1\"                                   Completed     10.162.0.7     /masters/kevin-test1/system-upgrade           Fri Jul 31 06:39 UTC
    ✓ uncordon                 Uncordon node \"kevin-test1\"                                Completed     10.162.0.7     /masters/kevin-test1/taint                    Fri Jul 31 06:39 UTC
    ✓ untaint                  Remove taint from node \"kevin-test1\"                       Completed     10.162.0.7     /masters/kevin-test1/uncordon                 Fri Jul 31 06:39 UTC
  ✓ elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Completed     -              /masters/kevin-test1                          Fri Jul 31 06:39 UTC
  ✓ kevin-test2                Update system software on master node \"kevin-test2\"        Completed     -              /masters/elect-kevin-test1                    Fri Jul 31 06:40 UTC
    ✓ drain                    Drain node \"kevin-test2\"                                   Completed     10.162.0.7     -                                             Fri Jul 31 06:39 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test2\"               Completed     10.162.0.6     /masters/kevin-test2/drain                    Fri Jul 31 06:40 UTC
    ✓ taint                    Taint node \"kevin-test2\"                                   Completed     10.162.0.7     /masters/kevin-test2/system-upgrade           Fri Jul 31 06:40 UTC
    ✓ uncordon                 Uncordon node \"kevin-test2\"                                Completed     10.162.0.7     /masters/kevin-test2/taint                    Fri Jul 31 06:40 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Completed     10.162.0.7     /masters/kevin-test2/uncordon                 Fri Jul 31 06:40 UTC
    ✓ untaint                  Remove taint from node \"kevin-test2\"                       Completed     10.162.0.7     /masters/kevin-test2/endpoints                Fri Jul 31 06:40 UTC
    ✓ enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Completed     -              /masters/kevin-test2/untaint                  Fri Jul 31 06:40 UTC
  ✓ kevin-test3                Update system software on master node \"kevin-test3\"        Completed     -              /masters/kevin-test2                          Fri Jul 31 06:41 UTC
    ✓ drain                    Drain node \"kevin-test3\"                                   Completed     10.162.0.7     -                                             Fri Jul 31 06:40 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test3\"               Completed     10.162.0.5     /masters/kevin-test3/drain                    Fri Jul 31 06:41 UTC
    ✓ taint                    Taint node \"kevin-test3\"                                   Completed     10.162.0.7     /masters/kevin-test3/system-upgrade           Fri Jul 31 06:41 UTC
    ✓ uncordon                 Uncordon node \"kevin-test3\"                                Completed     10.162.0.7     /masters/kevin-test3/taint                    Fri Jul 31 06:41 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Completed     10.162.0.7     /masters/kevin-test3/uncordon                 Fri Jul 31 06:41 UTC
    ✓ untaint                  Remove taint from node \"kevin-test3\"                       Completed     10.162.0.7     /masters/kevin-test3/endpoints                Fri Jul 31 06:41 UTC
    ✓ enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Completed     -              /masters/kevin-test3/untaint                  Fri Jul 31 06:41 UTC
✓ etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Completed     -              -                                             Fri Jul 31 07:00 UTC
  ✓ backup                     Backup etcd data                                           Completed     -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test1              Backup etcd on node \"kevin-test1\"                          Completed     -              -                                             Fri Jul 31 06:42 UTC
    ✓ kevin-test2              Backup etcd on node \"kevin-test2\"                          Completed     -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test3              Backup etcd on node \"kevin-test3\"                          Completed     -              -                                             Fri Jul 31 06:44 UTC
  ✓ shutdown                   Shutdown etcd cluster                                      Completed     -              -                                             Fri Jul 31 06:46 UTC
    ✓ kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Completed     -              /etcd/backup/kevin-test1                      Fri Jul 31 06:45 UTC
    ✓ kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Completed     -              /etcd/backup/kevin-test2                      Fri Jul 31 06:46 UTC
    ✓ kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Completed     -              /etcd/backup/kevin-test3                      Fri Jul 31 06:46 UTC
  ✓ upgrade                    Upgrade etcd servers                                       Completed     -              -                                             Fri Jul 31 06:55 UTC
    ✓ kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Completed     -              /etcd/shutdown/kevin-test1                    Fri Jul 31 06:50 UTC
    ✓ kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Completed     -              /etcd/shutdown/kevin-test2                    Fri Jul 31 06:55 UTC
    ✓ kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Completed     -              /etcd/shutdown/kevin-test3                    Fri Jul 31 06:55 UTC
  ✓ restore                    Restore etcd data from backup                              Completed     -              /etcd/upgrade                                 Fri Jul 31 06:56 UTC
  ✓ restart                    Restart etcd servers                                       Completed     -              -                                             Fri Jul 31 07:00 UTC
    ✓ kevin-test1              Restart etcd on node \"kevin-test1\"                         Completed     -              /etcd/restore                                 Fri Jul 31 06:59 UTC
    ✓ kevin-test2              Restart etcd on node \"kevin-test2\"                         Completed     -              /etcd/upgrade/kevin-test2                     Fri Jul 31 07:00 UTC
    ✓ kevin-test3              Restart etcd on node \"kevin-test3\"                         Completed     -              /etcd/upgrade/kevin-test3                     Fri Jul 31 07:00 UTC
    ✓ gravity-site             Restart gravity-site service                               Completed     -              -                                             Fri Jul 31 07:00 UTC
✓ config                       Update system configuration on nodes                       Completed     -              /etcd                                         Fri Jul 31 07:07 UTC
  ✓ kevin-test1                Update system configuration on node \"kevin-test1\"          Completed     -              -                                             Fri Jul 31 07:06 UTC
  ✓ kevin-test2                Update system configuration on node \"kevin-test2\"          Completed     -              -                                             Fri Jul 31 07:06 UTC
  ✓ kevin-test3                Update system configuration on node \"kevin-test3\"          Completed     -              -                                             Fri Jul 31 07:07 UTC
✓ runtime                      Update application runtime                                 Completed     -              /config                                       Fri Jul 31 07:18 UTC
  ✓ rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Completed     -              -                                             Fri Jul 31 07:14 UTC
  ✓ logging-app                Update system application \"logging-app\" to 5.0.3           Completed     -              /runtime/rbac-app                             Fri Jul 31 07:17 UTC
  ✓ monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Completed     -              /runtime/logging-app                          Fri Jul 31 07:18 UTC
  ✓ site                       Update system application \"site\" to 5.5.50-dev.9           Completed     -              /runtime/monitoring-app                       Fri Jul 31 07:18 UTC
  ✓ kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Completed     -              /runtime/site                                 Fri Jul 31 07:18 UTC
✓ migration                    Perform system database migration                          Completed     -              /runtime                                      Fri Jul 31 07:44 UTC
  ✓ labels                     Update node labels                                         Completed     -              -                                             Fri Jul 31 07:44 UTC
* app                          Update installed application                               Unstarted     -              /migration                                    -
  * telekube                   Update application \"telekube\" to 5.5.50-dev.9              Unstarted     -              -                                             -
* gc                           Run cleanup tasks                                          Unstarted     -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted     -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted     -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted     -              -                                             -
." fsm/logger.go:49
Fri Jul 31 07:44:08 UTC	Executing phase "/migration/labels" finished in 1 second
```

### Application
Everything up until this point is just upgrading gravity. But gravity doesn't just ship patches for gravity, it also ships updates for the application within gravity. So the application steps trigger the hooks that actually run the application upgrade and post upgrade hooks, to work with the latest version.

The example application is just an empty kubernetes cluster, so nothing really happens here.

```
root@kevin-test1:~/build# ./gravity --debug plan execute --phase /app/telekube 2>&1 | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'

...

2020-07-31T07:49:21Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Fri Jul 31 06:32 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Fri Jul 31 06:32 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Fri Jul 31 06:34 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Fri Jul 31 06:36 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Fri Jul 31 06:38 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Fri Jul 31 06:38 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Fri Jul 31 06:38 UTC
✓ masters                      Update master nodes                                        Completed       -              /coredns                                      Fri Jul 31 06:41 UTC
  ✓ kevin-test1                Update system software on master node \"kevin-test1\"        Completed       -              -                                             Fri Jul 31 06:39 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Fri Jul 31 06:38 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Fri Jul 31 06:38 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Fri Jul 31 06:38 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Fri Jul 31 06:39 UTC
    ✓ taint                    Taint node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Fri Jul 31 06:39 UTC
    ✓ uncordon                 Uncordon node \"kevin-test1\"                                Completed       10.162.0.7     /masters/kevin-test1/taint                    Fri Jul 31 06:39 UTC
    ✓ untaint                  Remove taint from node \"kevin-test1\"                       Completed       10.162.0.7     /masters/kevin-test1/uncordon                 Fri Jul 31 06:39 UTC
  ✓ elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Completed       -              /masters/kevin-test1                          Fri Jul 31 06:39 UTC
  ✓ kevin-test2                Update system software on master node \"kevin-test2\"        Completed       -              /masters/elect-kevin-test1                    Fri Jul 31 06:40 UTC
    ✓ drain                    Drain node \"kevin-test2\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:39 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test2\"               Completed       10.162.0.6     /masters/kevin-test2/drain                    Fri Jul 31 06:40 UTC
    ✓ taint                    Taint node \"kevin-test2\"                                   Completed       10.162.0.7     /masters/kevin-test2/system-upgrade           Fri Jul 31 06:40 UTC
    ✓ uncordon                 Uncordon node \"kevin-test2\"                                Completed       10.162.0.7     /masters/kevin-test2/taint                    Fri Jul 31 06:40 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Completed       10.162.0.7     /masters/kevin-test2/uncordon                 Fri Jul 31 06:40 UTC
    ✓ untaint                  Remove taint from node \"kevin-test2\"                       Completed       10.162.0.7     /masters/kevin-test2/endpoints                Fri Jul 31 06:40 UTC
    ✓ enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Completed       -              /masters/kevin-test2/untaint                  Fri Jul 31 06:40 UTC
  ✓ kevin-test3                Update system software on master node \"kevin-test3\"        Completed       -              /masters/kevin-test2                          Fri Jul 31 06:41 UTC
    ✓ drain                    Drain node \"kevin-test3\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:40 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test3\"               Completed       10.162.0.5     /masters/kevin-test3/drain                    Fri Jul 31 06:41 UTC
    ✓ taint                    Taint node \"kevin-test3\"                                   Completed       10.162.0.7     /masters/kevin-test3/system-upgrade           Fri Jul 31 06:41 UTC
    ✓ uncordon                 Uncordon node \"kevin-test3\"                                Completed       10.162.0.7     /masters/kevin-test3/taint                    Fri Jul 31 06:41 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Completed       10.162.0.7     /masters/kevin-test3/uncordon                 Fri Jul 31 06:41 UTC
    ✓ untaint                  Remove taint from node \"kevin-test3\"                       Completed       10.162.0.7     /masters/kevin-test3/endpoints                Fri Jul 31 06:41 UTC
    ✓ enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Completed       -              /masters/kevin-test3/untaint                  Fri Jul 31 06:41 UTC
✓ etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Completed       -              -                                             Fri Jul 31 07:00 UTC
  ✓ backup                     Backup etcd data                                           Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test1              Backup etcd on node \"kevin-test1\"                          Completed       -              -                                             Fri Jul 31 06:42 UTC
    ✓ kevin-test2              Backup etcd on node \"kevin-test2\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test3              Backup etcd on node \"kevin-test3\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
  ✓ shutdown                   Shutdown etcd cluster                                      Completed       -              -                                             Fri Jul 31 06:46 UTC
    ✓ kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Completed       -              /etcd/backup/kevin-test1                      Fri Jul 31 06:45 UTC
    ✓ kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Completed       -              /etcd/backup/kevin-test2                      Fri Jul 31 06:46 UTC
    ✓ kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Completed       -              /etcd/backup/kevin-test3                      Fri Jul 31 06:46 UTC
  ✓ upgrade                    Upgrade etcd servers                                       Completed       -              -                                             Fri Jul 31 06:55 UTC
    ✓ kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Completed       -              /etcd/shutdown/kevin-test1                    Fri Jul 31 06:50 UTC
    ✓ kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Completed       -              /etcd/shutdown/kevin-test2                    Fri Jul 31 06:55 UTC
    ✓ kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Completed       -              /etcd/shutdown/kevin-test3                    Fri Jul 31 06:55 UTC
  ✓ restore                    Restore etcd data from backup                              Completed       -              /etcd/upgrade                                 Fri Jul 31 06:56 UTC
  ✓ restart                    Restart etcd servers                                       Completed       -              -                                             Fri Jul 31 07:00 UTC
    ✓ kevin-test1              Restart etcd on node \"kevin-test1\"                         Completed       -              /etcd/restore                                 Fri Jul 31 06:59 UTC
    ✓ kevin-test2              Restart etcd on node \"kevin-test2\"                         Completed       -              /etcd/upgrade/kevin-test2                     Fri Jul 31 07:00 UTC
    ✓ kevin-test3              Restart etcd on node \"kevin-test3\"                         Completed       -              /etcd/upgrade/kevin-test3                     Fri Jul 31 07:00 UTC
    ✓ gravity-site             Restart gravity-site service                               Completed       -              -                                             Fri Jul 31 07:00 UTC
✓ config                       Update system configuration on nodes                       Completed       -              /etcd                                         Fri Jul 31 07:07 UTC
  ✓ kevin-test1                Update system configuration on node \"kevin-test1\"          Completed       -              -                                             Fri Jul 31 07:06 UTC
  ✓ kevin-test2                Update system configuration on node \"kevin-test2\"          Completed       -              -                                             Fri Jul 31 07:06 UTC
  ✓ kevin-test3                Update system configuration on node \"kevin-test3\"          Completed       -              -                                             Fri Jul 31 07:07 UTC
✓ runtime                      Update application runtime                                 Completed       -              /config                                       Fri Jul 31 07:18 UTC
  ✓ rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Completed       -              -                                             Fri Jul 31 07:14 UTC
  ✓ logging-app                Update system application \"logging-app\" to 5.0.3           Completed       -              /runtime/rbac-app                             Fri Jul 31 07:17 UTC
  ✓ monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Completed       -              /runtime/logging-app                          Fri Jul 31 07:18 UTC
  ✓ site                       Update system application \"site\" to 5.5.50-dev.9           Completed       -              /runtime/monitoring-app                       Fri Jul 31 07:18 UTC
  ✓ kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Completed       -              /runtime/site                                 Fri Jul 31 07:18 UTC
✓ migration                    Perform system database migration                          Completed       -              /runtime                                      Fri Jul 31 07:44 UTC
  ✓ labels                     Update node labels                                         Completed       -              -                                             Fri Jul 31 07:44 UTC
→ app                          Update installed application                               In Progress     -              /migration                                    Fri Jul 31 07:49 UTC
  → telekube                   Update application \"telekube\" to 5.5.50-dev.9              In Progress     -              -                                             Fri Jul 31 07:49 UTC
* gc                           Run cleanup tasks                                          Unstarted       -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted       -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
2020-07-31T07:49:21Z INFO             Executing phase: /app/telekube. phase:/app/telekube fsm/logger.go:61
2020-07-31T07:49:21Z DEBU             gravitational.io/telekube:5.5.50-dev.9 does not have networkUpdate hook. phase:/app/telekube fsm/logger.go:49
2020-07-31T07:49:21Z DEBU             gravitational.io/telekube:5.5.50-dev.9 does not have update hook. phase:/app/telekube fsm/logger.go:49
2020-07-31T07:49:21Z DEBU             gravitational.io/telekube:5.5.50-dev.9 does not have postUpdate hook. phase:/app/telekube fsm/logger.go:49
2020-07-31T07:49:21Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/app/telekube, State=completed) cluster/engine.go:288
2020-07-31T07:49:21Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State         Node           Requires                                      Updated
-----                          -----------                                                -----         ----           --------                                      -------
✓ init                         Initialize update operation                                Completed     -              -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed     10.162.0.7     -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed     10.162.0.6     -                                             Fri Jul 31 06:32 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed     10.162.0.5     -                                             Fri Jul 31 06:32 UTC
✓ checks                       Run preflight checks                                       Completed     -              /init                                         Fri Jul 31 06:34 UTC
✓ pre-update                   Run pre-update application hook                            Completed     -              /init,/checks                                 Fri Jul 31 06:36 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed     -              /checks,/pre-update                           Fri Jul 31 06:38 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed     10.162.0.7     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed     10.162.0.6     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed     10.162.0.5     -                                             Fri Jul 31 06:38 UTC
✓ coredns                      Provision CoreDNS resources                                Completed     -              /bootstrap                                    Fri Jul 31 06:38 UTC
✓ masters                      Update master nodes                                        Completed     -              /coredns                                      Fri Jul 31 06:41 UTC
  ✓ kevin-test1                Update system software on master node \"kevin-test1\"        Completed     -              -                                             Fri Jul 31 06:39 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed     -              -                                             Fri Jul 31 06:38 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed     -              /masters/kevin-test1/kubelet-permissions      Fri Jul 31 06:38 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed     10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Fri Jul 31 06:38 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed     10.162.0.7     /masters/kevin-test1/drain                    Fri Jul 31 06:39 UTC
    ✓ taint                    Taint node \"kevin-test1\"                                   Completed     10.162.0.7     /masters/kevin-test1/system-upgrade           Fri Jul 31 06:39 UTC
    ✓ uncordon                 Uncordon node \"kevin-test1\"                                Completed     10.162.0.7     /masters/kevin-test1/taint                    Fri Jul 31 06:39 UTC
    ✓ untaint                  Remove taint from node \"kevin-test1\"                       Completed     10.162.0.7     /masters/kevin-test1/uncordon                 Fri Jul 31 06:39 UTC
  ✓ elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Completed     -              /masters/kevin-test1                          Fri Jul 31 06:39 UTC
  ✓ kevin-test2                Update system software on master node \"kevin-test2\"        Completed     -              /masters/elect-kevin-test1                    Fri Jul 31 06:40 UTC
    ✓ drain                    Drain node \"kevin-test2\"                                   Completed     10.162.0.7     -                                             Fri Jul 31 06:39 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test2\"               Completed     10.162.0.6     /masters/kevin-test2/drain                    Fri Jul 31 06:40 UTC
    ✓ taint                    Taint node \"kevin-test2\"                                   Completed     10.162.0.7     /masters/kevin-test2/system-upgrade           Fri Jul 31 06:40 UTC
    ✓ uncordon                 Uncordon node \"kevin-test2\"                                Completed     10.162.0.7     /masters/kevin-test2/taint                    Fri Jul 31 06:40 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Completed     10.162.0.7     /masters/kevin-test2/uncordon                 Fri Jul 31 06:40 UTC
    ✓ untaint                  Remove taint from node \"kevin-test2\"                       Completed     10.162.0.7     /masters/kevin-test2/endpoints                Fri Jul 31 06:40 UTC
    ✓ enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Completed     -              /masters/kevin-test2/untaint                  Fri Jul 31 06:40 UTC
  ✓ kevin-test3                Update system software on master node \"kevin-test3\"        Completed     -              /masters/kevin-test2                          Fri Jul 31 06:41 UTC
    ✓ drain                    Drain node \"kevin-test3\"                                   Completed     10.162.0.7     -                                             Fri Jul 31 06:40 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test3\"               Completed     10.162.0.5     /masters/kevin-test3/drain                    Fri Jul 31 06:41 UTC
    ✓ taint                    Taint node \"kevin-test3\"                                   Completed     10.162.0.7     /masters/kevin-test3/system-upgrade           Fri Jul 31 06:41 UTC
    ✓ uncordon                 Uncordon node \"kevin-test3\"                                Completed     10.162.0.7     /masters/kevin-test3/taint                    Fri Jul 31 06:41 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Completed     10.162.0.7     /masters/kevin-test3/uncordon                 Fri Jul 31 06:41 UTC
    ✓ untaint                  Remove taint from node \"kevin-test3\"                       Completed     10.162.0.7     /masters/kevin-test3/endpoints                Fri Jul 31 06:41 UTC
    ✓ enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Completed     -              /masters/kevin-test3/untaint                  Fri Jul 31 06:41 UTC
✓ etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Completed     -              -                                             Fri Jul 31 07:00 UTC
  ✓ backup                     Backup etcd data                                           Completed     -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test1              Backup etcd on node \"kevin-test1\"                          Completed     -              -                                             Fri Jul 31 06:42 UTC
    ✓ kevin-test2              Backup etcd on node \"kevin-test2\"                          Completed     -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test3              Backup etcd on node \"kevin-test3\"                          Completed     -              -                                             Fri Jul 31 06:44 UTC
  ✓ shutdown                   Shutdown etcd cluster                                      Completed     -              -                                             Fri Jul 31 06:46 UTC
    ✓ kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Completed     -              /etcd/backup/kevin-test1                      Fri Jul 31 06:45 UTC
    ✓ kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Completed     -              /etcd/backup/kevin-test2                      Fri Jul 31 06:46 UTC
    ✓ kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Completed     -              /etcd/backup/kevin-test3                      Fri Jul 31 06:46 UTC
  ✓ upgrade                    Upgrade etcd servers                                       Completed     -              -                                             Fri Jul 31 06:55 UTC
    ✓ kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Completed     -              /etcd/shutdown/kevin-test1                    Fri Jul 31 06:50 UTC
    ✓ kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Completed     -              /etcd/shutdown/kevin-test2                    Fri Jul 31 06:55 UTC
    ✓ kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Completed     -              /etcd/shutdown/kevin-test3                    Fri Jul 31 06:55 UTC
  ✓ restore                    Restore etcd data from backup                              Completed     -              /etcd/upgrade                                 Fri Jul 31 06:56 UTC
  ✓ restart                    Restart etcd servers                                       Completed     -              -                                             Fri Jul 31 07:00 UTC
    ✓ kevin-test1              Restart etcd on node \"kevin-test1\"                         Completed     -              /etcd/restore                                 Fri Jul 31 06:59 UTC
    ✓ kevin-test2              Restart etcd on node \"kevin-test2\"                         Completed     -              /etcd/upgrade/kevin-test2                     Fri Jul 31 07:00 UTC
    ✓ kevin-test3              Restart etcd on node \"kevin-test3\"                         Completed     -              /etcd/upgrade/kevin-test3                     Fri Jul 31 07:00 UTC
    ✓ gravity-site             Restart gravity-site service                               Completed     -              -                                             Fri Jul 31 07:00 UTC
✓ config                       Update system configuration on nodes                       Completed     -              /etcd                                         Fri Jul 31 07:07 UTC
  ✓ kevin-test1                Update system configuration on node \"kevin-test1\"          Completed     -              -                                             Fri Jul 31 07:06 UTC
  ✓ kevin-test2                Update system configuration on node \"kevin-test2\"          Completed     -              -                                             Fri Jul 31 07:06 UTC
  ✓ kevin-test3                Update system configuration on node \"kevin-test3\"          Completed     -              -                                             Fri Jul 31 07:07 UTC
✓ runtime                      Update application runtime                                 Completed     -              /config                                       Fri Jul 31 07:18 UTC
  ✓ rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Completed     -              -                                             Fri Jul 31 07:14 UTC
  ✓ logging-app                Update system application \"logging-app\" to 5.0.3           Completed     -              /runtime/rbac-app                             Fri Jul 31 07:17 UTC
  ✓ monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Completed     -              /runtime/logging-app                          Fri Jul 31 07:18 UTC
  ✓ site                       Update system application \"site\" to 5.5.50-dev.9           Completed     -              /runtime/monitoring-app                       Fri Jul 31 07:18 UTC
  ✓ kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Completed     -              /runtime/site                                 Fri Jul 31 07:18 UTC
✓ migration                    Perform system database migration                          Completed     -              /runtime                                      Fri Jul 31 07:44 UTC
  ✓ labels                     Update node labels                                         Completed     -              -                                             Fri Jul 31 07:44 UTC
✓ app                          Update installed application                               Completed     -              /migration                                    Fri Jul 31 07:49 UTC
  ✓ telekube                   Update application \"telekube\" to 5.5.50-dev.9              Completed     -              -                                             Fri Jul 31 07:49 UTC
* gc                           Run cleanup tasks                                          Unstarted     -              /app                                          -
  * kevin-test1                Clean up node \"kevin-test1\"                                Unstarted     -              -                                             -
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted     -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted     -              -                                             -
." fsm/logger.go:49
Fri Jul 31 07:49:21 UTC	Executing phase "/app/telekube" finished in 1 second
```

### Garbage Collection
The last step of the upgrade is to run "garbage collection", which is a cleanup of files and directories that are no longer needed by the cluster.

```
root@kevin-test1:~/build# ./gravity --debug plan execute --phase /gc/kevin-test1 2>&1 | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'

...

2020-07-31T07:51:29Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Fri Jul 31 06:32 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Fri Jul 31 06:32 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Fri Jul 31 06:34 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Fri Jul 31 06:36 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Fri Jul 31 06:38 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Fri Jul 31 06:38 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Fri Jul 31 06:38 UTC
✓ masters                      Update master nodes                                        Completed       -              /coredns                                      Fri Jul 31 06:41 UTC
  ✓ kevin-test1                Update system software on master node \"kevin-test1\"        Completed       -              -                                             Fri Jul 31 06:39 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Fri Jul 31 06:38 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Fri Jul 31 06:38 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Fri Jul 31 06:38 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Fri Jul 31 06:39 UTC
    ✓ taint                    Taint node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Fri Jul 31 06:39 UTC
    ✓ uncordon                 Uncordon node \"kevin-test1\"                                Completed       10.162.0.7     /masters/kevin-test1/taint                    Fri Jul 31 06:39 UTC
    ✓ untaint                  Remove taint from node \"kevin-test1\"                       Completed       10.162.0.7     /masters/kevin-test1/uncordon                 Fri Jul 31 06:39 UTC
  ✓ elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Completed       -              /masters/kevin-test1                          Fri Jul 31 06:39 UTC
  ✓ kevin-test2                Update system software on master node \"kevin-test2\"        Completed       -              /masters/elect-kevin-test1                    Fri Jul 31 06:40 UTC
    ✓ drain                    Drain node \"kevin-test2\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:39 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test2\"               Completed       10.162.0.6     /masters/kevin-test2/drain                    Fri Jul 31 06:40 UTC
    ✓ taint                    Taint node \"kevin-test2\"                                   Completed       10.162.0.7     /masters/kevin-test2/system-upgrade           Fri Jul 31 06:40 UTC
    ✓ uncordon                 Uncordon node \"kevin-test2\"                                Completed       10.162.0.7     /masters/kevin-test2/taint                    Fri Jul 31 06:40 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Completed       10.162.0.7     /masters/kevin-test2/uncordon                 Fri Jul 31 06:40 UTC
    ✓ untaint                  Remove taint from node \"kevin-test2\"                       Completed       10.162.0.7     /masters/kevin-test2/endpoints                Fri Jul 31 06:40 UTC
    ✓ enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Completed       -              /masters/kevin-test2/untaint                  Fri Jul 31 06:40 UTC
  ✓ kevin-test3                Update system software on master node \"kevin-test3\"        Completed       -              /masters/kevin-test2                          Fri Jul 31 06:41 UTC
    ✓ drain                    Drain node \"kevin-test3\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:40 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test3\"               Completed       10.162.0.5     /masters/kevin-test3/drain                    Fri Jul 31 06:41 UTC
    ✓ taint                    Taint node \"kevin-test3\"                                   Completed       10.162.0.7     /masters/kevin-test3/system-upgrade           Fri Jul 31 06:41 UTC
    ✓ uncordon                 Uncordon node \"kevin-test3\"                                Completed       10.162.0.7     /masters/kevin-test3/taint                    Fri Jul 31 06:41 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Completed       10.162.0.7     /masters/kevin-test3/uncordon                 Fri Jul 31 06:41 UTC
    ✓ untaint                  Remove taint from node \"kevin-test3\"                       Completed       10.162.0.7     /masters/kevin-test3/endpoints                Fri Jul 31 06:41 UTC
    ✓ enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Completed       -              /masters/kevin-test3/untaint                  Fri Jul 31 06:41 UTC
✓ etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Completed       -              -                                             Fri Jul 31 07:00 UTC
  ✓ backup                     Backup etcd data                                           Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test1              Backup etcd on node \"kevin-test1\"                          Completed       -              -                                             Fri Jul 31 06:42 UTC
    ✓ kevin-test2              Backup etcd on node \"kevin-test2\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test3              Backup etcd on node \"kevin-test3\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
  ✓ shutdown                   Shutdown etcd cluster                                      Completed       -              -                                             Fri Jul 31 06:46 UTC
    ✓ kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Completed       -              /etcd/backup/kevin-test1                      Fri Jul 31 06:45 UTC
    ✓ kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Completed       -              /etcd/backup/kevin-test2                      Fri Jul 31 06:46 UTC
    ✓ kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Completed       -              /etcd/backup/kevin-test3                      Fri Jul 31 06:46 UTC
  ✓ upgrade                    Upgrade etcd servers                                       Completed       -              -                                             Fri Jul 31 06:55 UTC
    ✓ kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Completed       -              /etcd/shutdown/kevin-test1                    Fri Jul 31 06:50 UTC
    ✓ kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Completed       -              /etcd/shutdown/kevin-test2                    Fri Jul 31 06:55 UTC
    ✓ kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Completed       -              /etcd/shutdown/kevin-test3                    Fri Jul 31 06:55 UTC
  ✓ restore                    Restore etcd data from backup                              Completed       -              /etcd/upgrade                                 Fri Jul 31 06:56 UTC
  ✓ restart                    Restart etcd servers                                       Completed       -              -                                             Fri Jul 31 07:00 UTC
    ✓ kevin-test1              Restart etcd on node \"kevin-test1\"                         Completed       -              /etcd/restore                                 Fri Jul 31 06:59 UTC
    ✓ kevin-test2              Restart etcd on node \"kevin-test2\"                         Completed       -              /etcd/upgrade/kevin-test2                     Fri Jul 31 07:00 UTC
    ✓ kevin-test3              Restart etcd on node \"kevin-test3\"                         Completed       -              /etcd/upgrade/kevin-test3                     Fri Jul 31 07:00 UTC
    ✓ gravity-site             Restart gravity-site service                               Completed       -              -                                             Fri Jul 31 07:00 UTC
✓ config                       Update system configuration on nodes                       Completed       -              /etcd                                         Fri Jul 31 07:07 UTC
  ✓ kevin-test1                Update system configuration on node \"kevin-test1\"          Completed       -              -                                             Fri Jul 31 07:06 UTC
  ✓ kevin-test2                Update system configuration on node \"kevin-test2\"          Completed       -              -                                             Fri Jul 31 07:06 UTC
  ✓ kevin-test3                Update system configuration on node \"kevin-test3\"          Completed       -              -                                             Fri Jul 31 07:07 UTC
✓ runtime                      Update application runtime                                 Completed       -              /config                                       Fri Jul 31 07:18 UTC
  ✓ rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Completed       -              -                                             Fri Jul 31 07:14 UTC
  ✓ logging-app                Update system application \"logging-app\" to 5.0.3           Completed       -              /runtime/rbac-app                             Fri Jul 31 07:17 UTC
  ✓ monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Completed       -              /runtime/logging-app                          Fri Jul 31 07:18 UTC
  ✓ site                       Update system application \"site\" to 5.5.50-dev.9           Completed       -              /runtime/monitoring-app                       Fri Jul 31 07:18 UTC
  ✓ kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Completed       -              /runtime/site                                 Fri Jul 31 07:18 UTC
✓ migration                    Perform system database migration                          Completed       -              /runtime                                      Fri Jul 31 07:44 UTC
  ✓ labels                     Update node labels                                         Completed       -              -                                             Fri Jul 31 07:44 UTC
✓ app                          Update installed application                               Completed       -              /migration                                    Fri Jul 31 07:49 UTC
  ✓ telekube                   Update application \"telekube\" to 5.5.50-dev.9              Completed       -              -                                             Fri Jul 31 07:49 UTC
→ gc                           Run cleanup tasks                                          In Progress     -              /app                                          Fri Jul 31 07:51 UTC
  → kevin-test1                Clean up node \"kevin-test1\"                                In Progress     -              -                                             Fri Jul 31 07:51 UTC
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
2020-07-31T07:51:29Z INFO             Executing phase: /gc/kevin-test1. phase:/gc/kevin-test1 fsm/logger.go:61
2020-07-31T07:51:29Z INFO             Gabrage collect obsolete journal files. phase:/gc/kevin-test1 fsm/logger.go:61
2020-07-31T07:51:29Z DEBU             Executing command: [/home/knisbet/build/gravity planet enter -- --notty /bin/journalctl -- --flush --rotate]. fsm/rpc.go:217
2020-07-31T07:51:30Z DEBU             command:[/home/knisbet/build/gravity planet enter -- --notty /bin/journalctl -- --flush --rotate] phases/gc.go:80
2020-07-31T07:51:30Z DEBU             Executing command: [/home/knisbet/build/gravity planet enter -- --notty /usr/bin/gravity -- system gc journal --debug]. fsm/rpc.go:217
2020-07-31T07:51:30Z DEBU             "2020-07-31T07:51:30Z DEBU             got search paths: [/var/lib/gravity assets/local] processconfig/config.go:57
2020-07-31T07:51:30Z DEBU             look up configs in /var/lib/gravity processconfig/config.go:59
2020-07-31T07:51:30Z DEBU             /var/lib/gravity/gravity.yaml not found in search path processconfig/config.go:67
2020-07-31T07:51:30Z DEBU             look up configs in assets/local processconfig/config.go:59
2020-07-31T07:51:30Z DEBU             assets/local/gravity.yaml not found in search path processconfig/config.go:67
2020-07-31T07:51:30Z DEBU [LOCAL]     Creating local env: localenv.LocalEnvironmentArgs{LocalKeyStoreDir:\"\", StateDir:\"/var/lib/gravity/local\", Insecure:false, Silent:false, Debug:true, EtcdRetryTimeout:0, Reporter:(pack.ProgressReporterFn)(0x1e168d0), DNS:localenv.DNSConfig{Addrs:[]string(nil), Port:0}}. localenv/localenv.go:146
2020-07-31T07:51:30Z INFO [GC:JOURNA] Skipped. directory:7265fe765262551a676151a24c02b7b6 journal/journal.go:110
" command:[/home/knisbet/build/gravity planet enter -- --notty /usr/bin/gravity -- system gc journal --debug] phases/gc.go:80
2020-07-31T07:51:30Z DEBU [FSM:UPDAT] Apply. change:StateChange(Phase=/gc/kevin-test1, State=completed) cluster/engine.go:288
2020-07-31T07:51:30Z DEBU [FSM:UPDAT] "Reconciled plan: Phase                          Description                                                State           Node           Requires                                      Updated
-----                          -----------                                                -----           ----           --------                                      -------
✓ init                         Initialize update operation                                Completed       -              -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test1                Initialize node \"kevin-test1\"                              Completed       10.162.0.7     -                                             Fri Jul 31 06:33 UTC
  ✓ kevin-test2                Initialize node \"kevin-test2\"                              Completed       10.162.0.6     -                                             Fri Jul 31 06:32 UTC
  ✓ kevin-test3                Initialize node \"kevin-test3\"                              Completed       10.162.0.5     -                                             Fri Jul 31 06:32 UTC
✓ checks                       Run preflight checks                                       Completed       -              /init                                         Fri Jul 31 06:34 UTC
✓ pre-update                   Run pre-update application hook                            Completed       -              /init,/checks                                 Fri Jul 31 06:36 UTC
✓ bootstrap                    Bootstrap update operation on nodes                        Completed       -              /checks,/pre-update                           Fri Jul 31 06:38 UTC
  ✓ kevin-test1                Bootstrap node \"kevin-test1\"                               Completed       10.162.0.7     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test2                Bootstrap node \"kevin-test2\"                               Completed       10.162.0.6     -                                             Fri Jul 31 06:37 UTC
  ✓ kevin-test3                Bootstrap node \"kevin-test3\"                               Completed       10.162.0.5     -                                             Fri Jul 31 06:38 UTC
✓ coredns                      Provision CoreDNS resources                                Completed       -              /bootstrap                                    Fri Jul 31 06:38 UTC
✓ masters                      Update master nodes                                        Completed       -              /coredns                                      Fri Jul 31 06:41 UTC
  ✓ kevin-test1                Update system software on master node \"kevin-test1\"        Completed       -              -                                             Fri Jul 31 06:39 UTC
    ✓ kubelet-permissions      Add permissions to kubelet on \"kevin-test1\"                Completed       -              -                                             Fri Jul 31 06:38 UTC
    ✓ stepdown-kevin-test1     Step down \"kevin-test1\" as Kubernetes leader               Completed       -              /masters/kevin-test1/kubelet-permissions      Fri Jul 31 06:38 UTC
    ✓ drain                    Drain node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/stepdown-kevin-test1     Fri Jul 31 06:38 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test1\"               Completed       10.162.0.7     /masters/kevin-test1/drain                    Fri Jul 31 06:39 UTC
    ✓ taint                    Taint node \"kevin-test1\"                                   Completed       10.162.0.7     /masters/kevin-test1/system-upgrade           Fri Jul 31 06:39 UTC
    ✓ uncordon                 Uncordon node \"kevin-test1\"                                Completed       10.162.0.7     /masters/kevin-test1/taint                    Fri Jul 31 06:39 UTC
    ✓ untaint                  Remove taint from node \"kevin-test1\"                       Completed       10.162.0.7     /masters/kevin-test1/uncordon                 Fri Jul 31 06:39 UTC
  ✓ elect-kevin-test1          Make node \"kevin-test1\" Kubernetes leader                  Completed       -              /masters/kevin-test1                          Fri Jul 31 06:39 UTC
  ✓ kevin-test2                Update system software on master node \"kevin-test2\"        Completed       -              /masters/elect-kevin-test1                    Fri Jul 31 06:40 UTC
    ✓ drain                    Drain node \"kevin-test2\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:39 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test2\"               Completed       10.162.0.6     /masters/kevin-test2/drain                    Fri Jul 31 06:40 UTC
    ✓ taint                    Taint node \"kevin-test2\"                                   Completed       10.162.0.7     /masters/kevin-test2/system-upgrade           Fri Jul 31 06:40 UTC
    ✓ uncordon                 Uncordon node \"kevin-test2\"                                Completed       10.162.0.7     /masters/kevin-test2/taint                    Fri Jul 31 06:40 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test2\"            Completed       10.162.0.7     /masters/kevin-test2/uncordon                 Fri Jul 31 06:40 UTC
    ✓ untaint                  Remove taint from node \"kevin-test2\"                       Completed       10.162.0.7     /masters/kevin-test2/endpoints                Fri Jul 31 06:40 UTC
    ✓ enable-kevin-test2       Enable leader election on node \"kevin-test2\"               Completed       -              /masters/kevin-test2/untaint                  Fri Jul 31 06:40 UTC
  ✓ kevin-test3                Update system software on master node \"kevin-test3\"        Completed       -              /masters/kevin-test2                          Fri Jul 31 06:41 UTC
    ✓ drain                    Drain node \"kevin-test3\"                                   Completed       10.162.0.7     -                                             Fri Jul 31 06:40 UTC
    ✓ system-upgrade           Update system software on node \"kevin-test3\"               Completed       10.162.0.5     /masters/kevin-test3/drain                    Fri Jul 31 06:41 UTC
    ✓ taint                    Taint node \"kevin-test3\"                                   Completed       10.162.0.7     /masters/kevin-test3/system-upgrade           Fri Jul 31 06:41 UTC
    ✓ uncordon                 Uncordon node \"kevin-test3\"                                Completed       10.162.0.7     /masters/kevin-test3/taint                    Fri Jul 31 06:41 UTC
    ✓ endpoints                Wait for DNS/cluster endpoints on \"kevin-test3\"            Completed       10.162.0.7     /masters/kevin-test3/uncordon                 Fri Jul 31 06:41 UTC
    ✓ untaint                  Remove taint from node \"kevin-test3\"                       Completed       10.162.0.7     /masters/kevin-test3/endpoints                Fri Jul 31 06:41 UTC
    ✓ enable-kevin-test3       Enable leader election on node \"kevin-test3\"               Completed       -              /masters/kevin-test3/untaint                  Fri Jul 31 06:41 UTC
✓ etcd                         Upgrade etcd 3.3.20 to 3.3.22                              Completed       -              -                                             Fri Jul 31 07:00 UTC
  ✓ backup                     Backup etcd data                                           Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test1              Backup etcd on node \"kevin-test1\"                          Completed       -              -                                             Fri Jul 31 06:42 UTC
    ✓ kevin-test2              Backup etcd on node \"kevin-test2\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
    ✓ kevin-test3              Backup etcd on node \"kevin-test3\"                          Completed       -              -                                             Fri Jul 31 06:44 UTC
  ✓ shutdown                   Shutdown etcd cluster                                      Completed       -              -                                             Fri Jul 31 06:46 UTC
    ✓ kevin-test1              Shutdown etcd on node \"kevin-test1\"                        Completed       -              /etcd/backup/kevin-test1                      Fri Jul 31 06:45 UTC
    ✓ kevin-test2              Shutdown etcd on node \"kevin-test2\"                        Completed       -              /etcd/backup/kevin-test2                      Fri Jul 31 06:46 UTC
    ✓ kevin-test3              Shutdown etcd on node \"kevin-test3\"                        Completed       -              /etcd/backup/kevin-test3                      Fri Jul 31 06:46 UTC
  ✓ upgrade                    Upgrade etcd servers                                       Completed       -              -                                             Fri Jul 31 06:55 UTC
    ✓ kevin-test1              Upgrade etcd on node \"kevin-test1\"                         Completed       -              /etcd/shutdown/kevin-test1                    Fri Jul 31 06:50 UTC
    ✓ kevin-test2              Upgrade etcd on node \"kevin-test2\"                         Completed       -              /etcd/shutdown/kevin-test2                    Fri Jul 31 06:55 UTC
    ✓ kevin-test3              Upgrade etcd on node \"kevin-test3\"                         Completed       -              /etcd/shutdown/kevin-test3                    Fri Jul 31 06:55 UTC
  ✓ restore                    Restore etcd data from backup                              Completed       -              /etcd/upgrade                                 Fri Jul 31 06:56 UTC
  ✓ restart                    Restart etcd servers                                       Completed       -              -                                             Fri Jul 31 07:00 UTC
    ✓ kevin-test1              Restart etcd on node \"kevin-test1\"                         Completed       -              /etcd/restore                                 Fri Jul 31 06:59 UTC
    ✓ kevin-test2              Restart etcd on node \"kevin-test2\"                         Completed       -              /etcd/upgrade/kevin-test2                     Fri Jul 31 07:00 UTC
    ✓ kevin-test3              Restart etcd on node \"kevin-test3\"                         Completed       -              /etcd/upgrade/kevin-test3                     Fri Jul 31 07:00 UTC
    ✓ gravity-site             Restart gravity-site service                               Completed       -              -                                             Fri Jul 31 07:00 UTC
✓ config                       Update system configuration on nodes                       Completed       -              /etcd                                         Fri Jul 31 07:07 UTC
  ✓ kevin-test1                Update system configuration on node \"kevin-test1\"          Completed       -              -                                             Fri Jul 31 07:06 UTC
  ✓ kevin-test2                Update system configuration on node \"kevin-test2\"          Completed       -              -                                             Fri Jul 31 07:06 UTC
  ✓ kevin-test3                Update system configuration on node \"kevin-test3\"          Completed       -              -                                             Fri Jul 31 07:07 UTC
✓ runtime                      Update application runtime                                 Completed       -              /config                                       Fri Jul 31 07:18 UTC
  ✓ rbac-app                   Update system application \"rbac-app\" to 5.5.50-dev.9       Completed       -              -                                             Fri Jul 31 07:14 UTC
  ✓ logging-app                Update system application \"logging-app\" to 5.0.3           Completed       -              /runtime/rbac-app                             Fri Jul 31 07:17 UTC
  ✓ monitoring-app             Update system application \"monitoring-app\" to 5.5.21       Completed       -              /runtime/logging-app                          Fri Jul 31 07:18 UTC
  ✓ site                       Update system application \"site\" to 5.5.50-dev.9           Completed       -              /runtime/monitoring-app                       Fri Jul 31 07:18 UTC
  ✓ kubernetes                 Update system application \"kubernetes\" to 5.5.50-dev.9     Completed       -              /runtime/site                                 Fri Jul 31 07:18 UTC
✓ migration                    Perform system database migration                          Completed       -              /runtime                                      Fri Jul 31 07:44 UTC
  ✓ labels                     Update node labels                                         Completed       -              -                                             Fri Jul 31 07:44 UTC
✓ app                          Update installed application                               Completed       -              /migration                                    Fri Jul 31 07:49 UTC
  ✓ telekube                   Update application \"telekube\" to 5.5.50-dev.9              Completed       -              -                                             Fri Jul 31 07:49 UTC
→ gc                           Run cleanup tasks                                          In Progress     -              /app                                          Fri Jul 31 07:51 UTC
  ✓ kevin-test1                Clean up node \"kevin-test1\"                                Completed       -              -                                             Fri Jul 31 07:51 UTC
  * kevin-test2                Clean up node \"kevin-test2\"                                Unstarted       -              -                                             -
  * kevin-test3                Clean up node \"kevin-test3\"                                Unstarted       -              -                                             -
." fsm/logger.go:49
Fri Jul 31 07:51:30 UTC	Executing phase "/gc/kevin-test1" finished in 1 second
```

### Complete the Upgrade

```
root@kevin-test1:~/build# ./gravity plan complete
```

## Upgrade Scenarios

In this section we will cover several Gravity upgrade scenarios. Using what you have learned in this workshop the goal will to be successfully complete an upgrade for each of the following scenarios.

### Pre-requisite

Please clone the workshop repo locally via:
```
git clone https://github.com/gravitational/workshop
```
and setup three nodes, using the Terraform script in the `env` directory or
provide a similar environment.

### Initial Setup

Once the VMs are ready, follow the instructions in upgrade/lab0.sh to get ready
for the following scenarios.

### Upgrade Scenario 1:

Copy on a VM and then run the script `upgrade/lab1.sh`

### Upgrade Scenario 2:

Copy on a VM and then run the script `upgrade/lab2.sh`

### Upgrade Scenario 3:

Copy on a VM and then run the script `upgrade/lab3.sh`

### Upgrade Scenario 4:

Copy on a VM and then run the script `upgrade/lab4.sh`

### Upgrade Scenario 5:

Copy on a VM and then run the script `upgrade/lab5.sh`

### Upgrade Scenario 6:

Copy on a VM and then run the script `upgrade/lab6.sh`

### Upgrade Scenario 7:

Copy on a VM and then run the script `upgrade/lab7.sh`
