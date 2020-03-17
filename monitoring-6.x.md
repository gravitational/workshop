# Gravity Monitoring & Alerts (for Gravity 6.0 and later)

## Prerequisites

Docker 101, Kubernetes 101, Gravity 101.

## Introduction

_Note: This part of the training pertains to Gravity 6.0 and later. In Gravity 6.0 Gravitational replaced InfluxDB/Kapacitor monitoring stack with Prometheus/Alertmanager._

Gravity Clusters come with a fully configured and customizable monitoring and alerting systems by default. The system consists of various components, which are automatically included into a Cluster Image that is built with a single command `tele build`.

## Overview

Before getting into Gravity’s monitoring and alerts capability in more detail, let’s first discuss the various components that are involved.

There are 4 main components in the monitoring system: Prometheus, Grafana, Alertmanager and Satellite.

### Prometheus

Is an open source Kubernetes native monitoring system and time-series database that collects hardware and OS metrics, as well as metrics about various k8s resources (deployments, nodes, and pods). Prometheus exposes the cluster-internal service `prometheus-k8s.monitoring.svc.cluster.local:9090`.

### Grafana

Is an open source metrics suite which provides the dashboard in the Gravity monitoring and alerts system. The dashboard provides a visual to the information stored in Prometheus, which is exposed as the service `grafana.monitoring.svc.cluster.local:3000`. Credentials generated are placed into a secret `grafana` in the monitoring namespace

Gravity is shipped with 2 pre-configured dashboards providing a visual of machine and pod-level overview of the installed cluster. Within the Gravity control panel, you can access the dashboard by navigating to the Monitoring page.

By default, Grafana is running in anonymous read-only mode. Anyone who logs into Gravity can view but not modify the dashboards.

### Alertmanager

Is a Prometheus component that handles alerts sent by client  applications such as a Prometheus server. Alertmanager handles deduplicating, grouping and routing alerts to the correct receiver integration such as an email recipient. Alertmanager exposes the cluster-internal service `alertmanager-main.monitoring.svc.cluster.local:9093`.

### Satellite

[Satellite](https://github.com/gravitational/satellite) is an open-source tool prepared by Gravitational that collects health information related to the Kubernetes cluster. Satellite runs on each Gravity Cluster node and has various checks assessing the health of a Cluster. Any issues detected by Satellite are shown in the output of the gravity status command.

## Metrics Overview

All monitoring components are running in the “monitoring” namespace in Gravity. Let’s take a look at them:

```
$ kubectl -nmonitoring get pods
NAME                         READY   STATUS    RESTARTS   AGE
alertmanager-main-0                    3/3     Running   0          27m
alertmanager-main-1                    3/3     Running   0          26m
alertmanager-main-2                    3/3     Running   0          26m
grafana-6b645587d-chxxg                2/2     Running   0          27m
kube-state-metrics-69594c468-wcr4g     3/3     Running   0          27m
nethealth-4cjwh                        1/1     Running   0          26m
node-exporter-hz972                    2/2     Running   0          27m
prometheus-adapter-6586cf7b4f-hmwkf    1/1     Running   0          27m
prometheus-k8s-0                       3/3     Running   1          26m
prometheus-k8s-1                       0/3     Pending   0          26m
prometheus-operator-7bd7d57788-mf8xn   1/1     Running   0          27m
watcher-7b99cc55c-8qgms                1/1     Running   0          27m
```

Most of the cluster metrics are collected by Prometheus which uses the following in-cluster services:

*   [node-exporter](https://github.com/prometheus/node_exporter) (collects hardware and OS metrics)
*   [kube-state-metrics](https://github.com/kubernetes/kube-state-metrics) (collects Kubernetes resource metrics - deployments, nodes, pods)

kube-state-metrics collects metrics about various Kubernetes resources such as deployments, nodes and pods. It is a service that listens to the Kubernetes API server and generates metrics about the state of the objects.

Further, kube-state-metrics exposes raw data that is unmodified from the Kubernetes API, which allows users to have all the data they require and perform heuristics as they see fit. In return, kubectl may not show the same values, as kubectl applies certain heuristics to display cleaner messages.

Metrics from kube-state-metrics service are exported on the HTTP endpoint `/metrics` on the listening port (default 8080) and are designed to be consumed by Prometheus.

![diagram](https://miro.medium.com/max/832/1*7thrW4Wa5y6b03PxtPlQzA.jpeg)

(Source: https://medium.com/faun/production-grade-kubernetes-monitoring-using-prometheus-78144b835b60)

All metrics collected by node-exporter and kube-state-metrics are stored as time series in Prometheus. See below for a list of metrics collected by Prometheus. Each metric is stored as a separate “series” in Prometheus.

Prometheus allows users to differentiate on the things that are being measured. Label names should not be used in the metric name as that leads to some redundancy.

*   `api_http_requests_total` - differentiate request types: `operation="create|update|delete"`

When troubleshooting problems with metrics, it is sometimes useful to look into the specified container logs where it can be seen if it experiences communication issues with Prometheus service or has other issues:

```
$ kubectl -nmonitoring logs prometheus-adapter-6586cf7b4f-hmwkf
```

```
$ kubectl -nmonitoring logs kube-state-metrics-69594c468-wcr4g kube-state-metrics
```

```
$ kubectl -nmonitoring logs node-exporter-hz972 node-exporter
```

In addition, any other apps that collect metrics should also submit them into the same DB in order for proper retention policies to be enforced.

## Exploring Prometheus

Like mentioned above, Prometheus is exposed via a cluster-local Kubernetes service `prometheus-k8s.monitoring.svc.cluster.local:9090` and serves its HTTP API on port `9090` so we can use it to explore the database from the CLI.

Also, as seen above we have the following Prometheus pods:

```
prometheus-adapter-6586cf7b4f-hmwkf
prometheus-k8s-0
prometheus-operator-7bd7d57788-mf8xn
```
Prometheus operator for Kubernetes allows easy monitoring definitions for kubernetes services and deployment and management of Prometheus instances.

Prometheus adapter is an API extension for kubernetes that users prometheus queries to populate kubernetes resources and custom metrics APIs.

Let's enter the Gravity master container to make sure the services are resolvable and to get access to additional CLI tools:

```bash
$ sudo gravity shell
```

Let's ping the database to make sure it's up and running:

```bash
$ curl -sl http://prometheus-k8s.monitoring.svc.cluster.local:9090/api/v1/status/config
// Should return "status":"success" within currently loaded configuration file.
```

A list of alerting and recording rules that are currently loaded is available by executing:

```bash
$ curl http://prometheus-k8s.monitoring.svc.cluster.local:9090/api/v1/rules | jq
```
Also we can see all metric points, by executing the following command:

```bash
$ curl http://prometheus-k8s.monitoring.svc.cluster.local:9090/api/v1/query?query=up | jq
```

Finally, we can query Prometheus using it's SQL-like query language (PromQL) to for example evaluate metrics identified under the expression `up` at the specified time:

```bash
$ curl 'http://prometheus-k8s.monitoring.svc.cluster.local:9090/api/v1/query?query=up&time=2020-03-13T20:10:51.781Z' | jq
```

Refer to the Prometheus [API documentation](https://prometheus.io/docs/prometheus/latest/querying/basics/) if you want to learn more about querying the database.

## Metric Retention Policy

### Time based retention

By default Gravitational configures Prometheus with a time based retention policy of 30 days.

## Custom Dashboards

Along with the dashboards mentioned above, your applications can use their own Grafana dashboards by using ConfigMaps.

In order to create a custom dashboard, the ConfigMap should be created in the `monitoring` namespace, assigned a `monitoring` label with a value `dashboard`.

Under the specified namespace, the ConfigMap will be recognized and loaded when installing the application. It is possible to add new ConfigMaps at a later time as the watcher will then pick it up and create it in Grafana. Similarly, if you delete the ConfigMap, the watcher will delete it from Grafana.

Dashboard ConfigMaps may contain multiple keys with dashboards as key names are not relevant.

An example ConfigMap is shown below:

```
apiVersion: v1
kind: ConfigMap
metadata:
  name: mydashboard
  namespace: monitoring
  labels:
    monitoring: dashboard
data:
  mydashboard: |
    { ... dashboard JSON ... }
```

_Note: by default Grafana is run in read-only mode, a separate Grafana instance is required to create custom dashboards._

## Default Metrics

The following are the default metrics captured by the Gravity Monitoring & Alerts system:

### node-exporter Metrics

Below are a list of metrics captured by node-exporter which are exported to the backend by based on OS:

<table>
  <tr>
   <td><strong>Name</strong>
   </td>
   <td><strong>Description</strong>
   </td>
   <td><strong>OS</strong>
   </td>
  </tr>
  <tr>
   <td>arp
   </td>
   <td>Exposes ARP statistics from /proc/net/arp.
   </td>
   <td>Linux
   </td>
  </tr>
  <tr>
   <td>bcache
   </td>
   <td>Exposes bcache statistics from /sys/fs/bcache/.
   </td>
   <td>Linux
   </td>
  </tr>
  <tr>
   <td>bonding
   </td>
   <td>Exposes the number of configured and active slaves of Linux bonding interfaces.
   </td>
   <td>Linux
   </td>
  </tr>
  <tr>
   <td>boottime
   </td>
   <td>Exposes system boot time derived from the kern.boottime sysctl.
   </td>
   <td>Darwin, Dragonfly, FreeBSD, NetBSD, OpenBSD, Solaris
   </td>
  </tr>
  <tr>
   <td>conntrack
   </td>
   <td>Shows conntrack statistics (does nothing if no /proc/sys/net/netfilter/ present).
   </td>
   <td>Linux
   </td>
  </tr>
  <tr>
   <td>cpu
   </td>
   <td>Exposes CPU statistics
   </td>
   <td>Darwin, Dragonfly, FreeBSD, Linux, Solaris
   </td>
  </tr>
  <tr>
   <td>cpufreq
   </td>
   <td>Exposes CPU frequency statistics
   </td>
   <td>Linux, Solaris
   </td>
  </tr>
  <tr>
   <td>diskstats
   </td>
   <td>Exposes disk I/O statistics.
   </td>
   <td>Darwin, Linux, OpenBSD
   </td>
  </tr>
  <tr>
   <td>edac
   </td>
   <td>Exposes error detection and correction statistics.
   </td>
   <td>Linux
   </td>
  </tr>
  <tr>
   <td>entropy
   </td>
   <td>Exposes available entropy.
   </td>
   <td>Linux
   </td>
  </tr>
  <tr>
   <td>exec
   </td>
   <td>Exposes execution statistics.
   </td>
   <td>Dragonfly, FreeBSD
   </td>
  </tr>
  <tr>
   <td>filefd
   </td>
   <td>Exposes file descriptor statistics from /proc/sys/fs/file-nr.
   </td>
   <td>Linux
   </td>
  </tr>
  <tr>
   <td>filesystem
   </td>
   <td>Exposes filesystem statistics, such as disk space used.
   </td>
   <td>Darwin, Dragonfly, FreeBSD, Linux, OpenBSD
   </td>
  </tr>
  <tr>
   <td>hwmon
   </td>
   <td>Expose hardware monitoring and sensor data from /sys/class/hwmon/.
   </td>
   <td>Linux
   </td>
  </tr>
  <tr>
   <td>infiniband
   </td>
   <td>Exposes network statistics specific to InfiniBand and Intel OmniPath configurations.
   </td>
   <td>Linux
   </td>
  </tr>
  <tr>
   <td>ipvs
   </td>
   <td>Exposes IPVS status from /proc/net/ip_vs and stats from /proc/net/ip_vs_stats.
   </td>
   <td>Linux
   </td>
  </tr>
  <tr>
   <td>loadavg
   </td>
   <td>Exposes load average.
   </td>
   <td>Darwin, Dragonfly, FreeBSD, Linux, NetBSD, OpenBSD, Solaris
   </td>
  </tr>
  <tr>
   <td>mdadm
   </td>
   <td>Exposes statistics about devices in /proc/mdstat (does nothing if no /proc/mdstat present).
   </td>
   <td>Linux
   </td>
  </tr>
  <tr>
   <td>meminfo
   </td>
   <td>Exposes memory statistics.
   </td>
   <td>Darwin, Dragonfly, FreeBSD, Linux, OpenBSD
   </td>
  </tr>
  <tr>
   <td>netclass
   </td>
   <td>Exposes network interface info from /sys/class/net/
   </td>
   <td>Linux
   </td>
  </tr>
  <tr>
   <td>netdev
   </td>
   <td>Exposes network interface statistics such as bytes transferred.
   </td>
   <td>Darwin, Dragonfly, FreeBSD, Linux, OpenBSD
   </td>
  </tr>
  <tr>
   <td>netstat
   </td>
   <td>Exposes network statistics from /proc/net/netstat. This is the same information as netstat -s.
   </td>
   <td>Linux
   </td>
  </tr>
  <tr>
   <td>nfs
   </td>
   <td>Exposes NFS client statistics from /proc/net/rpc/nfs. This is the same information as nfsstat -c.
   </td>
   <td>Linux
   </td>
  </tr>
  <tr>
   <td>nfsd
   </td>
   <td>Exposes NFS kernel server statistics from /proc/net/rpc/nfsd. This is the same information as nfsstat -s.
   </td>
   <td>Linux
   </td>
  </tr>
  <tr>
   <td>pressure
   </td>
   <td>Exposes pressure stall statistics from /proc/pressure/.
   </td>
   <td>Linux (kernel 4.20+ and/or <a href="https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/Documentation/accounting/psi.txt">CONFIG_PSI</a>)
   </td>
  </tr>
  <tr>
   <td>rapl
   </td>
   <td>Exposes various statistics from /sys/class/powercap.
   </td>
   <td>Linux
   </td>
  </tr>
  <tr>
   <td>schedstat
   </td>
   <td>Exposes task scheduler statistics from /proc/schedstat.
   </td>
   <td>Linux
   </td>
  </tr>
  <tr>
   <td>sockstat
   </td>
   <td>Exposes various statistics from /proc/net/sockstat.
   </td>
   <td>Linux
   </td>
  </tr>
  <tr>
   <td>softnet
   </td>
   <td>Exposes statistics from /proc/net/softnet_stat.
   </td>
   <td>Linux
   </td>
  </tr>
  <tr>
   <td>stat
   </td>
   <td>Exposes various statistics from /proc/stat. This includes boot time, forks and interrupts.
   </td>
   <td>Linux
   </td>
  </tr>
  <tr>
   <td>textfile
   </td>
   <td>Exposes statistics read from local disk. The --collector.textfile.directory flag must be set.
   </td>
   <td>any
   </td>
  </tr>
  <tr>
   <td>thermal_zone
   </td>
   <td>Exposes thermal zone & cooling device statistics from /sys/class/thermal.
   </td>
   <td>Linux
   </td>
  </tr>
  <tr>
   <td>time
   </td>
   <td>Exposes the current system time.
   </td>
   <td>any
   </td>
  </tr>
  <tr>
   <td>timex
   </td>
   <td>Exposes selected adjtimex(2) system call stats.
   </td>
   <td>Linux
   </td>
  </tr>
  <tr>
   <td>uname
   </td>
   <td>Exposes system information as provided by the uname system call.
   </td>
   <td>Darwin, FreeBSD, Linux, OpenBSD
   </td>
  </tr>
  <tr>
   <td>vmstat
   </td>
   <td>Exposes statistics from /proc/vmstat.
   </td>
   <td>Linux
   </td>
  </tr>
  <tr>
   <td>xfs
   </td>
   <td>Exposes XFS runtime statistics.
   </td>
   <td>Linux (kernel 4.4+)
   </td>
  </tr>
  <tr>
   <td>zfs
   </td>
   <td>Exposes <a href="http://open-zfs.org/">ZFS</a> performance statistics.
   </td>
   <td><a href="http://zfsonlinux.org/">Linux</a>, Solaris
   </td>
  </tr>
</table>

### kube-state-metrics

A list of metrics captured by kube-state metrics can be found [here](https://github.com/kubernetes/kube-state-metrics/tree/master/docs).

There are various groups of metrics for each set, some of these include:

*   ConfigMap Metrics
*   Pod Metrics
*   ReplicaSet Metrics
*   Service Metrics

Example list of [ConfigMap Metrics](https://github.com/kubernetes/kube-state-metrics/blob/master/docs/configmap-metrics.md)


<table>
  <tr>
   <td><strong>Metric name</strong>
   </td>
   <td><strong>Metric type</strong>
   </td>
   <td><strong>Labels/tags</strong>
   </td>
   <td><strong>Status</strong>
   </td>
  </tr>
  <tr>
   <td>kube_configmap_info
   </td>
   <td>Gauge
   </td>
   <td>configmap=&lt;configmap-name>
<p>
namespace=&lt;configmap-namespace>
   </td>
   <td>STABLE
   </td>
  </tr>
  <tr>
   <td>kube_configmap_created
   </td>
   <td>Gauge
   </td>
   <td>configmap=&lt;configmap-name>
<p>
namespace=&lt;configmap-namespace>
   </td>
   <td>STABLE
   </td>
  </tr>
  <tr>
   <td>kube_configmap_metadata_resource_version
   </td>
   <td>Gauge
   </td>
   <td>configmap=&lt;configmap-name>
<p>
namespace=&lt;configmap-namespace>
   </td>
   <td>EXPERIMENTAL
   </td>
  </tr>
</table>

### Satellite

[Satellite](https://github.com/gravitational/satellite) is an open-source tool prepared by Gravitational that collects health information related to the Kubernetes cluster. Satellite runs on each Gravity Cluster node and has various checks assessing the health of a Cluster.

Satellite collects several metrics related to cluster health and exposes them over the Prometheus endpoint. Among the metrics collected by Satellite are:

*   Etcd related metrics:
    *   Current leader address
    *   Etcd cluster health
*   Docker related metrics:
    *   Overall health of the Docker daemon
*   Sysctl related metrics:
    *   Status of IPv4 forwarding
    *   Status of netfilter
*   Systemd related metrics:
    *   State of various systemd units such as etcd, flannel, kube-*, etc.

## More about Alertmanager

As mentioned Alertmanager is a Prometheus component that handles alerts sent by client applications such as the Prometheus server. Alertmanager handles deduplicating, grouping and routing alerts to the correct receiver integration such as an email recipient.

The following are alerts that Gravity Monitoring & Alerts system ships with by default:

<table>
  <tr>
   <td><strong>Component</strong>
   </td>
   <td><strong>Alert</strong>
   </td>
   <td><strong>Description</strong>
   </td>
  </tr>
  <tr>
   <td>CPU
   </td>
   <td>High CPU usage
   </td>
   <td>Warning at > 75% used
<p>
Critical error at > 90% used
   </td>
  </tr>
  <tr>
   <td>Memory
   </td>
   <td>High Memory usage
   </td>
   <td>Warning at > 80% used
<p>
Critical error at > 90% used
   </td>
  </tr>
  <tr>
   <td rowspan="2" >Systemd
   </td>
   <td>Individual
   </td>
   <td>Error when unit not loaded/active
   </td>
  </tr>
  <tr>
   <td>Overall systemd health
   </td>
   <td>Error when systemd detects a failed service
   </td>
  </tr>
  <tr>
   <td rowspan="2" >Filesystem
   </td>
   <td>High disk space usage
   </td>
   <td>Warning at > 80% used
<p>
Critical error at > 90% used
   </td>
  </tr>
  <tr>
   <td>High inode usage
   </td>
   <td>Warning at > 90% used
<p>
Critical error at > 95% used
   </td>
  </tr>
  <tr>
   <td rowspan="2" >System
   </td>
   <td>Uptime
   </td>
   <td>Warning node uptime &lt; 5 mins
   </td>
  </tr>
  <tr>
   <td>Kernel params
   </td>
   <td>Error if param not set
   </td>
  </tr>
  <tr>
   <td rowspan="2" >Etcd
   </td>
   <td>Etcd instance health
   </td>
   <td>Error when etcd master down > 5 mins
   </td>
  </tr>
  <tr>
   <td>Etcd latency check
   </td>
   <td>Warning when follower &lt;-> leader latency > 500 ms
<p>
Error when > 1 sec over period of 1 min
   </td>
  </tr>
  <tr>
   <td>Docker
   </td>
   <td>Docker daemon health
   </td>
   <td>Error when docker daemon is down
   </td>
  </tr>
  <tr>
   <td>Kubernetes
   </td>
   <td>Kubernetes node readiness
   </td>
   <td>Error when the node is not ready
   </td>
  </tr>
</table>

### Alertmanager Email Configuration

In order to configure email alerts via Alertmanager you will need to create Gravity resources of type `smtp `and `alerttarget`.

An example of the configuration is shown below:

```
kind: smtp
version: v2
metadata:
  name: smtp
spec:
  host: smtp.host
  port: <smtp port> # 465 by default
  username: <username>
  password: <password>
---
kind: alerttarget
version: v2
metadata:
  name: email-alerts
spec:
  email: triage@example.com # Email address of the alert recipient
```

Creating these resources will accordingly update and reload Alertmanager configuration:

```
$ gravity resource create -f smtp.yaml
```

In order to view the current SMTP settings or alert target:

```
$ gravity resource get smtp
$ gravity resource get alerttarget
```

Only a single alert target can be configured. To remove the current alert target, you can execute the following command:

```
$ gravity resource rm alerttarget email-alerts
```

### Alertmanager Custom Alerts

Creating new alerts is as easy as using another Gravity resource of type `alert`. Alerting rules are configured in Prometheus in the same way as recording rules and are automatically detected, loaded, and enabled for Gravity Monitoring and Alerts system.

For demonstration purposes let’s define an alert that always fires:

```
kind: alert
version: v2
metadata:
  name: cpu1
spec:
  alert_name: CPU1
  group_name: test-group
  formula: |
    node:cluster_cpu_utilization:ratio * 100 > 1
  labels:
    severity: info
  annotations:
    description: |
      This is a test alert
```

And create it :

```
$ gravity resource create -f alert.yaml
```

Custom alerts are being monitored by another “watcher” type of service that runs in its own pod:

```
$ kubectl -nmonitoring logs watcher-7b99cc55c-8qgms
time="2020-03-14T01:12:02Z" level=info msg="Detected event ADDED for configmap cpu1." label="monitoring in (alert)" watch=configmap
```

We can confirm the alert is running by checking active alerts to see if the cluster has overcommitted CPU resource requests, as we set the cpu usage threshold to 1%.

```bash
$ sudo gravity shell
```

```bash
$ curl http://prometheus-k8s.monitoring.svc.cluster.local:9090/api/v1/alerts | jq
```

We see the following output:

```bash
      {
        "labels": {
          "alertname": "CPU1",
          "node": "abdu-dev-test0",
          "severity": "info"
        },
        "annotations": {
          "description": "This is a test alert\n"
        },
        "state": "firing",
        "activeAt": "2020-03-14T01:12:20.102178408Z",
        "value": 43.51506264996971
      }
```

To view all currently configured custom alerts you can run:

```
$ gravity resource get alert cpu1
```

In order to remove a specific alert you can execute the following altermanager command inside the designated pod:

```
$ gravity resource rm alert cpu1
```

This concludes our monitoring training.
