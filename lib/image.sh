#!/bin/bash -eu

buildImage() {
	ensureStartedImageBuild
	
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
