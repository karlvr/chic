#!/bin/bash -eu

describe_instance_status() {
	local instance_id
	instance_id="$1"

	aws ec2 describe-instances $global_aws_options --instance-ids "$instance_id" \
		--output text --query Reservations[0].Instances[0].State.Name
}

waitForInstanceStopped() {
	local instance_id
	instance_id="$1"

	local instance_state
	instance_state=$(describe_instance_status $instance_id)

	if [ -z "$instance_state" -o "$instance_state" != "stopped" ]; then
		echo -n "* Waiting for instance to stop: $instance_id" >&2
		while [ -z "$instance_state" -o "$instance_state" != "stopped" ]; do
			sleep 5
			echo -n . >&2
			instance_state=$(describe_instance_status "$instance_id")
		done
		echo >&2
	fi
}

buildImage() {
	ensureStartedImageBuild

	echo "* Stopping image build instance" >&2
	aws ec2 stop-instances $global_aws_options \
		--instance-id $instance_id >/dev/null
	waitForInstanceStopped $instance_id
	
	echo "* Creating AMI" >&2

	if [ -z "${name:-}" ]; then
		name="chic-{{timestamp}}"
	fi
	name=$(echo "$name" | sed -e "s/{{timestamp}}/$date_stamp/")

	set +e
	new_ami_id=$(aws ec2 create-image $global_aws_options \
		--instance-id $instance_id --name "$name" \
		--description "AMI built using Chic" \
		--query ImageId --output text)
	if [ $? != 0 ]; then
		echo "Failed to create image" >&2
		terminate y
		exit 1
	fi

	# Add tags
	if [ ! -z "$tags" ]; then
		echo "* Tagging AMI" >&2
		aws ec2 create-tags $global_aws_options --resources $new_ami_id --tags $tags
		if [ $? != 0 ]; then
			echo "Failed to tag image" >&2
		fi
	fi

	new_ami_state=
	echo -n "* Waiting for AMI to complete" >&2
	while [ -z "$new_ami_state" -o "$new_ami_state" == "pending" ]; do
		sleep 10
		echo -n . >&2
		new_ami_state=$(aws ec2 describe-images $global_aws_options --image-ids "$new_ami_id" --query Images[].State --output text)
		if [ $? != 0 ]; then
			echo
			echo "Failed to get status of AMI: $new_ami_id" >&2
			terminate y
			exit 1
		fi
	done
	echo >&2
}

chic_find_image() {
	local owner=
	local architecture=x86_64
	local root_device_type=ebs
	local image_type=machine
	local hypervisor=xen
	local virtualization_type=hvm
	local volume_type=
	local release=
	local tag_filters=

	local option
	for option in "$@" ; do
		local option_key
		local option_value
		option_key=$(echo "$option" | cut -d= -f1)
		option_value=$(echo "$option" | cut -d= -f2)

		if [ "$option_key" == "owner" ]; then
			owner="$option_value"
		elif [ "$option_key" == "architecture" ]; then
			architecture="$option_value"
		elif [ "$option_key" == "root_device_type" ]; then
			root_device_type="$option_value"
		elif [ "$option_key" == "image_type" ]; then
			image_type="$option_value"
		elif [ "$option_key" == "hypervisor" ]; then
			hypervisor="$option_value"
		elif [ "$option_key" == "virtualization_type" ]; then
			virtualization_type="$option_value"
		elif [ "$option_key" == "volume_type" ]; then
			volume_type="$option_value"
		elif [ "$option_key" == "release" ]; then
			release="$option_value"
		elif [[ "$option_key" =~ ^tag: ]]; then
			tag_filters="$tag_filters \"Name=$option_key,Values=$option_value\""
		else
			echo "  * chic_find_image: Unsupported filter option: $option" >&2
			return 0
		fi
	done

	local filters=

	if [ ! -z "$architecture" ]; then
		filters="$filters \"Name=architecture,Values=$architecture\""
	fi
	if [ ! -z "$root_device_type" ]; then
		filters="$filters \"Name=root-device-type,Values=$root_device_type\""
	fi
	if [ ! -z "$image_type" ]; then
		filters="$filters \"Name=image-type,Values=$image_type\""
	fi
	if [ ! -z "$hypervisor" ]; then
		filters="$filters \"Name=hypervisor,Values=$hypervisor\""
	fi
	if [ ! -z "$virtualization_type" ]; then
		filters="$filters \"Name=virtualization-type,Values=$virtualization_type\""
	fi
	if [ ! -z "$volume_type" ]; then
		filters="$filters \"Name=block-device-mapping.volume-type,Values=$volume_type\""
	fi
	if [ ! -z "$release" ]; then
		filters="$filters \"Name=name,Values=ubuntu/images/*$release*\""
	fi
	if [ ! -z "$tag_filters" ]; then
		filters="$filters $tag_filters"
	fi

	# Find AMI
	eval aws ec2 describe-images $global_aws_options \
		--filters $filters \
		--owners "$owner" \
		--output text --query 'Images[].[ImageId,CreationDate,Name,Description]' \
		| sort -k2 -r | head -n 1 | cut -f 1
}

chic_find_image_ubuntu() {
	# Use official Canonical owner id
	chic_find_image owner=099720109477 "$@"
}

chic_find_image_self() {
	chic_find_image owner=self "$@"
}
