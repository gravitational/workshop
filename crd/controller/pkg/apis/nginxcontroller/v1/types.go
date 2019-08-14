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

package v1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// +genclient
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// Nginx describes a custom nginx resource kind.
type Nginx struct {
	// TypeMeta contains the resource API version and kind.
	metav1.TypeMeta `json:",inline"`
	// ObjectMeta contains the resource metadata.
	metav1.ObjectMeta `json:"metadata,omitempty"`
	// Spec is the resource spec.
	Spec NginxSpec `json:"spec"`
	// Status contains the resource runtime information.
	Status NginxStatus `json:"status"`
}

// NginxSpec is the spec for an nginx resource.
type NginxSpec struct {
	// Version is the nginx version.
	Version string `json:"version"`
}

// NginxStatus is the status for a nginx resource.
type NginxStatus struct {
	// PodName is the name of the controlled pod.
	PodName string `json:"podName"`
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// NginxList is a list of nginx resources.
type NginxList struct {
	// TypeMeta contains the resource API version and kind.
	metav1.TypeMeta `json:",inline"`
	// ListMeta contains the list metadata.
	metav1.ListMeta `json:"metadata"`
	// Item is a collection of Nginx resources.
	Items []Nginx `json:"items"`
}
