# Gravity Logging (for Gravity 5.5 and earlier)

## Prerequisites

Docker 101, Kubernetes 101, Gravity 101.

## Introduction

_Note: This part of the training pertains to Gravity 5.5 and earlier._

Gravity clusters come preconfigured with the logging infrastructure that collects the logs from all running containers, forwards them to a single destination and makes them available for viewing and querying via an API.

In Gravity 5.5 and earlier the logging stack is based on the rsyslog protocol and consists of two components: collector and forwarder.

## Pods / Containers Logs Locations

Before diving into Gravity’s logging infrastructure, let’s explore how it is set up in Kubernetes in general.

Kubernetes sets up symlinks in well-known locations for logs of all containers running in the cluster and groups them up in two directories on each node, by pod and by container. The directories where these logs go are `/var/log/pods` and `/var/log/containers` respectively.

Note that these directories reside inside the planet container, not on the host.

On each node, the logs of all containers running in the same pod will be grouped in that pod directory under `/var/log/pods`:

```bash
planet$ ls -l /var/log/pods/<pod-id>/
```

If we look at the logs of a particular container, we’ll see that these are in fact symlinks to the actual log files Docker keeps inside its data directory:

```bash
planet$ ls -l /var/log/pods/01146b3e-3709-11ea-b8d5-080027f6e425/init/
total 4
lrwxrwxrwx 1 root root 161 Jan 14 20:04 0.log -> /ext/docker/containers/236f...-json.log
```

In addition to `/var/log/pods`, Kubernetes also sets up a `/var/log/containers` directory which has a flat structure and the logs of all containers running on the node. The log files are also symlinks that point to the respective files in `/var/log/pods`:

```bash
planet$ ls -l /var/log/containers/
total 180
lrwxrwxrwx 1 root root 66 Jan 15 00:24 bandwagon-6c4b...-lqbll_kube-system_bandwagon-2641....log -> /var/log/pods/0b8e.../bandwagon/1.log
```

## Forwarder

Log forwarder runs on every node of the cluster as a part of a DaemonSet:

```bash
$ kubectl -nkube-system get ds,pods -lname=log-forwarder
```

This component uses [remote_syslog2](https://github.com/papertrail/remote_syslog2) to monitor files in the following directories:

* `/var/log/containers/*.log`

Like explained above, this directory contains logs for all containers running on the node.

* `/var/lib/gravity/site/**/*.log`

This directory contains Gravity-specific operation logs:

```bash
$ ls -l /var/lib/gravity/site/*/*.log
```

The forwarder Docker image and its configuration can be found [here](https://github.com/gravitational/logging-app/tree/version/5.5.x/images/forwarder).

## Collector

Log collector is an rsyslogd server that’s running as a part of a Deployment:

```bash
$ kubectl -nkube-system get deploy,pods -lrole=log-collector
```

The collector exposes rsyslog server via a Kubernetes Service where forwarders send entries from the files they monitor over tcp protocol:

```bash
$ kubectl -nkube-system get services/log-collector
NAME            TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)                    AGE
log-collector   ClusterIP   10.100.81.83   <none>        514/UDP,514/TCP,8083/TCP   6h54m
```

The collector itself writes all logs into `/var/log/messages` which is mounted into its pod so we can inspect all the logs on the node where the collector is running, inside the planet container:

```bash
planet$ less /var/log/messages
```

Keep in mind that since the collector runs on a single node at a time and writes to the local `/var/log/messages`, the logs may become scattered across multiple nodes if the pod gets rescheduled to another node.

The collector Docker image and its configuration can be found [here](https://github.com/gravitational/logging-app/tree/version/5.5.x/images/collector).

### wstail

In addition to running rsyslog daemon, the log collector container also runs a program called “wstail”. It adds the following functionality:

* Serves an HTTP API that allows to query all collected logs. The API is exposed via the same Kubernetes service and is used by Gravity Control Panel to provide search functionality.
* Is responsible for creating/deleting log forwarder configurations when they are created/deleted by users.

## Custom Log Forwarders

The rsyslog server that runs as a part of the log collector can be configured to ship logs to a remote destination, for example to another external rsyslog server for aggregation.

To support this scenario, Gravity exposes a resource called `LogForwarder`. Let’s create a log forwarder that will be forwarding the logs to some server running on our node:

```bash
$ cat <<EOF > logforwarder.yaml
kind: logforwarder
version: v2
metadata:
   name: forwarder1
spec:
   address: 192.168.99.102:514
   protocol: udp
EOF
$ gravity resource create logforwarder.yaml
```

To see all currently configured log forwarders we can use the resource get command:

```bash
$ gravity resource get logforwarders
Name           Address                Protocol
----           -------                --------
forwarder1     192.168.99.102:514     udp
```

When the resource is created, Gravity does the following to set up the forwarding.

The `kube-system/log-forwarders` config map is updated by Gravity with information about the newly created or updated forwarder:

```bash
$ kubectl -nkube-system get configmaps/log-forwarders -oyaml
```

Then it restarts the log-collector pod:

```bash
$ kubectl -nkube-system get pods -lrole=log-collector
NAME                            READY   STATUS    RESTARTS   AGE
log-collector-697d94486-2fgxp   1/1     Running   0          5s
```

Upon initialization, wstail process initializes the rsyslog daemon configuration based on the configured log forwarders and sets it up with the appropriate forwarding rules:

```bash
$ kubectl -nkube-system exec log-collector-697d94486-2fgxp -- ls -l /etc/rsyslog.d
total 4
-rw-r--r-- 1 root root 23 Jan 15 19:22 forwarder1
$ kubectl -nkube-system exec log-collector-697d94486-2fgxp -- cat /etc/rsyslog.d/forwarder1
*.* @192.168.99.102:514
```

From here on, the rsyslog server running inside the log collector pod will be forwarding all logs it receives to the configured destinations using the rsyslog protocol.

We can test this by capturing all traffic on this port using netcat:

```bash
$ sudo nc -4ulk 514
```

To deconfigure a log forwarder, we can just delete its Gravity resource and it will take care of updating the config map and rsyslog configuration:

```bash
$ gravity resource rm logforwarders forwarder1
```

## Troubleshooting

Gravity does not provide a built-in way to update the rsyslogd configuration other than configuring log forwarding, but it is possible to enable debug mode on it in order to be able to troubleshoot.

The rsyslog server supports reading debugging configuration from environment variables so in order to turn it on we can update the deployment specification:

```bash
$ EDITOR=nano kubectl -nkube-system edit deploy/log-collector
```

And add the following environment variables to the collector container:

```yaml
- env:
  - name: RSYSLOG_DEBUGLOG
    value: /var/log/rsyslog.txt
  - name: RSYSLOG_DEBUG
    value: Debug NoStdOut
```

Once the pod has restarted, the rsyslog server’s debug logs will go to the configured file inside the container:

```bash
$ kubectl -nkube-system exec log-collector-68cc9dccc7-nvldg tail -- -f /var/log/rsyslog.txt
```

See more information about various debugging options available for ryslogd in its documentation.

The other common types of issues related to log forwarding are various networking errors so standard network troubleshooting tools like tcpdump can be utilized to find problems in that area.
