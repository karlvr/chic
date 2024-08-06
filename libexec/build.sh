#!/bin/bash -eu

buildImageStack() {
	if [ -z "$ami" ]; then
		echo "Chicfile must contain FROM before any image manipulation functions" >&2
		terminate
		exit 1
	fi
	if [ -z "$instance_type" ]; then
		echo "Chicfile must contain INSTANCE_TYPE before any image manipulation functions" >&2
		terminate
		exit 1
	fi
	if [ -z "$vpcid" ]; then
		local vpcs
		vpcs=$(aws ec2 describe-vpcs $global_aws_options --output text --query 'Vpcs[].VpcId' --filters Name=state,Values=available Name=is-default,Values=true)
		if [ -z "$vpcs" ]; then
			vpcs=$(aws ec2 describe-vpcs $global_aws_options --output text --query 'Vpcs[].VpcId' --filters Name=state,Values=available)
		fi

		if [ -z "$vpcs" ]; then
			echo "No VPC found. Set CHIC_VPC_ID or create a VPC" >&2
			terminate
			exit 1
		fi

		vpcid=$(echo "$vpcs" | tr '\t' '\n' | sort -R | head -n 1)
		echo "  * Determined VPC id: $vpcid" >&2
	else
		echo "  * Using VPC id: $vpcid" >&2
	fi
	if [ -z "$subnetid" ]; then
		local subnets
		subnets=$(aws ec2 describe-subnets $global_aws_options --output text --query 'Subnets[].SubnetId' --filters Name=vpc-id,Values=$vpcid)

		if [ -z "$subnets" ]; then
			echo "No subnets found in VPC $vpcid. Set CHIC_SUBNET_ID or create a subnet in the VPC" >&2
			terminate
			exit 1
		fi

		subnetid=$(echo "$subnets" | tr '\t' '\n' | sort -R | head -n 1)
		echo "  * Determined subnet id: $subnetid" >&2
	else
		echo "  * Using subnet id: $subnetid" >&2
	fi

	if [ -z "$root_volume_device_name" ]; then
		root_volume_device_name=$(aws ec2 describe-images $global_aws_options --image-ids "$ami" --output text --query 'Images[].BlockDeviceMappings[0].DeviceName')
		echo "  * Determined root volume: $root_volume_device_name" >&2
	fi
	if [ -z "$root_volume_size" ]; then
		root_volume_size=$(aws ec2 describe-images $global_aws_options --image-ids "$ami" --output text --query 'Images[].BlockDeviceMappings[0].Ebs.VolumeSize')
		echo "  * Determined root volume size: ${root_volume_size}GB" >&2
	fi

	image_stack_name="chic-image-$date_stamp"
	local my_public_ip=$(curl --silent http://checkip.amazonaws.com/)

	echo "* Creating image stack: $image_stack_name" >&2
	aws cloudformation create-stack $global_aws_options \
		--stack-name "$image_stack_name" \
		--template-body file://$"$CHIC_LIB_DIR"/build-image.yml \
		--capabilities CAPABILITY_IAM \
		--disable-rollback \
		--parameters \
		ParameterKey=ImageId,ParameterValue="$ami" \
		ParameterKey=InstanceType,ParameterValue="${instance_type}" \
		ParameterKey=KeyName,ParameterValue="$key_name" \
		ParameterKey=SSHLocation,ParameterValue="$my_public_ip/32" \
		ParameterKey=RootVolumeDeviceName,ParameterValue="$root_volume_device_name" \
		ParameterKey=RootVolumeSize,ParameterValue="$root_volume_size" \
		ParameterKey=VpcId,ParameterValue="$vpcid" \
		ParameterKey=SubnetId,ParameterValue="$subnetid" \
		> /dev/null
}

waitForImageStack() {
	set +e
	waitForCompleteStack "$image_stack_name"
	if [ $? != 0 ]; then
		describe_stack_events "$image_stack_name"
		terminate y
		exit 1
	fi
	set -e

	local stack_state
	stack_state=$(waitForStack "$image_stack_name")

	if [ "$stack_state" != "CREATE_COMPLETE" ]; then
		echo "Unexpected image stack state: $stack_state" >&2

		describe_stack_events "$image_stack_name"

		terminate y
		exit 1
	fi

	local describe_stacks=$(describe_stack_outputs "$image_stack_name")

	instance_id=$(extract_stack_output BuildInstanceId "$describe_stacks")
	instance_public_ip=$(extract_stack_output BuildInstancePublicIp "$describe_stacks")
	if [ -z "$instance_id" ]; then
		echo "Didn't get instance id from image stack" >&2
		echo "CloudFormation stack output:" >&2
		echo "$describe_stacks" >&2
		terminate y
		exit 1
	fi
}

waitForPort() {
	local host="$1"
	local port="$2"
	set +e
	set -o pipefail

	local netcat_options="-z -G 5 -w 5"

	echo -n "* Waiting for port $port to be available: $host" >&2
	local success=
	local output=
	while [ -z "$success" ]; do
		output=$(nc $netcat_options "$host" "$port" 2>&1)
		if [ $? == 0 ]; then
			success=1
		else
			echo "$output" | grep "invalid option" >/dev/null
			if [ $? == 0 -a "$netcat_options" == "-z -G 5 -w 5" ]; then
				netcat_options="-z -w 5"
			else
				sleep 5
				echo -n . >&2
			fi
		fi
	done
	echo >&2

	set -e
}

waitForSsh() {
	# Test that ssh is currently available for our user
	local attempts=1
	local delay=5

	set +e
	ssh -T $ssh_options $ssh_username@$instance_public_ip true

	while [ $? != 0 ]; do
		if [ $attempts -gt 20 ]; then
			echo "  * Failed to establish SSH connection" >&2
			terminate y
			exit 1
		fi

		echo "  * Retrying SSH connection in ${delay}s ($attempts attempts)" >&2
		sleep $delay

		attempts=$((attempts + 1))
		ssh -T $ssh_options $ssh_username@$instance_public_ip true
	done

	set -e
}

ensureStartedImageBuild() {
	if [ -z "${image_stack_name:-}" ]; then
		if [ ! -z "${existing_image_stack_name:-}" ]; then
			image_stack_name="$existing_image_stack_name"
		else
			buildImageStack
		fi
		waitForImageStack
		waitForPort "$instance_public_ip" 22
		waitForSsh
	fi
}

ensureNotStartedImageBuild() {
	if [ ! -z "${image_stack_name:-}" ]; then
		echo "Invalid command after image stack has been created: $1" >&2
		terminate y
		exit 1
	fi
}

prompt_yn() {
	local prompt_message="$1"
	local prompt_response=""
	while [ "$prompt_response" != "y" -a "$prompt_response" != "n" -a "$prompt_response" != "m" ]; do
		read -e -p "$prompt_message (y)es/(n)o/(m)anual " prompt_response
	done
	echo "$prompt_response"
}

deleteStacks() {
	prompt="${1:-}"
	if [ -t 0 -a ! -z "$prompt" -a -z "${existing_image_stack_name:-}" -a ! -z "${image_stack_name:-}" -a -z "$noninteractive" ]; then
		local delete_response=$(prompt_yn "Delete stack")
		if [ "delete_response" == "n" ]; then
			return 0
		elif [ "delete_response" == "m" ]; then
			MANUAL
			deleteStacks "$prompt"
			return $?
		fi
	fi

	if [ -z "${existing_image_stack_name:-}" -a ! -z "${image_stack_name:-}" ]; then
		echo "* Deleting image stack..." >&2
		aws cloudformation delete-stack $global_aws_options --stack-name "$image_stack_name"
	fi
}
