#!/bin/bash -eu

ssh_username=
environment=
root_volume_device_name=
root_volume_size=
distro=

FROM() {
	ensureNotStartedImageBuild FROM

	if [ -z "$ami" ]; then
		if [[ "$1" =~ ^ami- ]]; then
			ami="$1"
			echo "  * Source AMI: $ami" >&2
		else
			echo "  * Searching for Source AMI: $*" >&2
			distro="$1"
			shift
			
			eval "ami=\$(chic_find_image_$distro \"$@\")"
			if [ -z "$ami" ]; then
				echo "  * Cannot find Source AMI for search query" >&2
				terminate y
				exit 1
			else
				echo "  * Source AMI: $ami" >&2
			fi
		fi
	else
		echo "  * Source AMI: $ami [overriden]" >&2
	fi
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

VOLUME() {
	ensureNotStartedImageBuild VOLUME

	local option
	for option in $* ; do
		local option_key
		local option_value
		option_key=$(echo "$option" | cut -d= -f1)
		option_value=$(echo "$option" | cut -d= -f2)


		if [ "$option_key" == "name" ]; then
			if [ -z "$root_volume_device_name" ]; then
				root_volume_device_name="$option_value"
				echo "  * Volume: name=$root_volume_device_name" >&2
			else
				echo "  * Volume: name=$root_volume_device_name [overriden]" >&2
			fi
		elif [ "$option_key" == "size" ]; then
			if [ -z "$root_volume_size" ]; then
				root_volume_size="$option_value"
				echo "  * Volume: size=${root_volume_size}GB" >&2
			else
				echo "  * Volume: size=${root_volume_size}GB [overriden]" >&2
			fi
		else
			echo "  * VOLUME: Unsupported option: $option" >&2
			terminate
			exit 1
		fi
	done
}

NAME() {
	if [ -z "$name" ]; then
		name="$*"
		echo "  * Name: $name" >&2
	else
		echo "  * Name: $name [overriden]" >&2
	fi
}

TAG() {
	if [ -z "$1" -o -z "$2" ]; then
		echo "TAG <key> <value>" &>2
		terminate
		exit 1
	fi

	tags="${tags:-} Key=$1,Value=\"$2\""
}

SSH_USERNAME() {
	ssh_username="$1"
	echo "  * SSH username: $ssh_username" >&2
	
	if [ -n "${image_stack_name:-}" ]; then
		waitForSsh
	fi
}

ENV() {
	local key="${1:-}"
	local value="${2:-}"

	if [ -z "$key" ]; then
		echo "ENV <key> [<value>]" >&2
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
		if [ -z "$value" ]; then
			if [ "$noninteractive" == 1 ]; then
				echo "  * ENV: $key not found in environment and does not have a default value" >&2
				terminate
				exit 1
			elif [[ "$key" =~ PASSWORD ]]; then
				read -s -p "  * ENV: Please enter value for $key: " value
				echo >&2
			else
				read -p "  * ENV: Please enter value for $key: " value
			fi
		fi

		eval "$key"="$value"
		environment="$environment $key=\"$value\""
		if [[ "$key" =~ PASSWORD ]]; then
			echo "  * ENV: $key=[REDACTED]" >&2
		else
			echo "  * ENV: $key=$value" >&2
		fi
	else
		environment="$environment $key=\"$current_value\""
		if [[ "$key" =~ PASSWORD ]]; then
			echo "  * ENV: $key=[REDACTED]" >&2
		else
			echo "  * ENV: $key=$current_value" >&2
		fi
	fi
}

COPY() {
	local chown=
	while getopts ":o:" opt; do
		case $opt in
			o)
				chown="$OPTARG"
				;;
			\?)
				echo "Invalid option: -$OPTARG" >&2
				terminate y
				exit 1
				;;
		esac
	done

	shift $((OPTIND-1))

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

	local rsync_options=
	if [ -n "$chown" ]; then
		rsync_options=--chown="$chown"
	fi
	rsync -rlptD -e "ssh $ssh_options" --rsync-path="sudo rsync" $rsync_options \
		--exclude "**/.git*" --exclude "**/.hg*" --exclude "**/.DS_Store" \
		"${@:1:$#-1}" $ssh_username@$instance_public_ip:"$dest" >&2
	if [ $? != 0 ]; then
		echo "Failed to copy files to the remote instance" >&2
		terminate y
		exit 1
	fi

	set -e
}

START() {
	ensureStartedImageBuild
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

MANUAL() {
	ensureStartedImageBuild

	set +e
	ssh -t $ssh_options $ssh_username@$instance_public_ip
	if [ $? != 0 ]; then
		echo "Failed to run commands on the remote instance" >&2
		terminate y
		exit 1
	fi
	set -e
}
