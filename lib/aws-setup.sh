#!/bin/bash -eu

# AWS configuration
global_aws_options=
if [ ! -z "${profile:-}" ]; then
	global_aws_options="$global_aws_options --profile $profile"
fi
if [ ! -z "${region:-}" ]; then
	global_aws_options="$global_aws_options --region $region"
fi

# Persistent configuration
set +e
access_key=$(aws configure get aws_access_key_id $global_aws_options)
if [ -z "$region" ]; then
	region=$(aws configure get region $global_aws_options)
fi
set -e

if [ -z "$region" ]; then
	echo "Cannot determine region, either provide profile or region as command-line arguments" >&2
	terminate
	exit 1
fi

conf_dir="$HOME/.chic/${access_key}/${region}"
mkdir -p "$conf_dir"

#username=$(aws iam get-user $global_aws_options --query User.UserName --output text)

settings_file="$conf_dir/settings.sh"
keypair_file="$conf_dir/keypair.pem"
key_name=

if [ -f "$settings_file" ]; then
	. "$settings_file"
fi

if [ -z "$key_name" -o ! -f "$keypair_file" ]; then
	key_name="chic-key-pair-${date_stamp}"
	echo "* Creating keypair: $key_name" >&2
	aws ec2 create-key-pair $global_aws_options --key-name "$key_name" --output text --query KeyMaterial > "$keypair_file"
	chmod 600 "$keypair_file"
	cat > "$settings_file" <<EOF
key_name="$key_name"
EOF
fi

ssh_options="-i \"$keypair_file\" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
