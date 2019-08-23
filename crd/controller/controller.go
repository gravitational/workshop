/*
Copyright 2019 Gravitational, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package main

import (
	"fmt"
	"time"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/util/wait"
	"k8s.io/client-go/tools/cache"
	"k8s.io/client-go/util/workqueue"

	corev1 "k8s.io/api/core/v1"
	coreinformer "k8s.io/client-go/informers/core/v1"
	coreclient "k8s.io/client-go/kubernetes"
	corelister "k8s.io/client-go/listers/core/v1"

	nginxv1 "github.com/gravitational/workshop/crd/controller/pkg/apis/nginxcontroller/v1"
	nginxclient "github.com/gravitational/workshop/crd/controller/pkg/generated/clientset/versioned"
	nginxinformer "github.com/gravitational/workshop/crd/controller/pkg/generated/informers/externalversions/nginxcontroller/v1"
	nginxlister "github.com/gravitational/workshop/crd/controller/pkg/generated/listers/nginxcontroller/v1"

	"github.com/gravitational/trace"
	"github.com/sirupsen/logrus"
)

// NewNginxController creates a new instance of a controller that watches
// custom Nginx resources and creates nginx pods for them.
func NewNginxController(
	kubeClient coreclient.Interface,
	nginxClient nginxclient.Interface,
	podInformer coreinformer.PodInformer,
	nginxInformer nginxinformer.NginxInformer,
) (*nginxController, error) {
	controller := &nginxController{
		queue: workqueue.NewNamedRateLimitingQueue(
			workqueue.DefaultControllerRateLimiter(), "Nginxes"),
		nginxClient:   nginxClient,
		nginxInformer: nginxInformer,
		nginxLister:   nginxInformer.Lister(),
		kubeClient:    kubeClient,
		podLister:     podInformer.Lister(),
	}

	// Register an event handler that fires an event every time a new
	// custom Nginx resource is created in the cluster.
	nginxInformer.Informer().AddEventHandler(cache.ResourceEventHandlerFuncs{
		// When a new Nginx resource is created, add it to the internal
		// work queue for processing.
		AddFunc: controller.enqueueNginx,
		// UpdateFunc handler can also be defined to handle updates
		// to Nginx resources.
		//
		// DeleteFunc handler is not required in this case because
		// created pods get an owner reference that points to their
		// parent Nginx resource so they get deleted in cascading
		// fashion.
	})

	return controller, nil
}

type nginxController struct {
	queue         workqueue.RateLimitingInterface
	nginxClient   nginxclient.Interface
	nginxInformer nginxinformer.NginxInformer
	nginxLister   nginxlister.NginxLister
	kubeClient    coreclient.Interface
	podLister     corelister.PodLister
}

// Run launches the Nginx controller.
//
// It is a blocking call.
func (c *nginxController) Run(stopCh <-chan struct{}) error {
	// Make sure to clean up the queue when done.
	defer c.queue.ShutDown()
	logrus.Info("Controller starting.")
	// Launch the Nginx informer. It will watch for Nginx resources and
	// call respective handlers registered above.
	go c.nginxInformer.Informer().Run(stopCh)
	// Before launching the worker, wait for informer's caches to sync.
	if !cache.WaitForCacheSync(stopCh, c.nginxInformer.Informer().HasSynced) {
		return trace.BadParameter("failed to sync informer cache")
	}
	// Launch the worker to process Nginx resources.
	wait.Until(c.runWorker, time.Second, stopCh)
	return nil
}

// runWorker iterates over the work queue and processes its items.
func (c *nginxController) runWorker() {
	for c.processWorkItem() {
	}
}

// processWorkItem processes a single item from the work queue.
func (c *nginxController) processWorkItem() bool {
	keyI, shutdown := c.queue.Get()
	if shutdown {
		return false
	}
	defer c.queue.Done(keyI)
	// The key is expected to be a string of format "namespace/name".
	key, ok := keyI.(string)
	if !ok {
		c.queue.Forget(keyI)
		logrus.Errorf("Expected string key, got: %T.", keyI)
		return true
	}
	// Handle the new Nginx resource and put it back in the queue with
	// some backoff in case of any errors for re-processing.
	err := c.handleItem(key)
	if err != nil {
		c.queue.AddRateLimited(key)
		logrus.WithField("key", key).WithError(err).Error("Failed to process.")
		return true
	}
	// The resource has been processed successfully, remove its rate-limiting
	// context.
	c.queue.Forget(keyI)
	return true
}

// handleItem creates a new nginx pod for the specified Nginx resource.
func (c *nginxController) handleItem(key string) error {
	// Convert the namespace/name string into a distinct namespace and name
	namespace, name, err := cache.SplitMetaNamespaceKey(key)
	if err != nil {
		logrus.WithField("key", key).WithError(err).Error("Invalid key format.")
		return nil
	}
	logrus.WithField("key", key).Info("New resource")
	// Retrieve the custom Nginx resource.
	nginx, err := c.nginxLister.Nginxes(namespace).Get(name)
	if err != nil {
		return trace.Wrap(err)
	}
	// See if there is already a pod for this Nginx resource. We're using
	// status.podName field for that.
	podName := nginx.Status.PodName
	if podName != "" {
		// The status field on the Nginx resource indicates that it
		// already manages a pod. Ideally, here we would check that
		// the pod is actually running (it may have been deleted)
		// and re-create it if it's not.
		logrus.WithField("key", key).Infof("Resource already manages pod %v.", podName)
		return nil
	}
	// There's no pod for this Nginx resource yet, create it.
	pod, err := c.kubeClient.CoreV1().Pods(namespace).Create(newPod(nginx))
	if err != nil {
		return trace.Wrap(err)
	}
	logrus.WithField("key", key).Infof("Created pod %v.", pod.Name)
	// Update the status field on the Nginx resource to indicate the name
	// of its child pod.
	nginxCopy := nginx.DeepCopy()
	nginxCopy.Status.PodName = pod.Name
	_, err = c.nginxClient.TrainingV1().Nginxes(namespace).Update(nginxCopy)
	if err != nil {
		return trace.Wrap(err)
	}
	return nil
}

// enqueueNginx places the provided nginx resource into the controller's work queue.
func (c *nginxController) enqueueNginx(obj interface{}) {
	key, err := cache.MetaNamespaceKeyFunc(obj)
	if err != nil {
		logrus.WithError(err).Errorf("Failed to parse key: %v.", obj)
	} else {
		c.queue.Add(key)
	}
}

// newPod generates a pod spec from the provided Nginx custom resource spec.
func newPod(nginx *nginxv1.Nginx) *corev1.Pod {
	return &corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			GenerateName: nginx.Name + "-",
			Namespace:    nginx.Namespace,
			OwnerReferences: []metav1.OwnerReference{
				*metav1.NewControllerRef(nginx, nginxv1.SchemeGroupVersion.WithKind("Nginx")),
			},
		},
		Spec: corev1.PodSpec{
			Containers: []corev1.Container{
				{
					Name:  "nginx",
					Image: fmt.Sprintf("nginx:%v", nginx.Spec.Version),
				},
			},
		},
	}
}
