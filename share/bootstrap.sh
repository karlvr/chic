#!/bin/bash -eu

export DEBIAN_FRONTEND=noninteractive

apt-get update && apt-get dist-upgrade
apt-get install -y nginx
