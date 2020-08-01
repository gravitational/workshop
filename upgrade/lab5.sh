#!/bin/bash

echo "ACTIVATING SCENARIO #5...
"

path="$1"
sudo $path/upload
sudo $path/gravity upgrade --manual
sudo $path/gravity system status-reset --confirm >/dev/null 2>&1

echo "
SCENARIO #5 ACTIVATED.

OBJECTIVE
---------

The upgrade process and requirements have now been tampered.

Your goal is to inspect the upgrade plan and fix current issues.
"
