# Gravity Fire Drill Exercises

## Prerequisites

Docker 101, Kubernetes 101 and Gravity 101.

## Setup

For these exercises we’ll be using a 3-node Gravity cluster.

!!! note:
    If you’re taking this training as a part of Gravitational training program, you will be provided with a pre-built environment.

## General Troubleshooting Tools

### Gravity Shell

Gravity runs Kubernetes inside a container. This master container (which is usually referred to as Planet) provides a “bubble of consistency” for all Kubernetes components and their dependencies and ensures that all nodes in the cluster look identical to each other. The Planet container is based on Debian Stretch.

Since all Kubernetes services and their dependencies are containerized, you cannot interact with them (e.g. see the logs, start/stop/restart, etc.) directly from the host. Let’s explore:

```bash
node-1$ ps aux
```

We can see that all Kubernetes processes appear to be running. However, if we try to query their status it won’t work:

```bash
node-1$ sudo systemctl status kube-apiserver
```

Gravity provides a way to obtain a shell inside the Planet container:

```bash
node-1$ sudo gravity shell
```

Now we’re inside the Planet container and can “see” all systemd units running inside it:

```bash
node-1-planet$ systemctl status kube-apiserver
```

You can think of the `gravity shell` command as an analogue of the Docker command that requests a shell inside a running Docker container: `docker exec -ti <container> /bin/bash`. In fact, `gravity shell` is just a convenient shorthand for a similarly-looking `gravity exec` command:

```bash
node-1$ sudo gravity exec -ti /bin/bash
```

The `gravity exec` command allows to execute a single command inside the Planet container, similar to `docker exec`, for example:

```bash
node-1$ sudo gravity exec systemctl status kube-apiserver
```

Keep in mind that `kubectl` and `helm` do work from host so you don’t need to enter Gravity shell in order to use them:

```bash
node-1$ kubectl get nodes
node-1$ helm ls
```

Note that `kubectl` and `helm` will only work on master nodes and give errors on regular nodes due to lack of permissions.

### Gravity Status

Every Gravity cluster includes a built-in problem detector called Satellite. Satellite runs on every cluster node and continuously executes a multitude of health checks ranging from single-node checks (such as whether all kernel modules are loaded or whether the node has enough disk space) to cluster-wide checks (such as network latency b/w the nodes or time drift).

The `gravity status` command provides general information about the cluster and includes cluster health data collected by Satellite. Right now the cluster is healthy:

```bash
node-1$ gravity status
```

We recommend building a habit of running `gravity status` command first thing when things go wrong in the cluster - it has proven to be an indispensable tool in pinpointing the most common problems that can occur and saving troubleshooting time.

The cluster health data collected by Satellite can be also accessed directly by running the `planet status` command from inside the Planet container.

Let's use Gravity shell to execute the command:

```bash
node-1$ sudo gravity exec planet status --pretty
```

Alternatively, if we're already inside the Planet container environment, the command can be executed directly:

```bash
node-1$ sudo gravity shell
node-1-planet$ planet status --pretty
```

The command will produce a JSON document with information about all individual probes run by Satellite and the overall cluster status.

### Logs

Gravity clusters consist of many different components and it is useful to learn how to troubleshoot one or the other. As with pretty much any software product, the best way to start troubleshooting is to look at the logs.

Let's take a look at the logs produced by the system and how to find them.

#### Operation Logs

When performing any cluster operation, such as install or upgrade, Gravity sends operation logs to two destinations: systemd journal and `/var/log` directory. Normally, `/var/log` directory contains two Gravity-specific log files.

One of them is called `gravity-install.log`. This log file contains user-friendly logs of the initial cluster installation operation:

```bash
node-1$ sudo cat /var/log/gravity-install.log
```

It is useful for getting a high-level overview of the install operation progress, or for example debugging install hooks because it includes output from hook jobs as well.

Another log file, called `gravity-system.log`, is much more verbose. This is where `gravity` binary writes its internal logs:

```bash
node-1$ cat /var/log/gravity-system.log
```

This file is normally used when debugging a particular problem with the platform, for example, because it contains debug logs, stack traces and so on.

Note, that `gravity-install.log` and `gravity-system.log` are written by Gravity agent processes on the respective machines they're running on, so if you're working with a multi-node cluster, you may need to check them on each node.

#### System Logs

Gravity only supports systemd-based Linux distributions. A node with Gravity installed on it runs two specific systemd units, Planet and Teleport, which we explored in more detail in Gravity 101 session. Just as a quick reminder, Planet service is a container that runs all Kubernetes components inside it and Teleport service provides controlled SSH access to the node.

Oftentimes it is useful to inspect the logs of these units, for example to figure out why one or the other is not starting properly. The services have generated names so to check their logs you’d need to find out what they are:

```bash
node-1$ sudo systemctl list-unit-files | grep planet
gravity__gravitational.io__planet__5.6.0-11305-10-g9e464aa.service enabled
```

Once we've found the service name, we can use `journalctl` to see its logs:

```
node-1$ sudo journalctl \
    -u gravity__gravitational.io__planet__5.6.0-11305-10-g9e464aa \
    --no-pager
```

#### Kubernetes Component Logs

As mentioned above, Planet container itself is based on Debian Stretch and thus uses systemd too. All parts of a Kubernetes cluster run as systemd units inside it (`docker`, `etcd`, `flanneld`, `kube-apiserver`, `kube-scheduler`, `kube-controller-manager`, `kube-proxy`, `kube-kubelet`, etc.) so their logs can be looked at using journalctl as well.

Note that since these services run inside Planet, we need to use Gravity shell, which we've just learned about, to see their logs:

```bash
node-1$ sudo gravity exec journalctl -u etcd --no-pager
```

Most often than not, however, it is more convenient to just launch Gravity shell session on a node and keep exploring, rather than prefixing every command with `gravity exec`:

```bash
node-1$ sudo gravity shell
node-1-planet$ systemctl list-unit-files | grep kube
node-1-planet$ journalctl -u kube-apiserver --no-pager
node-1-planet$ journalctl -u kube-kubelet --no-pager
```

#### Other System Logs

Apart from journald logs, it is useful to look at other log files in the host’s `/var/log` directory.

As a particular example, on systems where SELinux is enabled `/var/log/audit/audit.log` contains information about enforced policies which can sometimes block certain executables (e.g. `dockerd`) or paths breaking the cluster in mysterious ways.

#### Container Logs

Kubernetes provides access to logs of all containers running in the cluster. It is most useful to look at a container’s logs when debugging an issue with a particular application, but it is also helpful to check “system” pods for any errors/warnings when troubleshooting a cluster issue which may give an idea about the source of a problem.

One of such “system” pods runs CoreDNS which provides in-cluster DNS resolution. CoreDNS pod runs on every cluster node as a DaemonSet and handles resolution for cluster-local names (such as Kubernetes services) and forwards other requests to upstream servers.

To check its logs, let’s first find out the names of the pods running CoreDNS. It’s running as a part of DaemonSet so pod names have an auto-generated suffix:

```bash
node-1$ kubectl -nkube-system get pods -owide
```

From there, let’s grab any of the CoreDNS pods (there should be 3 - 1 per node) and check its logs:

```bash
node-1$ kubectl -nkube-system logs coredns-xxx
```

Note that in this case we specified only the name of the pod - since it’s running only 1 container. If there are multiple containers running in the same pod, you’ll need to provide the name of the container to fetch the logs for, or `--all-containers` flag to fetch the logs of all containers:

```bash
node-1$ kubectl -nkube-system logs corednx-xxx coredns
```

The kubectl command works both from host and inside the planet environment. Inside the planet there is a convenient shorthand for `kubectl -nkube-system` - `kctl`.

```bash
node-1$ sudo gravity exec kctl logs coredns-xxx
```

Another crucial pod runs the Gravity cluster controller. It has many responsibilities: handles cluster operations (expand, upgrade, etc.), keeps cluster-local registries in-sync, provides an API for the `gravity` command-line utility, serves as an authentication gateway and so on. It is called “gravity-site” and runs as a DaemonSet on master nodes.

```bash
node-1$ kubectl -nkube-system get pods -lapp=gravity-site -owide
```

Note that by design only single gravity-site is active (“ready”) in a multi-node cluster - the current leader - with others being on a standby.

The `kubectl logs` command has a couple of other flags that are often useful in troubleshooting. One of them is `-f` that allows to tail the container logs, similar to Linux `tail -f` command. Another flag, `--since`, allows to fetch the recent logs for the specified duration - by default, kubectl will returns the logs from the beginning of history which may be undesired if the container produces a lot of output.

For example, to fetch only the most recent 5 minutes of logs and keep watching them, you can do:

```bash
node-1$ kubectl -nkube-system logs gravity-site -f --since=5m
```

The same `kubectl logs` command can be used to check the logs for the application pods.

### Collecting Debug Report

Gravity also provides a command to generate a cluster-wide debug report:

```bash
node-1$ gravity report
```

It may take a while to execute, but as a result it will produce a `report.tar.gz` file with a lot of diagnostic information about the cluster, including all system/operation logs, OS and node configuration (such as iptables rules, loaded kernel modules, available disk space and so on), etc.

It is useful to remember this command and ask users to collect the debug report so it can be shared with your support team (or Gravitational team) for offline troubleshooting. The report provides a comprehensive overview of the cluster state and usually contains enough information to figure our (or at least narrow down) a particular issue.

### Sharing Files Between Planet And Host

Sometimes it is necessary to fetch files from the Planet container to the host, or vice versa, make them available inside Planet. As an example, you may need to retrieve a certain log file from Planet and be able to download it from the machine using scp for further inspection.

For this purpose Gravity provides a directory that’s shared between the host and the Planet environment. On host, this directory is `/var/lib/gravity/planet/share`. Inside Planet, this directory is mounted under `/ext/share`. Any file placed inside `/var/lib/gravity/planet/` share on host will be visible in `/ext/share` inside Planet, and vice versa.

For example, let’s export the API server audit log:

```bash
node-1$ sudo gravity exec cp /var/log/apiserver/audit.log /ext/share
```

We can now view it directly from host:

```bash
node-1$ less /var/lib/gravity/planet/share/audit.log
```

We should note here that Gravity provides a way to override its default state directory, `/var/lib/gravity`, and set it to something else during initial installation via `--state-dir` flag.

If the default state directory was overridden, say to `/opt/gravity`, then in the above example, the share directory will be:

```bash
node-1$ less /opt/gravity/planet/share/audit.log
```

### Entering Containers / Creating Debug Pod

Oftentimes, it is useful to get a shell inside one of the running containers to test various things, for example, when experiencing pod-to-pod or pod-to-service communication issues. The “problem” with existing running pods is that more often than not they either do not include shell at all or are missing many tools that are useful in troubleshooting (dig, netstat, etc.) - in order to keep Docker images small.

To facilitate our debugging, we can create a special “debug” pod that will have access to all tools from the Planet environment. Define it’s spec in a file called “debug.yaml”:

```yaml
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: debug
  labels:
    app: debug
spec:
  selector:
    matchLabels:
      app: debug
  template:
    metadata:
      labels:
        app: debug
    spec:
      securityContext:
        runAsUser: 0
      containers:
      - name: debug
        image: leader.telekube.local:5000/gravitational/debian-tall:0.0.1
        command: ["/bin/sh", "-c", "sleep 365d"]
        volumeMounts:
          - name: rootfs
            mountPath: /rootfs
      volumes:
        - name: rootfs
          hostPath:
            path: /
```

And create it:

```bash
node-1$ kubectl create -f debug.yaml
```

Now, an instance of the debug pod is running on each node in the default namespace:

```bash
node-1$ kubectl get pods -owide
```

We can obtain the shell inside one of them and use all the tools available in Planet:

```bash
node-1$ kubectl exec -ti debug-jl8nr /bin/chroot /rootfs
debug-pod$ netstat -lpten
debug-pod$ kctl get pods
```

Let’s keep the debug pods running, we’re going to use them for some of our troubleshooting exercises below. Now, let’s do some breaking!

## Cluster Troubleshooting

### Scenario 1.1: Kernel Modules / Parameters

Kubernetes requires a number of certain kernel modules to be loaded to function properly.

One example is the “overlay” module used by the Docker overlay storage driver. Another example is “br_netfilter” (or “bridge” on some older systems) which is used for packet filtering, NAT and other packet mangling and is required for Kubernetes-setup iptables to function correctly. Without it, the packets from one pod will not be able to reach other pods.

Gravity has an auto-load feature that makes sure to enable necessary modules and set appropriate kernel parameters upon installation but we’ve seen many times when users have some provisioning automation setup on their infrastructure (e.g. via Chef/Puppet/etc.) that can occasionally go and reset them.

Let’s simulate this scenario and introduce the network partition in the cluster by disabling kernel IPv4 forwarding:

```bash
node-1$ sudo sysctl -w net.ipv4.ip_forward=0
```

The probability of this happening on a real cluster is actually non-negligible because Linux kernel forwarding is off by default and this kernel setting sometimes gets disabled as a security precaution by the ops teams sweeps, but is required for Kubernetes networking to work.

Let’s see what happened to the cluster pods. We can use one of our debug pods to explore:

```bash
node-1$ kubectl exec -ti debug-jl8nr /bin/chroot /rootfs
debug-pod$ curl -k https://gravity-site.kube-system.svc.cluster.local:3009/healthz
<hangs>
```

This service URL points to the active cluster controller (gravity-site) and is supposed to return 200OK but the pod can no longer reach it. Let’s see if our problem detector can give us any hints:

```bash
node-1$ gravity status
...
Cluster nodes:  nostalgicbell4909
   Masters:
       * node-1 (192.168.121.232, node)
           Status:     degraded
           [×]         ipv4 forwarding is off, see https://www.gravitational.com/docs/faq/#ipv4-forwarding ()
```

Satellite just saved us (possibly) hours of troubleshooting and pointed to the documentation section that explains how to fix this particular issue. Let’s fix the networking and verify:

```
node-1$ sudo sysctl -w net.ipv4.ip_forward=1
...
debug-pod$ curl -k https://gravity-site.kube-system.svc.cluster.local:3009/healthz
{"info":"service is up and running","status":"ok"}
...
node-1$ gravity status
...
Cluster nodes:  nostalgicbell4909
   Masters:
       * node-1 (192.168.121.232, node)
           Status:     healthy
```

### Scenario 1.2: Overlay Network

Overlay network is an essential component of a Kubernetes cluster that allows pods to communicate with each other. By default the overlay network is provided by Flannel with VXLAN backend.

Flannel uses in-kernel VXLAN encapsulation (using UDP as a transport protocol) which in the default configuration uses port `8472`. Note that since this is a kernel feature, you will not see the program name in the `netstat` output:

```bash
node-1$ sudo netstat -lptenu | grep 8472
udp        0      0 0.0.0.0:8472            0.0.0.0:*                           0          345455728  -
```

Overlay network spans all cluster nodes and when Kubernetes traffic goes from one node to another, the packets flow through the overlay network. This means that when there's a malfunction in the overlay network, Kubernetes traffic can't travel across the nodes.

As an example, a usual symptom of an issue with overlay network would be scenario when pods on one node can't talk to pods on other nodes, while pods colocated on the same node are still able to talk to each other just fine.

This issue can manifest itself in different ways, for example, a pod may intermittently be not able to connect to a Kubernetes service (or even resolve a Kubernetes service name) when its request gets routed to a pod instance on another node.

Let's take a look at a few most common reasons for the overlay network failure.

#### Blocked VXLAN Port

Probably the most common (and easy to detect) reason for the overlay network issues is a blocked VXLAN port. Let’s demonstrate this scenario by introducing a firewall rule that rejects all VXLAN traffic:

```bash
node-1$ sudo iptables -A INPUT -p udp --dport 8472 -j REJECT
```

Now, on another node let’s pick a couple of pods running on different nodes and try to ping them:

```bash
node-2$ kubectl get pods -owide --all-namespaces
...
kube-system   coredns-t2rtd                         1/1     Running     4          149m   10.244.59.23      192.168.121.232   <none>           <none>
kube-system   coredns-wfvrm                         1/1     Running     0          115m   10.244.84.4       192.168.121.198   <none>           <none>
...
node-2$ ping -c1 10.244.59.23
<packets lost>
node-2$ ping -c1 10.244.84.4
PING 10.244.84.4 (10.244.84.4): 56 data bytes
64 bytes from 10.244.84.4: icmp_seq=0 ttl=64 time=0.068 ms
...
```

To detect things like that it is often useful to inspect the iptables rules and look for any suspicious DROP or REJECT rules:

```bash
node-1$ sudo iptables -L -n
...
REJECT     udp  --  0.0.0.0/0            0.0.0.0/0            udp dpt:8472 reject-with icmp-port-unreachable
```

Let’s repair the overlay network in our cluster in the meanwhile and make sure it recovers:

```bash
node-1$ sudo iptables -D INPUT -p udp --dport 8472 -j REJECT
node-2$ ping 10.244.59.23
```

#### Flannel Issues

Overlay network issues may be caused by issues with the flannel itself as well.

One example would be flannel not able to register routes for the node subnet. This is a more common occurrence in the cloud environments, for example if the node does not have sufficient cloud API permissions. For example, as mentioned in the [GCE](https://gravitational.com/gravity/docs/installation/#installing-on-google-compute-engine) section in our documentation, when installing on Google Compute Engine with cloud integration, the nodes must have appropriate Compute Engine permissions.

Similar issues can happen in onprem environments as well so when suspecting an issue with the overlay network, it is useful to check flannel logs:

```bash
node-1$ sudo gravity exec journalctl -u flanneld --no-pager
```

#### VMWare ESXi

Another example worth mentioning is that on virtual machines powered by VMWare ESXi (part of VMWare vSphere suite) port 8472 is used for VXLAN that encapsulates all VM-to-VM traffic which will conflict with Kubernetes overlay network. The tricky part about detecting this is that VXLAN runs over UDP so there is no evident port conflict issue (i.e. no “bind” error b/c there is no “bind”) and since it’s happening in-kernel, the port does not appear in netstat either.

To support such systems Gravity provides ability to override default VXLAN port at install time via a command-line flag:

```bash
node-1$ sudo ./gravity install --vxlan-port=9473
```

### Scenario 1.3: Firewalld / IPTables

Firewall blocking traffic is probably one of the more common reasons for cluster networking issues. It usually manifests itself in the pods not being able to talk to other pods with “connection refused” or “no route to host” errors, oftentimes including the ones running on the same machine. Obviously, depending on what kind of rules are configured, the issue may be less pronounced and, for example, only block communication b/w certain pods.

The two most common firewall services are `firewalld` and `iptables` and they both use the iptables command-line tool which can be used to view all configured rules:

```bash
node-1$ sudo iptables-save
```

As we’ve found, misconfigured `firewalld` is quite often the reason the traffic gets blocked. You can check whether `firewalld` is running using the following commands:

```bash
node-1$ sudo systemctl status firewalld
node-1$ sudo firewall-cmd --state
running
```

As an example, `firewalld` may be allowing connections only from a certain subnet causing packets sent by pods to be dropped:

```bash
node-1$ sudo firewall-cmd --permanent --zone=public --add-source=192.168.0.0/16
node-1$ sudo firewall-cmd --reload
```

Repeating our test from the previous scenario, `node-2` can no longer ping pods on `node-1`:

```bash
node-2$ ping -c1 10.244.59.23
<packets lost>
```

To summarize, if the cluster is having networking issues which look like they may be caused by a firewall and the nodes are running `firewalld`, the first step is to usually shut the service down and see if the cluster recovers which helps narrow down the issue:

```bash
node-1$ sudo systemctl stop firewalld
```

#### Security Software

We should also mention here that we've been encountering firewalls that are more difficult to detect, usually ones that are implemented as a custom kernel module as a part of some endpoint security product. So far, we've seen two of those in the field that were run on a customer infrastructure: `Symantec Endpoint Protection` and `CylancePROTECT`.

Presence of both of those services resulted in non-obvious hard-to-troubleshoot errors such as various syscalls (e.g. `connect()`) producing "permission denied" errors.

The problem with such services is that, like those two we've just mentioned, they run in a kernel space and oftentimes there's no trace of their activity in the system logs, making it hard to detect unless you know where to look. And unfortunately, more often than not, especially in large enterprise organizations, a person who uses the infrastructure is not the same person who provisions it so they themselves may be unaware if their machines have any kind of security software running on them.

When suspecting that the issue may be caused by such security software, a good place to start would be to inspect a list of all running processes:

```bash
node-1$ ps aux
```

And loaded kernel modules:

```bash
node-1$ sudo lsmod
```

### Scenario 1.4: DNS

Another set of pretty common issues a cluster can encounter are related to DNS resolution. Gravity uses CoreDNS for DNS resolution and service discovery within the cluster.

Gravity runs two different sets of CoreDNS. First, every cluster node runs CoreDNS as a systemd unit inside Planet container:

```bash
node-1$ sudo gravity shell
node-1-planet$ systemctl status coredns
```

This CoreDNS instance serves DNS queries from Planet and is used to make sure that certain internal DNS names (such as `leader.gravity.local` which always points to the active master node) resolve to correct IP addresses. We can inspect how it's configured:

```bash
node-1-planet$ cat /etc/coredns/coredns.conf
node-1-planet$ cat /etc/resolv.conf
```

Also, CoreDNS runs as a DaemonSet inside the cluster to provide DNS resolution for cluster pods:

```bash
node-1-planet$ kctl get pods,services -owide | grep dns
```

These two sets of CoreDNS servers work independently, so when troubleshooting DNS-related issues, it is important to check both. For example, if a DNS name can be resolved from inside the Planet, it doesn't mean that the cluster DNS is functioning.

Usually DNS issues manifest themselves in the pods not being able to talk to other pods via service names due to resolution failures, while the overlay network itself keeps functioning.

Let’s illustrate this behavior by intentionally crashing CoreDNS pods:

```bash
node-1$ EDITOR=nano kubectl -nkube-system edit configmaps/coredns
<break config>
```

Restart the pods so they re-read the configuration:

```bash
node-1$ kubectl -nkube-system delete pods -lk8s-app=kube-dns
```

Now let’s try to access a service from one of our debug pods:

```bash
node-1$ kubectl exec -ti debug-jl8nr /bin/chroot /rootfs
debug-pod$ curl -k https://gravity-site.kube-system.svc.cluster.local:3009/healthz
curl: (6) Could not resolve host: gravity-site.kube-system.svc.cluster.local
```

But CURLing the service IP directly works:

```bash
debug-pod$ kctl get services | grep gravity-site
debug-pod$ curl -k https://10.100.135.21:3009/healthz
{"info":"service is up and running","status":"ok"}
```

Thus far the issue seems to be laying on the DNS side. In order to further troubleshoot it, let’s also check the packets traffic using “tcpdump”. First, we need to find out the IP address of our container so we know what to filter by:

```bash
debug-pod$ ifconfig eth0
```

Now, launch another terminal on node-1 and start sniffing:

```bash
node-1$ sudo gravity exec tcpdump -n -i any host 10.244.4.21
```

Then, execute another “curl” from the debug container and see if “tcpdump” has captured any packets. Note, you may need to execute it a few times in order to get traffic on the correct node.

```
19:19:28.678062 IP 10.244.4.21.44651 > gravity.domain: 46573+ A? gravity-site.kube-system.svc.cluster.local. (60)
19:19:28.678130 IP 10.244.4.21.44651 > gravity.domain: 47613+ AAAA? gravity-site.kube-system.svc.cluster.local. (60)
19:19:28.678492 IP gravity.domain > 10.244.4.21.44651: 46573 ServFail 0/0/0 (60)
```

We can now see that “tcpdump” has captured the DNS request made by our pod and returned ServFail. This clearly points to the DNS issue so let’s check our CoreDNS pods and their logs:

```bash
node-1$ kubectl -nkube-system get pods -owide
node-1$ kubectl -nkube-system logs coredns-86fsb
```

Let’s fix the configuration back and restart the pods:

```bash
node-1$ EDITOR=nano kubectl -nkube-system edit configmaps/coredns
<unbreak config>
node-1$ kubectl -nkube-system delete pods -lk8s-app=kube-dns
```

Keep in mind that DNS resolution issues can also be a side effect of broader networking issues, such as if there’s an issue with the overlay network we looked at before. In this case, you might get intermittent DNS resolution failures, e.g. when a pod attempts to resolve a service name and Kubernetes routes the DNS request to CoreDNS pod running on another node.

### Scenario 1.5: Etcd

Etcd is the backbone of a Kubernetes cluster. It is a distributed key-value database which Kubernetes uses to keep and replicate all of its state. Gravity also uses etcd as a database for all local cluster data, metadata for in-cluster object storage, leader information and so on. In short, when etcd is unhappy, the cluster falls apart: basic cluster operations (e.g. retrieving a list of pods) are timing out, Kubernetes is not able to schedule new pods, etc. (existings pods should keep running though).

Being a distributed database, etcd relies on a distributed consensus algorithm which requires a majority of all members (“quorum”) to vote in order for cluster to be able to make progress. This is important to keep in mind: it means that in an etcd cluster of N nodes, at least N/2+1 of them must be healthy in order for the whole system to keep functioning. To put this in concrete numbers, in a 3-node cluster you can afford to lose 1 member and the cluster will keep running (albeit at degraded performance), while in a 2-node cluster losing a single member means cluster outage. Etcd documentation has a nice table that explains fault tolerance depending on cluster size: https://coreos.com/etcd/docs/latest/v2/admin_guide.html#optimal-cluster-size.

Note, that in Gravity clusters etcd runs only on master nodes. Regular, non-master nodes run an instance of etcd-proxy which does not maintain any data locally and only routes requests to a full member on another node. Thus, if you have a 3-node cluster, but only 1 of them is a master node, then this cluster is not HA and does not have any etcd redundancy.

One of the first things you wanna do when troubleshooting a cluster is to assess etcd health. Etcd provides a command that will collect health information from all cluster members:

```bash
node-1$ sudo gravity exec etcdctl cluster-health
member bdbf284ca403d577 is healthy: got healthy result from https://192.168.121.198:2379
member dce1aaf4c02dc4b5 is healthy: got healthy result from https://192.168.121.232:2379
cluster is healthy
```

This command is helpful to quickly check if all etcd members are up and running, however it does not give much information beyond that - to find out the state of an individual member you can take a look at its logs:

```bash
node-1$ sudo gravity exec journalctl -u etcd --no-pager
```

The most common source of etcd-related issues is suboptimal hardware - etcd is very sensitive to disk latency so it is highly recommended to store its data on a dedicated, reasonably high-performant SSD, as described in our docs: https://gravitational.com/gravity/docs/requirements/#etcd-disk. If etcd is not liking the hardware it’s running on, you’ll see a lot of messages like this in its logs:

```
node-1 etcd[142]: server is likely overloaded
```

Also worth mentioning, as any distributed system, etcd relies on synchronized clocks b/w the cluster nodes so it is strongly recommended to have time-synchronization services (such as ntpd or chronyd) running on all nodes which would prevent the clocks from drifting.

Clocks drift check is automatically done by Gravity as a part of its pre-flight checks suite which is run before install or upgrade procedures. In the installed cluster, etcd will be complaining in its logs if it detects that the drift between its members is too high:

```
2018-05-23 17:00:29.475936 W | rafthttp: the clock difference against peer 5bd0394181f135dd is too high [10.449391606s > 1s]
```

To fix the clock drift issues, as mentioned above, the servers should be running some sort of time-sync software, such as ntp or chrony, that maintains their time in sync with specific time servers.

## Cluster Operations

### Scenario 2.1: Taking Node Down For Maintenance

Sometimes it is necessary to temporarily pull one of the cluster nodes out of service, for example for some maintenance or to apply software updates. The node may be running the application pods though so it is better to take it out of service gracefully. Kubernetes provides a number of tools to do this.

First, let’s see the nodes that we currently have:

```bash
node-1$ kubectl get nodes
NAME              STATUS   ROLES    AGE    VERSION
192.168.121.198   Ready    <none>   25h    v1.14.1
192.168.121.217   Ready    <none>   6m7s   v1.14.1
192.168.121.232   Ready    <none>   26h    v1.14.1
```

Let’s say we want to take the .217 one out. First, let’s make sure that Kubernetes does not schedule any more pods onto it:

```bash
node-1$ kubectl cordon 192.168.121.217
node/192.168.121.217 cordoned
```

```bash
node-1$ kubectl get nodes
NAME              STATUS                     ROLES    AGE     VERSION
192.168.121.198   Ready                      <none>   25h     v1.14.1
192.168.121.217   Ready,SchedulingDisabled   <none>   7m47s   v1.14.1
192.168.121.232   Ready                      <none>   26h     v1.14.1
```

Once the node has been cordoned, let’s drain it to move all pods off of it:

```bash
node-1$ kubectl drain 192.168.121.217 --ignore-daemonsets
```

Note that since the node is running several daemon set pods, we need to pass the flag to ignore them, otherwise the command will refuse to work. Let’s verify all pods (excluding those that are controlled by daemon sets) are gone from the node:

```bash
node-1$ kubectl get pods -A -owide
```

In a production setting, it may take a while for a node to get drained. Once it’s completed, we can also safely shut down the Planet container. Generally speaking, it is not always required and will terminate all Kubernetes services running on this node, but is sometimes necessary if you, for example, updated DNS configuration on the node (/etc/resolv.conf) and need to propagate this change into Planet container.

To shut down the planet, find out its systemd unit name (note, that we’re on node-3 now):

```bash
node-3$ sudo systemctl list-units | grep planet | grep service
gravity__gravitational.io__planet__6.0.0-11401.service...
node-3$ sudo systemctl stop gravity__gravitational.io__planet__6.0.0-11401.service
```

Once the planet has shut down, you can perform whatever maintenance necessary. Note that the cluster has become “degraded” and the node appears offline in gravity status now (may take a few seconds to reflect):

```bash
node-1$ gravity status
Cluster status:         degraded
...
        * node-3 (192.168.121.217, node)
           Status:     offline
```

Keep in mind that if you restart the node, the planet unit will automatically start when the node boots up. Once the maintenance has been completed, uncordon the node and Kubernetes will start scheduling pods on it again:

```bash
node-1$ kubectl cordon 192.168.121.217
node/192.168.121.217 uncordoned
```

### Scenario 2.2: Replacing Failed Node

Now let’s consider another scenario - a failed node. A node can fail for various reasons, for the sake of this exercise we will assume that the node is unrecoverable. Let’s simulate this scenario by wiping out the node clean:

```bash
node-3$ sudo gravity system uninstall --confirm
```

!!! warning:
    This command is equivalent of `rm -rf` for all Kubernetes/Gravity data so never run it on a production cluster.

As we found out before, when we were talking about etcd, a 3-node cluster can afford to lose 1 node so the cluster remains functional, but the node is shown as offline:

```bash
node-1$ gravity status
node-1$ kubectl get nodes
node-1$ sudo gravity exec etcdctl cluster-health
```

We should note again here, that in our case we have (or had, rather) a 3-master HA cluster, thus we could afford to lose one of the masters. If we had a 3-node cluster with less than 3 masters, we would not have any etcd redundancy and wouldn't be able to afford the loss of a single master.

To replace the failed node, we first need to remove it from the cluster. To do that, let’s run:

```bash
node-1$ sudo gravity remove node-3 --force
Please confirm removing node-3 (192.168.121.217) from the cluster (yes/no):
```

Note that we need to force-remove in this case because the node is offline. For online nodes the flag is not required.

If you launch `gravity status` command now, you will see that Gravity launched “shrink” operation that is working on properly evicting the node from the cluster and Kubernetes state.

```bash
node-1$ gravity status
...
Active operations:
   * operation_shrink (71266b23-d0ea-46b6-a5c4-15906eeb770a)
     started:  Tue Apr 30 21:34 UTC (12 seconds ago)
     unregistering the node, 10% complete
```

Once the operation completes, the cluster will switch back into the active state and the node will no longer appear in the gravity status. The `kubectl get nodes` and `etcdctl cluster-health` commands will also show that the node is no longer a part of the cluster.

```bash
node-1$ gravity status
...
Cluster nodes:  nostalgicbell4909
   Masters:
       * node-1 (192.168.121.232, node)
           Status:     healthy
       * node-2 (192.168.121.198, node)
           Status:     healthy
```

Now that the node has been properly removed and the cluster is healthy (but running at a reduced capacity of 2 nodes), we can join a replacement node. In our case, we can just join back the node we’ve just removed.

First, let’s find out the cluster’s join token which the joining node will need to provide to authenticate:

```bash
node-1$ gravity status --token
45b56f472e71
```

Next, we need to run a `gravity join` command on our new node, however when we ran system uninstall on it, the gravity binary was removed as well. Let’s get it back:

```bash
node-3$ curl -k -H "Authorization: Bearer 45b56f472e71" https://192.168.121.232:3009/portal/v1/gravity -o gravity && chmod +x gravity
```

Now, let’s join the node to the cluster:

```bash
node-3$ sudo ./gravity join 192.168.121.232 --token=45b56f472e71
```

Once the node has joined, run gravity status to confirm.

### Scenario 2.3: Rolling Back Upgrade

Now we’re going to take a look at the cluster upgrade. In the ideal scenario cluster upgrade is straightforward - you upload a new installer tarball onto a cluster node, unpack it and execute included upgrade script which launches the automatic upgrade procedure.

Behind the scenes the upgrade works as a state machine: Gravity generates an upgrade plan that consists of multiple “phases” and launches an upgrade agent that executes phases of the plan one-by-one. If the automatic upgrade agent encounters an error during the execution of one of the phases, it stops. There is no automatic rollback, for safety and flexibility reasons. This approach allows an operator to inspect the upgrade operation plan, see where it failed, fix the issue and continue with the upgrade, either in automatic or manual fashion.

In some situations there may be no easy way to move forward with the interrupted upgrade so you might want to rollback the cluster to the previous state instead. Let’s simulate the failed upgrade by launching the operation and interrupting in a middle of a phase.

```bash
node-1$ cd ~/upgrade
node-1$ sudo ./upgrade
<progress output…>
<ctrl-c>
```

We have interrupted the upgrade and ended up with a partially upgraded cluster. If you run `gravity status`, you’ll see that the cluster is now in the “updating” state. From here we have two options: either resume the upgrade (supposedly, after fixing the issue that caused the upgrade to fail in the first place), or perform a rollback and re-attempt the upgrade later.

For the sake of this exercise, let’s assume that the upgrade have encountered an issue that can’t be easily fixed here and now and we want to rollback.

The first thing to do is to see which step of the plan the upgrade failed on. Gravity provides a set of commands that let you interact with the operation plan. Let’s inspect it:

```bash
node-1$ sudo ./gravity plan
```

Note: It is important to interact with the upgrade operation and operation plan using the new binary.

Depending on where you canceled the operation, some of the phases may be marked as “completed”. The phase that you interrupted is likely marked as “in progress”. In the event of a real failure, it would be marked as “failed”.

In order to rollback the operation, we need to rollback all phases that have been completed (or failed) thus far, in reverse order. Let’s do it:

```bash
node-1$ sudo ./gravity plan rollback --phase=/init --force
```

Note, that we pass a fully-qualified phase identifier to the command. You can think of the operation plan as a tree of phases so a fully-qualified phase name starts with the root (/) and the rest of sub-phase names concatenated by a /.

Once all phases have been rolled back and the plan only consists of “rolled back” and “unstarted” phases, we can mark the operation completed which will move the operation to the final “failed” state and activate the cluster:

```bash
node-1$ sudo ./gravity plan complete
```

Check `gravity status` to make sure that the cluster is back to active.

### Scenario 2.4. Resuming Upgrade

Now that we’ve learned how to do rollbacks, let’s reattempt the upgrade but this time execute it all the way through successful completion. To get started, let’s launch an upgrade operation in the manual mode. From the upgrade directory, run:

```bash
node-1$ sudo ./gravity upgrade --manual
```

This command has initialized the upgrade operation and launched upgrade agents on the cluster nodes, but has not started it. Let’s inspect the generated operation plan:

```bash
node-1$ sudo ./gravity plan
```

All of the steps in the plan need to be executed in order to upgrade the cluster. Let’s execute the first step. Similar to the rollback command we’ve just learned, there is a counterpart that executes the phase:

```bash
node-1$ sudo ./gravity plan execute --phase=/init
```

If we inspect the operation plan now, we will see that the “init” phase is now marked completed:

```bash
node-1$ sudo ./gravity plan
```

Note that some phases have prerequisites and can only execute if their requirements are met.

Let’s execute a couple more phases:

```bash
node-1$ sudo ./gravity plan execute --phase=/bootstrap/node-1
node-1$ sudo ./gravity plan execute --phase=/bootstrap/node-2
```

If you wish to continue the upgrade operation (for example, after having fixed the issue that caused the failure), you can keep executing the rest of the plan phases manually or resume the operation in the automatic mode:

```bash
node-1$ sudo ./gravity plan resume
```

If you choose to execute all phases manually, once all phases have been completed, similar to the rollback scenario above you will need to run `gravity plan complete` command to mark the operation completed and activate the cluster.

### Scenario 2.5. Resuming Install

For the final exercise of the day, we’re going to take a look at how to recover a failed install operation. Cluster installation employs the same plan-based approach as the upgrade operation where it generates an operation plan and install agents execute it.

To see how it works, we need a clean node which we can install a cluster on so let’s uninstall our existing 3-node cluster as we won’t need it anymore and reuse node-1. On all 3 nodes, run:

```bash
node-{1,2,3}$ sudo gravity system uninstall --confirm
```

We’ll be using node-1 to attempt to install a new single-node cluster. Let’s do something to the node which will cause the installation to fail but we’ll be able to easily fix. For example, let’s mess with of one of the directories that we know the installer will need:

```bash
node-1$ sudo mkdir -p /var/lib/gravity/planet
node-1$ sudo chattr +i /var/lib/gravity/planet
```

This will make the directory immutable so when installer attempts to create its subdirectories, it will fail. Let’s now launch the install operation:

```bash
node-1$ cd ~/installer
node-1$ sudo ./gravity install
...
Wed May  8 21:37:37 UTC Operation failure: failed to execute phase "/bootstrap/node-1"
Wed May  8 21:37:37 UTC Installation failed in 9.726002255s, check /var/log/gravity-install.log and /var/log/gravity-system.log for details
```

The installation will fail while trying to bootstrap the node. We can check the install log to see what happened:

```bash
node-1$ sudo cat /var/log/gravity-install.log
...
Wed May  8 22:05:06 UTC [ERROR] [node-1] Phase execution failed: mkdir /var/lib/gravity/planet/state: permission denied.
```

We can also launch another shell on node-1 and inspect the operation plan:

```bash
node-1$ sudo gravity plan
```

After figuring out the cause of the issue, we can wipe the node clean (using “gravity system uninstall” command) and reattempt the install. Starting from scratch every time may be quite inconvenient though, especially if you’re unsure what exactly is causing the issue and want to attempt to run the phase multiple times, or if the install failed later in the process. In this case we can just keep executing phases manually using familiar command:

```bash
node-1$ sudo gravity plan execute --phase=/bootstrap/node-1
```

The phase will obviously fail again since we haven’t fixed the issue yet. Let’s do it and retry:

```bash
node-1$ sudo chattr -i /var/lib/gravity/planet/
node-1$ sudo gravity plan execute --phase=/bootstrap/node-1
node-1$ sudo gravity plan
```

Great! The plan now shows that the node has been bootstrapped for install successfully. We can either continue to execute phases manually one-by-one, or simply resume the install which will continue the execution:

```bash
node-1$ sudo gravity plan resume
```

After the installation completes, you can shut down the installer process and we’ll have a single-node cluster.

This concludes our Gravity fire drills training.
