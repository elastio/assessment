Assesment script is used to collect some basic information from you AWS account, like count and size of EBS volumes and EC2 instances, EBS snapshots list with infrormation about encription and age, etc. This information will be used then to generate a vulnarability report for your organization.

Running the script is easy and doesn't need a lot of effort. However if you have a lot of accounts it might take some time. To make it easier there is a separate script that supports bulk account execution. If you have a few accounts you can use `single-account/assessment-script.sh`, guide on how to run it is in the next paragraph.

## Single Account Usage
To run the script you need a Linux machine with configured AWS CLI.
To setup conenection between AWS CLI and your AWS account run `aws configure` command and provide `AWS Access Key ID` and `AWS Secret Access Key`.

1. Copy the script to the instance or altermatively you can create new file (e.g. script.sh) and copy the content of the `single-account/assessment-script.sh` to newly created file.
2. Run `chmod +x script.sh` to make file executable.
3. Run script `./script.sh`.

As a result of the script run archive will be created and uploaded to the S3 buucket, you will see the output with its location in the terminal:
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
- s3:CreateBucket- 

Useful links:
 - [Installing or updating the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
 - [Configuring the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html)
