#!/bin/bash

if [ -z "$1" ]; then
    echo "Please pass a path to the unpacked upgrade tarball, for example: ./lab2.sh /home/ubuntu/gravity-5.5.49"
    exit 1
fi

echo "ACTIVATING SCENARIO #3...
"

path="$1"
sudo $path/upload
sudo mkdir -p /var/lib/gravity/site/update
sudo systemctl stop gravity__gravitational.io__teleport__3.0.5.service

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

    sudo ./gravity rollback"
