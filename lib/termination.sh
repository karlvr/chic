#!/bin/bash -eu
# Termination

prompt_yn() {
	local prompt_message="$1"
	local prompt_response=""
	while [ "$prompt_response" != "y" -a "$prompt_response" != "n" ]; do
		read -e -p "$prompt_message (y/n) " prompt_response
	done
	echo "$prompt_response"
}

terminate() {
	unclean="${1:-}"

	if [ ! -z "$unclean" -a -z "$noninteractive" ]; then
		local delete_response=$(prompt_yn "Delete stack")
		if [ "$delete_response" == "n" ]; then
			return 0
		fi
	fi

	if [ ! -z "${image_stack_name:-}" ]; then
		echo "* Deleting stack..." >&2
		aws cloudformation delete-stack $global_aws_options --stack-name "$image_stack_name"
	fi

	if [ ! -z "${archive:-}" ]; then
		rm -f "$archive"
	fi
	if [ ! -z "${working_dir:-}" ]; then
		rm -rf "$working_dir"
	fi
}

trap ctrl_c INT

ctrl_c() {
	echo "* Cancelling" >&2
	terminate y
	exit 1
}
