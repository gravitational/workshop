# Kubernetes networking explained

Brief description of Kubernetes networking internals

## Motivation

Unlike classic Docker networking which uses simple bridge to interconnect
containers and port-forwarding (proxy or NAT) K8S has addition requirements on
network fabric:

1. all containers can communicate with all other containers without NAT
2. all nodes can communicate with all containers (and vice-versa) without NAT
3. the IP that a container sees itself as is the same IP that others see it as

Obviously classic Docker network setup unable to provide this features in case
of more than one node.

K8S itself doesn't have built-in networking solutions (except for one-node case)
to fulfil this requirements. But there're a lot of 3rd-parti solutions to
implement network fabric. Every product has it's pros and cons, so it was a good
idea to make networking fabric independent and pluggable.

More about K8S networking solutions [here][1].

For this purposes K8S supports CNI plugins to manage networking. More about K8S
CNI (and other modes) [here][2].

## Docker network example

We can easily simulate docker-alike networking using namespaces, virtual
ethernet devices and a bridge.

Network diagram:

```text
+----------------------------------------------------+
| Linux host                                         |
| +----------------------+  +----------------------+ |
| | netns node1          |  | netns node2          | |
| |       +              |  |       +              | |
| |       | vethA        |  |       | vethX        | |
| |       | 10.10.0.2/24 |  |       | 10.10.0.3/24 | |
| |       |              |  |       |              | |
| +----------------------+  +----------------------+ |
|         |                         |                |
|         | vethB                   | vethY          |
|         |                         |                |
|   br0 +-------------------------------+            |
|       +-------------------------------+            |
|                                                    |
+----------------------------------------------------+
```

You can run this script to create this network configuration:

```shell
# Create bridge on host to interconnect virtual ethernets
ip link add br0 type bridge
ip link set br0 up

# Creating virtual ethernet pairs vethA-vethB and vethX-vethY
ip link add vethA type veth peer name vethB
ip link add vethX type veth peer name vethY
ip link set vethB up
ip link set vethY up

# Adding network namespaces node1 and node2
# They will work as containers with independent networking
ip netns add node1
ip netns add node2

# Put one end of each pair to each of netns'es
ip link set vethA netns node1
ip link set vethX netns node2

# Bring interfaces inside netns up
# This should be done AFTER putting interfaces to netns because this movet turns interfaces off
ip netns exec node1 ip link set vethA up
ip netns exec node2 ip link set vethX up

# Assign IP addresses from same 10.10.0.0/24 subnet
ip netns exec node1 ip address add 10.10.0.2/24 dev vethA
ip netns exec node2 ip address add 10.10.0.3/24 dev vethX

# Link on-host ends of veths to bridge, i.e. providing L2 connectivity between veth'es
ip link set vethB master br0
ip link set vethY master br0
```

Check connectivity between netns'es `node1` and `node2`:

```text
# ip netns exec node2 ping -c 3 10.10.0.2
PING 10.10.0.2 (10.10.0.2) 56(84) bytes of data.
64 bytes from 10.10.0.2: icmp_seq=1 ttl=64 time=0.124 ms
64 bytes from 10.10.0.2: icmp_seq=2 ttl=64 time=0.151 ms
64 bytes from 10.10.0.2: icmp_seq=3 ttl=64 time=0.066 ms

--- 10.10.0.2 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2054ms
rtt min/avg/max/mdev = 0.066/0.113/0.151/0.037 ms

# ip netns exec node1 ping -c 3 10.10.0.3
PING 10.10.0.3 (10.10.0.3) 56(84) bytes of data.
64 bytes from 10.10.0.3: icmp_seq=1 ttl=64 time=0.079 ms
64 bytes from 10.10.0.3: icmp_seq=2 ttl=64 time=0.062 ms
64 bytes from 10.10.0.3: icmp_seq=3 ttl=64 time=0.103 ms

--- 10.10.0.3 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2030ms
rtt min/avg/max/mdev = 0.062/0.081/0.103/0.018 ms
```

To destroy this setup simply run:

```shell
# Remove bridge
ip link set br0 down
ip link delete br0

# Remove namespaces
# We don't need to remove each of veth because `netns delete` destroys all interfaces
# inside itself, and veth can be destroyed by simply removing any of it's interfaces
ip netns delete node1
ip netns delete node2
```

## CNI basics

CNI (Container Network Interface) is a project which aims at providing universal
clean and easy way to connect containers to network fabric. *Container* here is
basically interchangeable with *Linux network namespace*. Simply speaking CNI
plugin is a wrapper command which configures network interfaces inside container
and attaches it to some backend network.

API is pretty simple, it consists of 3 operations:

* Add container to network
* Remove container to network
* Report self version

All arguments passed through environment variables. Plugin must return
JSON-serialized result which describes status of operation (like allocated IP,
created routes, etc). Also there is special type of plugin called IPAM
(IP address management) plugin, which function is to allocate IP addresses and
pass it to network cofiguration plugin.

CNI specification details described [here][3].

K8S expects CNI plugin binaries to be stored in `/opt/cni/bin` and configuration
files in `/etc/cni/net.d`. All plugin produced results are stored in
`/var/lib/cni/<plugin name>`.

## Lab installation

First, follow [installation instructions](README.md#installation)

## Sample pod configuration explored

Run `minikube start --network-driver=cni` to spin up K8S inside VirtualBox VM
with [bridge plugin][4] and [host-local ipam plugin][5] configured.

Let's deploy `nginx` application to cluster:

```text
$ kubectl run nginx --image=nginx
deployment "nginx" created
```

Make sure the pod is running:

```text
$ kubectl get pods
NAME                    READY     STATUS    RESTARTS   AGE
nginx-701339712-05fm4   1/1       Running   0          48s
```

Attach console to explore inside network:

```text
$ kubectl exec -t -i nginx-701339712-05fm4 -- /bin/bash
root@nginx-701339712-05fm4:/# ip a
...
4: eth0@if10: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1460 qdisc noqueue state UP group default
    link/ether 0a:58:0a:01:00:04 brd ff:ff:ff:ff:ff:ff
    inet 10.1.0.4/16 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::cf5:fff:fe7e:e2e2/64 scope link tentative dadfailed
       valid_lft forever preferred_lft forever
root@nginx-701339712-05fm4:/# ip r
default via 10.1.0.1 dev eth0
10.1.0.0/16 dev eth0  proto kernel  scope link  src 10.1.0.4
```

As we see container has quite simple network config. We're interested only in
interface #4, which is one end of `veth` virtual interface. Suffix `@if10`
indicates that other end of this pipe is interface #10 (which is located
outside netns -- on host). IP configuration is pretty straightforward: pod has
one IP address allocated on `10.1.0.0/16` subnet using host-local plugin. It
gets IP addresses from configured subnet.

We can review CNI configuration using following command (on host):

```
$ minikube ssh
# Name of config file may differ from version to version of minikube
$ cat /etc/cni/net.d/k8s.conf
```

Configuration explained briefly:

```text
{
  "name": "rkt.kubernetes.io",
  "type": "bridge",     # network configuration plugin
  "bridge": "mybridge", # name of host bridge to use
  ...
  "isGateway": true,    # Bridge is used as gateway, i.e. first subnet address
                        # is assigned to it
  "ipMasq": true,       # Enable IP Masquerading to pods outgoing traffic
  "ipam": {                     # IPAM configuration following
    "type": "host-local",       # IPAM plugin name
    "subnet": "10.1.0.0/16",    # Allocation subnet
    "gateway": "10.1.0.1",      # Inform host-local that router is here to
                                # render consistent IP level configuration
    ...
  }
}
```

Inside VM (if you've exited, enter again using `minikube ssh` command) we
can explore K8S host networking part.

```text
$ ip a
...
7: mybridge: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1460 qdisc noqueue state UP group default qlen 1000
    link/ether 0a:58:0a:01:00:01 brd ff:ff:ff:ff:ff:ff
    inet 10.1.0.1/16 scope global mybridge
       valid_lft forever preferred_lft forever
    inet6 fe80::d8da:1fff:fe99:e8c1/64 scope link
       valid_lft forever preferred_lft forever
8: vethd78e9f59@if4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1460 qdisc noqueue master mybridge state UP group default
    link/ether ce:30:18:e6:b7:a2 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet6 fe80::cc30:18ff:fee6:b7a2/64 scope link
       valid_lft forever preferred_lft forever
9: vethe0ce3592@if4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1460 qdisc noqueue master mybridge state UP group default
    link/ether 82:cf:10:3f:a5:38 brd ff:ff:ff:ff:ff:ff link-netnsid 1
    inet6 fe80::80cf:10ff:fe3f:a538/64 scope link
       valid_lft forever preferred_lft forever
10: veth10fac511@if4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1460 qdisc noqueue master mybridge state UP group default
    link/ether 02:29:a5:05:e4:7d brd ff:ff:ff:ff:ff:ff link-netnsid 2
    inet6 fe80::29:a5ff:fe05:e47d/64 scope link
       valid_lft forever preferred_lft forever
...
```

Host of course has `lo` and `ethX` interfaces in configuration required by
`docker-machine`. But our interest is here, as we see there is a bridge called
`mybridge` with gateway address assigned. And there are outer parts of `veths`
for containers.

*All `vethXXXX` interfaces have `@if4` suffix which indicates that they are
connected to "interface #4", but in every pod `eth` is interface #4, so it's
just meaningless suffix.*

Now see how interfaces are connected to bridge:

```text
$ brctl show
bridge name bridge id       STP enabled interfaces
docker0     8000.0242ec55eeb9   no
mybridge        8000.0a580a010001   no      veth10fac511
                            vethd78e9f59
                            vethe0ce3592
```

There's unused `docker0` bridge, and `mybridge` which is master of all outer
parts of `veths`.

Let's examine CNI plugins stored data:

```text
$ sudo -i
# ls /var/lib/cni/networks/rkt.kubernetes.io/
10.1.0.2          10.1.0.3          10.1.0.4          last_reserved_ip
# cat /var/lib/cni/networks/rkt.kubernetes.io/last_reserved_ip ; echo
10.1.0.4
# cat /var/lib/cni/networks/rkt.kubernetes.io/10.1.0.2 ; echo
0fa93b0f771db74d3f1da588a3f9b413e47b90d30bdc4b0a93b7cc841a37a156
```

Directory `/var/lib/cni/networks` contains information of IPAM plugins. We can
see that host-local plugin tracks IP address which was allocated last
`last_reserved_ip` to allocate IPs in order. And every file named after
allocated IP contains ID of docker container network namespace.

[1]: https://kubernetes.io/docs/concepts/cluster-administration/networking/
[2]: https://kubernetes.io/docs/concepts/cluster-administration/network-plugins/
[3]: https://github.com/containernetworking/cni/blob/master/SPEC.md
[4]: https://github.com/containernetworking/cni/blob/master/Documentation/bridge.md
[5]: https://github.com/containernetworking/cni/blob/master/Documentation/host-local.md
