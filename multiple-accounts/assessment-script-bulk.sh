#!/bin/bash

datenow=$(date +"%s")
today=$(date +%F)
oneWeek=$(date  +%F --date="7 days ago")
lastDayMonth=$(date -d "`date +%Y%m01` +1 month -1 day" +%Y-%m-%d)
twoMonths=$(date -d '-2 month' +%Y-%m-01)

reportDir="elastiostats$datenow"

mkdir $reportDir

echo "Install jq."
var=$(sudo yum install jq -y 2>&1)

echo "Configure AWS."
AWSAccessKeyID=$(jq -r '.AWSAccessKeyID' config.json)
AWSSecretAccessKey=$(jq -r '.AWSSecretAccessKey' config.json)
AWSRoleName=$(jq -r '.AWSRoleName' config.json)
AWSAccounts=$(jq -r '.AWSAccounts[]' config.json)

aws configure <<EOF > /dev/null 2>&1
$AWSAccessKeyID
$AWSSecretAccessKey
us-east-2
json
EOF

#if accounts list from config.json file is empty get list from AWS
if [ -z "$AWSAccounts" ]
then
	AWSAccounts=$(aws organizations list-accounts --output text --query 'Accounts[*].{ID:Id}' 2>>$reportDir/errors)
fi

if [ -z "$AWSAccounts" ]
then
	echo "AWS accounts list is empty. Nothing to do."
	exit
fi

for ACCOUNT in $AWSAccounts
do

cat <<EOF >> ~/.aws/config

[profile $ACCOUNT]
role_arn = arn:aws:iam::$ACCOUNT:role/$AWSRoleName
source_profile = default
region = us-east-2
EOF

done

echo
echo "Getting account statistics."

for ACCOUNT in $AWSAccounts
do

echo 
echo "Account: $ACCOUNT."

export AWS_PROFILE=$ACCOUNT

reportDir="elastiostats$datenow/$ACCOUNT"

mkdir $reportDir

echo "Getting list of snapshots."
for REGION in $(aws ec2 describe-regions --output text --query 'Regions[].[RegionName]' 2>>$reportDir/errors)
do 
aws ec2 describe-snapshots --owner self --region $REGION --output json > $reportDir/$ACCOUNT-snapshots-$(echo $REGION | sed 's/-//g').json 2>>$reportDir/errors
done

echo "Getting snapshot permissions."
for REGION in $(aws ec2 describe-regions --output text --query 'Regions[].[RegionName]' 2>>$reportDir/errors)
do 
for SNAP in $(aws ec2 describe-snapshots --owner-ids self --region $REGION --output text --query 'Snapshots[*].[SnapshotId]' 2>>$reportDir/errors)
do 
PERM=$(aws ec2 describe-snapshot-attribute --region $REGION --snapshot-id $SNAP --attribute createVolumePermission --output text 2>>$reportDir/errors)
if [[ $PERM == *"all"* ]]
then
echo $PERM | sed 's/ CREATEVOLUMEPERMISSIONS all//'g >> $reportDir/$ACCOUNT-snapshotPermissions.csv
fi
done
done

echo "Getting list of EBS."
for REGION in $(aws ec2 describe-regions --output text --query 'Regions[].[RegionName]' 2>>$reportDir/errors)
do 
aws ec2 describe-volumes --region $REGION --output json > $reportDir/$ACCOUNT-ebs-$(echo $REGION | sed 's/-//g').json 2>>$reportDir/errors
done

echo "Getting list of EC2."
for REGION in $(aws ec2 describe-regions --output text --query 'Regions[].[RegionName]' 2>>$reportDir/errors)
do 
aws ec2 describe-instances --region $REGION --output json > $reportDir/$ACCOUNT-ec2-$(echo $REGION | sed 's/-//g').json 2>>$reportDir/errors
done

echo "Getting list of CMKs."
for REGION in $(aws ec2 describe-regions --output text --query 'Regions[].[RegionName]' 2>>$reportDir/errors)
do
for ID in $(aws kms list-keys --output text --query 'Keys[].[KeyId]' --region $REGION 2>>$reportDir/errors)
do 
KEY=$(aws kms describe-key --key-id  $ID --query 'KeyMetadata.{ID:KeyId,Manager:KeyManager}' --output text --region $REGION 2>>$reportDir/errors)
if [[ $KEY == *"CUSTOMER"* ]]
then
echo $KEY | sed 's/ CUSTOMER//'g >> $reportDir/$ACCOUNT-cmk-$(echo $REGION | sed 's/-//g').csv
fi
done
done

echo "Getting costs info."
#get snapshot daily costs
aws ce get-cost-and-usage --output json --time-period Start=$oneWeek,End=$today \
--metrics "UnblendedCost" "UsageQuantity" --granularity DAILY --group-by Type=DIMENSION,Key=USAGE_TYPE \
--filter '{ "Dimensions": { "Key": "USAGE_TYPE_GROUP", "Values": [ "EC2: EBS - Snapshots" ] } }' > \
$reportDir/$ACCOUNT-costDailySnapshot.json 2>>$reportDir/errors

#get snapshot monthly costs
aws ce get-cost-and-usage --output json --time-period Start=$twoMonths,End=$lastDayMonth \
--metrics "UnblendedCost" "UsageQuantity" --granularity MONTHLY --group-by Type=DIMENSION,Key=USAGE_TYPE \
--filter '{ "Dimensions": { "Key": "USAGE_TYPE_GROUP", "Values": [ "EC2: EBS - Snapshots" ] } }' > \
$reportDir/$ACCOUNT-costMonthlySnapshot.json 2>>$reportDir/errors

#get ebs daily costs
aws ce get-cost-and-usage --output json --time-period Start=$oneWeek,End=$today \
--metrics "UnblendedCost" "UsageQuantity" --granularity DAILY --group-by Type=DIMENSION,Key=USAGE_TYPE \
--filter '{ "Dimensions": { "Key": "USAGE_TYPE_GROUP", "Values": [ "EC2: EBS - SSD(gp2)", "EC2: EBS - SSD(gp3)", "EC2: EBS Optimized" ] } }' > \
$reportDir/$ACCOUNT-costDailyEBS.json 2>>$reportDir/errors

#get ebs monthly costs
aws ce get-cost-and-usage --output json --time-period Start=$twoMonths,End=$lastDayMonth \
--metrics "UnblendedCost" "UsageQuantity" --granularity MONTHLY --group-by Type=DIMENSION,Key=USAGE_TYPE \
--filter '{ "Dimensions": { "Key": "USAGE_TYPE_GROUP", "Values": [ "EC2: EBS - SSD(gp2)", "EC2: EBS - SSD(gp3)", "EC2: EBS Optimized" ] } }' > \
$reportDir/$ACCOUNT-costMonthlyEBS.json 2>>$reportDir/errors

done

unset AWS_PROFILE

var=$(tar zcvf elastio$datenow.tar.gz elastiostats$datenow 2>&1)

rm elastiostats$datenow -r -d

#check if bucket exists, if not create a new bucket to upload assessment script results
bucket=$(aws s3api list-buckets --output text --query 'Buckets[].[Name]' | grep elastio-assesment-)

if [ -z "$bucket" ]
then
	bucket="elastio-assesment-$datenow"
	var=$(aws s3api create-bucket --bucket elastio-assesment-$datenow --region us-east-1 2>&1)
fi

echo

aws s3 cp elastio$datenow.tar.gz s3://$bucket

echo
