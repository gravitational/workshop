#!/bin/bash

if [ -z "$1" ]; then
    echo "Please pass a path to the unpacked upgrade tarball, for example: $0 /home/ubuntu/v2"
    exit 1
fi

echo "ACTIVATING SCENARIO #5...
"

path="$1"
sudo $path/upload
sudo $path/gravity upgrade --manual
sudo $path/gravity plan execute --phase=/init >/dev/null 2>&1
sudo $path/gravity plan execute --phase=/checks >/dev/null 2>&1
sudo $path/gravity plan execute --phase=/pre-update >/dev/null 2>&1
sudo $path/gravity plan execute --phase=/bootstrap >/dev/null 2>&1
sudo $path/gravity status-reset --confirm >/dev/null 2>&1

echo "
SCENARIO #5 ACTIVATED.

OBJECTIVE
---------

The upgrade process and requirements have now been tampered.

A manual upgrade has been already started, you can check the plan with

sudo ${path}/gravity plan

and

sudo ${path}/gravity status

Your goal is to inspect the upgrade plan and status and fix current issues.

Once you have executed a few upgrade phases, rollback the cluster to the original state.

    cd $1
    sudo ./gravity rollback
"
