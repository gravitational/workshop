#!/bin/bash

if [ -z "$1" ]; then
    echo "Please pass a path to the unpacked upgrade tarball, for example: $0 /home/ubuntu/v2"
    exit 1
fi

echo "ACTIVATING SCENARIO #4...
"

path="$1"
sudo $path/upload
sudo $path/gravity upgrade --manual
sudo $path/gravity agent shutdown >/dev/null 2>&1

echo "
SCENARIO #4 ACTIVATED.

OBJECTIVE
---------

The upgrade has been launched in the manual mode.

Your goal is to inspect the upgrade plan and step through a few phases.

Once you have executed a few upgrade phases, rollback the cluster to the original state.

    cd $1
    sudo ./gravity rollback
"
