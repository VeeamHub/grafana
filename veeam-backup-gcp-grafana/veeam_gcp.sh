#!/bin/bash
##      .SYNOPSIS
##      Grafana Dashboard for Veeam Backup for Google Cloud Platform v1.0 - Using API to InfluxDB Script
## 
##      .DESCRIPTION
##      This Script will query the Veeam Backup for GCP API and send the data directly to InfluxDB, which can be used to present it to Grafana. 
##      The Script and the Grafana Dashboard it is provided as it is, and bear in mind you can not open support Tickets regarding this project. It is a Community Project
##
##      .Notes
##      NAME:  veeam_gcp.sh
##      ORIGINAL NAME: veeam_gcp.sh
##      LASTEDIT: 27/12/2021
##      VERSION: 1.0
##      KEYWORDS: Veeam, InfluxDB, Grafana
   
##      .Link
##      https://jorgedelacruz.es/
##      https://jorgedelacruz.uk/

# Configurations
##
# Endpoint URL for InfluxDB
veeamInfluxDBURL="YOURINFLUXSERVER" ##Use https://fqdn or https://IP in case you use SSL
veeamInfluxDBPort="8086" #Default Port
veeamInfluxDBBucket="veeam" # InfluxDB bucket name (not ID)
veeamInfluxDBToken="TOKEN" # InfluxDB access token with read/write privileges for the bucket
veeamInfluxDBOrg="ORG NAME" # InfluxDB organisation name (not ID)

# Endpoint URL for login action
veeamUsername="YOURVEEAMBACKUPUSER"
veeamPassword="YOURVEEAMBACKUPPASS"
veeamBackupGCPServer="https://YOURVEEAMBACKUPIP"
veeamBackupGCPPort="13140" #Default Port

veeamBearer=$(curl -X POST --header "Content-Type: application/x-www-form-urlencoded" --header "Accept: application/json" -d "Username=$veeamUsername&Password=$veeamPassword&refresh_token=&grant_type=Password&mfa_token=&mfa_code=" "$veeamBackupGCPServer:$veeamBackupGCPPort/api/v1/token" -k --silent | jq -r '.access_token')

##
# Veeam Backup for GCP Overview. This part will check VBA Overview
##
veeamVBAURL="$veeamBackupGCPServer:$veeamBackupGCPPort/api/v1/version"
veeamVBAOverviewUrl=$(curl -X GET "$veeamVBAURL" -H "Authorization: Bearer $veeamBearer" -H "accept: application/json" -H "x-api-version: 1.0-rev0" 2>&1 -k --silent)

    version=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".version")
    
veeamVBAURL="$veeamBackupGCPServer:$veeamBackupGCPPort/api/v1/overview"
veeamVBAOverviewUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" -H "x-api-version: 1.0-rev0" 2>&1 -k --silent)

    WorkerLocationsCount=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".workerLocationsCount")
    PoliciesCount=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".policiesCount")
    RepositoriesCount=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".repositoryCount")
    
veeamVBAURL="$veeamBackupGCPServer:$veeamBackupGCPPort/api/v1/vmInstances"
veeamVBAOverviewUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" -H "x-api-version: 1.0-rev0" 2>&1 -k --silent)

    VMsCount=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".pagination.total")

veeamVBAURL="$veeamBackupGCPServer:$veeamBackupGCPPort/api/v1/licensing/license"
veeamVBAOverviewUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" -H "x-api-version: 1.0-rev0" 2>&1 -k --silent)

    VMsProtected=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".usedInstancesCount")
    
    #echo "veeam_gcp_overview,serverName=$veeamBackupGCPServer,version=$version VMs=$VMsCount,VMsProtected=$VMsProtected,Policies=$PoliciesCount,Repositories=$RepositoriesCount"
    echo "Writing veeam_gcp_overview to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_gcp_overview,serverName=$veeamBackupGCPServer,version=$version VMs=$VMsCount,VMsProtected=$VMsProtected,Policies=$PoliciesCount,Repositories=$RepositoriesCount"
    
##
# Veeam Backup for GCP Instances. This part will check VBA and report all the protected Instances
##
veeamVBAURL="$veeamBackupGCPServer:$veeamBackupGCPPort/api/v1/vmInstances"
veeamVBAInstancesUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" -H "x-api-version: 1.0-rev0" 2>&1 -k --silent)

declare -i arrayinstances=0
for id in $(echo "$veeamVBAInstancesUrl" | jq -r '.data[].id'); do
    VMID=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".data[$arrayinstances].id")
    
    # Check if the VM has points or not (Protected vs Unprotected)
    veeamVBAURL="$veeamBackupGCPServer:$veeamBackupGCPPort/api/v1/vmInstances/$VMID/restorePoints"
    veeamRestorePointsUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" -H "x-api-version: 1.0-rev0" 2>&1 -k --silent)
    
    VMRPTotal=$(echo "$veeamRestorePointsUrl" | jq --raw-output ".pagination.total")
    if (( $VMRPTotal > 0 )); then 
        
        VMName=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".data[$arrayinstances].name" | awk '{gsub(/ /,"\\ ");print}')        
        VMResourceID=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".data[$arrayinstances].resourceId" | awk '{gsub(/ /,"\\ ");print}')
        VMType=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".data[$arrayinstances].instanceType")              
        VMProjectID=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".data[$arrayinstances].projectId")  
        VMRegion=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".data[$arrayinstances].locationName")
        
        #echo "veeam_gcp_vm,serverName=$veeamBackupGCPServer,VMID=$VMID,VMName=$VMName,VMType=$VMType,VMRegion=$VMRegion RestorePoints=$VMRPTotal" 
        echo "Writing veeam_gcp_vm  to InfluxDB"
        curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_gcp_vm,serverName=$veeamBackupGCPServer,VMID=$VMID,VMName=$VMName,VMType=$VMType,VMRegion=$VMRegion RestorePoints=$VMRPTotal"
    fi 
 
    arrayinstances=$arrayinstances+1    
done

##
# Veeam Backup for GCP Instances. This part will check VBA and report all the unprotected Instances
##
veeamVBAURL="$veeamBackupGCPServer:$veeamBackupGCPPort/api/v1/vmInstances"
veeamVBAUnprotectedUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" -H "x-api-version: 1.0-rev0" 2>&1 -k --silent)

declare -i arrayunprotected=0
declare -i UPVM=0
declare -i unprotectedvms=0
for id in $(echo "$veeamVBAUnprotectedUrl" | jq -r '.data[].id'); do
    VMID=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".data[$arrayunprotected].id")
    
    # Check if the VM has points or not (Protected vs Unprotected)
    veeamVBAURL="$veeamBackupGCPServer:$veeamBackupGCPPort/api/v1/vmInstances/$VMID/restorePoints"
    veeamRestorePointsUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" -H "x-api-version: 1.0-rev0" 2>&1 -k --silent)
    
    VMRPTotal=$(echo "$veeamRestorePointsUrl" | jq --raw-output ".pagination.total")
    
    if (( $VMRPTotal < 1 )); then 
        
        VMName=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".data[$arrayunprotected].name" | awk '{gsub(/ /,"\\ ");print}')        
        VMResourceID=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".data[$arrayunprotected].resourceId" | awk '{gsub(/ /,"\\ ");print}')
        VMType=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".data[$arrayunprotected].instanceType")              
        VMProjectID=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".data[$arrayunprotected].projectId")
        VMRegion=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".data[$arrayunprotected].locationName") 
        case $VMRegion in 
        "asia-east1-a") geohash="wsm8" UPVM="1" ;;
        "asia-east1-b") geohash="wsm8" UPVM="1" ;;
        "asia-east1-c") geohash="wsm8" UPVM="1" ;;
        "asia-east2-a") geohash="wecnyn" UPVM="1" ;;
        "asia-east2-b") geohash="wecnyn" UPVM="1" ;;
        "asia-east2-c") geohash="wecnyn" UPVM="1" ;;
        "asia-northeast1-a") geohash="xn76ux" UPVM="1" ;;
        "asia-northeast1-b") geohash="xn76ux" UPVM="1" ;;
        "asia-northeast1-c") geohash="xn76ux" UPVM="1" ;;
        "asia-northeast2-a") geohash="xn0m5r" UPVM="1" ;;
        "asia-northeast2-b") geohash="xn0m5r" UPVM="1" ;;
        "asia-northeast2-c") geohash="xn0m5r" UPVM="1" ;;
        "asia-northeast3-a") geohash="wydm9k" UPVM="1" ;;
        "asia-northeast3-b") geohash="wydm9k" UPVM="1" ;;
        "asia-northeast3-c") geohash="wydm9k" UPVM="1" ;;
        "asia-south1-a") geohash="te7u6r" UPVM="1" ;;
        "asia-south1-b") geohash="te7u6r" UPVM="1" ;;
        "asia-south1-c") geohash="te7u6r" UPVM="1" ;;
        "asia-south2-a") geohash="ttngj2" UPVM="1" ;;
        "asia-south2-b") geohash="ttngj2" UPVM="1" ;;
        "asia-south2-c") geohash="ttngj2" UPVM="1" ;;
        "asia-southeast1-a") geohash="w21xxu" UPVM="1" ;;
        "asia-southeast1-b") geohash="w21xxu" UPVM="1" ;;
        "asia-southeast1-c") geohash="w21xxu" UPVM="1" ;;
        "asia-southeast2-a") geohash="qqguxm" UPVM="1" ;;
        "asia-southeast2-b") geohash="qqguxm" UPVM="1" ;;
        "asia-southeast2-c") geohash="qqguxm" UPVM="1" ;;
        "australia-southeast1-a") geohash="r3gx2c" UPVM="1" ;;
        "australia-southeast1-b") geohash="r3gx2c" UPVM="1" ;;
        "australia-southeast1-c") geohash="r3gx2c" UPVM="1" ;;
        "australia-southeast2-a") geohash="r1r0fs" UPVM="1" ;;
        "australia-southeast2-b") geohash="r1r0fs" UPVM="1" ;;
        "australia-southeast2-c") geohash="r1r0fs" UPVM="1" ;;
        "europe-central2-a") geohash="u3qcjt" UPVM="1" ;;
        "europe-central2-b") geohash="u3qcjt" UPVM="1" ;;
        "europe-central2-c") geohash="u3qcjt" UPVM="1" ;;
        "europe-north1-a") geohash="udg2df" UPVM="1" ;;
        "europe-north1-b") geohash="udg2df" UPVM="1" ;;
        "europe-north1-c") geohash="udg2df" UPVM="1" ;;
        "europe-west1-b") geohash="u0fxne" UPVM="1" ;;
        "europe-west1-c") geohash="u0fxne" UPVM="1" ;;
        "europe-west1-d") geohash="u0fxne" UPVM="1" ;;
        "europe-west2-a") geohash="gcpvj" UPVM="1" ;;
        "europe-west2-b") geohash="gcpvj" UPVM="1" ;;
        "europe-west2-c") geohash="gcpvj" UPVM="1" ;;
        "europe-west3-a") geohash="u0yjj7" UPVM="1" ;;
        "europe-west3-b") geohash="u0yjj7" UPVM="1" ;;
        "europe-west3-c") geohash="u0yjj7" UPVM="1" ;;
        "europe-west4-a") geohash="u1kzun" UPVM="1" ;;
        "europe-west4-b") geohash="u1kzun" UPVM="1" ;;
        "europe-west4-c") geohash="u1kzun" UPVM="1" ;;
        "europe-west6-a") geohash="u0qjd2" UPVM="1" ;;
        "europe-west6-b") geohash="u0qjd2" UPVM="1" ;;
        "europe-west6-c") geohash="u0qjd2" UPVM="1" ;;
        "northamerica-northeast1-a") geohash="f25dfb" UPVM="1" ;;
        "northamerica-northeast1-b") geohash="f25dfb" UPVM="1" ;;
        "northamerica-northeast1-c") geohash="f25dfb" UPVM="1" ;;
        "northamerica-northeast2-a") geohash="dpz82u" UPVM="1" ;;
        "northamerica-northeast2-b") geohash="dpz82u" UPVM="1" ;;
        "northamerica-northeast2-c") geohash="dpz82u" UPVM="1" ;;
        "southamerica-east1-a") geohash="6gydpe" UPVM="1" ;;
        "southamerica-east1-b") geohash="6gydpe" UPVM="1" ;;
        "southamerica-east1-c") geohash="6gydpe" UPVM="1" ;;
        "southamerica-west1-a,b,c") geohash="66jcck" UPVM="1" ;;
        "us-central1-a") geohash="1b5b48" UPVM="1" ;;
        "us-central1-b") geohash="1b5b48" UPVM="1" ;;
        "us-central1-c") geohash="1b5b48" UPVM="1" ;;
        "us-central1-f") geohash="1b5b48" UPVM="1" ;;
        "us-east1-b") geohash="djzhg4" UPVM="1" ;;
        "us-east1-c") geohash="djzhg4" UPVM="1" ;;
        "us-east1-d") geohash="djzhg4" UPVM="1" ;;
        "us-east4-a") geohash="dqbyhd" UPVM="1" ;;
        "us-east4-b") geohash="dqbyhd" UPVM="1" ;;
        "us-east4-c") geohash="dqbyhd" UPVM="1" ;;
        "us-west1-a") geohash="c21g6j" UPVM="1" ;;
        "us-west1-b") geohash="c21g6j" UPVM="1" ;;
        "us-west1-c") geohash="c21g6j" UPVM="1" ;;
        "us-west2-a") geohash="9q5cth" UPVM="1" ;;
        "us-west2-b") geohash="9q5cth" UPVM="1" ;;
        "us-west2-c") geohash="9q5cth" UPVM="1" ;;
        "us-west3-a") geohash="9x224b" UPVM="1" ;;
        "us-west3-b") geohash="9x224b" UPVM="1" ;;
        "us-west3-c") geohash="9x224b" UPVM="1" ;;
        "us-west4-a") geohash="9qqjnu" UPVM="1" ;;
        "us-west4-b") geohash="9qqjnu" UPVM="1" ;;
        "us-west4-c") geohash="9qqjnu" UPVM="1" ;;
        esac

        #echo "veeam_gcp_vm_unprotected,serverName=$veeamBackupGCPServer,VMID=$VMID,VMName=$VMName,VMType=$VMType,VMRegion=$VMRegion,geohash=$geohash,UPVM=$UPVM RestorePoints=$VMRPTotal" 
        echo "Writing veeam_gcp_vm_unprotected  to InfluxDB"
        curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_gcp_vm_unprotected,serverName=$veeamBackupGCPServer,VMID=$VMID,VMName=$VMName,VMType=$VMType,VMRegion=$VMRegion,geohash=$geohash UPVM=$UPVM,RestorePoints=$VMRPTotal"
        unprotectedvms=$unprotectedvms+1
    fi 
 
    arrayunprotected=$arrayunprotected+1    
done

    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_gcp_vm_unprotected TotalVMs=$unprotectedvms"

##
# Veeam Backup for GCP Policies. This part will check VBA VM Policies
##
veeamVBAURL="$veeamBackupGCPServer:$veeamBackupGCPPort/api/v1/vmInstance/policies"
veeamVBAPoliciesUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" -H "x-api-version: 1.0-rev0" 2>&1 -k --silent)

declare -i arraypolicies=0
for id in $(echo "$veeamVBAPoliciesUrl" | jq -r '.data[].id'); do
    PolicyID=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".data[$arraypolicies].id")
    ProjectID=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".data[$arraypolicies].projectId")
    PolicyStatus=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".data[$arraypolicies].isEnabled")
    PolicyName=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".data[$arraypolicies].name" | awk '{gsub(/ /,"\\ ");print}')
    PolicyDescription=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".data[$arraypolicies].description" | awk '{gsub(/ /,"\\ ");print}')
    if [ "$PolicyDescription" == "" ]; then declare -i PolicyDescription=0; fi
    PolicyBackupEnabled=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".data[$arraypolicies].backupOptionsEnabled")
    PolicySnapshotCountDaily=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".data[$arraypolicies].scheduleOptions.dailySchedule.snapshotOptions.retention.count")
    if [[ $PolicySnapshotCountDaily == "null" ]]; then PolicySnapshotCountDaily=0; fi
    PolicySnapshotCountWeekly=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".data[$arraypolicies].scheduleOptions.weeklySchedule.snapshotOptions.retention.count")
    if [[ $PolicySnapshotCountWeekly == "null" ]]; then PolicySnapshotCountWeekly=0; fi
    PolicySnapshotCountMonthly=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".data[$arraypolicies].scheduleOptions.monthlySchedule.snapshotOptions.retention.count")
    if [[ $PolicySnapshotCountMonthly == "null" ]]; then PolicySnapshotCountMonthly=0; fi
    PolicySnapshotCountYearly=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].scheduleOptions.yearlySchedule.snapshotOptions.retention.count")
    if [[ $PolicySnapshotCountYearly == "null" ]]; then PolicySnapshotCountYearly=0; fi
    appaware=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].snapshotSettings.applicationAwareSnapshot")


    #echo "veeam_gcp_policies,serverName=$veeamBackupGCPServer,PolicyID=$PolicyID,ProjectID=$ProjectID,PolicyStatus=$PolicyStatus,PolicyName=$PolicyName,PolicyDescription=$PolicyDescription PolicySnapshotCountDaily=$PolicySnapshotCountDaily,PolicySnapshotCountWeekly=$PolicySnapshotCountWeekly,PolicySnapshotCountMonthly=$PolicySnapshotCountMonthly,PolicySnapshotCountYearly=$PolicySnapshotCountYearly"
    echo "Writing veeam_gcp_policies to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_gcp_policies,serverName=$veeamBackupGCPServer,PolicyID=$PolicyID,ProjectID=$ProjectID,PolicyStatus=$PolicyStatus,PolicyName=$PolicyName,PolicyDescription=$PolicyDescription PolicySnapshotCountDaily=$PolicySnapshotCountDaily,PolicySnapshotCountWeekly=$PolicySnapshotCountWeekly,PolicySnapshotCountMonthly=$PolicySnapshotCountMonthly,PolicySnapshotCountYearly=$PolicySnapshotCountYearly"
    
    arraypolicies=$arraypolicies+1
done

##
# Veeam Backup for GCP Repositories. This part will check VBA Repositories
##
veeamVBAURL="$veeamBackupGCPServer:$veeamBackupGCPPort/api/v1/repositories"
veeamVBARepositoriesUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" -H "x-api-version: 1.0-rev0" 2>&1 -k --silent)

declare -i arrayrepositories=0
for id in $(echo "$veeamVBARepositoriesUrl" | jq -r '.data[].id'); do
    RepositoryID=$(echo "$veeamVBARepositoriesUrl" | jq --raw-output ".data[$arrayrepositories].id")
    RepositoryName=$(echo "$veeamVBARepositoriesUrl" | jq --raw-output ".data[$arrayrepositories].name" | awk '{gsub(/ /,"\\ ");print}')
    RepositoryDescription=$(echo "$veeamVBARepositoriesUrl" | jq --raw-output ".data[$arrayrepositories].description" | awk '{gsub(/ /,"\\ ");print}')
    if [ "$RepositoryDescription" == "" ]; then declare -i RepositoryDescription=0; fi
    RepositoryBucketName=$(echo "$veeamVBARepositoriesUrl" | jq --raw-output ".data[$arrayrepositories].bucketName" | awk '{gsub(/ /,"\\ ");print}')
    RepositoryFolderName=$(echo "$veeamVBARepositoriesUrl" | jq --raw-output ".data[$arrayrepositories].folderName" | awk '{gsub(/ /,"\\ ");print}')
    ProjectID=$(echo "$veeamVBARepositoriesUrl" | jq --raw-output ".data[$arrayrepositories].projectId")  
    RepositoryEncryption=$(echo "$veeamVBARepositoriesUrl" | jq --raw-output ".data[$arrayrepositories].encryptionEnabled") 
        case $RepositoryEncryption in
        "false")
            encryption="0"
       ;;
        "true")
            encryption="1"
       ;;
        esac
    RepositoryTier=$(echo "$veeamVBARepositoriesUrl" | jq --raw-output ".data[$arrayrepositories].storageClass")

    #echo "veeam_gcp_repositories,serverName=$veeamBackupGCPServer,repoID=$RepositoryID,repoName=$RepositoryName,repoDescription=$RepositoryDescription,repoBucketName=$RepositoryBucketName,repoAFolder=$RepositoryFolderName,ProjectID=$ProjectID,repoTier=$RepositoryTier repoEncryption=$encryption"
    echo "Writing veeam_gcp_repositories to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_gcp_repositories,serverName=$veeamBackupGCPServer,repoID=$RepositoryID,repoName=$RepositoryName,repoDescription=$RepositoryDescription,repoBucketName=$RepositoryBucketName,repoAFolder=$RepositoryFolderName,ProjectID=$ProjectID,repoTier=$RepositoryTier repoEncryption=$encryption"
    
    arrayrepositories=$arrayrepositories+1
done

##
# Veeam Backup for GCP Sessions. This part will check VBA Sessions
##
veeamVBAURL="$veeamBackupGCPServer:$veeamBackupGCPPort/api/v1/sessions?limit=50"
veeamVBASessionsBackupUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" -H "x-api-version: 1.0-rev0" 2>&1 -k --silent)

declare -i arraysessionsbackup=0
for id in $(echo "$veeamVBASessionsBackupUrl" | jq -r '.data[].id'); do
    SessionID=$(echo "$veeamVBASessionsBackupUrl" | jq --raw-output ".data[$arraysessionsbackup].id")
    SessionStatus=$(echo "$veeamVBASessionsBackupUrl" | jq --raw-output ".data[$arraysessionsbackup].result")
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
    SessionType=$(echo "$veeamVBASessionsBackupUrl" | jq --raw-output ".data[$arraysessionsbackup].sessionType")
    SessionStartTime=$(echo "$veeamVBASessionsBackupUrl" | jq --raw-output ".data[$arraysessionsbackup].creationTimeUtc")
    creationTimeUnix=$(date -d "$SessionStartTime" +"%s")
    SessionStopTime=$(echo "$veeamVBASessionsBackupUrl" | jq --raw-output ".data[$arraysessionsbackup].endTimeUtc")
    SessionTimeStamp=$(date -d "${SessionStopTime}" '+%s')
    endTimeUnix=$(date -d "$SessionStopTime" +"%s")
    SessionDuration=$(($endTimeUnix-$creationTimeUnix))

    SessionPolicyName=$(echo "$veeamVBASessionsBackupUrl" | jq --raw-output ".data[$arraysessionsbackup].name" | awk '{gsub(/ /,"\\ ");print}')
    if [ "$SessionPolicyName" == "" ]; then SessionPolicyName="System\\ Policy"; fi

    #echo "veeam_gcp_sessions,serverName=$veeamBackupGCPServer,sessionID=$SessionID,sessionType=$SessionType,sessionPolicyName=$SessionPolicyName sessionStatus=$jobStatus,sessionDuration=$SessionDuration $SessionTimeStamp"
    echo "Writing veeam_gcp_sessions to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_gcp_sessions,serverName=$veeamBackupGCPServer,sessionID=$SessionID,sessionType=$SessionType,sessionPolicyName=$SessionPolicyName sessionStatus=$jobStatus,sessionDuration=$SessionDuration $SessionTimeStamp"
    
    arraysessionsbackup=$arraysessionsbackup+1
done