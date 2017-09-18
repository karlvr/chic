#!/bin/bash -eu

ami=
ssh_username=ubuntu

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

	# https://stackoverflow.com/a/26059282/1951952
	[[ $# -gt 0 ]] && exec <<< "$@"

	set +e
	ssh -T $ssh_options $ssh_username@$instance_public_ip sudo -i >&2
	if [ $? != 0 ]; then
		echo "Failed to run commands on the remote instance" >&2
		terminate y
		exit 1
	fi
	set -e
}
