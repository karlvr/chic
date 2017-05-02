#!/bin/bash -eu

export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get -y dist-upgrade

apt-get install -y ntp ntpdate makepasswd rsync vim iotop zip screen traceroute update-notifier-common landscape-common curl software-properties-common needrestart
