#!/bin/bash -eu
###############################################################################
# Chic bootstrap

###############################################################################
# Bootstrap
# Run the bootstrap script

set +eu
{{BOOTSTRAP_SCRIPT}}
set -eu

###############################################################################
# Image
apt-get install -y awscli

export AWS_ACCESS_KEY_ID={{BOOTSTRAP_AWS_ACCESS_KEY_ID}}
export AWS_SECRET_ACCESS_KEY={{BOOTSTRAP_AWS_SECRET_ACCESS_KEY}}
export AWS_DEFAULT_REGION={{BOOTSTRAP_AWS_REGION}}

instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
aws ec2 create-image --instance-id $instance_id --name "chic-$instance_id" \
	--description "AMI built using Chic"
