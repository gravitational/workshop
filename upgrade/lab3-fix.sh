#!/bin/bash
echo "ROLLING BACK SCENARIO #3..."

service=$(sudo systemctl --all | grep teleport | awk '{print $1}')
sudo systemctl start $service

echo "SCENARIO #3 ROLLED BACK"
