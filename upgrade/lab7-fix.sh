#!/bin/bash

echo "ROLLING BACK SCENARIO #7..."

if which chronyd > /dev/null 2>&1
then
    sudo systemctl enable --now chronyd >/dev/null 2>&1
elif which ntpd > /dev/null 2>&1
then
    sudo systemctl enable --now ntp >/dev/null 2>&1
else
    echo "Please re-enable the system time correction daemon (NTP or similar)"
fi

echo "SCENARIO #6 ROLLED BACK"
