# Kubernetes Custom Resources

Custom resources allow to extend Kubernetes API with additional types not
available in the default Kubernetes distribution.

Like native types, such as `Pod`, `Deployment` or `Service`, custom resources
become first-class citizens in a Kubernetes cluster and can be queried via API
and manipulated by `kubectl`.

## Creating Custom Resource Definition

Before a custom resource can be created, we need to let Kubernetes know what
the new resource kind is, what its spec looks like, how to validate its fields
and so on.

Kubernetes provides an easy declarative way of doing so via a special resource
called `CustomResourceDefinition`, or CRD. Let's create a CRD spec that
describes a new resources called `Nginx`:

```shell
$ cat ~/workshop/crd/assets/crd.yaml
```

```yaml
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: nginxes.training.example.com
spec:
  group: training.example.com
  version: v1
  scope: Namespaced
  names:
    kind: Nginx
    plural: nginxes
    singular: nginx
    shortNames:
      - ng
  validation:
    openAPIV3Schema:
      required: ["spec"]
      properties:
        spec:
          required: ["version"]
          properties:
            version:
              type: "string"
```

## Registering Custom Resource

Now that the spec for our new resource has been defined, we need to register
it with the Kubernetes API server.

To do that, simply create the CRD resource:

```shell
$ kubectl create -f ~/workshop/crd/assets/crd.yaml
```

CRDs themselves are global (not namespaced) resources and all currently
registered custom types can be viewed using:

```shell
$ kubectl get crd
```

## Defining Custom Resource

Now that the custom type has been registered, we can create our custom resource.

Let's define its spec:

```shell
$ cat ~/workshop/crd/assets/nginx.yaml
```

```yaml
apiVersion: training.example.com/v1
kind: Nginx
metadata:
  name: mynginx
spec:
  version: 1.17.5
```

## Creating Custom Resource

Since custom resources are treated exactly like built-in resources, to create
an instance of a new custom resource we can use:

```shell
$ kubectl create -f ~/workshop/crd/assets/nginx.yaml
```

We can also view our new custom resource in exactly the same way as the core
resource:

```shell
$ kubectl get ng
```

Or delete it:

```shell
$ kubectl delete ng/mynginx
```

## Custom Resource Controller

On their own custom resources already provide a lot of value as they allow to
store and retrieve structured data using native Kubernetes tools.

It is also possible to create a custom controller that can monitor custom
resources and take specific actions, thus unlocking true declarative
capabilities of custom resources.

When combined together, custom resources and custom controllers, constitute
what is called the Operator pattern.

Let's create a custom contoller that will be watching our `Nginx` resources
and launching respective nginx pods.

### Defining Custom Types

First we need to define the custom types for our `Nginx` resource and write
some boilerplate code to make sure they're registered with Kubernetes API
server.

The initial project structure looks like this:

```shell
$ tree ~/workshop/crd/controller/pkg/apis
~/workshop/crd/controller/pkg/apis
└── nginxcontroller
    ├── register.go
    └── v1
        ├── doc.go
        ├── register.go
        └── types.go
$ cat ~/workshop/crd/controller/pkg/apis/nginxcontroller/register.go
$ cat ~/workshop/crd/controller/pkg/apis/nginxcontroller/v1/doc.go
$ cat ~/workshop/crd/controller/pkg/apis/nginxcontroller/v1/register.go
$ cat ~/workshop/crd/controller/pkg/apis/nginxcontroller/v1/types.go
```

Note that the build tags are important as they tell Kubernetes code generator
how to process these files.

### Generating Client Stubs

Next we need to use [Kubernetes code generator](https://github.com/kubernetes/code-generator)
to generate native clients for our custom types:

```shell
$ cd ~/workshop/crd/controller
$ make generate
```

Note that you need https://github.com/kubernetes/code-generator installed in
your GOPATH for this to work.

After the generator has finished, it has produced a new package under
`~/workshop/crd/controller/pkg/generated` that contains stubs for creating
Kubernetes clients for interacting with our new `Nginx` resource and additional
utility methods.

```shell
$ tree ~/workshop/crd/controller/pkg/generated
```

### Writing Controller

Now we can use our new generated client stubs to initialize two Kubernetes
clients, for core resources and for the custom resource:

```shell
$ cat ~/workshop/crd/controller/main.go
```

And implement the actual controller logic that subscribes to `Nginx` resources
using the custom client and creates nginx pods:

```shell
$ cat ~/workshop/crd/controller/controller.go
```

Note that the controller does not subscribe to "delete" events in this case
because the custom resources become owners of their respective pods via the
`ownerReference` field and thus when they are deleted, they dependent pods
are also deleted.

### Deploying Controller

The controller is published to Gravitational's image registry so let's deploy
it in our Kubernetes cluster:

```shell
$ cat ~/workshop/crd/assets/controller.yaml
$ kubectl create -f ~/workshop/crd/assets/controller.yaml
```

Once the controller pod is up and running, let's create an `Nginx` resource
again:

```shell
$ kubectl create -f ~/workshop/crd/assets/nginx.yaml
```

And observe that the controller has spun up an nginx pod:

```shell
$ kubectl get nginx
$ kubectl get pods
```

Now attempt to delete the `Nginx` resource and see that the pod is deleted as well:

```shell
$ kubectl delete nginx/mynginx
$ kubectl get pods
```

## Useful Resources

https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/
https://kubernetes.io/docs/tasks/access-kubernetes-api/custom-resources/custom-resource-definitions/
https://github.com/kubernetes/sample-controller
https://supergiant.io/blog/custom-resources-and-custom-resource-definitions-crds-in-kubernetes/
https://medium.com/@trstringer/create-kubernetes-controllers-for-core-and-custom-resources-62fc35ad64a3
