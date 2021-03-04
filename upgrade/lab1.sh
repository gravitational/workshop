#!/bin/bash
echo "
OBJECTIVE
---------

Perform a manual upgrade of the installed cluster.


INSTRUCTIONS
------------

From the upgrade tarball, upload the new version to the cluster:

    sudo ./upload

Trigger the operation in manual mode:

    sudo ./gravity upgrade --manual

Inspect the operation plan and step through the manual upgrade until completion.

After successful upgrade, uninstall the cluster by running the following command on all three of the nodes:

    sudo gravity system uninstall --confirm

Then reset the cluster to the original v1 state from lab0.
"
