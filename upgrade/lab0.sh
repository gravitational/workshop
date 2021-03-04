#!/bin/bash
echo "
OBJECTIVE
---------

Prepare the lab environment by installing a three-node cluster.


INSTRUCTIONS
------------

On the first of the three nodes execute the install command from the v1 installer:

    sudo ./gravity install --cluster=test --cloud-provider=generic --token=qwe123 --flavor=three

On the other two nodes execute the join command:

    sudo ./gravity join <first-node-ip> --token=qwe123 --role=node

Verify the cluster is up and running after installation.
"
