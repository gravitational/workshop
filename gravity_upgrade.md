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

In order to execute a manual upgrade the operation will be started by adding `--manual | -m flag` with the upgrade command:

`sudo ./gravity upgrade --manual`

To ensure version compatibility, all upgrade related commands (agent deployment, phase execution/rollback, etc.) need to be executed using the gravity binary included in the upgrade tarball.

A manual upgrade operation starts with an operation plan which is a tree of actions required to be performed in the specified order to achieve the goal of the upgrade. This concept of the operation exists in order to have sets of smaller steps during an upgrade which can be re-executed or rolled back. Again, more on this as we will step through this in more detail further into the workshop.

## Gravity Upgrade Status, Logs, and more



## Exploring a Gravity Manual Upgrade



## Upgrade Scenarios

In this section we will cover several Gravity upgrade scenarios. Using what you have learned in this workshop the goal will to be successfully complete an upgrade for each of the following scenarios. 

### Upgrade Scenario 1:

### Upgrade Scenario 2: 

### Upgrade Scenario 3:

### Upgrade Scenario 4:

### Upgrade Scenario 5:



