# Kubernetes based Application Security Patterns

... and anti-patterns.

This workshop task will explore security concepts and the kubernetes primitives for aiding in secure application development.

## Kubernetes security primitives
Kubernetes provides a number of security primitives, that allow for an application to indicate what access it should have to the system.

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
automountServiceAccountToken: false
EOF
```

Each namespace automatically has a default serviceAccount called `default`

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
- Namespaces resources (like pods) across all namespaces (`kubectl get pods --all-namespaces`)

#### RoleBinding and ClusterRoleBinding
RoleBinding and ClusterRoleBinding create the links between users or groups, and the roles they're allowed to use.

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
`kubectl exec -it rbac-example kubectl -- auth can-i --list`

### Authentication
TODO: Refer to use creation in gravity101 and how to connect to a gravity cluster.

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

Securipty Properties:
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



### Quality of Service and Limits

### Network Policy

## Container Security
- Supply chain / notary
- Vulnerability scanning
- image signing
- privileged users

## Crypto Right Answers

## Tools


## 12 Factor Apps