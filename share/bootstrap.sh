#!/bin/bash -eux

export DEBIAN_FRONTEND=noninteractive

ls -l -R /opt

apt-get update && apt-get dist-upgrade -y
apt-get install -y ntp ntpdate makepasswd rsync vim iotop zip screen traceroute update-notifier-common landscape-common curl software-properties-common needrestart
