#!/bin/bash

echo "ACTIVATING SCENARIO #6...
"

sudo mv /etc/resolv.conf{,_original} >/dev/null 2>&1
sudo touch /etc/resolv.conf >/dev/null 2>&1

echo "
SCENARIO #6 ACTIVATED.

OBJECTIVE
---------

The upgrade process and requirements have now been tampered.

You should now start with the usual upgrade process.

Your goal is to inspect the upgrade process as it proceeds and fix issues.

Once you have executed a few upgrade phases, rollback the cluster to the original state.

    cd $1
    sudo ./gravity rollback
"
