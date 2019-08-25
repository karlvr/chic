#!/bin/bash -eu

describe_stack_status() {
	aws cloudformation describe-stacks $global_aws_options \
		--stack-name "$1" \
		--output text \
		--query 'Stacks[].StackStatus'
}

describe_stack_outputs() {
	aws cloudformation describe-stacks $global_aws_options \
		--stack-name "$1" \
		--output text \
		--query 'Stacks[].Outputs[].[OutputKey,OutputValue]'
}

describe_stack_events() {
	aws cloudformation describe-stack-events $global_aws_options \
		--stack-name "$1" \
		--output table \
		--query 'StackEvents[].[LogicalResourceId, ResourceStatus, ResourceType, ResourceStatusReason, Timestamp]'
}

extract_stack_output() {
	# TODO get the describe_stacks as a heredoc / here-string
	echo "$2" | grep "^$1\s" | cut -f2
}

waitForStack() {
	local stack
	stack="$1"

	local safe_stack
	safe_stack=$(echo "$stack" | tr -- '- ' _ | tr -C -d [:alnum:]_)

	local stack_state
	eval stack_state=\${global_stack_state_$safe_stack:-}
	if [ -z "$stack_state" ]; then
		stack_state=$(describe_stack_status "$stack")
	fi

	if [ -z "$stack_state" -o "$stack_state" == "CREATE_IN_PROGRESS" ]; then
		echo -n "* Waiting for stack to complete: $stack" >&2
		while [ -z "$stack_state" -o "$stack_state" == "CREATE_IN_PROGRESS" ]; do
			sleep 5
			echo -n . >&2
			stack_state=$(describe_stack_status "$stack")
		done
		echo >&2
	fi

	eval "global_stack_state_$safe_stack"="$stack_state"

	echo "$stack_state"
}

waitForCompleteStack() {
	local stack
	stack="$1"

	local stack_state
	stack_state=$(waitForStack "$stack")

	if [ "$stack_state" != "CREATE_COMPLETE" ]; then
		echo "Unexpected stack state for $stack: $stack_state" >&2
		return 1
	fi
}
