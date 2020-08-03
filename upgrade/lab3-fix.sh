#!/bin/bash
echo "ROLLING BACK SCENARIO #3..."
sudo systemctl start gravity__gravitational.io__teleport__3.0.5.service
echo "SCENARIO #3 ROLLED BACK"
