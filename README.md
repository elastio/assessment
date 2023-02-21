## Summary
Assessment script is used to collect some basic information from you AWS account, like count and size of EBS volumes and EC2 instances, EBS snapshots list with infrormation about encryption and age, etc. This information will be used then to generate a vulnerability report for your organization.

Running the script is easy and doesn't need a lot of effort. However, if you have a lot of accounts it might take some time. To make it easier there is a separate script that supports bulk account execution, please see "Multiple Account Usage" paragraph. If you have a few accounts, you can use `single-account/assessment-script.sh`, guide on how to run it is in the "Single Account Usage" paragraph.

## Prerequisites
To run the script you need a Linux machine with configured AWS CLI.
To setup connection  between AWS CLI and your AWS account run `aws configure` command and provide `AWS Access Key ID` and `AWS Secret Access Key`.

## Single Account Usage
1. Copy the script to the instance or alternatively you can create new file (e.g. script.sh) and copy the content of the `single-account/assessment-script.sh` to newly created file.
2. Run `chmod +x script.sh` to make file executable.
3. Run script `./script.sh`.

As a result of the script run archive will be created and uploaded to the S3 bucket, you will see the output with its location in the terminal:
```
upload: ./elastio1676898821.tar.gz to s3://elastio-assesment-1676898821/elastio1676898821.tar.gz
```

Please download the archive and send it to us.

**Permissions required to run the script:**
- ec2:DescribeRegions
- ec2:DescribeSnapshots
- ec2:DescribeSnapshotAttribute
- ec2:DescribeVolumes
- ec2:DescribeInstances
- kms:ListKeys
- kms:DescribeKey
- ce:GetCostAndUsage
- s3:ListBucket
- s3:CreateBucket

## Multiple Account Usage
1. Download `multiple-accounts/config.json` file.
2. Fill in `config.json` file with:
 - `AWS Access Key ID`
 - `AWS Secret Access Key`.
 - The IAM role name that you can assume in order to access each of the accounts in your organization.
 - List of accounts you would like to analyze. To get the list of accounts run command `aws organizations list-accounts --output json --query 'Accounts[*].Id'`. Alternately you could leave accounts list empty, in this case script will query accounts from AWS. Please note, you should have `organizations:ListAccounts` permission to be able to query list of accounts.

Config file will look similar to:
```
{
	"AWSAccessKeyID": "AKIA********YMVI",
	"AWSSecretAccessKey": "ktHj7*****************v7hp+n6",
	"AWSRoleName": "AssumeRoleName",
	"AWSAccounts": [
		"993*****684",
		"101*****4432"
	]
}
```
3. Copy the `config.json` file to the instance or alternatively you can create new file `config.json` and copy the content of the file to newly created one.
4. Copy the script to the instance or alternatively you can create new file (e.g. script.sh) and copy the content of the `multiple-accounts/assessment-script-bulk.sh` to newly created file.
5. Run `chmod +x script.sh` to make file executable.
6. Run script `./script.sh`. Please note that `jq` will be installed if it is not already.

As a result of the script run an archive will be created and uploaded to the S3 bucket, you will see the output with its location in the terminal:
```
upload: ./elastio1676898821.tar.gz to s3://elastio-assesment-1676898821/elastio1676898821.tar.gz
```

Please download the archive and send it to us.

**Permissions required to run the script:**
- organizations:ListAccounts
- ec2:DescribeRegions
- ec2:DescribeSnapshots
- ec2:DescribeSnapshotAttribute
- ec2:DescribeVolumes
- ec2:DescribeInstances
- kms:ListKeys
- kms:DescribeKey
- ce:GetCostAndUsage
- s3:ListBucket
- s3:CreateBucket

**Useful links:**
 - [Installing or updating the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
 - [Configuring the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html)
