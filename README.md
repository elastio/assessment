## Summary
The Elastio assessment script is used to collect some basic information from your AWS account(s), like the number and size of EBS volumes and EC2 instances, EBS snapshots with information about encryption and age, etc. This information will be used then to generate a report for your organization identifying potential vulnerabilities and cost savings which you can realize with Elastio.

Running the script is easy and doesn't require a lot of effort. However, if you have a lot of accounts it might take some time. To make it easier there is a separate script that supports bulk account execution, please see "Multiple Account Usage" section below. If you have a few accounts, you can use `single-account/assessment-script` (`.sh` for Linux, `.ps1` for Windows), guide on how to run it described in the "Single Account Usage" paragraph.

## Single Account Usage
To run the script you need a Linux or a Windows box with configured AWS CLI.
To setup connection  between AWS CLI and your AWS account run `aws configure` command and provide `AWS Access Key ID` and `AWS Secret Access Key`.

**For Linux:**
1. Copy the script to the instance or alternatively you can create a new file (e.g. `script.sh`) and copy/paste the content of the `single-account/assessment-script.sh` to newly created file.
2. Run `chmod +x script.sh` to make file executable.
3. Run script `./script.sh`.

As a result of running the script an archive file will be created and uploaded to an S3 bucket.  You will see the output with its location in the terminal:
```
upload: ./elastio1676898821.tar.gz to s3://elastio-assesment-1676898821/elastio1676898821.tar.gz
```

Please download the archive and send it to us. 

Note: Archive will also appear in the directory where script is located, for your convenience in case you want to review what information is included in the archive before sending it to Elastio.

**For Windows:**
1. Copy the script `single-account/assessment-script.ps1` to the Windows box.
2. Open the context menu by clicking right mouse button on file and select `Run with PowerShell`.

As a result of running the script an archive file will be created and stored in the directory where script is located.  You will see the output with its location in the terminal:

```
Report location: C:\elastio1677251593.zip
```

Please send this archive to us.

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
To run the script you need access to a Linux or Windows system with latest AWS CLI installed and configured. It's not important where this system is located, it can be an EC2 instance, or your local workstation.

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

**For Linux:**

4. Copy the script to the instance or alternatively you can create new file (e.g. script.sh) and copy the content of the `multiple-accounts/assessment-script-bulk.sh` to newly created file.
5. Run `chmod +x script.sh` to make file executable.
6. Run script `./script.sh`. Please note that `jq` will be installed if it is not already.

The script will execute `aws configure` command and will create `~/.aws/config` file with profiles required to connect to your accounts.

As a result of the script run an archive will be created and uploaded to the S3 bucket, you will see the output with its location in the terminal:
```
upload: ./elastio1676898821.tar.gz to s3://elastio-assesment-1676898821/elastio1676898821.tar.gz
```

Please download the archive and send it to us.

Note: Archive will also appear in the directory where script is locates for your convenience.

**For Windows:**
4. Copy the script `single-account/assessment-script.ps1` to the Windows box.
5. Open the context menu by clicking right mouse button on file and select `Run with PowerShell`.

The script will execute `aws configure` command and will create `~/.aws/config` file with profiles required to connect to your accounts.
As a result of running the script an archive file will be created and stored in the directory where script is located.  You will see the output with its location in the terminal:

```
Report location: C:\elastio1677251593.zip
```

Please send this archive to us.


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
