#!/bin/bash -eu

set +u
profile="$CHIC_PROFILE"
region="$CHIC_REGION"
set -u

name=
instance_type=
tags=
noninteractive=

usage() {
	echo "usage: $0 [-i <instance type>]" >&2
	echo "          [-n <output ami name>] [-t <tag key>=<value>]+" >&2
	echo "          [-p <profile>] [-r <region>]" >&2
	echo "          [-s <existing image build stack>]" >&2
	echo "          [-d] [-b] <basedir | Chicfile>" >&2
	echo >&2
	echo " -b Non-interactive mode" >&2
}

while getopts ":i:n:t:p:r:s:b" opt; do
	case $opt in
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
		s)
			existing_image_stack_name="$OPTARG"
			;;
		b)
			noninteractive=1
			;;
    	\?)
	      	echo "Invalid option: -$OPTARG" >&2
	      	;;
	esac
done

shift $((OPTIND-1))
