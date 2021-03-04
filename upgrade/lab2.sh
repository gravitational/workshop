#!/bin/bash

if [ -z "$1" ]; then
    echo "Please pass a path to the unpacked upgrade tarball, for example: $0 /home/ubuntu/v2"
    exit 1
fi

echo "ACTIVATING SCENARIO #2...
"

path="$1"
sudo $path/upload
sudo mkdir -p /var/lib/gravity/site/update
sudo fallocate -l1T /var/lib/gravity/planet/share/dummy >/dev/null 2>&1

echo "
SCENARIO #2 ACTIVATED

OBJECTIVE
---------

You will encounter an issue when trying to launch an upgrade. Your goal is
to fix the issue and successfully launch a upgrade in manual mode:

    cd $1
    sudo ./gravity upgrade --manual

Once the upgrade has successfully launched in manual mode:

  * Manually step through the phases until the system-upgrade phase.
  * Perform a rollback.
"
