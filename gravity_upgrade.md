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

* another set of pre-upgrade checks was added to verify if any Teleport node is
  unavailable

* `gravity plan resume` now launches its execution in background by default,
  but a new `--block` option was added to resume in foreground and a different
  command `gravity plan --tail` was also introduced to track the plan progress

* it's possible to view/collect Gravity command line logs via `journalctl -t gravity-cli`

## Exploring a Gravity Manual Upgrade

## Upgrade Scenarios

In this section we will cover several Gravity upgrade scenarios. Using what you have learned in this workshop the goal will to be successfully complete an upgrade for each of the following scenarios.

### Upgrade Scenario 1:

### Upgrade Scenario 2:

### Upgrade Scenario 3:

### Upgrade Scenario 4:

### Upgrade Scenario 5:
