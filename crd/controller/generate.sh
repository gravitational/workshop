#!/bin/bash

PACKAGE="github.com/gravitational/workshop/crd/controller"

# run the code-generator entrypoint script
$GOPATH/src/k8s.io/code-generator/generate-groups.sh \
    "deepcopy,client,informer,lister" \
    $PACKAGE/pkg/generated \
    $PACKAGE/pkg/apis \
    nginxcontroller:v1
