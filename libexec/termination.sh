#!/bin/bash -eu
# Termination

terminate() {
	prompt="${1:-}"
	deleteStacks "$prompt"

	if [ ! -z "${known_hosts_file:-}" ]; then
		rm -f "$known_hosts_file"
	fi
}

trap ctrl_c INT

ctrl_c() {
	echo "* Cancelling" >&2
	terminate y
	exit 1
}

trap 'error_trap ${LINENO}' ERR

error_trap() {
	echo "* Failed: exit status $?"
	terminate y
	exit 1
}
