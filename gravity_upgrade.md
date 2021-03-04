# Gravity Upgrade Training (for Gravity 7.x)

## Introduction

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

1. An upgrade agent is deployed on each cluster node as a `systemd` unit called `gravity-agent.service`

2. Phases listed in the upgrade plan are executed by the agents.

3. Upon completion the upgrade agents are shut down.

#### Manual Upgrade

Another option for a Gravity upgrade is a manual upgrade which we will cover by stepping through an example later in this workshop.

In order to execute a manual upgrade the operation will be started by adding `--manual | -m` flag with the upgrade command:

`sudo ./gravity upgrade --manual`

To ensure version compatibility, all upgrade related commands (agent deployment, phase execution/rollback, etc.) need to be executed using the gravity binary included in the upgrade tarball. This means many of the gravity commands in this guide will be prefixed with `./` to execute the upgrade gravity instead of the `gravity` in the shell's PATH.

A manual upgrade operation starts with an operation plan which is a tree of actions required to be performed in the specified order to achieve the goal of the upgrade. This concept of the operation exists in order to have sets of smaller steps during an upgrade which can be re-executed or rolled back. We will step through this in more detail further into the workshop.

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
  + `sudo ./gravity --debug plan execute --phase $PHASE 2>&1 | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'`
    This will re-run an upgrade phase with debug output (translated to be easier
    for humans to read.
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
  + `sudo gravity status history`
    The status command also features a `tail -f` equivalent that shows status
    time.  This can be useful for catching failures that are flapping.
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


## Gravity Manual Upgrade Demo

The demo of an upgrade will focus on a manual upgrade, taking our time to go through the upgrade step by step and taking a look at what is happening. The same steps are completed doing an automatic upgrade, the difference is that an automatic upgrade has a process trying to make progress on the upgrade until it encounters an error. In order to get a better understand of how the upgrades work, we'll walk through a manual upgrade from start to finish.

### Demo Setup

The demo of the manual upgrade will be on a simple 3 node cluster, with a minimal kubernetes application inside. These 3 nodes are masters within the cluster, and there are no workers. Upgrading a worker is the same as upgrading a master, but certain steps to do with being a master can be skipped. The manifest for these images can be found in the [upgrade/v1](./upgrade/v1/) and [upgrade/v2](./upgrade/v2/) directories.

```
ubuntu@node-1:~$ sudo gravity status
Cluster name:           upgrade-demo
Cluster status:         active
Cluster image:          upgrade-demo, version 1.0.0
Gravity version:        7.0.12 (client) / 7.0.12 (server)
Join token:             9db3ba257fb267c17b306a6657584dfa
Periodic updates:       Not Configured
Remote support:         Not Configured
Last completed operation:
    * Join node node-3 (10.138.0.8) as node
      ID:               b0a44c08-0aaf-4dd2-8c12-9c1f6ca0315a
      Started:          Thu Mar  4 03:56 UTC (2 minutes ago)
      Completed:        Thu Mar  4 03:59 UTC (51 seconds ago)
Cluster endpoints:
    * Authentication gateway:
        - 10.138.0.6:32009
        - 10.138.0.15:32009
        - 10.138.0.8:32009
    * Cluster management URL:
        - https://10.138.0.6:32009
        - https://10.138.0.15:32009
        - https://10.138.0.8:32009
Cluster nodes:
    Masters:
        * node-1 / 10.138.0.6 / node
            Status:             healthy
            Remote access:      online
        * node-2 / 10.138.0.15 / node
            Status:             healthy
            Remote access:      online
        * node-3 / 10.138.0.8 / node
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
ubuntu@node-1:~$ sudo gravity --insecure package list --ops-url=https://gravity-site.kube-system.svc.cluster.local:3009

[gravitational.io]
------------------

* gravitational.io/bandwagon:6.0.1 76MB
* gravitational.io/dns-app:0.4.1 70MB
* gravitational.io/fio:3.15.0 6.9MB
* gravitational.io/gravity:7.0.12 111MB
* gravitational.io/kubernetes:7.0.12 5.6MB
* gravitational.io/logging-app:6.0.5 127MB
* gravitational.io/monitoring-app:7.0.2 346MB
* gravitational.io/planet:7.0.35-11706 515MB purpose:runtime
* gravitational.io/rbac-app:7.0.12 5.6MB
* gravitational.io/rpcagent-secrets:0.0.1 12kB purpose:rpc-secrets
* gravitational.io/site:7.0.12 84MB
* gravitational.io/storage-app:0.0.3 1.0GB
* gravitational.io/teleport:3.2.14 33MB
* gravitational.io/tiller-app:7.0.1 34MB
* gravitational.io/upgrade-demo:1.0.0 13MB
* gravitational.io/web-assets:7.0.12 5.0MB

[upgrade-demo]
--------------

* upgrade-demo/cert-authority:0.0.1 12kB operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:ca
* upgrade-demo/planet-10.138.0.15-secrets:7.0.35-11706 70kB advertise-ip:10.138.0.15,operation-id:41ce33cc-247e-4921-89df-ae5ff36d113d,purpose:planet-secrets
* upgrade-demo/planet-10.138.0.6-secrets:7.0.35-11706 71kB advertise-ip:10.138.0.6,operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:planet-secrets
* upgrade-demo/planet-config-10138015upgrade-demo:7.0.35-11706 4.6kB purpose:planet-config,advertise-ip:10.138.0.15,config-package-for:gravitational.io/planet:0.0.0,operation-id:41ce33cc-247e-4921-89df-ae5ff36d113d
* upgrade-demo/planet-config-1013806upgrade-demo:7.0.35-11706 4.6kB operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:planet-config,advertise-ip:10.138.0.6,config-package-for:gravitational.io/planet:0.0.0
* upgrade-demo/teleport-master-config-10138015upgrade-demo:3.2.14 4.1kB purpose:teleport-master-config,advertise-ip:10.138.0.15,operation-id:41ce33cc-247e-4921-89df-ae5ff36d113d
* upgrade-demo/teleport-master-config-1013806upgrade-demo:3.2.14 4.1kB advertise-ip:10.138.0.6,operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:teleport-master-config
* upgrade-demo/teleport-node-config-10138015upgrade-demo:3.2.14 4.1kB advertise-ip:10.138.0.15,config-package-for:gravitational.io/teleport:0.0.0,operation-id:41ce33cc-247e-4921-89df-ae5ff36d113d,purpose:teleport-node-config
* upgrade-demo/teleport-node-config-1013806upgrade-demo:3.2.14 4.1kB advertise-ip:10.138.0.6,config-package-for:gravitational.io/teleport:0.0.0,operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:teleport-node-config
```

Notes:
1. There are two "namespace" of packages.
    1. `gravitational.io` are packages built by gravitational and shipped as updates. IE dns-app:0.3.0 is version 0.3.0 of the cluster DNS deployed within gravity.
    1. `<cluster_name>` are configuration packages for the particular cluster. These are configurations used for setting up nodes, like planet and teleport connectivity.

#### Node Package Store
The cluster package store works sort of like a docker registry server. It's a storage location for packages and blobs of data that can be pulled to another location. The node package store is the local copy of the packages on the node. This is similar to running `docker image ls` in that it shows the containers available on the node, and not the ones on the registry server.

```
ubuntu@node-1:~$ sudo gravity package list

[gravitational.io]
------------------

* gravitational.io/bandwagon:6.0.1 76MB
* gravitational.io/dns-app:0.4.1 70MB
* gravitational.io/fio:3.15.0 6.9MB
* gravitational.io/gravity:7.0.12 111MB installed:installed
* gravitational.io/kubernetes:7.0.12 5.6MB
* gravitational.io/logging-app:6.0.5 127MB
* gravitational.io/monitoring-app:7.0.2 346MB
* gravitational.io/planet:7.0.35-11706 515MB purpose:runtime,installed:installed
* gravitational.io/rbac-app:7.0.12 5.6MB
* gravitational.io/site:7.0.12 84MB
* gravitational.io/storage-app:0.0.3 1.0GB
* gravitational.io/teleport:3.2.14 33MB installed:installed
* gravitational.io/tiller-app:7.0.1 34MB
* gravitational.io/upgrade-demo:1.0.0 13MB
* gravitational.io/web-assets:7.0.12 5.0MB

[upgrade-demo]
--------------

* upgrade-demo/cert-authority:0.0.1 12kB operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:ca
* upgrade-demo/planet-10.138.0.6-secrets:7.0.35-11706 71kB advertise-ip:10.138.0.6,installed:installed,operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:planet-secrets
* upgrade-demo/planet-config-1013806upgrade-demo:7.0.35-11706 4.6kB installed:installed,operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:planet-config,advertise-ip:10.138.0.6,config-package-for:gravitational.io/planet:0.0.0
* upgrade-demo/site-export:0.0.1 262kB operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:export
* upgrade-demo/teleport-master-config-1013806upgrade-demo:3.2.14 4.1kB advertise-ip:10.138.0.6,operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:teleport-master-config
* upgrade-demo/teleport-node-config-1013806upgrade-demo:3.2.14 4.1kB advertise-ip:10.138.0.6,config-package-for:gravitational.io/teleport:0.0.0,installed:installed,operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:teleport-node-config
```

### Extract an upgrade
Gravity ships cluster images as tar files, so we need to extract the tar file of our new version in order to interact with the upgrade.

- `mkdir upgrade`
- `tar -xvf upgrade-demo-2.0.0.tar -C v2`
- `cd v2`

```
ubuntu@node-1:~/v2$ tree
.
├── app.yaml
├── gravity
├── gravity.db
├── install
├── packages
│   ├── blobs
│   │   ├── 0ca
│   │   │   └── 0ca6fd9984c186d36753867d5b3f3a8b79edc7ddc9fba9bcaf55283d343f13c4
│   │   ├── 106
│   │   │   └── 106c1f3f714fff69d11d876b7dd482af834087458afaaef718a153517830cc21
│   │   ├── 10b
│   │   │   └── 10b2e91950a40a685af3736b6d8b6fb99d0d4515233631feaac463ca75d74928
│   │   ├── 1b7
│   │   │   └── 1b78ceee195a357f3e41c226b07931d1d8b646d596298f8caaf95030ca3f8dd3
│   │   ├── 3ab
│   │   │   └── 3ab285bfe181a5421d6e3e5bf889c7c9c84337de6cd1bcc8da0078fc365a66ae
│   │   ├── 451
│   │   │   └── 4519800dc3d78a882979838189ff799079362368415356a134eb8a2b7980e185
│   │   ├── 500
│   │   │   └── 50054ebf04241ac167ed4a0654b123258105e2e14ba94b98d0c26c90e3520a85
│   │   ├── 5ce
│   │   │   └── 5ce1e0357d1b27adc5265cb62a13e68bd032e999d9920527a0062fa7dc781152
│   │   ├── 64d
│   │   │   └── 64dd0362d08e192e345a423646f7fa806359c9e3b0ee91f2188d00e461eeb4b3
│   │   ├── 722
│   │   │   └── 722bf46f5cff19af56834c31aca3768e70720d520dd3881b257ff4438b0f0c64
│   │   ├── 813
│   │   │   └── 813814d42514af4ff899a5ac5609c55a37769fce0e254b2d42e1ccb2dbacdd9d
│   │   ├── 860
│   │   │   └── 86044f3fbb8b03c9d3b3151b618a6015bf4233c5080abe071b47bb5064eb3a53
│   │   ├── c65
│   │   │   └── c655c3ecac3b608ca214acbc439b1400c5b8d223a67cfa937917074acc515af1
│   │   ├── d18
│   │   │   └── d18e06f5f9170214e5831f6673082d2f520dcb7d2def426b626b863e6e3b0ba9
│   │   └── d4f
│   │       └── d4fdbfdc0fe15bf67055ba5f7a085c68a7600b94273b5e0bdd989b65dc3ed0ad
│   ├── tmp
│   └── unpacked
├── README
├── run_preflight_checks
├── upgrade
└── upload

19 directories, 23 files
```


### Upload the package
Inside the gravity tarball is a script for uploading the contents of the local directory to the cluster package store. In effect, we take the assets we unzipped from the installer tarball, and sync the differences to the cluster.

```
ubuntu@node-1:~/v2$ sudo ./upload
Thu Mar  4 04:02:00 UTC Importing application upgrade-demo v2.0.0
Thu Mar  4 04:03:54 UTC Synchronizing application with Docker registry 10.138.0.6:5000
Thu Mar  4 04:04:22 UTC Synchronizing application with Docker registry 10.138.0.15:5000
Thu Mar  4 04:04:52 UTC Synchronizing application with Docker registry 10.138.0.8:5000
Thu Mar  4 04:05:22 UTC Verifying cluster health
Thu Mar  4 04:05:22 UTC Application has been uploaded
```

Notes:
- This uploads the packages to the cluster package store.
- This uploads the containers to the docker registry running on every master.
- Waits for the cluster to become healthy, if the upload caused a performance issue within etcd.

The cluster package store will now have additional packages present:
```

ubuntu@node-1:~/v2$ sudo gravity --insecure package list --ops-url=https://gravity-site.kube-system.svc.cluster.local:3009

[gravitational.io]
------------------

* gravitational.io/bandwagon:6.0.1 76MB
* gravitational.io/dns-app:0.4.1 70MB
* gravitational.io/dns-app:7.0.3 82MB
* gravitational.io/fio:3.15.0 6.9MB
* gravitational.io/gravity:7.0.12 111MB
* gravitational.io/gravity:7.0.30 112MB
* gravitational.io/kubernetes:7.0.12 5.6MB
* gravitational.io/kubernetes:7.0.30 5.6MB
* gravitational.io/logging-app:6.0.5 127MB
* gravitational.io/logging-app:6.0.8 122MB
* gravitational.io/monitoring-app:7.0.2 346MB
* gravitational.io/monitoring-app:7.0.8 364MB
* gravitational.io/planet:7.0.35-11706 515MB purpose:runtime
* gravitational.io/planet:7.0.56-11709 558MB purpose:runtime
* gravitational.io/rbac-app:7.0.12 5.6MB
* gravitational.io/rbac-app:7.0.30 5.6MB
* gravitational.io/rpcagent-secrets:0.0.1 12kB purpose:rpc-secrets
* gravitational.io/site:7.0.12 84MB
* gravitational.io/site:7.0.30 85MB
* gravitational.io/storage-app:0.0.3 1.0GB
* gravitational.io/teleport:3.2.14 33MB
* gravitational.io/teleport:3.2.16 33MB
* gravitational.io/tiller-app:7.0.1 34MB
* gravitational.io/tiller-app:7.0.2 34MB
* gravitational.io/upgrade-demo:1.0.0 13MB
* gravitational.io/upgrade-demo:2.0.0 13MB
* gravitational.io/web-assets:7.0.12 5.0MB
* gravitational.io/web-assets:7.0.30 5.0MB

[upgrade-demo]
--------------

* upgrade-demo/cert-authority:0.0.1 12kB operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:ca
* upgrade-demo/planet-10.138.0.15-secrets:7.0.35-11706 70kB advertise-ip:10.138.0.15,operation-id:41ce33cc-247e-4921-89df-ae5ff36d113d,purpose:planet-secrets
* upgrade-demo/planet-10.138.0.6-secrets:7.0.35-11706 71kB advertise-ip:10.138.0.6,operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:planet-secrets
* upgrade-demo/planet-10.138.0.8-secrets:7.0.35-11706 70kB advertise-ip:10.138.0.8,operation-id:b0a44c08-0aaf-4dd2-8c12-9c1f6ca0315a,purpose:planet-secrets
* upgrade-demo/planet-config-10138015upgrade-demo:7.0.35-11706 4.6kB advertise-ip:10.138.0.15,config-package-for:gravitational.io/planet:0.0.0,operation-id:41ce33cc-247e-4921-89df-ae5ff36d113d,purpose:planet-config
* upgrade-demo/planet-config-1013806upgrade-demo:7.0.35-11706 4.6kB advertise-ip:10.138.0.6,config-package-for:gravitational.io/planet:0.0.0,operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:planet-config
* upgrade-demo/planet-config-1013808upgrade-demo:7.0.35-11706 4.6kB config-package-for:gravitational.io/planet:0.0.0,operation-id:b0a44c08-0aaf-4dd2-8c12-9c1f6ca0315a,purpose:planet-config,advertise-ip:10.138.0.8
* upgrade-demo/teleport-master-config-10138015upgrade-demo:3.2.14 4.1kB advertise-ip:10.138.0.15,operation-id:41ce33cc-247e-4921-89df-ae5ff36d113d,purpose:teleport-master-config
* upgrade-demo/teleport-master-config-1013806upgrade-demo:3.2.14 4.1kB advertise-ip:10.138.0.6,operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:teleport-master-config
* upgrade-demo/teleport-master-config-1013808upgrade-demo:3.2.14 4.1kB purpose:teleport-master-config,advertise-ip:10.138.0.8,operation-id:b0a44c08-0aaf-4dd2-8c12-9c1f6ca0315a
* upgrade-demo/teleport-node-config-10138015upgrade-demo:3.2.14 4.1kB advertise-ip:10.138.0.15,config-package-for:gravitational.io/teleport:0.0.0,operation-id:41ce33cc-247e-4921-89df-ae5ff36d113d,purpose:teleport-node-config
* upgrade-demo/teleport-node-config-1013806upgrade-demo:3.2.14 4.1kB advertise-ip:10.138.0.6,config-package-for:gravitational.io/teleport:0.0.0,operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:teleport-node-config
* upgrade-demo/teleport-node-config-1013808upgrade-demo:3.2.14 4.1kB advertise-ip:10.138.0.8,config-package-for:gravitational.io/teleport:0.0.0,operation-id:b0a44c08-0aaf-4dd2-8c12-9c1f6ca0315a,purpose:teleport-node-config
```

But if we look at the packages on our nodes package store, the new packages aren't shown.
```
ubuntu@node-1:~/v2$ sudo gravity package list

[gravitational.io]
------------------

* gravitational.io/bandwagon:6.0.1 76MB
* gravitational.io/dns-app:0.4.1 70MB
* gravitational.io/fio:3.15.0 6.9MB
* gravitational.io/gravity:7.0.12 111MB installed:installed
* gravitational.io/kubernetes:7.0.12 5.6MB
* gravitational.io/logging-app:6.0.5 127MB
* gravitational.io/monitoring-app:7.0.2 346MB
* gravitational.io/planet:7.0.35-11706 515MB installed:installed,purpose:runtime
* gravitational.io/rbac-app:7.0.12 5.6MB
* gravitational.io/site:7.0.12 84MB
* gravitational.io/storage-app:0.0.3 1.0GB
* gravitational.io/teleport:3.2.14 33MB installed:installed
* gravitational.io/tiller-app:7.0.1 34MB
* gravitational.io/upgrade-demo:1.0.0 13MB
* gravitational.io/web-assets:7.0.12 5.0MB

[upgrade-demo]
--------------

* upgrade-demo/cert-authority:0.0.1 12kB operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:ca
* upgrade-demo/planet-10.138.0.6-secrets:7.0.35-11706 71kB advertise-ip:10.138.0.6,installed:installed,operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:planet-secrets
* upgrade-demo/planet-config-1013806upgrade-demo:7.0.35-11706 4.6kB config-package-for:gravitational.io/planet:0.0.0,installed:installed,operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:planet-config,advertise-ip:10.138.0.6
* upgrade-demo/site-export:0.0.1 262kB operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:export
* upgrade-demo/teleport-master-config-1013806upgrade-demo:3.2.14 4.1kB advertise-ip:10.138.0.6,operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:teleport-master-config
* upgrade-demo/teleport-node-config-1013806upgrade-demo:3.2.14 4.1kB advertise-ip:10.138.0.6,config-package-for:gravitational.io/teleport:0.0.0,installed:installed,operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:teleport-node-config
```

This is because the node hasn't been upgraded yet. The required packages will be pulled to the node only when they are needed.

### Start a manual upgrade
To start a manual upgrade, we run the `./gravity upgrade --manual` command.

```
ubuntu@node-1:~/v2$ sudo ./gravity upgrade --manual
Thu Mar  4 04:09:57 UTC Upgrading cluster from 1.0.0 to 2.0.0
Thu Mar  4 04:10:09 UTC Deploying agents on cluster nodes
Deployed agent on node-3 (10.138.0.8)
Deployed agent on node-1 (10.138.0.6)
Deployed agent on node-2 (10.138.0.15)
The operation 099bdfa1-883a-43d5-a286-5fc983a835ac has been created in manual mode.

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
ubuntu@node-1:~/v2$ sudo systemctl status gravity-agent
● gravity-agent.service - Auto-generated service for the gravity-agent.service
   Loaded: loaded (/etc/systemd/system/gravity-agent.service; enabled; vendor preset: enabled)
   Active: active (running) since Thu 2021-03-04 04:10:11 UTC; 1min 4s ago
 Main PID: 24861 (gravity-upgrade)
    Tasks: 12
   Memory: 19.0M
      CPU: 7.439s
   CGroup: /system.slice/gravity-agent.service
           └─24861 /usr/local/bin/gravity-upgrade-agent --debug agent run sync-plan

Mar 04 04:10:11 node-1 systemd[1]: Started Auto-generated service for the gravity-agent.service.
Mar 04 04:10:11 node-1 gravity-cli[24861]: [RUNNING]: /usr/local/bin/gravity-upgrade-agent agent run --debug "sync-plan"
```

And we have the latest version of the gravity binary available on each node.
```
ubuntu@node-1:~/v2$ /var/lib/gravity/site/update/agent/gravity version
Edition:        enterprise
Version:        7.0.30
Git Commit:     b8214a8ce8aa5d173395f039ca63dcd219b2a760
Helm Version:   v2.15
```

Althogh the default gravity binary in the path remains the old version
until later in the upgrade process:

```
ubuntu@node-1:~/v2$ gravity version
Edition:        enterprise
Version:        7.0.12
Git Commit:     8a1dbd9c0cfa4ae4ce11a63e3b4a8d6c7b9226e7
Helm Version:   v2.15
```

### Stopping and Restarting the agents

While the agents should start and shutdown automatically by the upgrade, sometimes unexpected factors will cause the agents to not be running.
So the agents can be stopped and started as required.

Stop the agent:
```
ubuntu@node-1:~/v2$ sudo gravity agent shutdown
Thu Mar  4 04:13:48 UTC Shutting down the agents
```

Start the agents:
```
ubuntu@node-1:~/v2$ sudo gravity agent deploy
Thu Mar  4 04:13:55 UTC Deploying agents on the cluster nodes
Deployed agent on node-2 (10.138.0.15)
Deployed agent on node-3 (10.138.0.8)
Deployed agent on node-1 (10.138.0.6)
```

### Plans
Gravity uses a planning system to break up an upgrade into separate small steps to be executed.
These "phases" of the upgrade perform separate and individual actions to make progress on the upgrade.
The planning system creates the plan for the upgrade when the upgrade is triggered, inspecting the current state of the system,
and only includes the steps necessary to get the cluster to the latest version.

For example, if planet is already the latest version, none of the steps to rolling restart planet on the latest version will be included in the plan. It's not needed, as planet is already at the desired version.

We can view and interact with the plan using `gravity plan`.

```
ubuntu@node-1:~/v2$ sudo ./gravity plan
Phase                         Description                                             State         Node            Requires                                Updated
-----                         -----------                                             -----         ----            --------                                -------
* init                        Initialize update operation                             Unstarted     -               -                                       -
  * node-1                    Initialize node "node-1"                                Unstarted     10.138.0.6      -                                       -
  * node-2                    Initialize node "node-2"                                Unstarted     10.138.0.15     -                                       -
  * node-3                    Initialize node "node-3"                                Unstarted     10.138.0.8      -                                       -
* checks                      Run preflight checks                                    Unstarted     -               /init                                   -
* pre-update                  Run pre-update application hook                         Unstarted     -               /init,/checks                           -
* bootstrap                   Bootstrap update operation on nodes                     Unstarted     -               /checks,/pre-update                     -
  * node-1                    Bootstrap node "node-1"                                 Unstarted     10.138.0.6      -                                       -
  * node-2                    Bootstrap node "node-2"                                 Unstarted     10.138.0.15     -                                       -
  * node-3                    Bootstrap node "node-3"                                 Unstarted     10.138.0.8      -                                       -
* coredns                     Provision CoreDNS resources                             Unstarted     -               /bootstrap                              -
* masters                     Update master nodes                                     Unstarted     -               /coredns                                -
  * node-1                    Update system software on master node "node-1"          Unstarted     -               -                                       -
    * kubelet-permissions     Add permissions to kubelet on "node-1"                  Unstarted     -               -                                       -
    * stepdown                Step down "node-1" as Kubernetes leader                 Unstarted     -               /masters/node-1/kubelet-permissions     -
    * drain                   Drain node "node-1"                                     Unstarted     10.138.0.6      /masters/node-1/stepdown                -
    * system-upgrade          Update system software on node "node-1"                 Unstarted     10.138.0.6      /masters/node-1/drain                   -
    * elect                   Make node "node-1" Kubernetes leader                    Unstarted     -               /masters/node-1/system-upgrade          -
    * health                  Health check node "node-1"                              Unstarted     -               /masters/node-1/elect                   -
    * taint                   Taint node "node-1"                                     Unstarted     10.138.0.6      /masters/node-1/health                  -
    * uncordon                Uncordon node "node-1"                                  Unstarted     10.138.0.6      /masters/node-1/taint                   -
    * untaint                 Remove taint from node "node-1"                         Unstarted     10.138.0.6      /masters/node-1/uncordon                -
  * node-2                    Update system software on master node "node-2"          Unstarted     -               /masters/node-1                         -
    * drain                   Drain node "node-2"                                     Unstarted     10.138.0.6      -                                       -
    * system-upgrade          Update system software on node "node-2"                 Unstarted     10.138.0.15     /masters/node-2/drain                   -
    * elect                   Enable leader election on node "node-2"                 Unstarted     -               /masters/node-2/system-upgrade          -
    * health                  Health check node "node-2"                              Unstarted     -               /masters/node-2/elect                   -
    * taint                   Taint node "node-2"                                     Unstarted     10.138.0.6      /masters/node-2/health                  -
    * uncordon                Uncordon node "node-2"                                  Unstarted     10.138.0.6      /masters/node-2/taint                   -
    * endpoints               Wait for DNS/cluster endpoints on "node-2"              Unstarted     10.138.0.6      /masters/node-2/uncordon                -
    * untaint                 Remove taint from node "node-2"                         Unstarted     10.138.0.6      /masters/node-2/endpoints               -
  * node-3                    Update system software on master node "node-3"          Unstarted     -               /masters/node-2                         -
    * drain                   Drain node "node-3"                                     Unstarted     10.138.0.6      -                                       -
    * system-upgrade          Update system software on node "node-3"                 Unstarted     10.138.0.8      /masters/node-3/drain                   -
    * elect                   Enable leader election on node "node-3"                 Unstarted     -               /masters/node-3/system-upgrade          -
    * health                  Health check node "node-3"                              Unstarted     -               /masters/node-3/elect                   -
    * taint                   Taint node "node-3"                                     Unstarted     10.138.0.6      /masters/node-3/health                  -
    * uncordon                Uncordon node "node-3"                                  Unstarted     10.138.0.6      /masters/node-3/taint                   -
    * endpoints               Wait for DNS/cluster endpoints on "node-3"              Unstarted     10.138.0.6      /masters/node-3/uncordon                -
    * untaint                 Remove taint from node "node-3"                         Unstarted     10.138.0.6      /masters/node-3/endpoints               -
* config                      Update system configuration on nodes                    Unstarted     -               /masters                                -
  * node-1                    Update system configuration on node "node-1"            Unstarted     -               -                                       -
  * node-2                    Update system configuration on node "node-2"            Unstarted     -               -                                       -
  * node-3                    Update system configuration on node "node-3"            Unstarted     -               -                                       -
* runtime                     Update application runtime                              Unstarted     -               /config                                 -
  * rbac-app                  Update system application "rbac-app" to 7.0.30          Unstarted     -               -                                       -
  * dns-app                   Update system application "dns-app" to 7.0.3            Unstarted     -               /runtime/rbac-app                       -
  * logging-app               Update system application "logging-app" to 6.0.8        Unstarted     -               /runtime/dns-app                        -
  * monitoring-app            Update system application "monitoring-app" to 7.0.8     Unstarted     -               /runtime/logging-app                    -
  * tiller-app                Update system application "tiller-app" to 7.0.2         Unstarted     -               /runtime/monitoring-app                 -
  * site                      Update system application "site" to 7.0.30              Unstarted     -               /runtime/tiller-app                     -
  * kubernetes                Update system application "kubernetes" to 7.0.30        Unstarted     -               /runtime/site                           -
* migration                   Perform system database migration                       Unstarted     -               /runtime                                -
  * labels                    Update node labels                                      Unstarted     -               -                                       -
* app                         Update installed application                            Unstarted     -               /migration                              -
  * upgrade-demo              Update application "upgrade-demo" to 2.0.0              Unstarted     -               -                                       -
* gc                          Run cleanup tasks                                       Unstarted     -               /app                                    -
  * node-1                    Clean up node "node-1"                                  Unstarted     -               -                                       -
  * node-2                    Clean up node "node-2"                                  Unstarted     -               -                                       -
  * node-3                    Clean up node "node-3"                                  Unstarted     -               -                                       -
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
ubuntu@node-1:~/v2$ sudo ./gravity plan
Phase                         Description                                             State         Node            Requires                                Updated
-----                         -----------                                             -----         ----            --------                                -------
...
* masters                     Update master nodes                                     Unstarted     -               /coredns                                -
  * node-1                    Update system software on master node "node-1"          Unstarted     -               -                                       -
    * kubelet-permissions     Add permissions to kubelet on "node-1"                  Unstarted     -               -                                       -
    * stepdown                Step down "node-1" as Kubernetes leader                 Unstarted     -               /masters/node-1/kubelet-permissions     -
    * drain                   Drain node "node-1"                                     Unstarted     10.138.0.6      /masters/node-1/stepdown                -
    * system-upgrade          Update system software on node "node-1"                 Unstarted     10.138.0.6      /masters/node-1/drain                   -
    * elect                   Make node "node-1" Kubernetes leader                    Unstarted     -               /masters/node-1/system-upgrade          -
    * health                  Health check node "node-1"                              Unstarted     -               /masters/node-1/elect                   -
    * taint                   Taint node "node-1"                                     Unstarted     10.138.0.6      /masters/node-1/health                  -
    * uncordon                Uncordon node "node-1"                                  Unstarted     10.138.0.6      /masters/node-1/taint                   -
    * untaint                 Remove taint from node "node-1"                         Unstarted     10.138.0.6      /masters/node-1/uncordon                -
...
```

To manually run the `drain` phase on node `node-1` we build a path of `/masters/node-1/drain`

### Continuing our Manual Upgrade

#### Init
The first step in the upgrade process, is we initialize and prepare each node to accept the upgrade.

```
ubuntu@node-1:~/v2$ sudo ./gravity plan execute --phase /init/node-1
Executing "/init/node-1" locally
Executing phase "/init/node-1" finished in 3 seconds
```

The init phase:
- Removes update directories left over from previous upgrades if present
- Creates an admin agent user if this cluster doesn't have one (upgrades from old gravity versions)
- Creates the Default Service User on host if needed and not overriden by the installer
- Updates RPC Credentials (The credentials used to coordinate the upgrade)
- Updates any cluster roles that are changing with the new version
- Updates DNS parameters used internally within gravity
- Updated Docker configuration within the cluster

For more debug information about what was run during this (or any phase),
see `/var/log/gravity-system.log`:

```
ubuntu@node-1:~/v2$ cat /var/log/gravity-system.log
...
2021-03-04T04:51:37Z INFO [CLI]       Start. args:[./gravity plan execute --phase /init/node-1] utils/logging.go:103
2021-03-04T04:51:38Z INFO             2021/03/04 04:51:38 [INFO] generate received request utils/logging.go:103
2021-03-04T04:51:38Z INFO             2021/03/04 04:51:38 [INFO] received CSR utils/logging.go:103
2021-03-04T04:51:38Z INFO             2021/03/04 04:51:38 [INFO] generating key: rsa-2048 utils/logging.go:103
2021-03-04T04:51:38Z INFO             2021/03/04 04:51:38 [INFO] encoded CSR utils/logging.go:103
2021-03-04T04:51:38Z INFO [CLIENT]    Connecting proxy=127.0.0.1:3023 login='root' method=0 utils/logging.go:103
2021-03-04T04:51:38Z INFO [CLIENT]    Successful auth with proxy 127.0.0.1:3023 utils/logging.go:103
2021-03-04T04:51:38Z INFO             2021/03/04 04:51:38 [INFO] generate received request utils/logging.go:103
2021-03-04T04:51:38Z INFO             2021/03/04 04:51:38 [INFO] received CSR utils/logging.go:103
2021-03-04T04:51:38Z INFO             2021/03/04 04:51:38 [INFO] generating key: rsa-2048 utils/logging.go:103
2021-03-04T04:51:38Z INFO             2021/03/04 04:51:38 [INFO] encoded CSR utils/logging.go:103
2021-03-04T04:51:38Z INFO [CLIENT]    Connecting proxy=127.0.0.1:3023 login='root' method=0 utils/logging.go:103
2021-03-04T04:51:38Z INFO [CLIENT]    Successful auth with proxy 127.0.0.1:3023 utils/logging.go:103
2021-03-04T04:51:40Z INFO             Executing phase: /init/node-1. phase:/init/node-1 utils/logging.go:103
2021-03-04T04:51:40Z INFO             Create admin agent user. phase:/init/node-1 utils/logging.go:103
2021-03-04T04:51:40Z INFO             Update RPC credentials phase:/init/node-1 utils/logging.go:103
2021-03-04T04:51:40Z INFO             Backup RPC credentials phase:/init/node-1 utils/logging.go:103
2021-03-04T04:51:40Z INFO             2021/03/04 04:51:40 [INFO] generate received request utils/logging.go:103
2021-03-04T04:51:40Z INFO             2021/03/04 04:51:40 [INFO] received CSR utils/logging.go:103
2021-03-04T04:51:40Z INFO             2021/03/04 04:51:40 [INFO] generating key: rsa-2048 utils/logging.go:103
2021-03-04T04:51:40Z INFO             2021/03/04 04:51:40 [INFO] encoded CSR utils/logging.go:103
2021-03-04T04:51:40Z INFO             2021/03/04 04:51:40 [INFO] signed certificate with serial number 208927082247322267715007484895749327046862382937 utils/logging.go:103
2021-03-04T04:51:40Z INFO             2021/03/04 04:51:40 [INFO] generate received request utils/logging.go:103
2021-03-04T04:51:40Z INFO             2021/03/04 04:51:40 [INFO] received CSR utils/logging.go:103
2021-03-04T04:51:40Z INFO             2021/03/04 04:51:40 [INFO] generating key: rsa-2048 utils/logging.go:103
2021-03-04T04:51:40Z INFO             2021/03/04 04:51:40 [INFO] encoded CSR utils/logging.go:103
2021-03-04T04:51:40Z INFO             2021/03/04 04:51:40 [INFO] signed certificate with serial number 322338163851067236898426558458578859688116279226 utils/logging.go:103
2021-03-04T04:51:40Z INFO             2021/03/04 04:51:40 [INFO] generate received request utils/logging.go:103
2021-03-04T04:51:40Z INFO             2021/03/04 04:51:40 [INFO] received CSR utils/logging.go:103
2021-03-04T04:51:40Z INFO             2021/03/04 04:51:40 [INFO] generating key: rsa-2048 utils/logging.go:103
2021-03-04T04:51:41Z INFO             2021/03/04 04:51:41 [INFO] encoded CSR utils/logging.go:103
2021-03-04T04:51:41Z INFO             2021/03/04 04:51:41 [INFO] signed certificate with serial number 383327443217842556441004513882442554321371673170 utils/logging.go:103
2021-03-04T04:51:41Z INFO             Update RPC credentials. package:gravitational.io/rpcagent-secrets:0.0.1 phase:/init/node-1 utils/logging.go:103
2021-03-04T04:51:41Z INFO             Update cluster roles. phase:/init/node-1 utils/logging.go:103
2021-03-04T04:51:41Z INFO             Update cluster DNS configuration. phase:/init/node-1 utils/logging.go:103
2021-03-04T04:51:41Z INFO             Update cluster-info config map. phase:/init/node-1 utils/logging.go:103
2021-03-04T04:51:41Z INFO             Config map cluster-info already exists. phase:/init/node-1 utils/logging.go:103
2021-03-04T04:51:41Z INFO             update package labels gravitational.io/planet:7.0.35-11706 (+map[installed:installed purpose:runtime] -[]) phase:/init/node-1 utils/logging.go:103
```

#### Rolling Back a Phase
Now that we've made some progress in our upgrade, if we encounter a problem, we can rollback our upgrade.

```
ubuntu@node-1:~/v2$ sudo ./gravity plan rollback --phase /init/node-1
Rolling back "/init/node-1" locally
Rolling back phase "/init/node-1" finished in 2 seconds
ubuntu@node-1:~/v2$ sudo gravity plan | head
Phase                         Description                                             State           Node            Requires                                Updated
-----                         -----------                                             -----           ----            --------                                -------
× init                        Initialize update operation                             Failed          -               -                                       Thu Mar  4 04:31 UTC
  ⤺ node-1                    Initialize node "node-1"                                Rolled Back     10.138.0.6      -                                       Thu Mar  4 04:31 UTC
  * node-2                    Initialize node "node-2"                                Unstarted       10.138.0.15     -                                       -
  * node-3                    Initialize node "node-3"                                Unstarted       10.138.0.8      -                                       -
* checks                      Run preflight checks                                    Unstarted       -               /init                                   -
* pre-update                  Run pre-update application hook                         Unstarted       -               /init,/checks                           -
* bootstrap                   Bootstrap update operation on nodes                     Unstarted       -               /checks,/pre-update                     -
  * node-1                    Bootstrap node "node-1"                                 Unstarted       10.138.0.6      -                                       -
```

#### Committing an Upgrade
Once all phases have been completed, or all phases have been rolled back, the upgrade needs to be committed / completed, in order to unlock the cluster. Use `gravity plan complete` to commit the upgrade.

```
ubuntu@node-1:~/v2$ sudo gravity status | head -12
Cluster name:           upgrade-demo
Cluster status:         updating
Cluster image:          upgrade-demo, version 1.0.0
Gravity version:        7.0.12 (client) / 7.0.12 (server)
Join token:             9db3ba257fb267c17b306a6657584dfa
Periodic updates:       Not Configured
Remote support:         Not Configured
Active operations:
    * Upgrade to version 2.0.0
      ID:       34b7c840-44ef-4e8d-ad1b-647d71244761
      Started:  Thu Mar  4 04:16 UTC (17 minutes ago)
      Use 'gravity plan --operation-id=34b7c840-44ef-4e8d-ad1b-647d71244761' to check operation status
ubuntu@node-1:~/v2$ sudo ./gravity plan complete
ubuntu@node-1:~/v2$ sudo gravity status | head -12
Cluster name:           upgrade-demo
Cluster status:         active
Cluster image:          upgrade-demo, version 1.0.0
Gravity version:        7.0.12 (client) / 7.0.12 (server)
Join token:             9db3ba257fb267c17b306a6657584dfa
Periodic updates:       Not Configured
Remote support:         Not Configured
Last completed operation:
    * Upgrade to version 2.0.0
      ID:       34b7c840-44ef-4e8d-ad1b-647d71244761
      Started:  Thu Mar  4 04:16 UTC (18 minutes ago)
      Failed:   Thu Mar  4 04:34 UTC (4 seconds ago)

```

Notice the cluster status moves from `updating` to `active` and the `Active operations:` section
dissappears upon plan completion.


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
ubuntu@node-1:~/v2$ sudo ./gravity plan | head
Phase                         Description                                             State         Node            Requires                                Updated
-----                         -----------                                             -----         ----            --------                                -------
* init                        Initialize update operation                             Unstarted     -               -                                       -
  * node-1                    Initialize node "node-1"                                Unstarted     10.138.0.6      -                                       -
  * node-2                    Initialize node "node-2"                                Unstarted     10.138.0.15     -                                       -
  * node-3                    Initialize node "node-3"                                Unstarted     10.138.0.8      -                                       -
* checks                      Run preflight checks                                    Unstarted     -               /init                                   -
* pre-update                  Run pre-update application hook                         Unstarted     -               /init,/checks                           -
* bootstrap                   Bootstrap update operation on nodes                     Unstarted     -               /checks,/pre-update                     -
  * node-1                    Bootstrap node "node-1"                                 Unstarted     10.138.0.6      -                                       -

```

In order to run all init phases, we can target the `/init` phase, and all subphases will be executed.


```
ubuntu@node-1:~/v2$ sudo ./gravity plan execute --phase /init
Executing "/init/node-1" locally
Executing "/init/node-2" on remote node node-2
Executing "/init/node-3" on remote node node-3
Executing phase "/init" finished in 10 seconds
```

Alternatively, we can run `./gravity plan execute --phase /` to run the entire upgrade through to completion or `./gravity plan resume`, which does the same thing.

#### Checks
The checks phase is used to check that the cluster meets any new requirements defined by the application.

```
ubuntu@node-1:~/v2$ sudo ./gravity plan execute --phase /checks
Executing "/checks" locally
Executing phase "/checks" finished in 4 seconds
```

We can see more about what exactly happened in `/var/log/gravity-system.log`:

```
ubuntu@node-1:~/v2$ cat /var/log/gravity-system.log
...
2021-03-04T04:57:10Z INFO [CLI]       Start. args:[./gravity plan execute --phase /checks] utils/logging.go:103
2021-03-04T04:57:10Z INFO             2021/03/04 04:57:10 [INFO] generate received request utils/logging.go:103
2021-03-04T04:57:10Z INFO             2021/03/04 04:57:10 [INFO] received CSR utils/logging.go:103
2021-03-04T04:57:10Z INFO             2021/03/04 04:57:10 [INFO] generating key: rsa-2048 utils/logging.go:103
2021-03-04T04:57:10Z INFO             2021/03/04 04:57:10 [INFO] encoded CSR utils/logging.go:103
2021-03-04T04:57:10Z INFO [CLIENT]    Connecting proxy=127.0.0.1:3023 login='root' method=0 utils/logging.go:103
2021-03-04T04:57:10Z INFO [CLIENT]    Successful auth with proxy 127.0.0.1:3023 utils/logging.go:103
2021-03-04T04:57:10Z INFO             2021/03/04 04:57:10 [INFO] generate received request utils/logging.go:103
2021-03-04T04:57:10Z INFO             2021/03/04 04:57:10 [INFO] received CSR utils/logging.go:103
2021-03-04T04:57:10Z INFO             2021/03/04 04:57:10 [INFO] generating key: rsa-2048 utils/logging.go:103
2021-03-04T04:57:10Z INFO             2021/03/04 04:57:10 [INFO] encoded CSR utils/logging.go:103
2021-03-04T04:57:10Z INFO [CLIENT]    Connecting proxy=127.0.0.1:3023 login='root' method=0 utils/logging.go:103
2021-03-04T04:57:10Z INFO [CLIENT]    Successful auth with proxy 127.0.0.1:3023 utils/logging.go:103
2021-03-04T04:57:12Z INFO             Executing phase: /checks. phase:/checks utils/logging.go:103
2021-03-04T04:57:12Z INFO             Executing preflight checks on Server(AdvertiseIP=10.138.0.6, Hostname=node-1, Role=node, ClusterRole=master), Server(AdvertiseIP=10.138.0.15, Hostname=node-2, Role=node, ClusterRole=master), Server(AdvertiseIP=10.138.0.8, Hostname=node-3, Role=node, ClusterRole=master). phase:/checks utils/logging.go:103
2021-03-04T04:57:12Z DEBU [RPCSERVER] Request received. args:[touch /tmp/tmpcheck.faac21e7-8367-452d-a1c5-1b15c19ccb20] request:Command utils/logging.go:103
2021-03-04T04:57:12Z DEBU [RPCSERVER] Command completed OK. args:[touch /tmp/tmpcheck.faac21e7-8367-452d-a1c5-1b15c19ccb20] request:Command utils/logging.go:103
2021-03-04T04:57:12Z DEBU [RPCSERVER] Request received. args:[rm /tmp/tmpcheck.faac21e7-8367-452d-a1c5-1b15c19ccb20] request:Command utils/logging.go:103
2021-03-04T04:57:12Z DEBU [RPCSERVER] Command completed OK. args:[rm /tmp/tmpcheck.faac21e7-8367-452d-a1c5-1b15c19ccb20] request:Command utils/logging.go:103
2021-03-04T04:57:12Z INFO [CHECKS]    Server "node-1" passed temp directory check: /tmp. utils/logging.go:103
2021-03-04T04:57:12Z DEBU [RPCSERVER] Request received. args:[dd if=/dev/zero of=/var/lib/gravity/testfile bs=100K count=1024 conv=fdatasync] request:Command utils/logging.go:103
2021-03-04T04:57:12Z DEBU [RPCSERVER] Command completed OK. args:[dd if=/dev/zero of=/var/lib/gravity/testfile bs=100K count=1024 conv=fdatasync] request:Command utils/logging.go:103
2021-03-04T04:57:12Z WARN [CHECKS:RE] "1024+0 records in\n1024+0 records out\n104857600 bytes (105 MB, 100 MiB) copied, 0.221969 s, 472 MB/s\n" CMD:dd#1 utils/logging.go:103
2021-03-04T04:57:12Z DEBU [RPCSERVER] Request received. args:[rm /var/lib/gravity/testfile] request:Command utils/logging.go:103
2021-03-04T04:57:12Z DEBU [RPCSERVER] Command completed OK. args:[rm /var/lib/gravity/testfile] request:Command utils/logging.go:103
2021-03-04T04:57:12Z DEBU [RPCSERVER] Request received. args:[dd if=/dev/zero of=/var/lib/gravity/testfile bs=100K count=1024 conv=fdatasync] request:Command utils/logging.go:103
2021-03-04T04:57:13Z DEBU [RPCSERVER] Command completed OK. args:[dd if=/dev/zero of=/var/lib/gravity/testfile bs=100K count=1024 conv=fdatasync] request:Command utils/logging.go:103
2021-03-04T04:57:13Z WARN [CHECKS:RE] "1024+0 records in\n1024+0 records out\n" CMD:dd#1 utils/logging.go:103
2021-03-04T04:57:13Z WARN [CHECKS:RE] "104857600 bytes (105 MB, 100 MiB) copied, 0.207898 s, 504 MB/s" CMD:dd#1 utils/logging.go:103
2021-03-04T04:57:13Z WARN [CHECKS:RE] "\n" CMD:dd#1 utils/logging.go:103
2021-03-04T04:57:13Z DEBU [RPCSERVER] Request received. args:[rm /var/lib/gravity/testfile] request:Command utils/logging.go:103
2021-03-04T04:57:13Z DEBU [RPCSERVER] Command completed OK. args:[rm /var/lib/gravity/testfile] request:Command utils/logging.go:103
2021-03-04T04:57:13Z DEBU [RPCSERVER] Request received. args:[dd if=/dev/zero of=/var/lib/gravity/testfile bs=100K count=1024 conv=fdatasync] request:Command utils/logging.go:103
2021-03-04T04:57:13Z DEBU [RPCSERVER] Command completed OK. args:[dd if=/dev/zero of=/var/lib/gravity/testfile bs=100K count=1024 conv=fdatasync] request:Command utils/logging.go:103
2021-03-04T04:57:13Z WARN [CHECKS:RE] "1024+0 records in\n1024+0 records out\n" CMD:dd#1 utils/logging.go:103
2021-03-04T04:57:13Z WARN [CHECKS:RE] "104857600 bytes (105 MB, 100 MiB) copied, 0.213613 s, 491 MB/s" CMD:dd#1 utils/logging.go:103
2021-03-04T04:57:13Z WARN [CHECKS:RE] "\n" CMD:dd#1 utils/logging.go:103
2021-03-04T04:57:13Z DEBU [RPCSERVER] Request received. args:[rm /var/lib/gravity/testfile] request:Command utils/logging.go:103
2021-03-04T04:57:13Z DEBU [RPCSERVER] Command completed OK. args:[rm /var/lib/gravity/testfile] request:Command utils/logging.go:103
2021-03-04T04:57:13Z INFO [CHECKS]    Server "node-1" passed disk I/O check on disk(path=/var/lib/gravity/testfile, rate=10MB/s): 504MB/s. utils/logging.go:103
2021-03-04T04:57:13Z INFO [CHECKS]    Server "node-2" passed temp directory check: /tmp. utils/logging.go:103
2021-03-04T04:57:13Z WARN [CHECKS:RE] "1024+0 records in\n1024+0 records out\n104857600 bytes (105 MB, 100 MiB) copied, 0.282961 s, 371 MB/s\n" CMD:dd#1 utils/logging.go:103
2021-03-04T04:57:13Z WARN [CHECKS:RE] "1024+0 records in\n1024+0 records out\n104857600 bytes (105 MB, 100 MiB) copied, 0.265159 s, 395 MB/s\n" CMD:dd#1 utils/logging.go:103
2021-03-04T04:57:14Z WARN [CHECKS:RE] "1024+0 records in\n1024+0 records out\n104857600 bytes (105 MB, 100 MiB) copied, 0.273963 s, 383 MB/s\n" CMD:dd#1 utils/logging.go:103
2021-03-04T04:57:14Z INFO [CHECKS]    Server "node-2" passed disk I/O check on disk(path=/var/lib/gravity/testfile, rate=10MB/s): 395MB/s. utils/logging.go:103
2021-03-04T04:57:14Z INFO [CHECKS]    Server "node-3" passed temp directory check: /tmp. utils/logging.go:103
2021-03-04T04:57:14Z WARN [CHECKS:RE] "1024+0 records in\n1024+0 records out\n104857600 bytes (105 MB, 100 MiB) copied, 0.20313 s, 516 MB/s\n" CMD:dd#1 utils/logging.go:103
2021-03-04T04:57:14Z WARN [CHECKS:RE] "1024+0 records in\n1024+0 records out\n104857600 bytes (105 MB, 100 MiB) copied, 0.192936 s, 543 MB/s\n" CMD:dd#1 utils/logging.go:103
2021-03-04T04:57:14Z WARN [CHECKS:RE] "1024+0 records in\n1024+0 records out\n" CMD:dd#1 utils/logging.go:103
2021-03-04T04:57:14Z WARN [CHECKS:RE] "104857600 bytes (105 MB, 100 MiB) copied, 0.194227 s, 540 MB/s\n" CMD:dd#1 utils/logging.go:103
2021-03-04T04:57:14Z INFO [CHECKS]    Server "node-3" passed disk I/O check on disk(path=/var/lib/gravity/testfile, rate=10MB/s): 543MB/s. utils/logging.go:103
2021-03-04T04:57:14Z INFO [CHECKS]    Servers [node-1/10.138.0.6 node-2/10.138.0.15 node-3/10.138.0.8] passed time drift check. utils/logging.go:103
2021-03-04T04:57:14Z INFO [CHECKS]    Ping pong request: map[]. utils/logging.go:103
2021-03-04T04:57:14Z INFO [CHECKS]    Empty ping pong request. utils/logging.go:103
```

Notes:
- Checks disk requirements
- Tests that temporary directories are writeable
- Checks server time drift
- Checks profile requirements against node profiles

#### Pre-update Hook
The pre-update hook is an application hook that runs indicating to the application that an upgrade is starting. This allows the application developers to make changes to the application while the upgrade is running, such as scaling down the cluster services.

```
ubuntu@node-1:~/v2$ sudo ./gravity plan execute --phase /pre-update
Executing "/pre-update" locally
Executing phase "/pre-update" finished in 2 seconds
```

#### Bootstrap
The bootstrap phase is used to do initial configuration on each node within the cluster, to prepare the nodes for the upgrade. None of the changes should impact the system, these are just the preparation steps.

```
ubuntu@node-1:~/v2$ sudo ./gravity plan | head -14
Phase                         Description                                             State         Node            Requires                                Updated
-----                         -----------                                             -----         ----            --------                                -------
✓ init                        Initialize update operation                             Completed     -               -                                       Thu Mar  4 04:56 UTC
  ✓ node-1                    Initialize node "node-1"                                Completed     10.138.0.6      -                                       Thu Mar  4 04:51 UTC
  ✓ node-2                    Initialize node "node-2"                                Completed     10.138.0.15     -                                       Thu Mar  4 04:56 UTC
  ✓ node-3                    Initialize node "node-3"                                Completed     10.138.0.8      -                                       Thu Mar  4 04:56 UTC
✓ checks                      Run preflight checks                                    Completed     -               /init                                   Thu Mar  4 04:57 UTC
✓ pre-update                  Run pre-update application hook                         Completed     -               /init,/checks                           Thu Mar  4 05:00 UTC
* bootstrap                   Bootstrap update operation on nodes                     Unstarted     -               /checks,/pre-update                     -
  * node-1                    Bootstrap node "node-1"                                 Unstarted     10.138.0.6      -                                       -
  * node-2                    Bootstrap node "node-2"                                 Unstarted     10.138.0.15     -                                       -
  * node-3                    Bootstrap node "node-3"                                 Unstarted     10.138.0.8      -                                       -
* coredns                     Provision CoreDNS resources                             Unstarted     -               /bootstrap                              -
* masters                     Update master nodes                                     Unstarted     -               /coredns                                -

```
ubuntu@node-1:~/v2$ sudo ./gravity plan execute --phase /bootstrap/node-1
Executing "/bootstrap/node-1" locally
        Still executing "/bootstrap/node-1" locally (10 seconds elapsed)
        Still executing "/bootstrap/node-1" locally (20 seconds elapsed)
Executing phase "/bootstrap/node-1" finished in 27 seconds
```

Notes:
1. Ensures required directories exist on the host, and chowns/chmods the package directories to the planet user
2. Persists some required configuration to the local node database, such as some DNS settings and the Node's advertise IP
3. Pulls packages that will be needed by the node, to the local package store
4. Updates the labeling in the local package store, to identify the packages

New packages will now be available on each node:
```
ubuntu@node-1:~/v2$ sudo ./gravity package list

[gravitational.io]
------------------

* gravitational.io/bandwagon:6.0.1 76MB
* gravitational.io/dns-app:0.4.1 70MB
* gravitational.io/fio:3.15.0 6.9MB
* gravitational.io/gravity:7.0.12 111MB installed:installed
* gravitational.io/gravity:7.0.30 112MB
* gravitational.io/kubernetes:7.0.12 5.6MB
* gravitational.io/logging-app:6.0.5 127MB
* gravitational.io/monitoring-app:7.0.2 346MB
* gravitational.io/planet:7.0.35-11706 515MB purpose:runtime,installed:installed
* gravitational.io/planet:7.0.56-11709 558MB purpose:runtime
* gravitational.io/rbac-app:7.0.12 5.6MB
* gravitational.io/site:7.0.12 84MB
* gravitational.io/storage-app:0.0.3 1.0GB
* gravitational.io/teleport:3.2.14 33MB installed:installed
* gravitational.io/teleport:3.2.16 33MB
* gravitational.io/tiller-app:7.0.1 34MB
* gravitational.io/upgrade-demo:1.0.0 13MB
* gravitational.io/web-assets:7.0.12 5.0MB

[upgrade-demo]
--------------

* upgrade-demo/cert-authority:0.0.1 12kB operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:ca
* upgrade-demo/planet-10.138.0.6-secrets:7.0.35-11706 71kB advertise-ip:10.138.0.6,installed:installed,operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:planet-secrets
* upgrade-demo/planet-10.138.0.6-secrets:7.0.56-11709+1614832578 70kB advertise-ip:10.138.0.6,operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:planet-secrets
* upgrade-demo/planet-config-1013806upgrade-demo:7.0.35-11706 4.6kB operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:planet-config,advertise-ip:10.138.0.6,config-package-for:gravitational.io/planet:0.0.0,installed:installed
* upgrade-demo/planet-config-1013806upgrade-demo:7.0.56-11709+1614832578 4.6kB config-package-for:gravitational.io/planet:0.0.0,operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:planet-config,advertise-ip:10.138.0.6
* upgrade-demo/site-export:0.0.1 262kB operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:export
* upgrade-demo/teleport-master-config-1013806upgrade-demo:3.2.14 4.1kB advertise-ip:10.138.0.6,operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:teleport-master-config
* upgrade-demo/teleport-node-config-1013806upgrade-demo:3.2.14 4.1kB config-package-for:gravitational.io/teleport:0.0.0,installed:installed,operation-id:4e00a1cc-7b0d-4bd2-b157-9a955de8b683,purpose:teleport-node-config,advertise-ip:10.138.0.6
* upgrade-demo/teleport-node-config-1013806upgrade-demo:3.2.16+1614832578 4.1kB advertise-ip:10.138.0.6,config-package-for:gravitational.io/teleport:0.0.0,operation-id:cae7b67a-4580-466a-a0be-3f9e75ea99c5,purpose:teleport-node-config
```

Bootstrap the rest of the nodes:
```
ubuntu@node-1:~/v2$ sudo ./gravity plan execute --phase /bootstrap
Executing "/bootstrap/node-2" on remote node node-2
Executing "/bootstrap/node-3" on remote node node-3
Executing phase "/bootstrap" finished in 19 seconds
```

#### CoreDNS
The CoreDNS phase configures the cluster DNS configuration within kubernetes.

```
ubuntu@node-1:~/v2$ sudo ./gravity plan
Phase                         Description                                             State         Node            Requires                                Updated
-----                         -----------                                             -----         ----            --------                                -------
...
✓ pre-update                  Run pre-update application hook                         Completed     -               /init,/checks                           Thu Mar  4 05:00 UTC
✓ bootstrap                   Bootstrap update operation on nodes                     Completed     -               /checks,/pre-update                     Thu Mar  4 05:07 UTC
  ✓ node-1                    Bootstrap node "node-1"                                 Completed     10.138.0.6      -                                       Thu Mar  4 05:04 UTC
  ✓ node-2                    Bootstrap node "node-2"                                 Completed     10.138.0.15     -                                       Thu Mar  4 05:07 UTC
  ✓ node-3                    Bootstrap node "node-3"                                 Completed     10.138.0.8      -                                       Thu Mar  4 05:07 UTC
* coredns                     Provision CoreDNS resources                             Unstarted     -               /bootstrap                              -
* masters                     Update master nodes                                     Unstarted     -               /coredns                                -
  * node-1                    Update system software on master node "node-1"          Unstarted     -               -                                       -
    * kubelet-permissions     Add permissions to kubelet on "node-1"                  Unstarted     -               -                                       -
    * stepdown                Step down "node-1" as Kubernetes leader                 Unstarted     -               /masters/node-1/kubelet-permissions     -
    * drain                   Drain node "node-1"                                     Unstarted     10.138.0.6      /masters/node-1/stepdown                -
    * system-upgrade          Update system software on node "node-1"                 Unstarted     10.138.0.6      /masters/node-1/drain                   -
    * elect                   Make node "node-1" Kubernetes leader                    Unstarted     -               /masters/node-1/system-upgrade          -
    * health                  Health check node "node-1"                              Unstarted     -               /masters/node-1/elect                   -
    * taint                   Taint node "node-1"                                     Unstarted     10.138.0.6      /masters/node-1/health                  -
    * uncordon                Uncordon node "node-1"                                  Unstarted     10.138.0.6      /masters/node-1/taint                   -
    * untaint                 Remove taint from node "node-1"                         Unstarted     10.138.0.6      /masters/node-1/uncordon                -
...
ubuntu@node-1:~/v2$ sudo ./gravity plan execute --phase /coredns
Executing "/coredns" locally
Executing phase "/coredns" finished in 2 seconds
```

Notes:
- If not already present (pre 5.5) creates the RBAC rules and configuration needed for CoreDNS
- Generates / Updates the corefile for coredns, with any new settings that may be required.


#### Node Upgrades (/masters and /workers)
The Masters and Workers groups of subphases are the steps needed to upgrade the planet container on each node in the cluster. This operates as a rolling upgrade strategy, where one node at a time is cordoned and drained, upgraded to the new version of planet, restarted, etc. Each node is done in sequence, so other than
moving software around the cluster the application and cluster largely remain online. This cluster has no workers, however workers have a subset of master phases, so we don't omit any important steps by ignoring them.

Note that not all masters have the same operations.  In particular, the current leader has an ajusted plan, which we'll touch on below.

```
ubuntu@node-1:~/v2$ sudo ./gravity plan
Phase                         Description                                             State         Node            Requires                                Updated
-----                         -----------                                             -----         ----            --------                                -------
...
✓ coredns                     Provision CoreDNS resources                             Completed     -               /bootstrap                              Thu Mar  4 05:09 UTC
* masters                     Update master nodes                                     Unstarted     -               /coredns                                -
  * node-1                    Update system software on master node "node-1"          Unstarted     -               -                                       -
    * kubelet-permissions     Add permissions to kubelet on "node-1"                  Unstarted     -               -                                       -
    * stepdown                Step down "node-1" as Kubernetes leader                 Unstarted     -               /masters/node-1/kubelet-permissions     -
    * drain                   Drain node "node-1"                                     Unstarted     10.138.0.6      /masters/node-1/stepdown                -
    * system-upgrade          Update system software on node "node-1"                 Unstarted     10.138.0.6      /masters/node-1/drain                   -
    * elect                   Make node "node-1" Kubernetes leader                    Unstarted     -               /masters/node-1/system-upgrade          -
    * health                  Health check node "node-1"                              Unstarted     -               /masters/node-1/elect                   -
    * taint                   Taint node "node-1"                                     Unstarted     10.138.0.6      /masters/node-1/health                  -
    * uncordon                Uncordon node "node-1"                                  Unstarted     10.138.0.6      /masters/node-1/taint                   -
    * untaint                 Remove taint from node "node-1"                         Unstarted     10.138.0.6      /masters/node-1/uncordon                -
  * node-2                    Update system software on master node "node-2"          Unstarted     -               /masters/node-1                         -
    * drain                   Drain node "node-2"                                     Unstarted     10.138.0.6      -                                       -
    * system-upgrade          Update system software on node "node-2"                 Unstarted     10.138.0.15     /masters/node-2/drain                   -
    * elect                   Enable leader election on node "node-2"                 Unstarted     -               /masters/node-2/system-upgrade          -
    * health                  Health check node "node-2"                              Unstarted     -               /masters/node-2/elect                   -
    * taint                   Taint node "node-2"                                     Unstarted     10.138.0.6      /masters/node-2/health                  -
    * uncordon                Uncordon node "node-2"                                  Unstarted     10.138.0.6      /masters/node-2/taint                   -
    * endpoints               Wait for DNS/cluster endpoints on "node-2"              Unstarted     10.138.0.6      /masters/node-2/uncordon                -
    * untaint                 Remove taint from node "node-2"                         Unstarted     10.138.0.6      /masters/node-2/endpoints               -
  * node-3                    Update system software on master node "node-3"          Unstarted     -               /masters/node-2                         -
    * drain                   Drain node "node-3"                                     Unstarted     10.138.0.6      -                                       -
    * system-upgrade          Update system software on node "node-3"                 Unstarted     10.138.0.8      /masters/node-3/drain                   -
    * elect                   Enable leader election on node "node-3"                 Unstarted     -               /masters/node-3/system-upgrade          -
    * health                  Health check node "node-3"                              Unstarted     -               /masters/node-3/elect                   -
    * taint                   Taint node "node-3"                                     Unstarted     10.138.0.6      /masters/node-3/health                  -
    * uncordon                Uncordon node "node-3"                                  Unstarted     10.138.0.6      /masters/node-3/taint                   -
    * endpoints               Wait for DNS/cluster endpoints on "node-3"              Unstarted     10.138.0.6      /masters/node-3/uncordon                -
    * untaint                 Remove taint from node "node-3"                         Unstarted     10.138.0.6      /masters/node-3/endpoints               -
* config                      Update system configuration on nodes                    Unstarted     -               /masters                                -
...
```

#### Nodes: Kubelet Permissions
Ensures kubelet RBAC permissions within kubernetes are up to date.

```
ubuntu@node-1:~/v2$ sudo ./gravity plan execute --phase /masters/node-1/kubelet-permissions
Executing "/masters/node-1/kubelet-permissions" locally
Executing phase "/masters/node-1/kubelet-permissions" finished in 2 seconds
```

When planet restarts in the `system-upgrade` phase, it will launch a new version of kubelet, which we want to ensure any new requirements are written to kubernetes.


#### Nodes: Stepdown (First masters only)
Makes sure the particular node is not elected leader of the cluster during the upgrade. Instead the node is removed from the election
pool while it is being disrupted, and is finally re-added later.

```
ubuntu@node-1:~/v2$ sudo ./gravity plan execute --phase /masters/node-1/stepdown
Executing "/masters/node-1/stepdown" locally
Executing phase "/masters/node-1/stepdown" finished in 2 seconds
```

#### Nodes: Drain
Drains the node of running pods, having kubernetes reschedule the application on other nodes within the cluster. This is equivelant to using kubectl to drain a node, where the node will be left in a SchedulingDisabled state.

```
ubuntu@node-1:~/v2$ sudo kubectl get nodes
NAME          STATUS   ROLES   AGE   VERSION
10.138.0.15   Ready    node    85m   v1.17.6
10.138.0.6    Ready    node    94m   v1.17.6
10.138.0.8    Ready    node    83m   v1.17.6
ubuntu@node-1:~/v2$ sudo ./gravity plan execute --phase /masters/node-1/drain
Executing "/masters/node-1/drain" locally
        Still executing "/masters/node-1/drain" locally (10 seconds elapsed)
        Still executing "/masters/node-1/drain" locally (20 seconds elapsed)
        Still executing "/masters/node-1/drain" locally (30 seconds elapsed)
Executing phase "/masters/node-1/drain" finished in 39 seconds
ubuntu@node-1:~/v2$ sudo kubectl get nodes
NAME          STATUS                     ROLES   AGE   VERSION
10.138.0.15   Ready                      node    87m   v1.17.6
10.138.0.6    Ready,SchedulingDisabled   node    95m   v1.17.6
10.138.0.8    Ready                      node    84m   v1.17.6

```

#### Nodes: System-upgrade
The System Upgrade phase is where we restart the planet container on the new version of kubernetes, and wait for the startup to be healthy. Failures at this phase can sometimes be triggered by planet services not starting, due to some unforseen system cause. So checking and walking through the health of planet services can be important here.
The changes to planet can most easily be seen in the kubernetes version (when it is updated). In this case, we go from 1.17.6 to 1.17.9 when planet is updated

First, some baseline information about kubernetes versions (within planet) and gravity on the system:
```
ubuntu@node-1:~/v2$ sudo ./gravity exec kubectl version
Client Version: version.Info{Major:"1", Minor:"17", GitVersion:"v1.17.6", GitCommit:"d32e40e20d167e103faf894261614c5b45c44198", GitTreeState:"clean", BuildDate:"2020-05-20T13:16:24Z", GoVersion:"go1.13.9", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"17", GitVersion:"v1.17.6", GitCommit:"d32e40e20d167e103faf894261614c5b45c44198", GitTreeState:"clean", BuildDate:"2020-05-20T13:08:34Z", GoVersion:"go1.13.9", Compiler:"gc", Platform:"linux/amd64"}
ubuntu@node-1:~/v2$ which gravity
/usr/bin/gravity
ubuntu@node-1:~/v2$ gravity version
Edition:        enterprise
Version:        7.0.30
Git Commit:     b8214a8ce8aa5d173395f039ca63dcd219b2a760
Helm Version:   v2.15
```

Next, the system upgrade:

```
ubuntu@node-1:~/v2$ sudo ./gravity plan execute --phase /masters/node-1/system-upgrade
Executing "/masters/node-1/system-upgrade" locally
        Still executing "/masters/node-1/system-upgrade" locally (10 seconds elapsed)
        Still executing "/masters/node-1/system-upgrade" locally (20 seconds elapsed)
binary package gravitational.io/gravity:7.0.30 installed in /usr/bin/gravity
        Still executing "/masters/node-1/system-upgrade" locally (30 seconds elapsed)
Executing phase "/masters/node-1/system-upgrade" finished in 31 seconds
```

We can see that kubernetes was upgraded within planet:

```
ubuntu@node-1:~/v2$ sudo ./gravity exec kubectl version
Client Version: version.Info{Major:"1", Minor:"17", GitVersion:"v1.17.9", GitCommit:"4fb7ed12476d57b8437ada90b4f93b17ffaeed99", GitTreeState:"clean", BuildDate:"2020-07-15T16:18:16Z", GoVersion:"go1.13.9", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"17", GitVersion:"v1.17.6", GitCommit:"d32e40e20d167e103faf894261614c5b45c44198", GitTreeState:"clean", BuildDate:"2020-05-20T13:08:34Z", GoVersion:"go1.13.9", Compiler:"gc", Platform:"linux/amd64"}
```

Note that the server version has not updated yet, because one of the other nodes is acting as the master while this one upgrades.
We also see the gravity binary in the system path is updated, which means subsequent steps (on the same node) no longer need to use `./gravity`

```
ubuntu@node-1:~/v2$ which gravity
/usr/bin/gravity
ubuntu@node-1:~/v2$ gravity version
Edition:        enterprise
Version:        7.0.30
Git Commit:     b8214a8ce8aa5d173395f039ca63dcd219b2a760
Helm Version:   v2.15
ubuntu@node-1:~/v2$ cd ..
```

#### Nodes: Elect (First Master)
After the first master node has been upgraded, the leader election is changed to only allow the upgraded node to take leadership. In effect, we force the first master to be upgraded to also be elected the planet leader, and remain on the latest version of kubernetes throughout the rest of the upgrade. As the masters are upgraded, they'll be re-added to the election process, to take over in the case of a failure.
We can see this because now the kubernetes server version will also return the new kubernets version.

```
ubuntu@node-1:~$ sudo gravity plan execute --phase /masters/node-1/elect
Executing "/masters/node-1/elect" locally
Executing phase "/masters/node-1/elect" finished in 2 seconds
ubuntu@node-1:~$ sudo ./gravity exec kubectl version
Client Version: version.Info{Major:"1", Minor:"17", GitVersion:"v1.17.9", GitCommit:"4fb7ed12476d57b8437ada90b4f93b17ffaeed99", GitTreeState:"clean", BuildDate:"2020-07-15T16:18:16Z", GoVersion:"go1.13.9", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"17", GitVersion:"v1.17.9", GitCommit:"4fb7ed12476d57b8437ada90b4f93b17ffaeed99", GitTreeState:"clean", BuildDate:"2020-07-15T16:10:45Z", GoVersion:"go1.13.9", Compiler:"gc", Platform:"linux/amd64"}
```

#### Nodes: Health
Wait for Sattelite health checks to return healthy. Upon startup, planet may take a couple moments to converge. We make sure this is the case before Uncordoning the node in kubernetes.

```
ubuntu@node-1:~$ sudo gravity plan execute --phase /masters/node-1/health
Executing "/masters/node-1/health" locally
Executing phase "/masters/node-1/health" finished in 2 seconds
```

#### Nodes: Taint
A Kubernetes Node Taint is added to the node prior to Uncordoning. This allows only the gravitational internal services to launch on the node before it's returned to service.

```
ubuntu@node-1:~$ sudo gravity plan execute --phase /masters/node-1/taint
Executing "/masters/node-1/taint" locally
Executing phase "/masters/node-1/taint" finished in 2 seconds
```

Check Taints:
```
ubuntu@node-1:~$ sudo kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
sudo kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
NAME          TAINTS
10.138.0.15   <none>
10.138.0.6    [map[effect:NoExecute key:gravitational.io/runlevel value:system] map[effect:NoSchedule key:node.kubernetes.io/unschedulable timeAdded:2021-03-04T05:22:47Z]]
10.138.0.8    <none>
```

#### Nodes: Uncordon
Removed the cordon setting on the node (reversing the `drain` phase), allowing the kubernetes scheduler to see the node as available to be scheduled to.

```
ubuntu@node-1:~$ sudo gravity plan execute --phase /masters/node-1/uncordon
Executing "/masters/node-1/uncordon" locally
Executing phase "/masters/node-1/uncordon" finished in 2 seconds
```

The node is no longer marked `SchedulingDisabled`.
```
ubuntu@node-1:~/v2$ sudo kubectl get nodes
NAME          STATUS   ROLES   AGE    VERSION
10.138.0.15   Ready    node    113m   v1.17.6
10.138.0.6    Ready    node    121m   v1.17.9
10.138.0.8    Ready    node    110m   v1.17.6
```

Gravity services tolerant to the taint applied earlier will begin scheduling on the node, giving them a chance to allocate resources before the node fills up.

#### Nodes: Untaint
Removes the node taint placed earlier, to open the node up for additional scheduling.

```
ubuntu@node-1:~$ sudo gravity plan execute --phase /masters/node-1/untaint
Executing "/masters/node-1/untaint" locally
Executing phase "/masters/node-1/untaint" finished in 2 seconds
```

The taint applied earlier is removed:

```
ubuntu@node-1:~$ sudo kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
NAME          TAINTS
10.138.0.15   <none>
10.138.0.6    <none>
10.138.0.8    <none>
```

This completes the first of the master nodes, which will lead the kubernetes cluster for the rest of the
upgrade.

```
ubuntu@node-1:~$ sudo gravity plan
Phase                         Description                                             State           Node            Requires                                Updated
-----                         -----------                                             -----           ----            --------                                -------
...
✓ coredns                     Provision CoreDNS resources                             Completed       -               /bootstrap                              Thu Mar  4 05:09 UTC
→ masters                     Update master nodes                                     In Progress     -               /coredns                                Thu Mar  4 05:53 UTC
  ✓ node-1                    Update system software on master node "node-1"          Completed       -               -                                       Thu Mar  4 05:53 UTC
    ✓ kubelet-permissions     Add permissions to kubelet on "node-1"                  Completed       -               -                                       Thu Mar  4 05:18 UTC
    ✓ stepdown                Step down "node-1" as Kubernetes leader                 Completed       -               /masters/node-1/kubelet-permissions     Thu Mar  4 05:19 UTC
    ✓ drain                   Drain node "node-1"                                     Completed       10.138.0.6      /masters/node-1/stepdown                Thu Mar  4 05:23 UTC
    ✓ system-upgrade          Update system software on node "node-1"                 Completed       10.138.0.6      /masters/node-1/drain                   Thu Mar  4 05:25 UTC
    ✓ elect                   Make node "node-1" Kubernetes leader                    Completed       -               /masters/node-1/system-upgrade          Thu Mar  4 05:29 UTC
    ✓ health                  Health check node "node-1"                              Completed       -               /masters/node-1/elect                   Thu Mar  4 05:34 UTC
    ✓ taint                   Taint node "node-1"                                     Completed       10.138.0.6      /masters/node-1/health                  Thu Mar  4 05:41 UTC
    ✓ uncordon                Uncordon node "node-1"                                  Completed       10.138.0.6      /masters/node-1/taint                   Thu Mar  4 05:52 UTC
    ✓ untaint                 Remove taint from node "node-1"                         Completed       10.138.0.6      /masters/node-1/uncordon                Thu Mar  4 05:53 UTC
  * node-2                    Update system software on master node "node-2"          Unstarted       -               /masters/node-1                         -
    * drain                   Drain node "node-2"                                     Unstarted       10.138.0.6      -                                       -
    * system-upgrade          Update system software on node "node-2"                 Unstarted       10.138.0.15     /masters/node-2/drain                   -
    * elect                   Enable leader election on node "node-2"                 Unstarted       -               /masters/node-2/system-upgrade          -
    * health                  Health check node "node-2"                              Unstarted       -               /masters/node-2/elect                   -
    * taint                   Taint node "node-2"                                     Unstarted       10.138.0.6      /masters/node-2/health                  -
    * uncordon                Uncordon node "node-2"                                  Unstarted       10.138.0.6      /masters/node-2/taint                   -
    * endpoints               Wait for DNS/cluster endpoints on "node-2"              Unstarted       10.138.0.6      /masters/node-2/uncordon                -
    * untaint                 Remove taint from node "node-2"                         Unstarted       10.138.0.6      /masters/node-2/endpoints               -
  * node-3                    Update system software on master node "node-3"          Unstarted       -               /masters/node-2                         -
    * drain                   Drain node "node-3"                                     Unstarted       10.138.0.6      -                                       -
    * system-upgrade          Update system software on node "node-3"                 Unstarted       10.138.0.8      /masters/node-3/drain                   -
    * elect                   Enable leader election on node "node-3"                 Unstarted       -               /masters/node-3/system-upgrade          -
    * health                  Health check node "node-3"                              Unstarted       -               /masters/node-3/elect                   -
    * taint                   Taint node "node-3"                                     Unstarted       10.138.0.6      /masters/node-3/health                  -
    * uncordon                Uncordon node "node-3"                                  Unstarted       10.138.0.6      /masters/node-3/taint                   -
    * endpoints               Wait for DNS/cluster endpoints on "node-3"              Unstarted       10.138.0.6      /masters/node-3/uncordon                -
    * untaint                 Remove taint from node "node-3"                         Unstarted       10.138.0.6      /masters/node-3/endpoints               -
* config                      Update system configuration on nodes                    Unstarted       -               /masters                                -
...
```

#### Complete the Masters
Complete upgrading the rest of the masters (in this case, the entire cluster). If you have workers, you'll also want to run the `/workers` phase.

```
ubuntu@node-1:~$ sudo gravity plan execute --phase /masters
Executing "/masters/node-2/drain" locally
        Still executing "/masters/node-2/drain" locally (10 seconds elapsed)
        Still executing "/masters/node-2/drain" locally (20 seconds elapsed)
        Still executing "/masters/node-2/drain" locally (30 seconds elapsed)
Executing "/masters/node-2/system-upgrade" on remote node node-2
        Still executing "/masters/node-2/system-upgrade" on remote node node-2 (10 seconds elapsed)
        Still executing "/masters/node-2/system-upgrade" on remote node node-2 (20 seconds elapsed)
        Still executing "/masters/node-2/system-upgrade" on remote node node-2 (30 seconds elapsed)
        Still executing "/masters/node-2/system-upgrade" on remote node node-2 (40 seconds elapsed)
Executing "/masters/node-2/elect" on remote node node-2
Executing "/masters/node-2/health" on remote node node-2
        Still executing "/masters/node-2/health" on remote node node-2 (10 seconds elapsed)
        Still executing "/masters/node-2/health" on remote node node-2 (20 seconds elapsed)
Executing "/masters/node-2/taint" locally
Executing "/masters/node-2/uncordon" locally
Executing "/masters/node-2/endpoints" locally
Executing "/masters/node-2/untaint" locally
Executing "/masters/node-3/drain" locally
        Still executing "/masters/node-3/drain" locally (10 seconds elapsed)
Executing "/masters/node-3/system-upgrade" on remote node node-3
        Still executing "/masters/node-3/system-upgrade" on remote node node-3 (10 seconds elapsed)
        Still executing "/masters/node-3/system-upgrade" on remote node node-3 (20 seconds elapsed)
        Still executing "/masters/node-3/system-upgrade" on remote node node-3 (30 seconds elapsed)
Executing "/masters/node-3/elect" on remote node node-3
Executing "/masters/node-3/health" on remote node node-3
        Still executing "/masters/node-3/health" on remote node node-3 (10 seconds elapsed)
        Still executing "/masters/node-3/health" on remote node node-3 (20 seconds elapsed)
Executing "/masters/node-3/taint" locally
Executing "/masters/node-3/uncordon" locally
Executing "/masters/node-3/endpoints" locally
Executing "/masters/node-3/untaint" locally
Executing phase "/masters" finished in 3 minutes
```

Wasn't that easier than running each step individually? All planet upgrades are now complete.

```
ubuntu@node-1:~$ sudo gravity plan
Phase                         Description                                             State         Node            Requires                                Updated
-----                         -----------                                             -----         ----            --------                                -------
...
✓ masters                     Update master nodes                                     Completed     -               /coredns                                Thu Mar  4 06:01 UTC
  ✓ node-1                    Update system software on master node "node-1"          Completed     -               -                                       Thu Mar  4 05:53 UTC
    ✓ kubelet-permissions     Add permissions to kubelet on "node-1"                  Completed     -               -                                       Thu Mar  4 05:18 UTC
    ✓ stepdown                Step down "node-1" as Kubernetes leader                 Completed     -               /masters/node-1/kubelet-permissions     Thu Mar  4 05:19 UTC
    ✓ drain                   Drain node "node-1"                                     Completed     10.138.0.6      /masters/node-1/stepdown                Thu Mar  4 05:23 UTC
    ✓ system-upgrade          Update system software on node "node-1"                 Completed     10.138.0.6      /masters/node-1/drain                   Thu Mar  4 05:25 UTC
    ✓ elect                   Make node "node-1" Kubernetes leader                    Completed     -               /masters/node-1/system-upgrade          Thu Mar  4 05:29 UTC
    ✓ health                  Health check node "node-1"                              Completed     -               /masters/node-1/elect                   Thu Mar  4 05:34 UTC
    ✓ taint                   Taint node "node-1"                                     Completed     10.138.0.6      /masters/node-1/health                  Thu Mar  4 05:41 UTC
    ✓ uncordon                Uncordon node "node-1"                                  Completed     10.138.0.6      /masters/node-1/taint                   Thu Mar  4 05:52 UTC
    ✓ untaint                 Remove taint from node "node-1"                         Completed     10.138.0.6      /masters/node-1/uncordon                Thu Mar  4 05:53 UTC
  ✓ node-2                    Update system software on master node "node-2"          Completed     -               /masters/node-1                         Thu Mar  4 06:00 UTC
    ✓ drain                   Drain node "node-2"                                     Completed     10.138.0.6      -                                       Thu Mar  4 05:59 UTC
    ✓ system-upgrade          Update system software on node "node-2"                 Completed     10.138.0.15     /masters/node-2/drain                   Thu Mar  4 05:59 UTC
    ✓ elect                   Enable leader election on node "node-2"                 Completed     -               /masters/node-2/system-upgrade          Thu Mar  4 05:59 UTC
    ✓ health                  Health check node "node-2"                              Completed     -               /masters/node-2/elect                   Thu Mar  4 06:00 UTC
    ✓ taint                   Taint node "node-2"                                     Completed     10.138.0.6      /masters/node-2/health                  Thu Mar  4 06:00 UTC
    ✓ uncordon                Uncordon node "node-2"                                  Completed     10.138.0.6      /masters/node-2/taint                   Thu Mar  4 06:00 UTC
    ✓ endpoints               Wait for DNS/cluster endpoints on "node-2"              Completed     10.138.0.6      /masters/node-2/uncordon                Thu Mar  4 06:00 UTC
    ✓ untaint                 Remove taint from node "node-2"                         Completed     10.138.0.6      /masters/node-2/endpoints               Thu Mar  4 06:00 UTC
  ✓ node-3                    Update system software on master node "node-3"          Completed     -               /masters/node-2                         Thu Mar  4 06:01 UTC
    ✓ drain                   Drain node "node-3"                                     Completed     10.138.0.6      -                                       Thu Mar  4 06:00 UTC
    ✓ system-upgrade          Update system software on node "node-3"                 Completed     10.138.0.8      /masters/node-3/drain                   Thu Mar  4 06:01 UTC
    ✓ elect                   Enable leader election on node "node-3"                 Completed     -               /masters/node-3/system-upgrade          Thu Mar  4 06:01 UTC
    ✓ health                  Health check node "node-3"                              Completed     -               /masters/node-3/elect                   Thu Mar  4 06:01 UTC
    ✓ taint                   Taint node "node-3"                                     Completed     10.138.0.6      /masters/node-3/health                  Thu Mar  4 06:01 UTC
    ✓ uncordon                Uncordon node "node-3"                                  Completed     10.138.0.6      /masters/node-3/taint                   Thu Mar  4 06:01 UTC
    ✓ endpoints               Wait for DNS/cluster endpoints on "node-3"              Completed     10.138.0.6      /masters/node-3/uncordon                Thu Mar  4 06:01 UTC
    ✓ untaint                 Remove taint from node "node-3"                         Completed     10.138.0.6      /masters/node-3/endpoints               Thu Mar  4 06:01 UTC
* config                      Update system configuration on nodes                    Unstarted     -               /masters                                -
  * node-1                    Update system configuration on node "node-1"            Unstarted     -               -                                       -
  * node-2                    Update system configuration on node "node-2"            Unstarted     -               -                                       -
  * node-3                    Update system configuration on node "node-3"            Unstarted     -               -                                       -
* runtime                     Update application runtime                              Unstarted     -               /config                                 -
...
```


#### Etcd (Skipped in this upgrade)
Many gravity versions also include an Etcd upgrade.  However 7.0.12 to 7.0.30 does not include this.  For an
in depth walk through, see the [5.x Upgrade Training](./upgrade-5.x.md)

#### System Configuration
The system configuration task is used to upgrade the teleport configuration on each node.

```
ubuntu@node-1:~$ sudo gravity plan execute --phase /config/node-1
Executing "/config/node-1" locally
Executing phase "/config/node-1" finished in 2 seconds
```

Run config on the rest of the nodes:
```
ubuntu@node-1:~$ sudo gravity plan execute --phase /config
Executing "/config/node-2" on remote node node-2
Executing "/config/node-3" on remote node node-3
Executing phase "/config" finished in 10 seconds
```

#### Runtime Applications
Gravity ships with a number of pre-configured "applications" which we refer to as runtime applications.
These runtime applications are internal applications that make up the cluster services that are part of gravity's offering.

As with other parts of the upgrade, we only make changes if the application has actually changed.

```
ubuntu@node-1:~$ sudo gravity plan
Phase                         Description                                             State         Node            Requires                                Updated
-----                         -----------                                             -----         ----            --------                                -------
...
✓ config                      Update system configuration on nodes                    Completed       -               /masters                                Thu Mar  4 06:14 UTC
  ✓ node-1                    Update system configuration on node "node-1"            Completed       -               -                                       Thu Mar  4 06:13 UTC
  ✓ node-2                    Update system configuration on node "node-2"            Completed       -               -                                       Thu Mar  4 06:14 UTC
  ✓ node-3                    Update system configuration on node "node-3"            Completed       -               -                                       Thu Mar  4 06:14 UTC
→ runtime                     Update application runtime                              In Progress     -               /config                                 Thu Mar  4 06:17 UTC
  * rbac-app                  Update system application "rbac-app" to 7.0.30          Unstarted       -               -                                       -
  * dns-app                   Update system application "dns-app" to 7.0.3            Unstarted       -               /runtime/rbac-app                       -
  * logging-app               Update system application "logging-app" to 6.0.8        Unstarted       -               /runtime/dns-app                        -
  * monitoring-app            Update system application "monitoring-app" to 7.0.8     Unstarted       -               /runtime/logging-app                    -
  * tiller-app                Update system application "tiller-app" to 7.0.2         Unstarted       -               /runtime/monitoring-app                 -
  * site                      Update system application "site" to 7.0.30              Unstarted       -               /runtime/tiller-app                     -
  * kubernetes                Update system application "kubernetes" to 7.0.30        Unstarted       -               /runtime/site                           -
* migration                   Perform system database migration                       Unstarted       -               /runtime                                -
  * labels                    Update node labels                                      Unstarted       -               -                                       -
* app                         Update installed application                            Unstarted       -               /migration                              -
  * upgrade-demo              Update application "upgrade-demo" to 2.0.0              Unstarted       -               -                                       -
* gc                          Run cleanup tasks                                       Unstarted       -               /app                                    -
  * node-1                    Clean up node "node-1"                                  Unstarted       -               -                                       -
  * node-2                    Clean up node "node-2"                                  Unstarted       -               -                                       -
  * node-3                    Clean up node "node-3"                                  Unstarted       -               -                                       -

```

In this particular demo, the following runtime applications are flagged to be updated:
- rbac-app: Our default rbac rules for the cluster as well as our services.
- dns-app: Our in cluster dns provider
- logging-app: The log collector and tools used by the cluster.
- monitoring-app: Our metrics stack
- tiller-app: The tiller server for helm 2.x
- site: The gravity-site UI and cluster controller
- kubernetes: Sort of a noop application

Let's see what updating a runtime application looks like. We'll move past rbac-app as it
does not have notable changes in this particular upgrade.

```
ubuntu@node-1:~$ sudo gravity plan execute --phase /runtime/rbac-app
Executing "/runtime/rbac-app" locally
Executing phase "/runtime/rbac-app" finished in 8 seconds
```

However the dns-app does have more interesting changes related to scaleabilty and duplication.  Before the phase:

```
ubuntu@node-1:~$ sudo kubectl get pods -n kube-system | grep dns
coredns-dl9g4                    1/1     Running   1          159m
coredns-gmj77                    1/1     Running   1          152m
coredns-q8lnf                    1/1     Running   1          149m
```

Running the update:

```
ubuntu@node-1:~$ sudo gravity plan execute --phase /runtime/dns-app
Executing "/runtime/dns-app" locally
        Still executing "/runtime/dns-app" locally (10 seconds elapsed)
        Still executing "/runtime/dns-app" locally (20 seconds elapsed)
        Still executing "/runtime/dns-app" locally (30 seconds elapsed)
Executing phase "/runtime/dns-app" finished in 37 seconds
```

Debug logs from `/var/log/gravity-system.log`:

```
2021-03-04T06:29:18Z INFO [CLI]       Start. args:[gravity plan execute --phase /runtime/dns-app] utils/logging.go:103
2021-03-04T06:29:19Z INFO             2021/03/04 06:29:19 [INFO] generate received request utils/logging.go:103
2021-03-04T06:29:19Z INFO             2021/03/04 06:29:19 [INFO] received CSR utils/logging.go:103
2021-03-04T06:29:19Z INFO             2021/03/04 06:29:19 [INFO] generating key: rsa-2048 utils/logging.go:103
2021-03-04T06:29:19Z INFO             2021/03/04 06:29:19 [INFO] encoded CSR utils/logging.go:103
2021-03-04T06:29:19Z INFO [CLIENT]    Connecting proxy=127.0.0.1:3023 login='root' method=0 utils/logging.go:103
2021-03-04T06:29:19Z INFO [CLIENT]    Successful auth with proxy 127.0.0.1:3023 utils/logging.go:103
2021-03-04T06:29:19Z INFO             2021/03/04 06:29:19 [INFO] generate received request utils/logging.go:103
2021-03-04T06:29:19Z INFO             2021/03/04 06:29:19 [INFO] received CSR utils/logging.go:103
2021-03-04T06:29:19Z INFO             2021/03/04 06:29:19 [INFO] generating key: rsa-2048 utils/logging.go:103
2021-03-04T06:29:19Z INFO             2021/03/04 06:29:19 [INFO] encoded CSR utils/logging.go:103
2021-03-04T06:29:19Z INFO [CLIENT]    Connecting proxy=127.0.0.1:3023 login='root' method=0 utils/logging.go:103
2021-03-04T06:29:19Z INFO [CLIENT]    Successful auth with proxy 127.0.0.1:3023 utils/logging.go:103
2021-03-04T06:29:21Z INFO             Executing phase: /runtime/dns-app. phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:21Z INFO             Execute gravitational.io/dns-app:7.0.3(update) hook. phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:21Z INFO             Created Pod "dns-app-update-fdef5e-szl8q" in namespace "kube-system". phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:21Z INFO             phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:21Z INFO             Container "hooks" created, current state is "waiting, reason PodInitializing". phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:21Z INFO             phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:33Z INFO             Pod "dns-app-update-fdef5e-szl8q" in namespace "kube-system", has changed state from "Pending" to "Running". phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:33Z INFO             Container "hooks" changed status from "waiting, reason PodInitializing" to "running". phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:33Z INFO             phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:33Z INFO             Assuming changeset from the environment: dns-703 phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:33Z INFO             Updating resources phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:33Z INFO             + echo Assuming changeset from the environment: dns-703 phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:33Z INFO             + [ update = update ] phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:33Z INFO             + echo Updating resources phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:33Z INFO             + rig upsert -f /var/lib/gravity/resources/dns.yaml phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:52Z INFO             changeset dns-703 updated  phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:52Z INFO             Deleting coredns daemonset that has been replaced by a deployment phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:52Z INFO             + echo Deleting coredns daemonset that has been replaced by a deployment phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:52Z INFO             + rig delete ds/coredns-worker --resource-namespace=kube-system --force phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:53Z INFO             changeset dns-703 updated  phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:53Z INFO             Checking status phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:53Z INFO             + echo Checking status phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:53Z INFO             + rig status dns-703 --retry-attempts=600 --retry-period=1s --debug phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:53Z INFO             2021-03-04T06:29:53Z DEBU             changeset init logrus/exported.go:77 phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:53Z INFO             2021-03-04T06:29:53Z INFO             found pod kube-system/coredns-8hqn7 on node 10.138.0.8 daemonset:kube-system/coredns rigging/utils.go:117 phase:/r
untime/dns-app utils/logging.go:103
2021-03-04T06:29:53Z INFO             2021-03-04T06:29:53Z INFO             found pod kube-system/coredns-kzbmj on node 10.138.0.6 daemonset:kube-system/coredns rigging/utils.go:117 phase:/r
untime/dns-app utils/logging.go:103
2021-03-04T06:29:53Z INFO             2021-03-04T06:29:53Z INFO             found pod kube-system/coredns-sm5l4 on node 10.138.0.15 daemonset:kube-system/coredns rigging/utils.go:117 phase:/
runtime/dns-app utils/logging.go:103
2021-03-04T06:29:53Z INFO             2021-03-04T06:29:53Z INFO             node 10.138.0.15: pod kube-system/coredns-sm5l4 is up and running daemonset:kube-system/coredns rigging/utils.go:1
99 phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:53Z INFO             2021-03-04T06:29:53Z INFO             "attempt 2, result: \nERROR REPORT:\nOriginal Error: *trace.CompareFailedError deployment kube-system/autoscaler-c
oredns-worker not successful: expected replicas: 1, available: 0\nStack Trace:\n\t/gopath/src/github.com/gravitational/rigging/deployment.go:168 github.com/gravitational/rigging.(*Deployment
Control).Status\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:541 github.com/gravitational/rigging.(*Changeset).statusDeployment\n\t/gopath/src/github.com/gravitational/riggin
g/changeset.go:399 github.com/gravitational/rigging.(*Changeset).status\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:242 github.com/gravitational/rigging.(*Changeset).Status.
func1\n\t/gopath/src/github.com/gravitational/rigging/utils.go:128 github.com/gravitational/rigging.retry\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:235 github.com/gravitat
ional/rigging.(*Changeset).Status\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:292 main.status\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:124 main.r
un\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:31 main.main\n\t/go/src/runtime/proc.go:209 runtime.main\n\t/go/src/runtime/asm_amd64.s:1338 runtime.goexit\nUser Message:
 deployment kube-system/autoscaler-coredns-worker not successful: expected replicas: 1, available: 0\n, retry in 1s" logrus/exported.go:127 phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:54Z INFO             2021-03-04T06:29:54Z INFO             found pod kube-system/coredns-8hqn7 on node 10.138.0.8 daemonset:kube-system/coredns rigging/utils.go:117 phase:/r
untime/dns-app utils/logging.go:103
2021-03-04T06:29:55Z INFO             2021-03-04T06:29:54Z INFO             found pod kube-system/coredns-kzbmj on node 10.138.0.6 daemonset:kube-system/coredns rigging/utils.go:117 phase:/r
untime/dns-app utils/logging.go:103
2021-03-04T06:29:55Z INFO             2021-03-04T06:29:54Z INFO             found pod kube-system/coredns-sm5l4 on node 10.138.0.15 daemonset:kube-system/coredns rigging/utils.go:117 phase:/
runtime/dns-app utils/logging.go:103
2021-03-04T06:29:55Z INFO             2021-03-04T06:29:55Z INFO             node 10.138.0.15: pod kube-system/coredns-sm5l4 is up and running daemonset:kube-system/coredns rigging/utils.go:1
99 phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:55Z INFO             2021-03-04T06:29:55Z INFO             "attempt 3, result: \nERROR REPORT:\nOriginal Error: *trace.CompareFailedError deployment kube-system/autoscaler-c
oredns-worker not successful: expected replicas: 1, available: 0\nStack Trace:\n\t/gopath/src/github.com/gravitational/rigging/deployment.go:168 github.com/gravitational/rigging.(*Deployment
Control).Status\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:541 github.com/gravitational/rigging.(*Changeset).statusDeployment\n\t/gopath/src/github.com/gravitational/riggin
g/changeset.go:399 github.com/gravitational/rigging.(*Changeset).status\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:242 github.com/gravitational/rigging.(*Changeset).Status.
func1\n\t/gopath/src/github.com/gravitational/rigging/utils.go:137 github.com/gravitational/rigging.retry\n\t/gopath/src/github.com/gravitational/rigging/changeset.go:235 github.com/gravitat
ional/rigging.(*Changeset).Status\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:292 main.status\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:124 main.r
un\n\t/gopath/src/github.com/gravitational/rigging/tool/rig/main.go:31 main.main\n\t/go/src/runtime/proc.go:209 runtime.main\n\t/go/src/runtime/asm_amd64.s:1338 runtime.goexit\nUser Message:
 deployment kube-system/autoscaler-coredns-worker not successful: expected replicas: 1, available: 0\n, retry in 1s" logrus/exported.go:127 phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:56Z INFO             2021-03-04T06:29:56Z INFO             found pod kube-system/coredns-8hqn7 on node 10.138.0.8 daemonset:kube-system/coredns rigging/utils.go:117 phase:/r
untime/dns-app utils/logging.go:103
2021-03-04T06:29:56Z INFO             2021-03-04T06:29:56Z INFO             found pod kube-system/coredns-kzbmj on node 10.138.0.6 daemonset:kube-system/coredns rigging/utils.go:117 phase:/r
untime/dns-app utils/logging.go:103
2021-03-04T06:29:56Z INFO             2021-03-04T06:29:56Z INFO             found pod kube-system/coredns-sm5l4 on node 10.138.0.15 daemonset:kube-system/coredns rigging/utils.go:117 phase:/
runtime/dns-app utils/logging.go:103
2021-03-04T06:29:56Z INFO             2021-03-04T06:29:56Z INFO             node 10.138.0.15: pod kube-system/coredns-sm5l4 is up and running daemonset:kube-system/coredns rigging/utils.go:1
99 phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:56Z INFO             no errors detected for dns-703 phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:56Z INFO             Freezing phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:56Z INFO             + echo Freezing phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:56Z INFO             + rig freeze phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:56Z INFO             changeset dns-703 frozen, no further modifications are allowed phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:56Z INFO             Pod "dns-app-update-fdef5e-szl8q" in namespace "kube-system", has changed state from "Running" to "Succeeded". phase:/runtime/dns-app utils/logging.go:1
03
2021-03-04T06:29:56Z INFO             Container "hooks" changed status from "running" to "terminated, exit code 0". phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:56Z INFO             phase:/runtime/dns-app utils/logging.go:103
2021-03-04T06:29:56Z INFO             Job "dns-app-update-fdef5e" in namespace "kube-system" has completed, 35 seconds elapsed. phase:/runtime/dns-app utils/logging.go:103
```

After the update we see all the pods have been redeployed, a competed pod from a gravity update hook (kubernetes Job), and a brand new autoscaler pod that governs how many copies of coredns are running on the cluster. This is important for very large >>100 node Gravity clusters.

```
ubuntu@node-1:~$ sudo kubectl get pods -n kube-system | grep dns
autoscaler-coredns-worker-6cfc5968c5-nbd89   1/1     Running     0          3m6s
coredns-8hqn7                                1/1     Running     0          3m13s
coredns-kzbmj                                1/1     Running     0          3m13s
coredns-sm5l4                                1/1     Running     0          3m13s
dns-app-update-fdef5e-szl8q                  0/1     Completed   0          3m37s
```

#### Complete the runtime applications
The other runtime application updates are all importatn improvements, however we need not examine each one, as they follow the pattern we saw with dns-app. Complete them as a block:

```
ubuntu@node-1:~$ sudo gravity plan execute --phase /runtime
Executing "/runtime/logging-app" locally
        Still executing "/runtime/logging-app" locally (10 seconds elapsed)
        Still executing "/runtime/logging-app" locally (20 seconds elapsed)
        Still executing "/runtime/logging-app" locally (30 seconds elapsed)
        Still executing "/runtime/logging-app" locally (40 seconds elapsed)
        Still executing "/runtime/logging-app" locally (50 seconds elapsed)
Executing "/runtime/monitoring-app" locally
        Still executing "/runtime/monitoring-app" locally (10 seconds elapsed)
        Still executing "/runtime/monitoring-app" locally (20 seconds elapsed)
        Still executing "/runtime/monitoring-app" locally (30 seconds elapsed)
        Still executing "/runtime/monitoring-app" locally (40 seconds elapsed)
        Still executing "/runtime/monitoring-app" locally (50 seconds elapsed)
        Still executing "/runtime/monitoring-app" locally (1 minute elapsed)
        Still executing "/runtime/monitoring-app" locally (1 minute elapsed)
        Still executing "/runtime/monitoring-app" locally (1 minute elapsed)
        Still executing "/runtime/monitoring-app" locally (1 minute elapsed)
        Still executing "/runtime/monitoring-app" locally (1 minute elapsed)
        Still executing "/runtime/monitoring-app" locally (1 minute elapsed)
Executing "/runtime/tiller-app" locally
Executing "/runtime/site" locally
        Still executing "/runtime/site" locally (10 seconds elapsed)
        Still executing "/runtime/site" locally (20 seconds elapsed)
        Still executing "/runtime/site" locally (30 seconds elapsed)
        Still executing "/runtime/site" locally (40 seconds elapsed)
        Still executing "/runtime/site" locally (50 seconds elapsed)
Executing "/runtime/kubernetes" locally
Executing phase "/runtime" finished in 3 minutes
```

Afterwards, we can see all pods in the `kube-system` and `monitoring` namespaces were updated
in the past 10 minutes and several recent update hook job pods are compete:

```
ubuntu@node-1:~$ sudo kubectl get pods -A
NAMESPACE     NAME                                         READY   STATUS      RESTARTS   AGE
default       alpine-b57b54cb7-cqnlx                       1/1     Running     0          42m
kube-system   autoscaler-coredns-worker-6cfc5968c5-nbd89   1/1     Running     0          11m
kube-system   coredns-8hqn7                                1/1     Running     0          11m
kube-system   coredns-kzbmj                                1/1     Running     0          11m
kube-system   coredns-sm5l4                                1/1     Running     0          11m
kube-system   dns-app-update-fdef5e-szl8q                  0/1     Completed   0          11m
kube-system   gravity-site-65cwf                           0/1     Running     0          2m6s
kube-system   gravity-site-8qbh5                           1/1     Running     0          2m6s
kube-system   gravity-site-mbzwm                           0/1     Running     0          2m6s
kube-system   log-collector-697ff45b79-9pb9c               1/1     Running     0          4m35s
kube-system   logging-app-update-01e7fc-wb4w2              0/1     Completed   0          5m22s
kube-system   lr-aggregator-667795d87d-8mh99               1/1     Running     0          4m35s
kube-system   lr-collector-jqjbs                           1/1     Running     0          4m34s
kube-system   lr-collector-xv52w                           1/1     Running     0          4m34s
kube-system   lr-collector-xvpfq                           1/1     Running     0          4m34s
kube-system   lr-forwarder-59469b9659-stxqv                1/1     Running     0          4m34s
kube-system   monitoring-app-update-9880da-68m6p           0/1     Completed   0          4m27s
kube-system   site-app-post-update-284ae8-gbm9p            0/1     Completed   0          2m
kube-system   site-app-update-1a76f0-67rmf                 0/1     Completed   0          2m27s
kube-system   tiller-app-update-4dabef-rh65k               0/1     Completed   0          2m34s
kube-system   tiller-deploy-868c4567c5-l9ppp               1/1     Running     0          2m29s
monitoring    alertmanager-main-0                          3/3     Running     0          2m20s
monitoring    alertmanager-main-1                          3/3     Running     0          2m37s
monitoring    autoscaler-b8f58f945-k4rlf                   1/1     Running     0          3m49s
monitoring    grafana-5745965859-684gr                     2/2     Running     0          3m53s
monitoring    kube-state-metrics-7dbf48bf4d-8kf86          3/3     Running     0          3m39s
monitoring    nethealth-knmbv                              1/1     Running     0          2m46s
monitoring    nethealth-v4sq2                              1/1     Running     0          2m46s
monitoring    nethealth-vlw4v                              1/1     Running     0          2m46s
monitoring    node-exporter-bw2l5                          2/2     Running     0          3m29s
monitoring    node-exporter-q5kwq                          2/2     Running     0          3m29s
monitoring    node-exporter-xw727                          2/2     Running     0          3m29s
monitoring    prometheus-adapter-866f77d9b7-ctnxr          1/1     Running     0          3m20s
monitoring    prometheus-k8s-0                             3/3     Running     1          3m12s
monitoring    prometheus-k8s-1                             3/3     Running     1          2m37s
monitoring    prometheus-operator-747944cdd-hcsvc          1/1     Running     0          4m6s
monitoring    watcher-56676986d9-tftmq                     1/1     Running     0          3m49s
```

And we're nearing completion of the upgrade plan:

```
ubuntu@node-1:~$ sudo gravity plan | head
Phase                         Description                                             State         Node            Requires                                Updated
-----                         -----------                                             -----         ----            --------                                -------
...
✓ runtime                     Update application runtime                              Completed     -               /config                                 Thu Mar  4 06:39 UTC
  ✓ rbac-app                  Update system application "rbac-app" to 7.0.30          Completed     -               -                                       Thu Mar  4 06:17 UTC
  ✓ dns-app                   Update system application "dns-app" to 7.0.3            Completed     -               /runtime/rbac-app                       Thu Mar  4 06:29 UTC
  ✓ logging-app               Update system application "logging-app" to 6.0.8        Completed     -               /runtime/dns-app                        Thu Mar  4 06:36 UTC
  ✓ monitoring-app            Update system application "monitoring-app" to 7.0.8     Completed     -               /runtime/logging-app                    Thu Mar  4 06:38 UTC
  ✓ tiller-app                Update system application "tiller-app" to 7.0.2         Completed     -               /runtime/monitoring-app                 Thu Mar  4 06:38 UTC
  ✓ site                      Update system application "site" to 7.0.30              Completed     -               /runtime/tiller-app                     Thu Mar  4 06:39 UTC
  ✓ kubernetes                Update system application "kubernetes" to 7.0.30        Completed     -               /runtime/site                           Thu Mar  4 06:39 UTC
* migration                   Perform system database migration                       Unstarted     -               /runtime                                -
  * labels                    Update node labels                                      Unstarted     -               -                                       -
* app                         Update installed application                            Unstarted     -               /migration                              -
  * upgrade-demo              Update application "upgrade-demo" to 2.0.0              Unstarted     -               -                                       -
* gc                          Run cleanup tasks                                       Unstarted     -               /app                                    -
  * node-1                    Clean up node "node-1"                                  Unstarted     -               -                                       -
  * node-2                    Clean up node "node-2"                                  Unstarted     -               -                                       -
  * node-3                    Clean up node "node-3"                                  Unstarted     -               -                                       -
```




### Migrations
The migrations phase and it's subphases are where we define internal state updates now that the runtime applications have been updated. In this particular example, the only migration that is part of the plan, is to re-apply the node labels from the application manifest, to ensure they're up to date with any changes.

```
ubuntu@node-1:~$ sudo gravity plan execute --phase /migration/labels
Executing "/migration/labels" locally
Executing phase "/migration/labels" finished in 3 seconds
```

### Application
Everything up until this point is to upgrading Gravity. But Gravity doesn't just ship patches for Gravity, it also ships updates for the application within Gravity.
The application steps trigger the hooks that un the application upgrade and post upgrade hooks, to work with the latest version.

In our manifests, we defined a migration from alpine:3.3 to apline 3.4. Here is the pre-upgrade state of the pod:

```
ubuntu@node-1:~$ sudo kubectl get pod | grep alpine
alpine-b57b54cb7-cqnlx   1/1     Running   0          50m
ubuntu@node-1:~$ sudo kubectl describe pod alpine-b57b54cb7-cqnlx | grep -i alpine:3..
    Image:         registry.local:5000/alpine:3.3
  Normal  Pulling    50m        kubelet, 10.138.0.6  Pulling image "registry.local:5000/alpine:3.3"
  Normal  Pulled     50m        kubelet, 10.138.0.6  Successfully pulled image "registry.local:5000/alpine:3.3"
```

Running the phase:

```
ubuntu@node-1:~$ sudo gravity plan execute --phase /app/upgrade-demo
Executing "/app/upgrade-demo" locally
Executing phase "/app/upgrade-demo" finished in 8 seconds
```

Afterwards:

```
ubuntu@node-1:~$ sudo kubectl get pod | grep alpine
alpine-6dbf9d475b-bgnjf   1/1     Running   0          22s
ubuntu@node-1:~$ sudo kubectl describe pod alpine-6dbf9d475b-bgnjf | grep -i alpine:3..
    Image:         registry.local:5000/alpine:3.4
  Normal  Pulling    36s        kubelet, 10.138.0.6  Pulling image "registry.local:5000/alpine:3.4"
  Normal  Pulled     36s        kubelet, 10.138.0.6  Successfully pulled image "registry.local:5000/alpine:3.4"
```

We can also see the manifest defined upgrade hook ran in the `kube-system` namespace:

```
ubuntu@node-1:~$ sudo kubectl get jobs -n kube-system | grep upgrade
upgrade-db6743                  1/1           6s         3m22s
```

Only one phase remains:

```
ubuntu@node-1:~$ sudo gravity plan | head
Phase                         Description                                             State         Node            Requires                                Updated
-----                         -----------                                             -----         ----            --------                                -------
...
✓ app                         Update installed application                            Completed     -               /migration                              Thu Mar  4 06:50 UTC
  ✓ upgrade-demo              Update application "upgrade-demo" to 2.0.0              Completed     -               -                                       Thu Mar  4 06:50 UTC
* gc                          Run cleanup tasks                                       Unstarted     -               /app                                    -
  * node-1                    Clean up node "node-1"                                  Unstarted     -               -                                       -
  * node-2                    Clean up node "node-2"                                  Unstarted     -               -                                       -
  * node-3                    Clean up node "node-3"                                  Unstarted     -               -                                       -
```

### Garbage Collection
The last step of the upgrade is to run "garbage collection", which is a cleanup of files and directories that are no longer needed by the cluster.

```
ubuntu@node-1:~$ sudo gravity plan execute --phase /gc/node-1
Executing "/gc/node-1" locally
Executing phase "/gc/node-1" finished in 3 seconds
ubuntu@node-1:~$ sudo gravity plan execute --phase /gc
Executing "/gc/node-2" on remote node node-2
Executing "/gc/node-3" on remote node node-3
Executing phase "/gc" finished in 11 seconds
```

All steps in the plan are now finished:

```
ubuntu@node-1:~$ sudo gravity plan                                                                                                                                                            
Phase                         Description                                             State         Node            Requires                                Updated                           
-----                         -----------                                             -----         ----            --------                                -------                           
✓ init                        Initialize update operation                             Completed     -               -                                       Thu Mar  4 04:56 UTC              
  ✓ node-1                    Initialize node "node-1"                                Completed     10.138.0.6      -                                       Thu Mar  4 04:51 UTC              
  ✓ node-2                    Initialize node "node-2"                                Completed     10.138.0.15     -                                       Thu Mar  4 04:56 UTC              
  ✓ node-3                    Initialize node "node-3"                                Completed     10.138.0.8      -                                       Thu Mar  4 04:56 UTC              
✓ checks                      Run preflight checks                                    Completed     -               /init                                   Thu Mar  4 04:57 UTC              
✓ pre-update                  Run pre-update application hook                         Completed     -               /init,/checks                           Thu Mar  4 05:00 UTC              
✓ bootstrap                   Bootstrap update operation on nodes                     Completed     -               /checks,/pre-update                     Thu Mar  4 05:07 UTC              
  ✓ node-1                    Bootstrap node "node-1"                                 Completed     10.138.0.6      -                                       Thu Mar  4 05:04 UTC              
  ✓ node-2                    Bootstrap node "node-2"                                 Completed     10.138.0.15     -                                       Thu Mar  4 05:07 UTC              
  ✓ node-3                    Bootstrap node "node-3"                                 Completed     10.138.0.8      -                                       Thu Mar  4 05:07 UTC              
✓ coredns                     Provision CoreDNS resources                             Completed     -               /bootstrap                              Thu Mar  4 05:09 UTC              
✓ masters                     Update master nodes                                     Completed     -               /coredns                                Thu Mar  4 06:01 UTC              
  ✓ node-1                    Update system software on master node "node-1"          Completed     -               -                                       Thu Mar  4 05:53 UTC              
    ✓ kubelet-permissions     Add permissions to kubelet on "node-1"                  Completed     -               -                                       Thu Mar  4 05:18 UTC
    ✓ stepdown                Step down "node-1" as Kubernetes leader                 Completed     -               /masters/node-1/kubelet-permissions     Thu Mar  4 05:19 UTC
    ✓ drain                   Drain node "node-1"                                     Completed     10.138.0.6      /masters/node-1/stepdown                Thu Mar  4 05:23 UTC
    ✓ system-upgrade          Update system software on node "node-1"                 Completed     10.138.0.6      /masters/node-1/drain                   Thu Mar  4 05:25 UTC
    ✓ elect                   Make node "node-1" Kubernetes leader                    Completed     -               /masters/node-1/system-upgrade          Thu Mar  4 05:29 UTC
    ✓ health                  Health check node "node-1"                              Completed     -               /masters/node-1/elect                   Thu Mar  4 05:34 UTC
    ✓ taint                   Taint node "node-1"                                     Completed     10.138.0.6      /masters/node-1/health                  Thu Mar  4 05:41 UTC
    ✓ uncordon                Uncordon node "node-1"                                  Completed     10.138.0.6      /masters/node-1/taint                   Thu Mar  4 05:52 UTC
    ✓ untaint                 Remove taint from node "node-1"                         Completed     10.138.0.6      /masters/node-1/uncordon                Thu Mar  4 05:53 UTC
  ✓ node-2                    Update system software on master node "node-2"          Completed     -               /masters/node-1                         Thu Mar  4 06:00 UTC
    ✓ drain                   Drain node "node-2"                                     Completed     10.138.0.6      -                                       Thu Mar  4 05:59 UTC
    ✓ system-upgrade          Update system software on node "node-2"                 Completed     10.138.0.15     /masters/node-2/drain                   Thu Mar  4 05:59 UTC
    ✓ elect                   Enable leader election on node "node-2"                 Completed     -               /masters/node-2/system-upgrade          Thu Mar  4 05:59 UTC
    ✓ health                  Health check node "node-2"                              Completed     -               /masters/node-2/elect                   Thu Mar  4 06:00 UTC
    ✓ taint                   Taint node "node-2"                                     Completed     10.138.0.6      /masters/node-2/health                  Thu Mar  4 06:00 UTC
    ✓ uncordon                Uncordon node "node-2"                                  Completed     10.138.0.6      /masters/node-2/taint                   Thu Mar  4 06:00 UTC
    ✓ endpoints               Wait for DNS/cluster endpoints on "node-2"              Completed     10.138.0.6      /masters/node-2/uncordon                Thu Mar  4 06:00 UTC
    ✓ untaint                 Remove taint from node "node-2"                         Completed     10.138.0.6      /masters/node-2/endpoints               Thu Mar  4 06:00 UTC
  ✓ node-3                    Update system software on master node "node-3"          Completed     -               /masters/node-2                         Thu Mar  4 06:01 UTC
    ✓ drain                   Drain node "node-3"                                     Completed     10.138.0.6      -                                       Thu Mar  4 06:00 UTC
    ✓ system-upgrade          Update system software on node "node-3"                 Completed     10.138.0.8      /masters/node-3/drain                   Thu Mar  4 06:01 UTC
    ✓ elect                   Enable leader election on node "node-3"                 Completed     -               /masters/node-3/system-upgrade          Thu Mar  4 06:01 UTC
    ✓ health                  Health check node "node-3"                              Completed     -               /masters/node-3/elect                   Thu Mar  4 06:01 UTC
    ✓ taint                   Taint node "node-3"                                     Completed     10.138.0.6      /masters/node-3/health                  Thu Mar  4 06:01 UTC
    ✓ uncordon                Uncordon node "node-3"                                  Completed     10.138.0.6      /masters/node-3/taint                   Thu Mar  4 06:01 UTC
    ✓ endpoints               Wait for DNS/cluster endpoints on "node-3"              Completed     10.138.0.6      /masters/node-3/uncordon                Thu Mar  4 06:01 UTC
    ✓ untaint                 Remove taint from node "node-3"                         Completed     10.138.0.6      /masters/node-3/endpoints               Thu Mar  4 06:01 UTC
✓ config                      Update system configuration on nodes                    Completed     -               /masters                                Thu Mar  4 06:14 UTC
  ✓ node-1                    Update system configuration on node "node-1"            Completed     -               -                                       Thu Mar  4 06:13 UTC
  ✓ node-2                    Update system configuration on node "node-2"            Completed     -               -                                       Thu Mar  4 06:14 UTC
  ✓ node-3                    Update system configuration on node "node-3"            Completed     -               -                                       Thu Mar  4 06:14 UTC
✓ runtime                     Update application runtime                              Completed     -               /config                                 Thu Mar  4 06:39 UTC
  ✓ rbac-app                  Update system application "rbac-app" to 7.0.30          Completed     -               -                                       Thu Mar  4 06:17 UTC
  ✓ dns-app                   Update system application "dns-app" to 7.0.3            Completed     -               /runtime/rbac-app                       Thu Mar  4 06:29 UTC
  ✓ logging-app               Update system application "logging-app" to 6.0.8        Completed     -               /runtime/dns-app                        Thu Mar  4 06:36 UTC
  ✓ monitoring-app            Update system application "monitoring-app" to 7.0.8     Completed     -               /runtime/logging-app                    Thu Mar  4 06:38 UTC
  ✓ tiller-app                Update system application "tiller-app" to 7.0.2         Completed     -               /runtime/monitoring-app                 Thu Mar  4 06:38 UTC
  ✓ site                      Update system application "site" to 7.0.30              Completed     -               /runtime/tiller-app                     Thu Mar  4 06:39 UTC
  ✓ kubernetes                Update system application "kubernetes" to 7.0.30        Completed     -               /runtime/site                           Thu Mar  4 06:39 UTC
✓ migration                   Perform system database migration                       Completed     -               /runtime                                Thu Mar  4 06:45 UTC
  ✓ labels                    Update node labels                                      Completed     -               -                                       Thu Mar  4 06:45 UTC
✓ app                         Update installed application                            Completed     -               /migration                              Thu Mar  4 06:50 UTC
  ✓ upgrade-demo              Update application "upgrade-demo" to 2.0.0              Completed     -               -                                       Thu Mar  4 06:50 UTC
✓ gc                          Run cleanup tasks                                       Completed     -               /app                                    Thu Mar  4 06:59 UTC
  ✓ node-1                    Clean up node "node-1"                                  Completed     -               -                                       Thu Mar  4 06:58 UTC
  ✓ node-2                    Clean up node "node-2"                                  Completed     -               -                                       Thu Mar  4 06:59 UTC
  ✓ node-3                    Clean up node "node-3"                                  Completed     -               -                                       Thu Mar  4 06:59 UTC
```

But the operation is not complete yet:

```
ubuntu@node-1:~$ sudo gravity status | head -13
Cluster name:           upgrade-demo
Cluster status:         updating
Cluster image:          upgrade-demo, version 1.0.0
Cloud provider:         onprem
Gravity version:        7.0.30 (client) / 7.0.30 (server)
Join token:             9db3ba257fb267c17b306a6657584dfa
Periodic updates:       Not Configured
Remote support:         Not Configured
Active operations:
    * Upgrade to version 2.0.0
      ID:       cae7b67a-4580-466a-a0be-3f9e75ea99c5
      Started:  Thu Mar  4 04:36 UTC (2 hours ago)
      Use 'gravity plan --operation-id=cae7b67a-4580-466a-a0be-3f9e75ea99c5' to check operation status
```

### Complete the Upgrade
To finish the upgrade (or install, join, or shrink) goverend by the gravity state machine, run the following:

```
ubuntu@node-1:~$ sudo gravity plan complete
ubuntu@node-1:~$ sudo gravity status | head -13
Cluster name:           upgrade-demo
Cluster status:         active
Cluster image:          upgrade-demo, version 2.0.0
Cloud provider:         onprem
Gravity version:        7.0.30 (client) / 7.0.30 (server)
Join token:             9db3ba257fb267c17b306a6657584dfa
Periodic updates:       Not Configured
Remote support:         Not Configured
Last completed operation:
    * Upgrade to version 2.0.0
      ID:               cae7b67a-4580-466a-a0be-3f9e75ea99c5
      Started:          Thu Mar  4 04:36 UTC (2 hours ago)
      Completed:        Thu Mar  4 07:03 UTC (2 seconds ago)
```

Now the upgrade is finalized.

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
