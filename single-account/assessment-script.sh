#!/bin/bash

datenow=$(date +"%s")
today=$(date +%F)
oneWeek=$(date  +%F --date="7 days ago")
lastDayMonth=$(date -d "`date +%Y%m01` +1 month -1 day" +%Y-%m-%d)
twoMonths=$(date -d '-2 month' +%Y-%m-01)
account=$(aws sts get-caller-identity --query "Account" --output text)

#if there is no permissions to get account ID, set custom name
if [ -z "$account" ]
then
	t=$(date +"%s")
	account=NA$t
fi

reportDir="elastiostats$datenow/$account"

mkdir -p $reportDir

echo
echo "Getting list of snapshots."
for REGION in $(aws ec2 describe-regions --output text --query 'Regions[].[RegionName]' 2>>$reportDir/errors)
do 
aws ec2 describe-snapshots --owner self --region $REGION --output json > $reportDir/snapshots-$(echo $REGION | sed 's/-//g').json 2>>$reportDir/errors
done

echo "Getting snapshot permissions."
for REGION in $(aws ec2 describe-regions --output text --query 'Regions[].[RegionName]' 2>>$reportDir/errors)
do 
for SNAP in $(aws ec2 describe-snapshots --owner-ids self --region $REGION --output text --query 'Snapshots[*].[SnapshotId]' 2>>$reportDir/errors)
do 
PERM=$(aws ec2 describe-snapshot-attribute --region $REGION --snapshot-id $SNAP --attribute createVolumePermission --output text 2>>$reportDir/errors)
if [[ $PERM == *"all"* ]]
then
echo $PERM | sed 's/ CREATEVOLUMEPERMISSIONS all//'g >> $reportDir/snapshotPermissions.csv
fi
done
done

echo "Getting list of EBS."
for REGION in $(aws ec2 describe-regions --output text --query 'Regions[].[RegionName]' 2>>$reportDir/errors)
do 
aws ec2 describe-volumes --region $REGION --output json > $reportDir/ebs-$(echo $REGION | sed 's/-//g').json 2>>$reportDir/errors
done

echo "Getting list of EC2."
for REGION in $(aws ec2 describe-regions --output text --query 'Regions[].[RegionName]' 2>>$reportDir/errors)
do 
aws ec2 describe-instances --region $REGION --output json > $reportDir/ec2-$(echo $REGION | sed 's/-//g').json 2>>$reportDir/errors
done

echo "Getting list of CMKs."
for REGION in $(aws ec2 describe-regions --output text --query 'Regions[].[RegionName]' 2>>$reportDir/errors)
do
for ID in $(aws kms list-keys --output text --query 'Keys[].[KeyId]' --region $REGION 2>>$reportDir/errors)
do 
KEY=$(aws kms describe-key --key-id  $ID --query 'KeyMetadata.{ID:KeyId,Manager:KeyManager}' --output text --region $REGION 2>>$reportDir/errors)
if [[ $KEY == *"CUSTOMER"* ]]
then
echo $KEY | sed 's/ CUSTOMER//'g >> $reportDir/cmk-$(echo $REGION | sed 's/-//g').csv
fi
done
done

echo "Getting costs info."
#get snapshot daily costs
aws ce get-cost-and-usage --output json --time-period Start=$oneWeek,End=$today \
--metrics "UnblendedCost" "UsageQuantity" --granularity DAILY --group-by Type=DIMENSION,Key=USAGE_TYPE \
--filter '{ "Dimensions": { "Key": "USAGE_TYPE_GROUP", "Values": [ "EC2: EBS - Snapshots" ] } }' > \
$reportDir/costDailySnapshot.json 2>>$reportDir/errors

#get snapshot monthly costs
aws ce get-cost-and-usage --output json --time-period Start=$twoMonths,End=$lastDayMonth \
--metrics "UnblendedCost" "UsageQuantity" --granularity MONTHLY --group-by Type=DIMENSION,Key=USAGE_TYPE \
--filter '{ "Dimensions": { "Key": "USAGE_TYPE_GROUP", "Values": [ "EC2: EBS - Snapshots" ] } }' > \
$reportDir/costMonthlySnapshot.json 2>>$reportDir/errors

#get ebs daily costs
aws ce get-cost-and-usage --output json --time-period Start=$oneWeek,End=$today \
--metrics "UnblendedCost" "UsageQuantity" --granularity DAILY --group-by Type=DIMENSION,Key=USAGE_TYPE \
--filter '{ "Dimensions": { "Key": "USAGE_TYPE_GROUP", "Values": [ "EC2: EBS - SSD(gp2)", "EC2: EBS - SSD(gp3)", "EC2: EBS Optimized" ] } }' > \
$reportDir/costDailyEBS.json 2>>$reportDir/errors

#get ebs monthly costs
aws ce get-cost-and-usage --output json --time-period Start=$twoMonths,End=$lastDayMonth \
--metrics "UnblendedCost" "UsageQuantity" --granularity MONTHLY --group-by Type=DIMENSION,Key=USAGE_TYPE \
--filter '{ "Dimensions": { "Key": "USAGE_TYPE_GROUP", "Values": [ "EC2: EBS - SSD(gp2)", "EC2: EBS - SSD(gp3)", "EC2: EBS Optimized" ] } }' > \
$reportDir/costMonthlyEBS.json 2>>$reportDir/errors


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
