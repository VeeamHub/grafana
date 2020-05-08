#!/bin/bash
##      .SYNOPSIS
##      Grafana Dashboard for Veeam Backup Azure v1.0 - Using API to InfluxDB Script
## 
##      .DESCRIPTION
##      This Script will query the Veeam Backup for Azure API and send the data directly to InfluxDB, which can be used to present it to Grafana. 
##      The Script and the Grafana Dashboard it is provided as it is, and bear in mind you can not open support Tickets regarding this project. It is a Community Project
##	
##      .Notes
##      NAME:  veeam_azure.sh
##      ORIGINAL NAME: veeam_azure.sh
##      LASTEDIT: 27/04/2020
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
veeamInfluxDB="YOURINFLUXDB" #Default Database
veeamInfluxDBUser="YOURINFLUXUSER" #User for Database
veeamInfluxDBPassword="YOURINFLUXPASS" #Password for Database

# Endpoint URL for login action
veeamUsername="YOURVEEAMBACKUPUSER"
veeamPassword="YOURVEEAMBACKUPPASS"
veeamBackupAzureServer="https://YOURVEEAMBACKUPIP"
veeamBackupAzurePort="443" #Default Port

veeamBearer=$(curl -X POST --header "Content-Type: application/x-www-form-urlencoded" --header "Accept: application/json" -d "Username=$veeamUsername&Password=$veeamPassword&refresh_token=&grant_type=Password&mfa_token=&mfa_code=" "$veeamBackupAzureServer:$veeamBackupAzurePort/api/oauth2/token" -k --silent | jq -r '.access_token')

##
# Veeam Backup for Azure Overview. This part will check VBA Overview
##
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/v1/system/about"
veeamVBAOverviewUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

    version=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".serverVersion")
    workerversion=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".workerVersion")
    
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/v1/statistics/summary"
veeamVBAOverviewUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

    VMsCount=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".instancesCount")
    VMsProtected=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".protectedInstancesCount")
    PoliciesCount=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".policiesCount")
    RepositoriesCount=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".repositoriesCount")
    
    #echo "veeam_azure_overview VMs=$VMsCount,VMsProtected=$VMsProtected,Policies=$PoliciesCount,Repositories=$RepositoriesCount"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=s&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_azure_overview,version=$version,workerversion=$workerversion VMs=$VMsCount,VMsProtected=$VMsProtected,Policies=$PoliciesCount,Repositories=$RepositoriesCount"
    
##
# Veeam Backup for Azure Instances. This part will check VBA and report all the protected Instances
##
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/v1/virtualMachines?ProtectionStatus=Protected"
veeamVBAInstancesUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

declare -i arrayinstances=0
for id in $(echo "$veeamVBAInstancesUrl" | jq -r '.results[].id'); do
    VMID=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".results[$arrayinstances].id")
    VMName=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".results[$arrayinstances].name" | awk '{gsub(/ /,"\\ ");print}')
    VMResourceID=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".results[$arrayinstances].azureId")
    VMSize=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".results[$arrayinstances].totalSizeInGB")
    VMType=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".results[$arrayinstances].vmSize")    
    VMRegion=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".results[$arrayinstances].regionName")
        case $VMRegion in
        eastus)
            region="dq8hfn5y9wg"
        ;;
        eastus2)
            region="dq8hfn5y9wg"
        ;;
        centralus)
            region="9zmy1x8m433"
        ;;
        northcentralus)
            region="dp04jyu9y1h"
        ;;
        southcentralus)
            region="9v1zenczpg4"
        ;;
        westcentralus)
            region="9x9ut88ncmn"
        ;;
        westus)
            region="9qdc22t7bq5"
        ;;
        westus2)
            region="c22ky4rr2tr"
        ;;
        canadaeast)
            region="f2m4t3uwczv"
        ;;
        canadacentral)
            region="dpz2ww8wjj1"
        ;;
        brazilsouth)
            region="6ggzf5qgksb"
        ;;
        northeurope)
            region="gc2xsdvte9v"
        ;;
        westeurope)
            region="u16cn8kjdgh"
        ;;
        francecentral)
            region="u09tgyd042t"
        ;;
        francesouth)
            region="spey0yfznsg"
        ;;
        ukwest)
            region="gcjsvrxnucs"
        ;;
        uksouth)
            region="gcpv4s80b7q"
        ;;
        germanycentral)
            region="u0yj1k6fn2k"
        ;;
        germanynortheast)
            region="u320t9r2d24"
        ;;
        germanynorth)
            region="u1wbwwp4nbh"
        ;;
        germanywestcentral)
            region="u0yj1k6fn2k"
        ;;
        switzerlandnorth)
            region="u0qj88v4pz6"
        ;;
        switzerlandwest)
            region="u0hqg7m5zxh"
        ;;
        norwayeast)
            region="ukq8sp6wbxj"
        ;;
        norwaywest)
            region="u4exmjjkuqt"
        ;;
        southeastasia)
            region="w21xrz70d4w"
        ;;
        eastasia)
            region="wecp1v5pxcw"
        ;;
        australiaeast)
            region="r4pt8re3et0"
        ;;
        australiasoutheast)
            region="r1tb59hgjfe"
        ;;
        australiacentral)
            region="r3dp33jrs1y"
        ;;
        australiacentral2)
            region="r3dp33jrs1y"
        ;;
        chinaeast)
            region="wtw1tuk8sv2"
        ;;
        chinanorth)
            region="wx4e4qdjbwz"
        ;;
        chinaeast2)
            region="wtw1tuk8sv2"
        ;;
        chinanorth2)
            region="wx4e4qdjbwz"
        ;;
        centralindia)
            region="tek3rhq6efd"
        ;;
        westindia)
            region="te7sx3b7wxb"
        ;;
        southindia)
            region="tf2fnp23j4r"
        ;;
        japaneast)
            region="xn7k24npyzm"
        ;;
        japanwest)
            region="xn0m32yuw5f"
        ;;
        uksouth)
            region="gcpv4s80b7q"
        ;;
        koreacentral)
            region="wydjww8cwv6"
        ;;
        koreasouth)
            region="wy78p980qyu"
        ;;
        southafricawest)
            region="k3vp44hbv4f"
        ;;
        southafricanorth)
            region="ke7gj78s7cv"
        ;;
        uaecentral)
            region="thqdwrd35c1"
        ;;
        uaenorth)
            region="thrntscegt6"
        ;;
        esac
    VMOSType=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".results[$arrayinstances].osType") 
    veeamVBAVMURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/v1/policies?virtualMachineId=$veeamVBAInstanceId&usn=0&offset=0&limit=30"
    veeamVBAInstancesPolicyUrl=$(curl -X GET $veeamVBAVMURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)
    VMPolicy=$(echo "$veeamVBAInstancesPolicyUrl" | jq --raw-output ".results[0].name")   
    
    #echo "veeam_azure_vm,VMID=$VMID,VMName=$VMName,VMResourceId=$VMResourceID,VMType=$VMType,VMRegion=$region,VMPolicy=$VMPolicy,VMOSType=$VMOSType VMSize=$VMSize"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=s&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_azure_vm,VMID=$VMID,VMName=$VMName,VMResourceId=$VMResourceID,VMType=$VMType,VMPolicy=$VMPolicy,VMOSType=$VMOSType,VMRegion=$VMRegion VMSize=$VMSize"
    
    # Restore Points per Instance
    veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/v1/restorePoints?virtualMachineId=$VMID&onlyLatest=False"
    veeamRestorePointsUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)
    
    declare -i arrayRestorePoint=0
    for id in $(echo "$veeamRestorePointsUrl" | jq -r '.results[].id'); do
      VMJobType=$(echo "$veeamRestorePointsUrl" | jq --raw-output ".results[$arrayRestorePoint].backupDestination")
      VMJobid=$(echo "$veeamRestorePointsUrl" | jq --raw-output ".results[$arrayRestorePoint].id")
      VMJobBackupId=$(echo "$veeamRestorePointsUrl" | jq --raw-output ".results[$arrayRestorePoint].vbrId")
      VMJobSize=$(echo "$veeamRestorePointsUrl" | jq --raw-output ".results[$arrayRestorePoint].backupSizeBytes")
      VMJobTime=$(echo "$veeamRestorePointsUrl" | jq --raw-output ".results[$arrayRestorePoint].pointInTime")

        #echo "veeam_azure_restorepoints,JobType=$VMJobType,Jobid=$VMJobid,JobBackupId=$VMJobBackupId,JobTime=$VMJobTime JobSize=$VMJobSize"
        curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=s&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_azure_restorepoints,JobType=$VMJobType,Jobid=$VMJobid,JobBackupId=$VMJobBackupId,JobTime=$VMJobTime JobSize=$VMJobSize"
        
        arrayRestorePoint=$arrayRestorePoint+1
    done   
    arrayinstances=$arrayinstances+1    
done
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=s&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_azure_vm_protected TotalVMs=$arrayinstances"

##
# Veeam Backup for Azure Instances. This part will check VBA and report all the unprotected Instances
##
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/v1/virtualMachines?ProtectionStatus=Unprotected"
veeamVBAUnprotectedUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

declare -i arrayUnprotected=0
for id in $(echo "$veeamVBAUnprotectedUrl" | jq -r '.results[].id'); do
    VMID=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".results[$arrayUnprotected].id")
    VMName=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".results[$arrayUnprotected].name" | awk '{gsub(/ /,"\\ ");print}')
    VMResourceID=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".results[$arrayUnprotected].azureId")
    VMSize=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".results[$arrayUnprotected].totalSizeInGB")
    VMType=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".results[$arrayUnprotected].vmSize")    
    VMRegion=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".results[$arrayUnprotected].regionName")
        case $VMRegion in
        eastus)
            region="dq8hfn5y9wg"
        ;;
        eastus2)
            region="dq8hfn5y9wg"
        ;;
        centralus)
            region="9zmy1x8m433"
        ;;
        northcentralus)
            region="dp04jyu9y1h"
        ;;
        southcentralus)
            region="9v1zenczpg4"
        ;;
        westcentralus)
            region="9x9ut88ncmn"
        ;;
        westus)
            region="9qdc22t7bq5"
        ;;
        westus2)
            region="c22ky4rr2tr"
        ;;
        canadaeast)
            region="f2m4t3uwczv"
        ;;
        canadacentral)
            region="dpz2ww8wjj1"
        ;;
        brazilsouth)
            region="6ggzf5qgksb"
        ;;
        northeurope)
            region="gc2xsdvte9v"
        ;;
        westeurope)
            region="u16cn8kjdgh"
        ;;
        francecentral)
            region="u09tgyd042t"
        ;;
        francesouth)
            region="spey0yfznsg"
        ;;
        ukwest)
            region="gcjsvrxnucs"
        ;;
        uksouth)
            region="gcpv4s80b7q"
        ;;
        germanycentral)
            region="u0yj1k6fn2k"
        ;;
        germanynortheast)
            region="u320t9r2d24"
        ;;
        germanynorth)
            region="u1wbwwp4nbh"
        ;;
        germanywestcentral)
            region="u0yj1k6fn2k"
        ;;
        switzerlandnorth)
            region="u0qj88v4pz6"
        ;;
        switzerlandwest)
            region="u0hqg7m5zxh"
        ;;
        norwayeast)
            region="ukq8sp6wbxj"
        ;;
        norwaywest)
            region="u4exmjjkuqt"
        ;;
        southeastasia)
            region="w21xrz70d4w"
        ;;
        eastasia)
            region="wecp1v5pxcw"
        ;;
        australiaeast)
            region="r4pt8re3et0"
        ;;
        australiasoutheast)
            region="r1tb59hgjfe"
        ;;
        australiacentral)
            region="r3dp33jrs1y"
        ;;
        australiacentral2)
            region="r3dp33jrs1y"
        ;;
        chinaeast)
            region="wtw1tuk8sv2"
        ;;
        chinanorth)
            region="wx4e4qdjbwz"
        ;;
        chinaeast2)
            region="wtw1tuk8sv2"
        ;;
        chinanorth2)
            region="wx4e4qdjbwz"
        ;;
        centralindia)
            region="tek3rhq6efd"
        ;;
        westindia)
            region="te7sx3b7wxb"
        ;;
        southindia)
            region="tf2fnp23j4r"
        ;;
        japaneast)
            region="xn7k24npyzm"
        ;;
        japanwest)
            region="xn0m32yuw5f"
        ;;
        uksouth)
            region="gcpv4s80b7q"
        ;;
        koreacentral)
            region="wydjww8cwv6"
        ;;
        koreasouth)
            region="wy78p980qyu"
        ;;
        southafricawest)
            region="k3vp44hbv4f"
        ;;
        southafricanorth)
            region="ke7gj78s7cv"
        ;;
        uaecentral)
            region="thqdwrd35c1"
        ;;
        uaenorth)
            region="thrntscegt6"
        ;;
        esac
    VMOSType=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".results[$arrayUnprotected].osType")   
    
    #echo "veeam_azure_vm,VMID=$VMID,VMName=$VMName,VMResourceId=$VMResourceID,VMType=$VMType,VMRegion=$region,VMPolicy=$VMPolicy,VMOSType=$VMOSType VMSize=$VMSize"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=s&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_azure_vm_unprotected,VMID=$VMID,VMName=$VMName,VMResourceId=$VMResourceID,VMType=$VMType,VMOSType=$VMOSType,VMRegion=$VMRegion,geohash=$region UPVM=1,VMSize=$VMSize"
           
    arrayUnprotected=$arrayUnprotected+1
done
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=s&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_azure_vm_unprotected TotalVMs=$arrayUnprotected"

##
# Veeam Backup for Azure Policies. This part will check VBA Policies
##
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/v1/policies"
veeamVBAPoliciesUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

declare -i arraypolicies=0
for id in $(echo "$veeamVBAPoliciesUrl" | jq -r '.results[].id'); do
    PolicyID=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].id")
    TenantID=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].tenantId")
    PolicyStatus=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].isEnabled")
    PolicyName=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].name" | awk '{gsub(/ /,"\\ ");print}')
    PolicyDescription=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].description" | awk '{gsub(/ /,"\\ ");print}')
    PolicySnapshotCount=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].snapshotSettings.generationsToSave")
    PolicyBackupDurationType=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].backupSettings.retentionSettings.retentionDurationType")
    PolicyBackupRetentionCount=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].backupSettings.retentionSettings.timeRetentionDuration")
    PolicyBackupRepository=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].backupSettings.targetRepositoryId")

    #echo "veeam_azure_policies,PolicyID=$PolicyID,TenantID=$TenantID,PolicyStatus=$PolicyStatus,PolicyName=$PolicyName,PolicyDescription=$PolicyDescription,PolicyBackupDurationType=$PolicyBackupDurationType,PolicyBackupRepository=$PolicyBackupRepository PolicySnapshotCount=$PolicySnapshotCount,PolicyBackupRetentionCount=$PolicyBackupRetentionCount"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=s&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_azure_policies,PolicyID=$PolicyID,TenantID=$TenantID,PolicyStatus=$PolicyStatus,PolicyName=$PolicyName,PolicyDescription=$PolicyDescription,PolicyBackupDurationType=$PolicyBackupDurationType,PolicyBackupRepository=$PolicyBackupRepository PolicySnapshotCount=$PolicySnapshotCount,PolicyBackupRetentionCount=$PolicyBackupRetentionCount"
    
    arraypolicies=$arraypolicies+1
done

##
# Veeam Backup for Azure Repositories. This part will check VBA Repositories
##
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/v1/repositories"
veeamVBAPoliciesUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

declare -i arrayrepositories=0
for id in $(echo "$veeamVBAPoliciesUrl" | jq -r '.results[].id'); do
    RepositoryID=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrepositories].id")
    RepositoryName=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrepositories].name" | awk '{gsub(/ /,"\\ ");print}')
    RepositoryDescription=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrepositories].description" | awk '{gsub(/ /,"\\ ");print}')
    RepositoryAccountName=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrepositories].azureStorageAccountName" | awk '{gsub(/ /,"\\ ");print}')
    RepositoryContainerName=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrepositories].azureStorageContainer.name" | awk '{gsub(/ /,"\\ ");print}')    
    RepositoryEncryption=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrepositories].enableEncryption") 
        case $RepositoryEncryption in
        "false")
            encryption="0"
        ;;
        "true")
            encryption="1"
        ;;
        esac
    RepositoryRegion=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrepositories].regionId") 
    RepositoryAzureID=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrepositories].azureAccountId")
    RepositoryStatus=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrepositories].status")

    #echo "veeam_azure_repositories,repoID=$RepositoryID,repoName=$RepositoryName,repoDescription=$RepositoryDescription,repoAccountName=$RepositoryAccountName,repoContainer=$RepositoryContainerName,repoEncryption=$RepositoryEncryption,repoRegion=$region,repoAzureID=$RepositoryAzureID,repoStatus=$RepositoryStatus"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=s&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_azure_repositories,repoID=$RepositoryID,repoName=$RepositoryName,repoDescription=$RepositoryDescription,repoAccountName=$RepositoryAccountName,repoContainer=$RepositoryContainerName,repoAzureID=$RepositoryAzureID,repoStatus=$RepositoryStatus repoEncryption=$encryption"
    
    arrayrepositories=$arrayrepositories+1
done

##
# Veeam Backup for Azure Sessions. This part will check VBA Sessions
##
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/v1/jobSessions?Types=PolicyBackup"
veeamVBASessionsBackupUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

declare -i arraysessionsbackup=0
for id in $(echo "$veeamVBASessionsBackupUrl" | jq -r '.results[].id'); do
    SessionID=$(echo "$veeamVBASessionsBackupUrl" | jq --raw-output ".results[$arraysessionsbackup].id")
    SessionStatus=$(echo "$veeamVBASessionsBackupUrl" | jq --raw-output ".results[$arraysessionsbackup].status")
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
    SessionStopTime=$(echo "$veeamVBASessionsBackupUrl" | jq --raw-output ".results[$arraysessionsbackup].executionStopTime")
    SessionTimeStamp=$(date -d "${SessionStopTime}" '+%s')
    SessionPolicyID=$(echo "$veeamVBASessionsBackupUrl" | jq --raw-output ".results[$arraysessionsbackup].backupJobInfo.policyId")
    SessionPolicyName=$(echo "$veeamVBASessionsBackupUrl" | jq --raw-output ".results[$arraysessionsbackup].backupJobInfo.policyName" | awk '{gsub(/ /,"\\ ");print}')
    if [ "$veeamVBASessionPolicyName" == "" ];then
        declare -i veeamVBASessionPolicyName=0
    fi

    #echo "veeam_azure_sessions,sessionID=$SessionID,sessionStatus=$jobStatus,sessionType=$SessionType,sessionDuration=$SessionDuration,sessionPolicyID=$SessionPolicyID,sessionPolicyName=$SessionPolicyName"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=s&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_azure_sessions,sessionID=$SessionID,sessionType=$SessionType,sessionPolicyID=$SessionPolicyID,sessionPolicyName=$SessionPolicyName sessionStatus=$jobStatus,sessionDuration=$SessionDurationS $SessionTimeStamp"
    
    arraysessionsbackup=$arraysessionsbackup+1
done

veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/v1/jobSessions?Types=PolicySnapshot"
veeamVBASessionsSnapshotUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

declare -i arraysessionssnapshot=0
for id in $(echo "$veeamVBASessionsSnapshotUrl" | jq -r '.results[].id'); do
    SessionID=$(echo "$veeamVBASessionsSnapshotUrl" | jq --raw-output ".results[$arraysessionssnapshot].id")
    SessionStatus=$(echo "$veeamVBASessionsSnapshotUrl" | jq --raw-output ".results[$arraysessionssnapshot].status")
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
    SessionType=$(echo "$veeamVBASessionsSnapshotUrl" | jq --raw-output ".results[$arraysessionssnapshot].type")
    SessionDuration=$(echo "$veeamVBASessionsSnapshotUrl" | jq --raw-output ".results[$arraysessionssnapshot].executionDuration")
    SessionDurationS=$(echo $SessionDuration | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')
    SessionStopTime=$(echo "$veeamVBASessionsSnapshotUrl" | jq --raw-output ".results[$arraysessionssnapshot].executionStopTime")
    SessionTimeStamp=$(date -d "${SessionStopTime}" '+%s')
    SessionPolicyID=$(echo "$veeamVBASessionsSnapshotUrl" | jq --raw-output ".results[$arraysessionssnapshot].backupJobInfo.policyId")
    SessionPolicyName=$(echo "$veeamVBASessionsSnapshotUrl" | jq --raw-output ".results[$arraysessionssnapshot].backupJobInfo.policyName" | awk '{gsub(/ /,"\\ ");print}')
    if [ "$veeamVBASessionPolicyName" == "" ];then
        declare -i veeamVBASessionPolicyName=0
    fi

    #echo "veeam_azure_sessions,sessionID=$SessionID,sessionStatus=$SessionStatus,sessionType=$SessionType,sessionDuration=$SessionDuration,sessionPolicyID=$SessionPolicyID,sessionPolicyName=$SessionPolicyName"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=s&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_azure_sessions,sessionID=$SessionID,sessionType=$SessionType,sessionPolicyID=$SessionPolicyID,sessionPolicyName=$SessionPolicyName sessionStatus=$jobStatus,sessionDuration=$SessionDurationS $SessionTimeStamp"
    
    arraysessionssnapshot=$arraysessionssnapshot+1
done