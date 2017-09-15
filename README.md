# Chic

A simple utility to create an AMI from a bootstrap shell script.

## Options

The following command-line options are supported:

* `-a <base ami>` The AMI to use as the base for the image.
* `-i <instance type>` The instance type to use to build the image, defaults
	to `t2.micro`
* `-n <name>` The name to give to the resulting image
* `-t <tag key>=<value>` A tag to create on the resulting image. This option can be used multiple times.
* `-p <profile>` The awscli configuration profile to use to access AWS
* `-r <region>` The AWS region to use to build the image (defaults to the default region for your awscli profile)
* `-s <subnet>` The AWS subnet to use to build the image (defaults to the first subnet found)
* `-f <config>` Load configuration from the given file
* `-d` Dry run all awscli commands
* `-q` Quiet the output
* `-b` Non-interactive mode

Specify zero, one or more file names after the options to choose the shell-scripts to run
to bootstrap the instance to create the image.

## Example

```
chic -p my-aws-profile -a ami-e2021d81 -n "My image" share/example.sh
```
