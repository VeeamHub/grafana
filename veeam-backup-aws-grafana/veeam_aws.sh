#!/bin/bash
##      .SYNOPSIS
##      Grafana Dashboard for Veeam Backup AWS v4.0 - Using API to InfluxDB v2 Script
## 
##      .DESCRIPTION
##      This Script will query the Veeam Backup for AWS API and send the data directly to InfluxDB, which can be used to present it to Grafana. 
##      The Script and the Grafana Dashboard it is provided as it is, and bear in mind you can not open support Tickets regarding this project. It is a Community Project
##	
##      .Notes
##      NAME:  veeam_aws.sh
##      ORIGINAL NAME: veeam_aws.sh
##      LASTEDIT: 14/04/2022
##      VERSION: 4.0
##      KEYWORDS: Veeam, InfluxDB, Grafana
   
##      .Link
##      https://jorgedelacruz.es/
##      https://jorgedelacruz.uk/

# Configurations
##
# Endpoint URL for InfluxDB
##
veeamInfluxDBURL="http://YOURINFLUXSERVERIP" #Your InfluxDB Server, http://FQDN or https://FQDN if using SSL
veeamInfluxDBPort="8086" #Default Port
veeamInfluxDBBucket="veeam" # InfluxDB bucket name (not ID)
veeamInfluxDBToken="TOKEN" # InfluxDB access token with read/write privileges for the bucket
veeamInfluxDBOrg="ORG NAME" # InfluxDB organisation name (not ID)

# Endpoint URL for login action
veeamUsername="YOURVEEAMBACKUPUSER"
veeamPassword="YOURVEEAMBACKUPPASS"
veeamBackupAWSServer="https://YOURVEEAMBACKUPFORAWSIP"
veeamBackupAWSPort="11005" #Default Port

veeamBearer=$(curl -X POST --header "Content-Type: application/x-www-form-urlencoded" --header "Accept: application/json" --header "x-api-version: 1.2-rev0" -d "username=$veeamUsername&password=$veeamPassword&grant_type=password" "$veeamBackupAWSServer:$veeamBackupAWSPort/api/v1/token" -k --silent | jq -r '.access_token')

##
# Veeam Backup for AWS Overview. This part will check VBA Overview
##
veeamVBAURL="$veeamBackupAWSServer:$veeamBackupAWSPort/api/v1/system/version"
veeamVBAOverviewUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H "x-api-version: 1.2-rev0" "accept: application/json" 2>&1 -k --silent)

    version=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".version" |awk '{$1=$1};NF')
    
veeamVBAURL="$veeamBackupAWSServer:$veeamBackupAWSPort/api/v1/statistics/summary"
veeamVBAOverviewUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H "x-api-version: 1.2-rev0" "accept: application/json" 2>&1 -k --silent)

    VMsCount=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".instancesCount")
    VMsProtected=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".protectedInstancesCount")
    PoliciesCount=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".policiesCount")
    RepositoriesCount=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".repositoriesCount")

veeamVBAURL="$veeamBackupAWSServer:$veeamBackupAWSPort/api/v1/licensing/license"
veeamVBAOverviewUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H "x-api-version: 1.2-rev0" -H  "accept: application/json" 2>&1 -k --silent)

    LicenseType=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".licenseType")
    LicenseInstances=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".instancesUses")
    
    #echo "veeam_aws_overview,version=$version,LicenseType=$LicenseType VMs=$VMsCount,VMsProtected=$VMsProtected,Policies=$PoliciesCount,Repositories=$RepositoriesCount,InstancesUsed=$LicenseInstances"
    echo "Writing veeam_aws_overview to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_overview,version=$version,LicenseType=$LicenseType VMs=$VMsCount,VMsProtected=$VMsProtected,Policies=$PoliciesCount,Repositories=$RepositoriesCount,InstancesUsed=$LicenseInstances"
    
##
# Veeam Backup for AWS Instances. This part will check VBA and report all the protected Instances
##
veeamVBAURL="$veeamBackupAWSServer:$veeamBackupAWSPort/api/v1/virtualMachines?ProtectedByPolicy=Protected"
veeamVBAInstancesUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H "x-api-version: 1.2-rev0" -H  "accept: application/json" 2>&1 -k --silent)

declare -i arrayinstances=0
for id in $(echo "$veeamVBAInstancesUrl" | jq -r '.results[].id'); do
    VMID=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".results[$arrayinstances].id")
    VMName=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".results[$arrayinstances].name" | awk '{gsub(/ /,"\\ ");print}')
    if [ "$VMName" == "" ]; then declare -i VMName="Empty"; fi
    VMResourceID=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".results[$arrayinstances].awsResourceId")
    VMSize=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".results[$arrayinstances].instanceSizeGigabytes")
    VMType=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".results[$arrayinstances].instanceType")    
    VMRegion=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".results[$arrayinstances].region.name")
    VMBackup=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".results[$arrayinstances].backupState")
    if [ "$VMBackup" == "Protected" ]; then declare -i VMBackup="1"; 
    elif [ "$VMBackup" == "Unprotected" ]; then declare -i VMBackup="2"; fi
        
    veeamVBAVMURL="$veeamBackupAWSServer:$veeamBackupAWSPort/api/v1/policies?virtualMachineId=$veeamVBAInstanceId&usn=0&offset=0&limit=30"
    veeamVBAInstancesPolicyUrl=$(curl -X GET $veeamVBAVMURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)
    VMPolicy=$(echo "$veeamVBAInstancesPolicyUrl" | jq --raw-output ".results[0].name")   
    
    #echo "veeam_aws_vm,VMID=$VMID,VMName=$VMName,VMResourceId=$VMResourceID,VMType=$VMType,VMPolicy=$VMPolicy,VMRegion=$VMRegion VMSize=$VMSize,VMBackup=$VMBackup"
    echo "Writing veeam_aws_vm to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_vm,VMID=$VMID,VMName=$VMName,VMResourceId=$VMResourceID,VMType=$VMType,VMPolicy=$VMPolicy,VMRegion=$VMRegion VMSize=$VMSize,VMBackup=$VMBackup"
    
    # Restore Points per Instance
    veeamVBAURL="$veeamBackupAWSServer:$veeamBackupAWSPort/api/v1/virtualMachines/restorePoints?VirtualMachineId=$VMID&onlyLatest=False"
    veeamRestorePointsUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H "x-api-version: 1.2-rev0" -H  "accept: application/json" 2>&1 -k --silent)
    
    VMJobTotal=$(echo "$veeamRestorePointsUrl" | jq --raw-output ".totalCount")
    declare -i arrayRestorePoint=0
    for id in $(echo "$veeamRestorePointsUrl" | jq -r '.results[].id'); do
      VMJobType=$(echo "$veeamRestorePointsUrl" | jq --raw-output ".results[$arrayRestorePoint].jobType")
      VMJobid=$(echo "$veeamRestorePointsUrl" | jq --raw-output ".results[$arrayRestorePoint].id")
      VMJobBackupId=$(echo "$veeamRestorePointsUrl" | jq --raw-output ".results[$arrayRestorePoint].backupId")
      VMJobSize=$(echo "$veeamRestorePointsUrl" | jq --raw-output ".results[$arrayRestorePoint].backupSizeBytes")
      VMJobTime=$(echo "$veeamRestorePointsUrl" | jq --raw-output ".results[$arrayRestorePoint].pointInTime")

        #echo "veeam_aws_restorepoints,JobType=$VMJobType,Jobid=$VMJobid,JobBackupId=$VMJobBackupId,JobTime=$VMJobTime JobSize=$VMJobSize"
        echo "Writing veeam_aws_restorepoints to InfluxDB"
        curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_restorepoints,JobType=$VMJobType,Jobid=$VMJobid,JobBackupId=$VMJobBackupId,JobTime=$VMJobTime JobSize=$VMJobSize"
        
        arrayRestorePoint=$arrayRestorePoint+1
    done   
    arrayinstances=$arrayinstances+1    
done
    echo "Writing veeam_aws_vm_protected to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_vm_protected TotalVMs=$arrayinstances"

##
# Veeam Backup for AWS Instances. This part will check VBA and report all the unprotected Instances
##
veeamVBAURL="$veeamBackupAWSServer:$veeamBackupAWSPort/api/v1/virtualMachines?ProtectedByPolicy=Unprotected"
veeamVBAUnprotectedUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H "x-api-version: 1.2-rev0" -H  "accept: application/json" 2>&1 -k --silent)

declare -i arrayUnprotected=0
for id in $(echo "$veeamVBAUnprotectedUrl" | jq -r '.results[].id'); do
    VMID=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".results[$arrayUnprotected].id")
    VMName=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".results[$arrayUnprotected].name" | awk '{gsub(/ /,"\\ ");print}')
    if [ "$VMName" == "" ]; then declare -i VMName="Empty"; fi
    VMResourceID=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".results[$arrayUnprotected].awsResourceId")
    VMSize=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".results[$arrayUnprotected].instanceSizeGigabytes")
    VMType=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".results[$arrayUnprotected].instanceType")    
    VMRegion=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".results[$arrayUnprotected].region.name")
    
    #echo "veeam_aws_vm_unprotected,VMID=$VMID,VMName=$VMName,VMResourceId=$VMResourceID,VMType=$VMType,VMRegion=$VMRegion VMSize=$VMSize"
    echo "Writing veeam_aws_vm_unprotected to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_vm_unprotected,VMID=$VMID,VMName=$VMName,VMResourceId=$VMResourceID,VMType=$VMType,VMRegion=$VMRegion VMSize=$VMSize"
           
    arrayUnprotected=$arrayUnprotected+1
done
    echo "Writing veeam_aws_vm_unprotected to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_vm_unprotected TotalVMs=$arrayUnprotected"
##
# Unprotected VMs per Region with geohash
#
    useast2=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.region.name=="us-east-2")) | length')
    useast1=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.region.name=="us-east-1")) | length')
    uswest1=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.region.name=="us-west-1")) | length')
    uswest2=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.region.name=="us-west-2")) | length')
    afsouth1=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.region.name=="af-south-1")) | length')
    apeast1=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.region.name=="ap-east-1")) | length')
    apsouth1=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.region.name=="ap-south-1")) | length')
    apnortheast3=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.region.name=="ap-northeast-3")) | length')
    apnortheast2=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.region.name=="ap-northeast-2")) | length')
    apsoutheast1=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.region.name=="ap-southeast-1")) | length')
    apsoutheast2=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.region.name=="ap-southeast-2")) | length')
    apnortheast1=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.region.name=="ap-northeast-1")) | length')
    cacentral1=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.region.name=="ca-central-1")) | length')
    eucentral1=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.region.name=="eu-central-1")) | length')
    euwest1=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.region.name=="eu-west-1")) | length')
    euwest2=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.region.name=="eu-west-2")) | length')
    eusouth1=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.region.name=="eu-south-1")) | length')
    euwest3=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.region.name=="eu-west-3")) | length')
    eunorth1=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.region.name=="eu-north-1")) | length')
    mesouth1=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.region.name=="me-south-1")) | length')
    saeast1=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.region.name=="sa-east-1")) | length')


    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_vm_unprotected,VMRegion="us-east-2",geohash="dpjhy6u3dw" UPVM=$useast2"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_vm_unprotected,VMRegion="us-east-1",geohash="dq85jy563y" UPVM=$useast1"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_vm_unprotected,VMRegion="us-west-1",geohash="9qe8c9k988" UPVM=$uswest1"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_vm_unprotected,VMRegion="us-west-2",geohash="9rf4hw1vf5" UPVM=$uswest2"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_vm_unprotected,VMRegion="af-south-1",geohash="k3vngp7jk3" UPVM=$afsouth1"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_vm_unprotected,VMRegion="ap-east-1",geohash="wecpnkfcv6" UPVM=$apeast1"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_vm_unprotected,VMRegion="ap-south-1",geohash="te7ud2etwq" UPVM=$apsouth1"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_vm_unprotected,VMRegion="ap-northeast-3",geohash="xn0m7m2fuj" UPVM=$apnortheast3"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_vm_unprotected,VMRegion="ap-northeast-2",geohash="wydm9qycb8" UPVM=$apnortheast2"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_vm_unprotected,VMRegion="ap-southeast-1",geohash="w21zdrp19x" UPVM=$apsoutheast1"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_vm_unprotected,VMRegion="ap-southeast-2",geohash="r3gx3hbmqu" UPVM=$apsoutheast2"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_vm_unprotected,VMRegion="ap-northeast-1",geohash="xn76urcex7" UPVM=$apnortheast1"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_vm_unprotected,VMRegion="ca-central-1",geohash="cdg5qsfg6b" UPVM=$cacentral1"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_vm_unprotected,VMRegion="eu-central-1",geohash="u0yjjd65em" UPVM=$eucentral1"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_vm_unprotected,VMRegion="eu-west-1",geohash="gc6kdrvd14" UPVM=$euwest1"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_vm_unprotected,VMRegion="eu-west-2",geohash="gcpvj0e5cs" UPVM=$euwest2"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_vm_unprotected,VMRegion="eu-south-1",geohash="u0nd9hur61" UPVM=$eusouth1"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_vm_unprotected,VMRegion="eu-west-3",geohash="u09tvw06ch" UPVM=$euwest3"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_vm_unprotected,VMRegion="eu-north-1",geohash="u6sc7pycyg" UPVM=$eunorth1"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_vm_unprotected,VMRegion="me-south-1",geohash="theuvcqhdk" UPVM=$mesouth1"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_vm_unprotected,VMRegion="sa-east-1",geohash="6gyf4bdxe2" UPVM=$saeast1"


##
# Veeam Backup for AWS RDS. This part will check VBA and report all the RDS
##
veeamVBAURL="$veeamBackupAWSServer:$veeamBackupAWSPort/api/v1/rds"
veeamVBARDSUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H "x-api-version: 1.2-rev0" -H  "accept: application/json" 2>&1 -k --silent)

declare -i arrayRDS=0
for id in $(echo "$veeamVBARDSUrl" | jq -r '.results[].id'); do
    RDSID=$(echo "$veeamVBARDSUrl" | jq --raw-output ".results[$arrayRDS].id")    
    RDSEngine=$(echo "$veeamVBARDSUrl" | jq --raw-output ".results[$arrayRDS].engine")    
    RDSEngineVersion=$(echo "$veeamVBARDSUrl" | jq --raw-output ".results[$arrayRDS].engineVersion")
    RDSAWSID=$(echo "$veeamVBARDSUrl" | jq --raw-output ".results[$arrayRDS].awsResourceId")
    RDSName=$(echo "$veeamVBARDSUrl" | jq --raw-output ".results[$arrayRDS].name" | awk '{gsub(/ /,"\\ ");print}')
    RDSSize=$(echo "$veeamVBARDSUrl" | jq --raw-output ".results[$arrayRDS].instanceSizeGigabytes")
    RDSClass=$(echo "$veeamVBARDSUrl" | jq --raw-output ".results[$arrayRDS].instanceClass")
    RDSDNS=$(echo "$veeamVBARDSUrl" | jq --raw-output ".results[$arrayRDS].instanceDnsName")
    RDSRegion=$(echo "$veeamVBARDSUrl" | jq --raw-output ".results[$arrayRDS].location.name")
    
    #echo "veeam_aws_RDS,RDSID=$RDSID,RDSName=$RDSName,RDSEngine=$RDSEngine,RDSEngineVersion=$RDSEngineVersion,RDSAWSID=$RDSAWSID,RDSClass=$RDSClass,RDSDNS=$RDSDNS,RDSRegion=$RDSRegion RDSSize=$RDSSize"
    echo "Writing veeam_aws_rds to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_rds,rdsid=$RDSID,rdsname=$RDSName,rdsengine=$RDSEngine,rdsengineversion=$RDSEngineVersion,rdsawsid=$RDSAWSID,rdsclass=$RDSClass,rdsdns=$RDSDNS,rdsregion=$RDSRegion rdssize=$RDSSize"
           
    arrayRDS=$arrayRDS+1
done

##
# Veeam Backup for AWS EFS. This part will check VBA and report all the EFS
##
veeamVBAURL="$veeamBackupAWSServer:$veeamBackupAWSPort/api/v1/efs"
veeamVBAEFSUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H "x-api-version: 1.2-rev0" -H  "accept: application/json" 2>&1 -k --silent)

declare -i arrayEFS=0
for id in $(echo "$veeamVBAEFSUrl" | jq -r '.results[].id'); do
    EFSID=$(echo "$veeamVBAEFSUrl" | jq --raw-output ".results[$arrayEFS].id")
    EFSName=$(echo "$veeamVBAEFSUrl" | jq --raw-output ".results[$arrayEFS].name" | awk '{gsub(/ /,"\\ ");print}')
    EFSRegion=$(echo "$veeamVBAEFSUrl" | jq --raw-output ".results[$arrayEFS].region.name")    
    EFSAWSID=$(echo "$veeamVBAEFSUrl" | jq --raw-output ".results[$arrayEFS].awsResourceId")
    EFSAWSIDEncryption=$(echo "$veeamVBAEFSUrl" | jq --raw-output ".results[$arrayEFS].encrypted")
        case $EFSAWSIDEncryption in
        "false")
            encryption="0"
        ;;
        "true")
            encryption="1"
        ;;
        esac
    EFSSize=$(echo "$veeamVBAEFSUrl" | jq --raw-output ".results[$arrayEFS].size")
    EFSPerformance=$(echo "$veeamVBAEFSUrl" | jq --raw-output ".results[$arrayEFS].performanceMode")
    EFSThroughput=$(echo "$veeamVBAEFSUrl" | jq --raw-output ".results[$arrayEFS].throughputMode")
    
    #echo "veeam_aws_RDS,RDSID=$RDSID,RDSName=$RDSName,RDSEngine=$RDSEngine,RDSEngineVersion=$RDSEngineVersion,RDSAWSID=$RDSAWSID,RDSClass=$RDSClass,RDSDNS=$RDSDNS,RDSRegion=$RDSRegion RDSSize=$RDSSize"
    echo "Writing veeam_aws_efs to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_efs,efsid=$EFSID,efsname=$EFSName,efsregion=$EFSRegion,efsawsid=$EFSAWSID,efsperformance=$EFSPerformance,efsthroughput=$EFSThroughput,efsencryption=$EFSAWSIDEncryption rdssize=$EFSSize"
           
    arrayEFS=$arrayEFS+1
done

##
# Veeam Backup for AWS VPC. This part will check VBA and report all the Protected VPC
##
veeamVBAURL="$veeamBackupAWSServer:$veeamBackupAWSPort/api/v1/vpc/policy"
veeamVBAVPCUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H "x-api-version: 1.2-rev0" -H  "accept: application/json" 2>&1 -k --silent)

declare -i arrayVPC=0
for id in $(echo "$veeamVBAVPCUrl" | jq -r '.sourceOptions.selectedLocations[0].regions[].id'); do
    VPCID=$(echo "$veeamVBAVPCUrl" | jq --raw-output ".sourceOptions.selectedLocations[0].regions[$arrayVPC].id")    
    VPCRegion=$(echo "$veeamVBAVPCUrl" | jq --raw-output ".sourceOptions.selectedLocations[0].regions[$arrayVPC].displayName" | awk '{gsub(/ /,"\\ ");print}')    
    
    #echo "veeam_aws_VPC,VPCID=$VPCID,VPCRegion=$VPCRegion VPCProtected=1"
    echo "Writing veeam_aws_vpc to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_vpc,vpcid=$VPCID,vpcregion=$VPCRegion vpcprotected=1"
           
    arrayVPC=$arrayVPC+1
done

##
# Veeam Backup for AWS Policies. This part will check VBA EC2 Policies
##
veeamVBAURL="$veeamBackupAWSServer:$veeamBackupAWSPort/api/v1/virtualMachines/policies"
veeamVBAPoliciesUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H "x-api-version: 1.2-rev0" -H  "accept: application/json" 2>&1 -k --silent)

declare -i arraypolicies=0
for id in $(echo "$veeamVBAPoliciesUrl" | jq -r '.results[].id'); do
    PolicyID=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].id")
    PolicyStatus=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].isEnabled")
    PolicyName=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].name" | awk '{gsub(/ /,"\\ ");print}')
    PolicyDescription=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].description" | awk '{gsub(/ /,"\\ ");print}')
    if [ "$PolicyDescription" == "" ];then
        declare -i PolicyDescription=0
    fi
    PolicyBackupRepository=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].backupSettings.targetRepositoryId")
    PolicySnapshotCount=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].scheduleSettings.dailySchedule.snapshotOptions.retention.count")

    #echo "veeam_aws_policies,PolicyID=$PolicyID,PolicyType=EC2,PolicyStatus=$PolicyStatus,PolicyName=$PolicyName,PolicyDescription=$PolicyDescription,PolicyBackupRepository=$PolicyBackupRepository PolicySnapshotCount=$PolicySnapshotCount"
    echo "Writing veeam_aws_policies EC2 to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_policies,PolicyID=$PolicyID,PolicyType=EC2,PolicyStatus=$PolicyStatus,PolicyName=$PolicyName,PolicyDescription=$PolicyDescription,PolicyBackupRepository=$PolicyBackupRepository PolicySnapshotCount=$PolicySnapshotCount"
    
    arraypolicies=$arraypolicies+1
done

##
# Veeam Backup for AWS Policies. This part will check VBA RDS Policies
##
veeamVBAURL="$veeamBackupAWSServer:$veeamBackupAWSPort/api/v1/rds/policies"
veeamVBAPoliciesUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H "x-api-version: 1.2-rev0" -H  "accept: application/json" 2>&1 -k --silent)

declare -i arrayrdspolicies=0
for id in $(echo "$veeamVBAPoliciesUrl" | jq -r '.results[].id'); do
    PolicyID=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrdspolicies].id")
    PolicyStatus=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrdspolicies].isEnabled")
    PolicyName=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrdspolicies].name" | awk '{gsub(/ /,"\\ ");print}')
    PolicyDescription=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrdspolicies].description" | awk '{gsub(/ /,"\\ ");print}')
    if [ "$PolicyDescription" == "" ];then
        declare -i PolicyDescription=0
    fi
    PolicyBackupRepository=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrdspolicies].backupSettings.targetRepositoryId")
    PolicySnapshotCount=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrdspolicies].scheduleSettings.dailySchedule.snapshotOptions.retention.count")

    #echo "veeam_aws_policies,PolicyID=$PolicyID,PolicyType=RDS,PolicyStatus=$PolicyStatus,PolicyName=$PolicyName,PolicyDescription=$PolicyDescription,PolicyBackupRepository=$PolicyBackupRepository PolicySnapshotCount=$PolicySnapshotCount"
    echo "Writing veeam_aws_policies RDS to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_policies,PolicyID=$PolicyID,PolicyType=RDS,PolicyStatus=$PolicyStatus,PolicyName=$PolicyName,PolicyDescription=$PolicyDescription,PolicyBackupRepository=$PolicyBackupRepository PolicySnapshotCount=$PolicySnapshotCount"
    
    arrayrdspolicies=$arrayrdspolicies+1
done

##
# Veeam Backup for AWS Policies. This part will check VBA EFS Policies
##
veeamVBAURL="$veeamBackupAWSServer:$veeamBackupAWSPort/api/v1/efs/policies"
veeamVBAPoliciesUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H "x-api-version: 1.2-rev0" -H  "accept: application/json" 2>&1 -k --silent)

declare -i arrayefspolicies=0
for id in $(echo "$veeamVBAPoliciesUrl" | jq -r '.results[].id'); do
    PolicyID=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayefspolicies].id")
    PolicyStatus=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayefspolicies].isEnabled")
    PolicyName=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayefspolicies].name" | awk '{gsub(/ /,"\\ ");print}')
    PolicyDescription=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayefspolicies].description" | awk '{gsub(/ /,"\\ ");print}')
    if [ "$PolicyDescription" == "" ];then
        declare -i PolicyDescription=0
    fi
    PolicySnapshotCount=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayefspolicies].scheduleSettings.dailySchedule.backupOptions.retention.count")
    PolicyRegionID=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayefspolicies].regions[].regionId")    
    PolicyBackupVaultID=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayefspolicies].regions[].backupVaultId")    
    PolicySelectedEFSID=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayefspolicies].selectedItems.efsIds[]")

    #echo "veeam_aws_policies,PolicyID=$PolicyID,PolicyType=EFS,PolicyStatus=$PolicyStatus,PolicyName=$PolicyName,PolicyDescription=$PolicyDescription,PolicyRegionID=$PolicyRegionID,PolicyBackupVaultID=$PolicyBackupVaultID,PolicySelectedEFSID=$PolicySelectedEFSID PolicySnapshotCount=$PolicySnapshotCount"
    echo "Writing veeam_aws_policies EFS to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_policies,PolicyID=$PolicyID,PolicyType=EFS,PolicyStatus=$PolicyStatus,PolicyName=$PolicyName,PolicyDescription=$PolicyDescription,PolicyRegionID=$PolicyRegionID,PolicyBackupVaultID=$PolicyBackupVaultID,PolicySelectedEFSID=$PolicySelectedEFSID PolicySnapshotCount=$PolicySnapshotCount"
    
    arrayefspolicies=$arrayefspolicies+1
done

##
# Veeam Backup for AWS Policies. This part will check VBA VPC Policies
##
veeamVBAURL="$veeamBackupAWSServer:$veeamBackupAWSPort/api/v1/vpc/policy"
veeamVBAPoliciesVPCUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H "x-api-version: 1.2-rev0" -H  "accept: application/json" 2>&1 -k --silent)

    PolicyVPCStatus=$(echo "$veeamVBAPoliciesVPCUrl" | jq --raw-output ".backupOptionsEnabled")
    if [ "$PolicyVPCStatus" == "true" ];then
        PolicyVPCName="VPC\\ Configuration\\ Backup"
        PolicyVPCRetentionTypeLT=$(echo "$veeamVBAPoliciesVPCUrl" | jq --raw-output ".scheduleOptions.dailySchedule.retention.type")
        PolicyVPCRetentionCountLT=$(echo "$veeamVBAPoliciesVPCUrl" | jq --raw-output ".scheduleOptions.dailySchedule.retention.count")
        PolicyVPCRetentionTypeST=$(echo "$veeamVBAPoliciesVPCUrl" | jq --raw-output ".scheduleOptions.dailySchedule.schedule.type")
        PolicyVPCRetentionCountST=$(echo "$veeamVBAPoliciesVPCUrl" | jq --raw-output ".scheduleOptions.dailySchedule.schedule.count")
        PolicyVPCDescription="Collect\\ data\\ every\\ $PolicyVPCRetentionCountST\\ $PolicyVPCRetentionTypeST\\ and\\ keep\\ copies\\ for\\ $PolicyVPCRetentionCountLT\\ $PolicyVPCRetentionTypeLT"
    elif [ "$PolicyVPCStatus" == "false" ];then
        PolicyVPCName=""
        PolicyVPCRetentionTypeLT=""
        PolicyVPCRetentionCountLT="0"
        PolicyVPCRetentionTypeST=""
        PolicyVPCRetentionCountST="0"
        PolicyVPCDescription=""
    fi

    #echo "veeam_aws_policies,PolicyID=001,PolicyType=VPC,PolicyStatus=$PolicyStatus,PolicyVPCName=$PolicyVPCName,PolicyVPCDescription=$PolicyVPCDescription,PolicyVPCRetentionTypeLT=$PolicyVPCRetentionTypeLT,PolicyVPCRetentionTypeST=$PolicyVPCRetentionTypeST PolicyVPCRetentionCountLT=$PolicyVPCRetentionCountLT,PolicyVPCRetentionCountST=$PolicyVPCRetentionCountST,PolicySnapshotCount=999
    echo "Writing veeam_aws_policies VPC to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_policies,PolicyID=001,PolicyType=VPC,PolicyStatus=$PolicyStatus,PolicyName=$PolicyVPCName,PolicyDescription=$PolicyVPCDescription,PolicyVPCRetentionTypeLT=$PolicyVPCRetentionTypeLT,PolicyVPCRetentionTypeST=$PolicyVPCRetentionTypeST PolicyVPCRetentionCountLT=$PolicyVPCRetentionCountLT,PolicyVPCRetentionCountST=$PolicyVPCRetentionCountST,PolicySnapshotCount=999"

##
# Veeam Backup for AWS Repositories. This part will check VBA Repositories
##
veeamVBAURL="$veeamBackupAWSServer:$veeamBackupAWSPort/api/v1/repositories"
veeamVBAPoliciesUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H "x-api-version: 1.2-rev0" -H  "accept: application/json" 2>&1 -k --silent)

declare -i arrayrepositories=0
for id in $(echo "$veeamVBAPoliciesUrl" | jq -r '.results[].id'); do
    RepositoryID=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrepositories].id")
    RepositoryName=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrepositories].name" | awk '{gsub(/ /,"\\ ");print}')
    RepositoryDescription=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrepositories].description" | awk '{gsub(/ /,"\\ ");print}')
    if [ "$RepositoryDescription" == "" ];then
        declare -i RepositoryDescription=0
    fi
    RepositoryBucketName=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrepositories]._embedded.bucket" | awk '{gsub(/ /,"\\ ");print}')
    RepositoryRegion=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrepositories]._embedded.region")
    RepositoryStorageClass=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrepositories].storageClass")
    RepositoryFolderName=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrepositories].amazonStorageFolder" | awk '{gsub(/ /,"\\ ");print}')
    RepositoryEncryption=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrepositories].enableEncryption")
        case $RepositoryEncryption in
        "false")
            encryption="0"
        ;;
        "true")
            encryption="1"
        ;;
        esac
    RepositoryAWSID=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrepositories].IAMRoleId")

    #echo "veeam_aws_repositories,repoID=$RepositoryID,repoName=$RepositoryName,repoDescription=$RepositoryDescription,repoBucket=$RepositoryBucketName,repoFolderName=$RepositoryFolderName,repoRegion=$RepositoryRegion,repoclass=$RepositoryStorageClass,repoencryption=$RepositoryEncryption,repoAWSID=$RepositoryAWSID repoEncryption=$encryption"
    echo "Writing veeam_aws_repositories to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_repositories,repoID=$RepositoryID,repoName=$RepositoryName,repoDescription=$RepositoryDescription,repoBucket=$RepositoryBucketName,repoFolderName=$RepositoryFolderName,repoRegion=$RepositoryRegion,repoclass=$RepositoryStorageClass,repoencryption=$RepositoryEncryption,repoAWSID=$RepositoryAWSID repoEncryption=$encryption"
    
    arrayrepositories=$arrayrepositories+1
done

##
# Veeam Backup for AWS EC2 Sessions. This part will check VBA Sessions for EC2 Backup Jobs
##
veeamVBAURL="$veeamBackupAWSServer:$veeamBackupAWSPort/api/v1/sessions?Limit=50&Types=Job"
veeamVBASessionsBackupUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H "x-api-version: 1.2-rev0" -H  "accept: application/json" 2>&1 -k --silent)

declare -i arraysessionsbackup=0
for id in $(echo "$veeamVBASessionsBackupUrl" | jq -r '.results[].id'); do
    SessionID=$(echo "$veeamVBASessionsBackupUrl" | jq --raw-output ".results[$arraysessionsbackup].id")
    SessionStatus=$(echo "$veeamVBASessionsBackupUrl" | jq --raw-output ".results[$arraysessionsbackup].result")
    case $SessionStatus in
        Success)
            jobStatus="1"
        ;;
        Warning)
            jobStatus="2"
        ;;
        Failed)
            jobStatus="3"
        ;;
        esac
    SessionType=$(echo "$veeamVBASessionsBackupUrl" | jq --raw-output ".results[$arraysessionsbackup].type")
    SessionDuration=$(echo "$veeamVBASessionsBackupUrl" | jq --raw-output ".results[$arraysessionsbackup].executionDuration")
    SessionDurationS=$(echo $SessionDuration | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')
    SessionStopTime=$(echo "$veeamVBASessionsBackupUrl" | jq --raw-output ".results[$arraysessionsbackup].executionStartTime")
    SessionTimeStamp=$(date -d "${SessionStopTime}" '+%s')
    SessionPolicyID=$(echo "$veeamVBASessionsBackupUrl" | jq --raw-output ".results[$arraysessionsbackup].id")
    SessionPolicyJobName=$(echo "$veeamVBASessionsBackupUrl" | jq --raw-output ".results[$arraysessionsbackup].reason" | awk '{gsub(/ /,"\\ ");print}')
    if [ "$SessionPolicyJobName" == "" ];then
        declare -i SessionPolicyJobName=0
    fi

    #echo "veeam_aws_sessions,sessiontype="EC2",sessionID=$SessionID,sessionType=$SessionType,sessionPolicyID=$SessionPolicyID,sessionPolicyJobName=$SessionPolicyJobName sessionDuration=$SessionDuration, sessionStatus=$jobStatus $SessionTimeStamp"
    echo "Writing veeam_aws_sessions Job to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_sessions,sessiontype="EC2",sessionID=$SessionID,sessionType=$SessionType,sessionPolicyID=$SessionPolicyID,sessionPolicyJobName=$SessionPolicyJobName sessionDuration=$SessionDuration,sessionStatus=$jobStatus $SessionTimeStamp"
    
    arraysessionsbackup=$arraysessionsbackup+1
done

##
# Veeam Backup for AWS Policies Sessions. This part will check VBA Sessions for RDS, VPC, and EC2 Snapshots (Hope it will be improved when API allows us to filter per type)
##
veeamVBAURL="$veeamBackupAWSServer:$veeamBackupAWSPort/api/v1/sessions?Limit=50&Types=Policy"
veeamVBASessionsPolicyUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H "x-api-version: 1.2-rev0" -H  "accept: application/json" 2>&1 -k --silent)

declare -i arraysessionspolicy=0
for id in $(echo "$veeamVBASessionsPolicyUrl" | jq -r '.results[].id'); do
    SessionID=$(echo "$veeamVBASessionsPolicyUrl" | jq --raw-output ".results[$arraysessionspolicy].id")    
    SessionTypeExt=$(echo "$veeamVBASessionsPolicyUrl" | jq --raw-output ".results[$arraysessionspolicy].extendedSessionType")
    case $SessionTypeExt in
        PolicySnapshot)
            extendedSessionType="1"
        ;;
        PolicyRdsSnapshot)
            extendedSessionType="2"
        ;;
        VpcBackup)
            extendedSessionType="3"
        ;;
        PolicyBackup)
            extendedSessionType="4"
        ;;
        esac
    SessionStatus=$(echo "$veeamVBASessionsPolicyUrl" | jq --raw-output ".results[$arraysessionspolicy].result")
    case $SessionStatus in
        Success)
            jobStatus="1"
        ;;
        Warning)
            jobStatus="2"
        ;;
        Failed)
            jobStatus="3"
        ;;
        esac
    SessionType=$(echo "$veeamVBASessionsPolicyUrl" | jq --raw-output ".results[$arraysessionspolicy].type")
    SessionDuration=$(echo "$veeamVBASessionsPolicyUrl" | jq --raw-output ".results[$arraysessionspolicy].executionDuration")
    SessionDurationS=$(echo $SessionDuration | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')
    SessionStopTime=$(echo "$veeamVBASessionsPolicyUrl" | jq --raw-output ".results[$arraysessionspolicy].executionStartTime")
    SessionTimeStamp=$(date -d "${SessionStopTime}" '+%s')
    SessionPolicyID=$(echo "$veeamVBASessionsPolicyUrl" | jq --raw-output ".results[$arraysessionspolicy].id")
    SessionPolicyJobName=$(echo "$veeamVBASessionsPolicyUrl" | jq --raw-output ".results[$arraysessionspolicy].name" | awk '{gsub(/ /,"\\ ");print}')

    #echo "veeam_aws_sessions,sessiontype=$extendedSessionType,sessionID=$SessionID,sessionType=$SessionType,sessionDuration=$SessionDuration,sessionPolicyID=$SessionPolicyID,sessionPolicyJobName=$SessionPolicyJobName sessionStatus=$jobStatus $SessionTimeStamp"
    echo "Writing veeam_aws_sessions Policy to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_aws_sessions,sessiontype=$extendedSessionType,sessionID=$SessionID,sessionType=$SessionType,sessionPolicyID=$SessionPolicyID,sessionPolicyJobName=$SessionPolicyJobName sessionDuration=$SessionDuration,sessionStatus=$jobStatus $SessionTimeStamp"
    
    arraysessionspolicy=$arraysessionspolicy+1
done