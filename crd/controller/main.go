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
	"flag"
	"os"
	"time"

	kubeinformers "k8s.io/client-go/informers"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"

	clientset "github.com/gravitational/workshop/crd/controller/pkg/generated/clientset/versioned"
	informers "github.com/gravitational/workshop/crd/controller/pkg/generated/informers/externalversions"

	"github.com/gravitational/trace"
	"github.com/sirupsen/logrus"
)

func init() {
	flag.StringVar(&kubeconfig, "kubeconfig", "",
		"Path to a kubeconfig. Only required if out-of-cluster.")
	flag.StringVar(&masterURL, "master", "",
		"The address of the Kubernetes API server. Overrides any value in kubeconfig. Only required if out-of-cluster.")
	flag.BoolVar(&debug, "debug", false,
		"Enables debug logging.")
}

var (
	kubeconfig string
	masterURL  string
	debug      bool
)

func main() {
	flag.Parse()
	logrus.StandardLogger().SetHooks(make(logrus.LevelHooks))
	logrus.SetFormatter(&logrus.TextFormatter{})
	logrus.SetOutput(os.Stderr)
	if debug {
		logrus.SetLevel(logrus.DebugLevel)
	}
	if err := run(); err != nil {
		logrus.WithError(err).Error("Controller exited with error.")
		os.Exit(255)
	}
}

func run() error {
	cfg, err := clientcmd.BuildConfigFromFlags(masterURL, kubeconfig)
	if err != nil {
		return trace.Wrap(err, "error building Kubernetes config")
	}

	kubeClient, err := kubernetes.NewForConfig(cfg)
	if err != nil {
		return trace.Wrap(err, "error building Kubernetes client")
	}

	nginxClient, err := clientset.NewForConfig(cfg)
	if err != nil {
		return trace.Wrap(err, "error building Nginx client")
	}

	kubeInformerFactory := kubeinformers.NewSharedInformerFactory(
		kubeClient, time.Second*30)
	nginxInformerFactory := informers.NewSharedInformerFactory(
		nginxClient, time.Second*30)

	controller, err := NewNginxController(kubeClient, nginxClient,
		kubeInformerFactory.Core().V1().Pods(),
		nginxInformerFactory.Training().V1().Nginxes())
	if err != nil {
		return trace.Wrap(err, "error creating Nginx controller")
	}

	stopCh := make(chan struct{})
	kubeInformerFactory.Start(stopCh)
	nginxInformerFactory.Start(stopCh)

	err = controller.Run(stopCh)
	if err != nil {
		return trace.Wrap(err, "error running Nginx controller")
	}

	close(stopCh)
	return nil
}
