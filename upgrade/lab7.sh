#!/bin/bash

echo "ACTIVATING SCENARIO #7...
"

sudo systemctl disable --now chronyd >/dev/null 2>&1
sudo systemctl disable --now ntp >/dev/null 2>&1
sudo date --set '2000-01-01 00:00:00 UTC' >/dev/null 2>&1

echo "
SCENARIO #7 ACTIVATED.

OBJECTIVE
---------

The system and requirements have now been tampered.

Your goal is to run the usual upgrade process and fix current issues.
"
