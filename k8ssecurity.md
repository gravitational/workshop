# Kubernetes based Application Security Patterns

... and anti-patterns.

This workshop task will explore security concepts and the kubernetes primitives for aiding in secure application development.

## Kubernetes security primitives
Kubernetes provides a number of security primitives, that allow for an application to indicate what access it should have to the system.

### Authentication
Reference: https://kubernetes.io/docs/reference/access-authn-authz/authentication/

Two types of users:
- Normal Users
- Service Accounts

#### Normal Accounts
Normal accounts in kubernetes are controlled by an external system. Kubernetes does not include it's own internal user management system, and is built around using external identity providers.

#### Service Accounts
Service accounts are internal to kubernetes accounts, that are assigned to services (pods) to gain access to the kubernetes API.

### Role-based application controls
Reference: https://kubernetes.io/docs/reference/access-authn-authz/rbac/

The RBAC API declares resource objects that can be used to describe authorization policies for a cluster and how to link those policies to specific users.

#### Namespaces
Reference: https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/

Namespaces can create "virtual" kubernetes clusters within the same physical cluster.

Create a namespace:
```
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: test-namespace
EOF
```

#### Users and Groups
Users and Groups don't directly exist within kubernetes. The authentication layer instead embeds user and group information into the medium used to connect to the API, such as an x509 client certificate. 

Creating gravity users is covered in gravity101.md.



#### Service Accounts
Reference: https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/

Service accounts are internal accounts that software running within the kubernetes cluster can use to access the kubernetes API. The service accounts allow fine grained access to the kubernetes API using the RBAC authorization system.

Create a service account:
```
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: build-robot
  namespace: test-namespace
automountServiceAccountToken: false
EOF
```

Each namespace automatically has a default serviceAccount called `default`

Note: `automountServiceAccountToken: false` prevents the pod from automatically mounting the service account, which prevents access to the API. Definitly use this for services that don't need to interact with the kubernetes API.

#### Role and ClusterRole
Role and ClusterRole are kubernetes objects that contain rules that represent a set of allowed permissions. 

##### Role
```
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: pod-reader
rules:
- apiGroups: [""] # "" indicates the core API group
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
EOF
```

##### ClusterRole
```
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  # "namespace" omitted since ClusterRoles are not namespaced
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "watch", "list"]
EOF
```

What a cluster role can do that individual roles cannot:
- Access cluster-scoped resources (like nodes)
- Non-resource endpoints (like /healthz)
- Namespaced resources (like pods) across all namespaces (`kubectl get pods --all-namespaces`)

#### RoleBinding and ClusterRoleBinding
RoleBinding and ClusterRoleBinding create the links between users or groups, and the roles they're allowed to use.

```
kubectl apply -f - <<EOF
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: default
  name: example-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-reader
subjects:
- kind: ServiceAccount
  name: build-robot
  namespace: default
EOF
```

#### Complete Example
Deploy a pod with a service account, and a set of restricted API permissions.

```
kubectl apply -f - <<EOF
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: default
  name: list-pods
rules:
  - apiGroups:
      - ""
    resources:
      - pods
    verbs:
      - get
      - list
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: default
  name: list-pods
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: list-pods
subjects:
- kind: ServiceAccount
  name: rbac-example
  namespace: default
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: rbac-example
  namespace: default
---
apiVersion: v1
kind: Pod
metadata:
  name: rbac-example
  namespace: default
spec:
  serviceAccountName: rbac-example
  containers:
  - name: kubectl
    image: lachlanevenson/k8s-kubectl:v1.15.2
    command: ['sh', '-c', 'sleep 86400']
EOF
```

Verify the RBAC permissions assigned to the pod:
```
kubectl exec -it rbac-example kubectl -- auth can-i --list
```

Find out the permissions assigned to kubectl:
```
kubectl auth can-i --list
```

Find out the permissions for another users:
```
kubectl auth can-i --list --as rbac-example
```

Find the the permissions for another user as a fully qualified name:

```
kubectl auth can-i --list --as system:serviceaccount:kube-system:rbac-example
```



### Secrets
Reference: https://kubernetes.io/docs/concepts/configuration/secret/

Secrets are an object type in kubernetes, for storing sensitive data.

Create base64 encodings of some secrets to store:
```
echo -n 'admin' | base64
YWRtaW4=
echo -n '1f2d1e2e67df' | base64
MWYyZDFlMmU2N2Rm
```

Create the secret in kubernetes
```
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
  namespace: default
type: Opaque
data:
  username: YWRtaW4=
  password: MWYyZDFlMmU2N2Rm
EOF
```

Using the created secret as a volume mount:
```
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secret-volume-pod
  namespace: default
spec:
  containers:
  - name: mypod
    image: redis
    volumeMounts:
    - name: secret
      mountPath: "/etc/mysecret"
      readOnly: true
  volumes:
  - name: secret
    secret:
      secretName: mysecret
EOF
```

Show the mounted secret:
```
kubectl exec -it secret-volume-pod bash -- -c "/bin/ls -l /etc/mysecret"
kubectl exec -it secret-volume-pod bash -- -c "/bin/cat /etc/mysecret/username; echo"
```


Create the secret as an environment variable:
```
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secret-env-pod
spec:
  containers:
  - name: mycontainer
    image: redis
    env:
      - name: SECRET_USERNAME
        valueFrom:
          secretKeyRef:
            name: mysecret
            key: username
      - name: SECRET_PASSWORD
        valueFrom:
          secretKeyRef:
            name: mysecret
            key: password
  restartPolicy: Never
EOF
```

View the secrets:
```
kubectl exec -it secret-env-pod bash -- -c "env | grep SECRET"
```

Restrictions:
- Pods and Secrets must be in the same namespace
- The pod won't be able to start until the secret is created (except if marked as optional)
- Secrets are limited to 1MiB in size
- Secrets that create env variables will be skipped if the keys are not valid environment variable names

Security Properties:
- Secret objects are less likely to be accidentally exposed, because they're an independent object from the pods that use them.
- A secret is only sent to a node if a pod on that node requires the secret. 
- On the node, the secret will not be written to disk. Instead it will be written to a tmpfs mount.
- On a node, one pod does not have access to the secrets of another pod
- Each container within a pod must individually mount a secret. Only the containers that mount the secret will have access to it.
- Communications between API and a Node are protected by mTLS, which protects the secret in transit. 

Risks:
- Secrets are written to disk on the master nodes by etcd
- A user who can create a pod that uses a secret can view a secret, even in RBAC permissions prevent access to the secret object itself. The user can run a pod which exposes the secret.

### Encryption at Rest
Gravity doesn't support encryption at rest.

### Pod security policies
Reference: https://kubernetes.io/docs/concepts/policy/pod-security-policy/

Pod Security Policies (PSPs) enable fine-grained authorization of pod creation and updates. Through a set of rules, they create security rules / defaults that a pod must meet in order to be scheduled to the cluster.

The following privileges can be controlled:
- Running of privileged containers
- Usage of host namespaces
- Usage of host networking and ports
- Usage of volume types
- Usage of the host filesystem
- White list of Flexvolume drivers
- Allocating an FSGroup that owns the pod’s volumes
- Requiring the use of a read only root file system
- The user and group IDs of the container
- Restricting escalation to root privileges
- Linux capabilities
- The SELinux context of the container
- The Allowed Proc Mount types for the container
- The AppArmor profile used by containers
- The seccomp profile used by containers
- The sysctl profile used by containers

#### Policy Reference
The kubernetes docs describe these best: https://kubernetes.io/docs/concepts/policy/pod-security-policy/#policy-reference

Notes:
- Gravity by default prevents any privileged containers from running, as a security best practice.
- AppArmor is difficult to use with gravity. If the host kernel does not have AppArmor enabled, pods with apparmor annotations will not get scheduled.
- Seccomp is also difficult, as the profile to apply is pulled from the host, and gravity doesn't currently include any aids in loading seccomp profiles for kubernetes to reference. The runtime/default profile is adequate in most cases.

#### Example PSP
A sample PSP for restricted access:
```
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: privileged
  annotations:
    seccomp.security.alpha.kubernetes.io/allowedProfileNames: '*'
spec:
  privileged: true
  allowPrivilegeEscalation: true
  allowedCapabilities:
  - '*'
  volumes:
  - '*'
  hostNetwork: true
  hostPorts:
  - min: 0
    max: 65535
  hostIPC: true
  hostPID: true
  runAsUser:
    rule: 'RunAsAny'
  seLinux:
    rule: 'RunAsAny'
  supplementalGroups:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
  ```

#### Exercise: kubernetes PSP example
Follow the kubernetes docs example, on creating a PSP, and how to bind specific accounts: https://kubernetes.io/docs/concepts/policy/pod-security-policy/#example

### Quality of Service and Limits
Reference: https://kubernetes.io/docs/tasks/configure-pod-container/quality-service-pod/
Reference: https://medium.com/google-cloud/quality-of-service-class-qos-in-kubernetes-bb76a89eb2c6


Kubernetes pods can be assigned quality of service settings, that the kubernetes scheduling algorithms consider when making scheduling decisions.

There are 3 classes:
- Guaranteed
- Burstable
- BestEffort

#### Guaranteed
Pods are considered top-priority and are guaranteed to not be killed until they exceed their limits.

Conditions:
- Every Container in the Pod must have a memory limit and a memory request, and they must be the same.
- Every Container in the Pod must have a CPU limit and a CPU request, and they must be the same.

Example guaranteed pod:
```
apiVersion: v1
kind: Pod
metadata:
  name: qos-demo
  namespace: qos-example
spec:
  containers:
  - name: qos-demo-ctr
    image: nginx
    resources:
      limits:
        memory: "200Mi"
        cpu: "700m"
      requests:
        memory: "200Mi"
        cpu: "700m"
```

#### Burstable
Pods have some form of minimal resource guarantee, but can use more resources when available. Under system memory pressure, these containers are more likely to be killed once they exceed their requests and no Best-Effort pods exist.

Conditions:
- The Pod does not meet the criteria for QoS class Guaranteed.
- At least one Container in the Pod has a memory or CPU request.

Example burstable pod:
```
apiVersion: v1
kind: Pod
metadata:
  name: qos-demo-2
  namespace: qos-example
spec:
  containers:
  - name: qos-demo-2-ctr
    image: nginx
    resources:
      limits:
        memory: "200Mi"
      requests:
        memory: "100Mi"
```

#### Best Effort
Pods will be treated as lowest priority. Processes in these pods are the first to get killed if the system runs out of memory. These containers can use any amount of free memory in the node though.

For a Pod to be given a QoS class of BestEffort, the Containers in the Pod must not have any memory or CPU limits or requests.

Example best-effort pod:
apiVersion: v1
kind: Pod
metadata:
  name: qos-demo-3
  namespace: qos-example
spec:
  containers:
  - name: qos-demo-3-ctr
    image: nginx

### Pod Priority and Preemption
Reference: https://kubernetes.io/docs/concepts/configuration/pod-priority-preemption/

Pod priority is an indicator to the kubernetes scheduler how important a particular pod is, so that under resource pressure low priority tasks can be killed to make room for higher priority tasks.

Pods with lower numeric priorities will be preempted by pods with higher numeric priorities, with 1000000 considered the highest priority, equivalent with critical system tasks.

Kubernetes 1.11 and higher include a flag on the priorityClass that disables preemption of lower priority tasks, and will wait for scheduling until sufficient resources are free.

Example non-preempting priority class:
```
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority-nonpreempting
value: 1000000
preemptionPolicy: Never
globalDefault: false
description: "This priority class will not cause other pods to be preempted."
```

To use a priority class, specify the priorityClassName field in the pod spec or pod template:
```
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    env: test
spec:
  containers:
  - name: nginx
    image: nginx
    imagePullPolicy: IfNotPresent
  priorityClassName: high-priority
```

### Network Policy
Reference: https://kubernetes.io/docs/concepts/services-networking/network-policies/
Reference: https://kubernetes.io/docs/tasks/administer-cluster/network-policy-provider/kube-router-network-policy/

Note: gravity does not include a network policy controller by default. A Network policy controller such as kube-router can be added on top of a gravity cluster.

## Cloud Security
### The metadata API
Most cloud providers provide an API to each cloud instance, that can be used to control aspects of the cloud environment. When running untrusted software within a kubernetes cluster, or by proxying external traffic through a kubernetes service, it's easy to accidentally grant an external user access to this API. There are controllers / firewalls that can be installed ontop of a kubernetes cluster, which are cloud specific.

## Tools
An ecosystem like kubernetes, with inherent complexity also creates an ecosystem for tools to help navigate and implement sound policies.

Some of the tools we find helpful at gravitational are:
- KubeAudit: https://github.com/Shopify/kubeaudit
- KubeSec: https://kubesec.io
- KubeIAM: https://github.com/uswitch/kiam
- Trivy: https://github.com/aquasecurity/trivy
- Clair: https://github.com/coreos/clair
  - Clair doesn't tell you when it doesn't work!!
- kubectl-who-can: https://github.com/aquasecurity/kubectl-who-can
- rakkess: https://github.com/corneliusweig/rakkess
- rback: https://github.com/team-soteria/rback
