$datenow = ([Math]::Round((Get-Date -UFormat %s), 0))
$today = Get-Date -Format "yyyy-MM-dd"
$oneWeek = (Get-date -Date (Get-Date).AddDays(-7) -Format "yyyy-MM-dd")
$lastDayMonth = (Get-date -Date (Get-Date -Day 1).AddMonths(1).AddDays(-1) -Format "yyyy-MM-dd")
$twoMonths = (Get-date -Date (Get-Date -Day 1).AddMonths(-2) -Format "yyyy-MM-dd")
$account=$(aws sts get-caller-identity --query "Account" --output text)

if($account -eq $null)
{
    $account = "NA" + ([Math]::Round((Get-Date -UFormat %s), 0))
}

$reportDir="elastiostats$datenow\$account"

$var = New-Item -ItemType Directory -Path ".\$reportDir"

Write-Host "Getting list of snapshots."

$regions = aws ec2 describe-regions --output text --query 'Regions[].[RegionName]' 2>>$reportDir\errors

foreach($region in $regions)
{
    $path = "$reportDir\snapshots-" + ($region.Replace("-","")) + ".json"
    aws ec2 describe-snapshots --owner self --region $region --output json > $path 2>>$reportDir\errors
}

Write-Host "Getting snapshot permissions."
foreach($region in $regions)
{
    foreach($snap in (aws ec2 describe-snapshots --owner-ids self --region $region --output text --query 'Snapshots[*].[SnapshotId]' 2>>$reportDir/errors))
    { 
        $perm = aws ec2 describe-snapshot-attribute --region $region --snapshot-id $snap --attribute createVolumePermission --output json 2>>$reportDir/errors
        if(($perm |ConvertFrom-Json).CreateVolumePermissions.Group -eq "all")
        {
            ($perm |ConvertFrom-Json).SnapshotId >> $reportDir/snapshotPermissions.csv
        }
    }
}

Write-Host  "Getting list of EBS."
foreach($region in $regions)
{ 
    $path = "$reportDir\ebs-" + ($region.Replace("-","")) + ".json"
    aws ec2 describe-volumes --region $region --output json > $path 2>>$reportDir/errors
}

Write-Host  "Getting list of EC2."
foreach($region in $regions)
{ 
    $path = "$reportDir\ec2-" + ($region.Replace("-","")) + ".json"
    aws ec2 describe-instances --region $region --output json > $path 2>>$reportDir/errors
}

Write-Host "Getting list of CMKs."
foreach($region in $regions)
{
    foreach($id in (aws kms list-keys --output text --query 'Keys[].[KeyId]' --region $region 2>>$reportDir/errors))
    { 
        $key = aws kms describe-key --key-id  $id --query 'KeyMetadata.{ID:KeyId,Manager:KeyManager}' --output json --region $region 2>>$reportDir/errors
        if(($key | ConvertFrom-Json).Manager -eq "CUSTOMER")
        {
            $path = "$reportDir\cmk-" + ($region.Replace("-","")) + ".csv"
            ($key | ConvertFrom-Json).ID >> $path
        }
    }
}

Write-Host "Getting costs info."
#get snapshot daily costs
aws ce get-cost-and-usage --output json --time-period Start=$oneWeek,End=$today `
--metrics "UnblendedCost" "UsageQuantity" --granularity DAILY --group-by Type=DIMENSION,Key=USAGE_TYPE `
--filter '{\"Dimensions\":{\"Key\":\"USAGE_TYPE_GROUP\",\"Values\":[\"EC2:EBS-Snapshots\"]}}' > `
$reportDir/costDailySnapshot.json 2>>$reportDir/errors

#get snapshot monthly costs
aws ce get-cost-and-usage --output json --time-period Start=$twoMonths,End=$lastDayMonth `
--metrics "UnblendedCost" "UsageQuantity" --granularity MONTHLY --group-by Type=DIMENSION,Key=USAGE_TYPE `
--filter '{\"Dimensions\": {\"Key\":\"USAGE_TYPE_GROUP\",\"Values\":[\"EC2:EBS-Snapshots\"]}}' > `
$reportDir/costMonthlySnapshot.json 2>>$reportDir/errors

#get ebs daily costs
aws ce get-cost-and-usage --output json --time-period Start=$oneWeek,End=$today `
--metrics "UnblendedCost" "UsageQuantity" --granularity DAILY --group-by Type=DIMENSION,Key=USAGE_TYPE `
--filter '{\"Dimensions\":{\"Key\":\"USAGE_TYPE_GROUP\",\"Values\":[\"EC2:EBS-SSD(gp2)\",\"EC2:EBS-SSD(gp3)\",\"EC2:EBS Optimized\" ] } }' > `
$reportDir/costDailyEBS.json 2>>$reportDir/errors

#get ebs monthly costs
aws ce get-cost-and-usage --output json --time-period Start=$twoMonths,End=$lastDayMonth `
--metrics "UnblendedCost" "UsageQuantity" --granularity MONTHLY --group-by Type=DIMENSION,Key=USAGE_TYPE `
--filter '{\"Dimensions\":{\"Key\":\"USAGE_TYPE_GROUP\",\"Values\":[\"EC2:EBS-SSD(gp2)\",\"EC2:EBS-SSD(gp3)\",\"EC2:EBS Optimized\" ] } }' > `
$reportDir/costMonthlyEBS.json 2>>$reportDir/errors

Compress-Archive -Path ".\elastiostats$datenow" -DestinationPath ".\elastio$datenow.zip"

Remove-Item -Path ".\elastiostats$datenow" -Recurse

$report = (Get-Item -Path ".\elastio$datenow.zip").FullName

Write-Host "`r`nReport location: $report"

Read-Host