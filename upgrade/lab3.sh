#!/bin/bash

if [ -z "$1" ]; then
    echo "Please pass a path to the unpacked upgrade tarball, for example: $0 /home/ubuntu/v2"
    exit 1
fi

echo "ACTIVATING SCENARIO #3...
"

path="$1"
sudo $path/upload
sudo mkdir -p /var/lib/gravity/site/update
service=$(sudo systemctl --all | grep teleport | awk '{print $1}')
sudo systemctl stop $service

echo "
SCENARIO #3 ACTIVATED.

OBJECTIVE
---------

You will encounter an issue when trying to launch an upgrade. Your goal is
to fix the issue and successfully launch a upgrade in manual mode:

    cd $1
    sudo ./gravity upgrade --manual

Once the upgrade has successfully launched in manual mode, rollback the
operation so the cluster returns to the active state:

    sudo ./gravity rollback
"
