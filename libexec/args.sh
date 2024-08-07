#!/bin/bash -eu

findConfig() {
	local search_dir="$PWD"
	local config_file_name=".chic.cfg"
	while [ ! -f "$search_dir/$config_file_name" -a "$search_dir" != "/" ]; do
		search_dir="$(dirname $search_dir)"
	done

	if [ -f "$search_dir/$config_file_name" ]; then
		echo "$search_dir/$config_file_name"
	fi
}

config_file=$(findConfig)
if [ ! -z "$config_file" ]; then
	source "$config_file"
fi

profile="${CHIC_PROFILE:-}"
region="${CHIC_REGION:-}"
ami=
name=
instance_type=
tags=
noninteractive=
vpcid="${CHIC_VPC_ID:-}"
subnetid="${CHIC_SUBNET_ID:-}"

usage() {
	echo "Chic $CHIC_VERSION" >&2
	echo "usage: $0 [-a <ami>] [-i <instance type>]" >&2
	echo "          [-n <output ami name>] [-t <tag key>=<value>]+" >&2
	echo "          [-p <profile>] [-r <region>]" >&2
	echo "          [-v <vpc id>] [-s <subnet id>]" >&2
	echo "          [-e <existing image build stack>]" >&2
	echo "          [-b]" >&2
	echo "          <basedir | Chicfile>" >&2
	echo >&2
	echo " -b Non-interactive mode" >&2
}

while getopts ":a:i:n:t:p:r:s:bv:" opt; do
	case $opt in
		a)
			ami="$OPTARG"
			;;
		i)
			instance_type="$OPTARG"
			;;
	    n)
			tags="${tags:-} Key=Name,Value=\"$name\""
			;;
		t)
			tag_key=$(echo "$OPTARG" | cut -d = -f 1)
			tag_value=$(echo "$OPTARG" | cut -d = -f 2)
			tags="${tags:-} Key=$tag_key,Value=\"$tag_value\""
			;;
		p)
			profile="$OPTARG"
			;;
		r)
			region="$OPTARG"
			;;
		e)
			existing_image_stack_name="$OPTARG"
			;;
		b)
			noninteractive=1
			;;
		v)
			vpcid="$OPTARG"
			;;
    	\?)
	      	echo "Invalid option: -$OPTARG" >&2
	      	;;
	esac
done

shift $((OPTIND-1))
