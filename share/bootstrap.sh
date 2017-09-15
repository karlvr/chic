#!/bin/bash -eux

export DEBIAN_FRONTEND=noninteractive

apt-get update && apt-get dist-upgrade -y
apt-get install -y nginx
