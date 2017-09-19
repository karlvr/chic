#!/bin/bash -eu

ami=
ssh_username=ubuntu
environment=

FROM() {
	ensureNotStartedImageBuild FROM

	ami="$1"
	echo "  * Source AMI: $ami" >&2
}

INSTANCE_TYPE() {
	ensureNotStartedImageBuild INSTANCE_TYPE

	if [ -z "$instance_type" ]; then
		instance_type="$1"
		echo "  * Instance type: $instance_type" >&2
	else
		echo "  * Instance type: $instance_type [overriden]" >&2
	fi
}

NAME() {
	if [ -z "$name" ]; then
		name="$*"
		echo "  * Name: $name" >&2
	else
		echo "  * Name: $name [overriden]" >&2
	fi
}

SSH_USERNAME() {
	ensureNotStartedImageBuild SSH_USERNAME

	ssh_username="$1"
	echo "  * SSH username: $ssh_username" >&2
}

ENV() {
	local key="${1:-}"
	local value="${2:-}"

	if [ -z "$key" ]; then
		echo "ENV <key> <value>" >&2
		terminate
		exit 1
	fi

	local caps_key
	caps_key=$(echo "$key" | tr '[:lower:]' '[:upper:]')
	if [ "$key" != "$caps_key" ]; then
		echo "ENV variable names must be all caps: $key" >&2
		terminate
		exit 1
	fi

	local current_value
	eval current_value=\${$key:-}
	if [ -z "$current_value" ]; then
		eval "$key"="$value"
		environment="$environment $key=\"$value\""
		echo "  * ENV: $key=$value" >&2
	else
		environment="$environment $key=\"$current_value\""
		echo "  * ENV: $key=$current_value" >&2
	fi
}

COPY() {
	ensureStartedImageBuild

	if [ -z "$ssh_username" ]; then
		echo "Chicfile must contain SSH_USERNAME before COPY" >&2
		terminate
		exit 1
	fi

	local dest="${@:$#}"

	if [ $# -lt 2 ]; then
		echo "usage: COPY <source> ... <dest>" >&2
		return 1
	fi

	# Add leading /s
	if [[ "$dest" =~ ^[^/] ]]; then 
		dest=/$dest
	fi

	echo "  * Copying ${@:1:$#-1} to $dest" >&2
	
	set +e
	if [[ "$dest" =~ /$ ]]; then
		local dest_dir="$dest"
	else
		local dest_dir="$(dirname $dest)"
	fi
	ssh -T $ssh_options $ssh_username@$instance_public_ip sudo mkdir -p "$dest_dir" >&2

	rsync -a -e "ssh $ssh_options" --rsync-path="sudo rsync" \
		--exclude "**/.git*" --exclude "**/.hg*" --exclude "**/.DS_Store" \
		"${@:1:$#-1}" $ssh_username@$instance_public_ip:"$dest" >&2
	if [ $? != 0 ]; then
		echo "Failed to copy files to the remote instance" >&2
		terminate y
		exit 1
	fi

	set -e
}

RUN() {
	ensureStartedImageBuild

	if [ -z "$ssh_username" ]; then
		echo "Chicfile must contain SSH_USERNAME before RUN" >&2
		terminate
		exit 1
	fi

	echo "  * RUN" >&2

	local input
	if [ $# -gt 0 ]; then
		input="$@"
	elif [ ! -t 0 ]; then # Check that stdin isn't the terminal (ensure we have a here-doc)
		input=$(cat)
	else
		input=
	fi

	local input_and_environment="$environment
$input"

	set +e
	ssh -T $ssh_options $ssh_username@$instance_public_ip sudo -i >&2 <<<"$input_and_environment"
	if [ $? != 0 ]; then
		echo "Failed to run commands on the remote instance" >&2
		terminate y
		exit 1
	fi
	set -e
}
