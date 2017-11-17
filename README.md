# Chic

A simple utility to create an AMI using a recipe. This is an alternative to Packer.io.
Chic uses CloudFormation to create and destroy resources, so it's always easy to manage the AWS resources
that Chic creates.

## Usage

`chic <dir>` or `chic <Chicfile>`

## Chicfile

The Chicfile is intentionally quite similar to a Dockerfile. It is, however, a shell script,
so you can use shell scripting in the Chicfile. Note that the Chicfile is executed on your local
machine, unless you're using a `RUN` command to execute on the remote machine building the image.

* `FROM <ami>` The AMI to use as the base for the image.
* `INSTANCE_TYPE <instance type>` The instance type to use to build the image, defaults to `t2.micro`
* `NAME <name>` The name to give to the resulting image
* `TAG <name> <value>` A tag to create on the resulting image. This command can be used multiple times.
* `SSH_USERNAME <username>` The username to connect to the image builder for ssh
* `ENV <key> [<value>]` Set an environment variable default in the Chicfile. If a value is not specified then one MUST be provided in the environment or config file when chic is run. This command can be used multiple times.
* `COPY <source> ... <dest>` Copy a file from the local machine to the remote machine. This command can have multiple source arguments, and can be used multiple times.
* `RUN <command>` Run the given command on the remote machine. This command can be used multiple times, and can also accept its commands on stdin so can be used with heredocs.

### Environment variables

Environment variables are made available to scripts executing on the remote server as part of a
`RUN` command.

You must specify environment variables in the Chicfile using the `ENV` command. This also specifies
the default value for the environment variable.

### Example

Here is an example of a Chicfile to create a basic image:

```
FROM ami-e2021d81
NAME my-chic-ami
TAG stage production
SSH_USERNAME ubuntu
ENV MY_STAGE production
COPY my-bootstrap.sh /opt/
RUN hostname my-ami-host
RUN <<"RUN_EOF"
echo "$MY_STAGE" > /opt/my-stage
RUN_EOF
```

Note that the default value of the environment variable `MY_STAGE` is set to `production`, but you could
override this by setting the `MY_STAGE` environment variable before running chic, e.g. `MY_STAGE=staging chic .`

## Options

The following command-line options control chic:

* `-p <profile>` The awscli configuration profile to use to access AWS
* `-r <region>` The AWS region to use to build the image (defaults to the default region for your awscli profile)
* `-s <subnet>` The AWS subnet to use to build the image (defaults to the first subnet found)
* `-b` Non-interactive mode

The following command-line options are supported to override Chicfile settings:

* `-a <base ami>` The AMI to use as the base for the image.
* `-i <instance type>` The instance type to use to build the image, defaults
	to `t2.micro`
* `-n <name>` The name to give to the resulting image
* `-t <tag key>=<value>` A tag to create on the resulting image. This option can be used multiple times, and is in addition to Chicfile tags.

## Environment variables

You can also use the following environment variables to configure Chic:

* `CHIC_PROFILE` The awscli configuration profile to use to access AWS
* `CHIC_REGION` The AWS region to use to build the image

## Configuration file

Chic looks for a `.chic.cfg` file in your current working directory, and parent directories, until
it finds one. It then executes it to load environment variables from it.

### Example

```
CHIC_PROFILE=my-aws-profile
```

## Example

```
chic -p my-aws-profile -a ami-e2021d81 -n "My image" share/example.sh
```

