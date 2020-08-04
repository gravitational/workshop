#!/bin/bash

echo "ROLLING BACK SCENARIO #6..."

sudo rm /etc/resolv.conf >/dev/null 2>&1
sudo mv /etc/resolv.conf{_original,} >/dev/null 2>&1

echo "SCENARIO #6 ROLLED BACK"
