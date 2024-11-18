#!/bin/bash
##      .SYNOPSIS
##      Grafana Dashboard for Veeam Backup Azure v7.0 - Using API to InfluxDB Script
## 
##      .DESCRIPTION
##      This Script will query the Veeam Backup for Azure API and send the data directly to InfluxDB, which can be used to present it to Grafana. 
##      The Script and the Grafana Dashboard it is provided as it is, and bear in mind you can not open support Tickets regarding this project. It is a Community Project
##	
##      .Notes
##      NAME:  veeam_azure.sh
##      ORIGINAL NAME: veeam_azure.sh
##      LASTEDIT: 18/11/202
##      VERSION: 7.0
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
veeamBackupAzureServer="https://YOURVEEAMBACKUPIP"
veeamBackupAzurePort="443" #Default Port

# API Version
veeamAPIVersion="v7" # Set the API version here (e.g., v7)

# Get the bearer token and HTTP status code
response=$(curl -s -o response.json -w "%{http_code}" -X POST "$veeamBackupAzureServer:$veeamBackupAzurePort/api/oauth2/token" \
  -H "accept: application/json" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&username=$veeamUsername&password=$veeamPassword" \
  -k)

veeamBearertmp=$(<response.json)
rm response.json
http_status=$response

case $http_status in
    200)
        veeamBearer=$(echo "$veeamBearertmp" | jq -r '.access_token')
        if [ -n "$veeamBearer" ] && [ "$veeamBearer" != "null" ]; then
            echo "Successfully obtained bearer token"
        else
            echo "Bearer token was not found in the response."
            exit 1
        fi
        ;;
    400)
        # Parse error message
        errorMessage=$(echo "$veeamBearertmp" | jq -r '.message')
        echo "Bad request: $errorMessage"
        exit 1
        ;;
    401)
        errorMessage=$(echo "$veeamBearertmp" | jq -r '.message')
        echo "Unauthorized: $errorMessage"
        exit 1
        ;;
    403)
        errorMessage=$(echo "$veeamBearertmp" | jq -r '.message')
        echo "Forbidden: $errorMessage"
        exit 1
        ;;
    500)
        errorMessage=$(echo "$veeamBearertmp" | jq -r '.message')
        echo "Internal server error: $errorMessage"
        exit 1
        ;;
    *)
        echo "An unexpected error occurred with HTTP status code: $http_status."
        exit 1
        ;;
esac

# Get server name and azure region
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/$veeamAPIVersion/system/serverInfo"
veeamVBAOverviewUrl=$(curl -X GET "$veeamVBAURL" -H "Authorization: Bearer $veeamBearer" -H "accept: application/json" -k --silent)

    serverName=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".serverName" | awk '{gsub(/([ ,])/,"\\\\&");print}')
    azureRegion=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".azureRegion")

    # Collect system about information
    echo "Collecting system about information..."
    veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/$veeamAPIVersion/system/about"
    veeamVBAAboutUrl=$(curl -X GET "$veeamVBAURL" -H "Authorization: Bearer $veeamBearer" -H "accept: application/json" -k --silent)

    version=$(echo "$veeamVBAAboutUrl" | jq --raw-output ".serverVersion")
    workerversion=$(echo "$veeamVBAAboutUrl" | jq --raw-output ".workerVersion")

    influxData="veeam_azure_overview,serverName=$serverName,azureRegion=$azureRegion,version=$version,workerversion=$workerversion vb=1"

    # Send data to InfluxDB
    echo "Writing veeam_azure_overview to InfluxDB - Server Name and Region"
    influx write \
        --host "$veeamInfluxDBURL:$veeamInfluxDBPort" \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        --skip-verify \
        --format lp \
        "$influxData"

# Get Protected Workloads
echo "Collecting protected workloads information..."
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/$veeamAPIVersion/overview/protectedWorkloads?PeriodFlag=Day"
veeamVBAWorkloadsUrl=$(curl -X GET "$veeamVBAURL" -H "Authorization: Bearer $veeamBearer" -H "accept: application/json" -k --silent)

    VMsCount=$(echo "$veeamVBAWorkloadsUrl" | jq --raw-output ".virtualMachinesTotalCount")
    VMsProtected=$(echo "$veeamVBAWorkloadsUrl" | jq --raw-output ".virtualMachinesProtectedCount")
    DBsCount=$(echo "$veeamVBAWorkloadsUrl" | jq --raw-output ".sqlDatabasesTotalCount")
    DBsProtected=$(echo "$veeamVBAWorkloadsUrl" | jq --raw-output ".sqlDatabasesProtectedCount")
    fileSharesTotalCount=$(echo "$veeamVBAWorkloadsUrl" | jq --raw-output ".fileSharesTotalCount")
    fileSharesProtectedCount=$(echo "$veeamVBAWorkloadsUrl" | jq --raw-output ".fileSharesProtectedCount")

    influxData="veeam_azure_overview,serverName=$serverName VMs=$VMsCount,VMsProtected=$VMsProtected,DBs=$DBsCount,DBsProtected=$DBsProtected,fileSharesTotalCount=$fileSharesTotalCount,fileSharesProtectedCount=$fileSharesProtectedCount"

    # Send data to InfluxDB
    echo "Writing veeam_azure_overview to InfluxDB - Workload Summaries"
    influx write \
        --host "$veeamInfluxDBURL:$veeamInfluxDBPort" \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        --skip-verify \
        --format lp \
        "$influxData"

# Get Storage Usage
echo "Collecting storage usage information..."
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/$veeamAPIVersion/overview/storageUsage"
veeamVBAStorageUrl=$(curl -X GET "$veeamVBAURL" -H "Authorization: Bearer $veeamBearer" -H "accept: application/json" -k --silent)

    snapshotsCount=$(echo "$veeamVBAStorageUrl" | jq --raw-output ".snapshotsCount")
    archivesCount=$(echo "$veeamVBAStorageUrl" | jq --raw-output ".archivesCount")
    backupCount=$(echo "$veeamVBAStorageUrl" | jq --raw-output ".backupCount")
    totalUsage=$(echo "$veeamVBAStorageUrl" | jq --raw-output ".totalUsage")
    hotUsage=$(echo "$veeamVBAStorageUrl" | jq --raw-output ".hotUsage")
    coolUsage=$(echo "$veeamVBAStorageUrl" | jq --raw-output ".coolUsage")
    archiveUsage=$(echo "$veeamVBAStorageUrl" | jq --raw-output ".archiveUsage")

    influxData="veeam_azure_overview,serverName=$serverName snapshotsCount=$snapshotsCount,archivesCount=$archivesCount,backupCount=$backupCount,totalUsage=$totalUsage,hotUsage=$hotUsage,coolUsage=$coolUsage,archiveUsage=$archiveUsage"

    # Send data to InfluxDB
    echo "Writing veeam_azure_overview to InfluxDB - Storage Overview"
    influx write \
        --host "$veeamInfluxDBURL:$veeamInfluxDBPort" \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        --skip-verify \
        --format lp \
        "$influxData"

# Get License Information
echo "Collecting license information..."
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/$veeamAPIVersion/license"
veeamVBALicenseUrl=$(curl -X GET "$veeamVBAURL" -H "Authorization: Bearer $veeamBearer" -H "accept: application/json" -k --silent)

    licenseType=$(echo "$veeamVBALicenseUrl" | jq --raw-output ".licenseType")
    isFreeEdition=$(echo "$veeamVBALicenseUrl" | jq --raw-output ".isFreeEdition")
    totalInstancesUses=$(echo "$veeamVBALicenseUrl" | jq --raw-output ".totalInstancesUses")
    vmsInstancesUses=$(echo "$veeamVBALicenseUrl" | jq --raw-output ".vmsInstancesUses")
    sqlInstancesUses=$(echo "$veeamVBALicenseUrl" | jq --raw-output ".sqlInstancesUses")
    fileShareInstancesUses=$(echo "$veeamVBALicenseUrl" | jq --raw-output ".fileShareInstancesUses")
    cosmosDbInstancesUses=$(echo "$veeamVBALicenseUrl" | jq --raw-output ".cosmosDbInstancesUses")
    instances=$(echo "$veeamVBALicenseUrl" | jq --raw-output ".instances")
    gracePeriodDays=$(echo "$veeamVBALicenseUrl" | jq --raw-output ".gracePeriodDays")

    licensingServer_id=$(echo "$veeamVBALicenseUrl" | jq --raw-output ".licensingServer.id")
    licensingServer_hostname=$(echo "$veeamVBALicenseUrl" | jq --raw-output ".licensingServer.hostname" | awk '{gsub(/([ ,])/,"\\\\&");print}')
    licensingServer_status=$(echo "$veeamVBALicenseUrl" | jq --raw-output ".licensingServer.status")
    licensingServer_isExpired=$(echo "$veeamVBALicenseUrl" | jq --raw-output ".licensingServer.isExpired")

    isFreeEdition=$(echo "$isFreeEdition" | awk '{print tolower($0)}')
    licensingServer_isExpired=$(echo "$licensingServer_isExpired" | awk '{print tolower($0)}')

    influxData="veeam_azure_overview,serverName=$serverName,licenseType=$licenseType,licensingServer_hostname=$licensingServer_hostname,licensingServer_status=$licensingServer_status isFreeEdition=$isFreeEdition,licensingServer_isExpired=$licensingServer_isExpired,totalInstancesUses=$totalInstancesUses,vmsInstancesUses=$vmsInstancesUses,sqlInstancesUses=$sqlInstancesUses,fileShareInstancesUses=$fileShareInstancesUses,cosmosDbInstancesUses=$cosmosDbInstancesUses,instances=$instances,gracePeriodDays=$gracePeriodDays"

    # Send data to InfluxDB
    echo "Writing veeam_azure_overview to InfluxDB - Overview Licensing"
    influx write \
        --host "$veeamInfluxDBURL:$veeamInfluxDBPort" \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        --skip-verify \
        --format lp \
        "$influxData"

# Get server name and azure region
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/$veeamAPIVersion/system/serverInfo"
veeamVBAOverviewUrl=$(curl -X GET "$veeamVBAURL" -H "Authorization: Bearer $veeamBearer" -H "accept: application/json" -k --silent)

    serverName=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".serverName" | awk '{gsub(/([ ,])/,"\\\\&");print}')
    azureRegion=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".azureRegion")

    # Collect system about information
    echo "Collecting system about information..."
    veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/$veeamAPIVersion/system/about"
    veeamVBAAboutUrl=$(curl -X GET "$veeamVBAURL" -H "Authorization: Bearer $veeamBearer" -H "accept: application/json" -k --silent)

    version=$(echo "$veeamVBAAboutUrl" | jq --raw-output ".serverVersion")
    workerversion=$(echo "$veeamVBAAboutUrl" | jq --raw-output ".workerVersion")

    influxData="veeam_azure_overview,serverName=$serverName,azureRegion=$azureRegion,version=$version,workerversion=$workerversion vb=1"

    # Send data to InfluxDB
    echo "Writing veeam_azure_overview to InfluxDB - Server Name and Region"
    influx write \
        --host "$veeamInfluxDBURL:$veeamInfluxDBPort" \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        --skip-verify \
        --format lp \
        "$influxData"

# Get Protected Workloads
echo "Collecting protected workloads information..."
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/$veeamAPIVersion/overview/protectedWorkloads?PeriodFlag=Day"
veeamVBAWorkloadsUrl=$(curl -X GET "$veeamVBAURL" -H "Authorization: Bearer $veeamBearer" -H "accept: application/json" -k --silent)

    VMsCount=$(echo "$veeamVBAWorkloadsUrl" | jq --raw-output ".virtualMachinesTotalCount")
    VMsProtected=$(echo "$veeamVBAWorkloadsUrl" | jq --raw-output ".virtualMachinesProtectedCount")
    DBsCount=$(echo "$veeamVBAWorkloadsUrl" | jq --raw-output ".sqlDatabasesTotalCount")
    DBsProtected=$(echo "$veeamVBAWorkloadsUrl" | jq --raw-output ".sqlDatabasesProtectedCount")
    fileSharesTotalCount=$(echo "$veeamVBAWorkloadsUrl" | jq --raw-output ".fileSharesTotalCount")
    fileSharesProtectedCount=$(echo "$veeamVBAWorkloadsUrl" | jq --raw-output ".fileSharesProtectedCount")

    influxData="veeam_azure_overview,serverName=$serverName VMs=$VMsCount,VMsProtected=$VMsProtected,DBs=$DBsCount,DBsProtected=$DBsProtected,fileSharesTotalCount=$fileSharesTotalCount,fileSharesProtectedCount=$fileSharesProtectedCount"

    # Send data to InfluxDB
    echo "Writing veeam_azure_overview to InfluxDB - Workload Summaries"
    influx write \
        --host "$veeamInfluxDBURL:$veeamInfluxDBPort" \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        --skip-verify \
        --format lp \
        "$influxData"

# Get Storage Usage
echo "Collecting storage usage information..."
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/$veeamAPIVersion/overview/storageUsage"
veeamVBAStorageUrl=$(curl -X GET "$veeamVBAURL" -H "Authorization: Bearer $veeamBearer" -H "accept: application/json" -k --silent)

    snapshotsCount=$(echo "$veeamVBAStorageUrl" | jq --raw-output ".snapshotsCount")
    archivesCount=$(echo "$veeamVBAStorageUrl" | jq --raw-output ".archivesCount")
    backupCount=$(echo "$veeamVBAStorageUrl" | jq --raw-output ".backupCount")
    totalUsage=$(echo "$veeamVBAStorageUrl" | jq --raw-output ".totalUsage")
    hotUsage=$(echo "$veeamVBAStorageUrl" | jq --raw-output ".hotUsage")
    coolUsage=$(echo "$veeamVBAStorageUrl" | jq --raw-output ".coolUsage")
    archiveUsage=$(echo "$veeamVBAStorageUrl" | jq --raw-output ".archiveUsage")

    influxData="veeam_azure_overview,serverName=$serverName snapshotsCount=$snapshotsCount,archivesCount=$archivesCount,backupCount=$backupCount,totalUsage=$totalUsage,hotUsage=$hotUsage,coolUsage=$coolUsage,archiveUsage=$archiveUsage"

    # Send data to InfluxDB
    echo "Writing veeam_azure_overview to InfluxDB - Storage Overview"
    influx write \
        --host "$veeamInfluxDBURL:$veeamInfluxDBPort" \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        --skip-verify \
        --format lp \
        "$influxData"

# Get License Information
echo "Collecting license information..."
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/$veeamAPIVersion/license"
veeamVBALicenseUrl=$(curl -X GET "$veeamVBAURL" -H "Authorization: Bearer $veeamBearer" -H "accept: application/json" -k --silent)

    licenseType=$(echo "$veeamVBALicenseUrl" | jq --raw-output ".licenseType")
    isFreeEdition=$(echo "$veeamVBALicenseUrl" | jq --raw-output ".isFreeEdition")
    totalInstancesUses=$(echo "$veeamVBALicenseUrl" | jq --raw-output ".totalInstancesUses")
    vmsInstancesUses=$(echo "$veeamVBALicenseUrl" | jq --raw-output ".vmsInstancesUses")
    sqlInstancesUses=$(echo "$veeamVBALicenseUrl" | jq --raw-output ".sqlInstancesUses")
    fileShareInstancesUses=$(echo "$veeamVBALicenseUrl" | jq --raw-output ".fileShareInstancesUses")
    cosmosDbInstancesUses=$(echo "$veeamVBALicenseUrl" | jq --raw-output ".cosmosDbInstancesUses")
    instances=$(echo "$veeamVBALicenseUrl" | jq --raw-output ".instances")
    gracePeriodDays=$(echo "$veeamVBALicenseUrl" | jq --raw-output ".gracePeriodDays")

    licensingServer_id=$(echo "$veeamVBALicenseUrl" | jq --raw-output ".licensingServer.id")
    licensingServer_hostname=$(echo "$veeamVBALicenseUrl" | jq --raw-output ".licensingServer.hostname" | awk '{gsub(/([ ,])/,"\\\\&");print}')
    licensingServer_status=$(echo "$veeamVBALicenseUrl" | jq --raw-output ".licensingServer.status")
    licensingServer_isExpired=$(echo "$veeamVBALicenseUrl" | jq --raw-output ".licensingServer.isExpired")

    isFreeEdition=$(echo "$isFreeEdition" | awk '{print tolower($0)}')
    licensingServer_isExpired=$(echo "$licensingServer_isExpired" | awk '{print tolower($0)}')

    influxData="veeam_azure_overview,serverName=$serverName,licenseType=$licenseType,licensingServer_hostname=$licensingServer_hostname,licensingServer_status=$licensingServer_status isFreeEdition=$isFreeEdition,licensingServer_isExpired=$licensingServer_isExpired,totalInstancesUses=$totalInstancesUses,vmsInstancesUses=$vmsInstancesUses,sqlInstancesUses=$sqlInstancesUses,fileShareInstancesUses=$fileShareInstancesUses,cosmosDbInstancesUses=$cosmosDbInstancesUses,instances=$instances,gracePeriodDays=$gracePeriodDays"

    # Send data to InfluxDB
    echo "Writing veeam_azure_overview to InfluxDB - Overview Licensing"
    influx write \
        --host "$veeamInfluxDBURL:$veeamInfluxDBPort" \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        --skip-verify \
        --format lp \
        "$influxData"

##
# Veeam Backup for Azure Instances. This part will check VBA and report all the protected Instances
##
echo "Collecting protected virtual machines information..."
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/$veeamAPIVersion/virtualMachines?protectionStatus=Protected"
veeamVBAInstancesUrl=$(curl -X GET "$veeamVBAURL" -H "Authorization: Bearer $veeamBearer" -H "accept: application/json" -k --silent)

declare -i arrayinstances=0
for id in $(echo "$veeamVBAInstancesUrl" | jq -r '.results[].id'); do
    VMID=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".results[$arrayinstances].id")
    VMName=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".results[$arrayinstances].name" | awk '{gsub(/ /,"\\ ");print}')
    VMSize=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".results[$arrayinstances].totalSizeInGB")
    VMOSType=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".results[$arrayinstances].osType") 
    VMType=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".results[$arrayinstances].vmSize")        
    VMvirtualNetwork=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".results[$arrayinstances].virtualNetwork")
    VMsubnet=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".results[$arrayinstances].subnet")
    VMpublicIP=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".results[$arrayinstances].publicIP") 
    VMprivateIP=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".results[$arrayinstances].privateIP")       
    VMavailabilityZone=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".results[$arrayinstances].availabilityZone")  
    VMRegion=$(echo "$veeamVBAInstancesUrl" | jq --raw-output ".results[$arrayinstances].regionName")
    
    # Getting the Policies attached to the Instance
    veeamVBAVMURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/$veeamAPIVersion/policies/virtualMachines?VirtualMachineId=$VMID"
    veeamVBAInstancesPolicyUrl=$(curl -X GET "$veeamVBAVMURL" -H "Authorization: Bearer $veeamBearer" -H "accept: application/json" -k --silent)
    VMPolicy=$(echo "$veeamVBAInstancesPolicyUrl" | jq --raw-output ".results[0].name" | awk '{gsub(/ /,"\\ ");print}')   

    # Prepare data for InfluxDB
    influxData="veeam_azure_vm,serverName=$serverName,VMID=$VMID,VMName=$VMName,VMType=$VMType,VMPolicy=$VMPolicy,VMOSType=$VMOSType,VMRegion=$VMRegion,VMvirtualNetwork=$VMvirtualNetwork,VMsubnet=$VMsubnet,VMprivateIP=$VMprivateIP,VMpublicIP=$VMpublicIP VMSize=$VMSize"

    # Send data to InfluxDB
    echo "Writing veeam_azure_vm to InfluxDB for VM: $VMName"
    influx write \
        --host "$veeamInfluxDBURL:$veeamInfluxDBPort" \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        --skip-verify \
        --format lp \
        "$influxData"
    
    # Restore Points per Instance
    echo "Collecting restore points for VM: $VMName..."
    veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/$veeamAPIVersion/restorePoints/virtualMachines?VirtualMachineId=$VMID&OnlyLatest=false"
    veeamRestorePointsUrl=$(curl -X GET "$veeamVBAURL" -H "Authorization: Bearer $veeamBearer" -H "accept: application/json" -k --silent)
    
    declare -i arrayRestorePoint=0
    for rp_id in $(echo "$veeamRestorePointsUrl" | jq -r '.results[].id'); do
        VMJobType=$(echo "$veeamRestorePointsUrl" | jq --raw-output ".results[$arrayRestorePoint].backupDestination")
        VMJobid=$(echo "$veeamRestorePointsUrl" | jq --raw-output ".results[$arrayRestorePoint].id")
        VMJobSize=$(echo "$veeamRestorePointsUrl" | jq --raw-output ".results[$arrayRestorePoint].backupSizeBytes")
        VMJobTime=$(echo "$veeamRestorePointsUrl" | jq --raw-output ".results[$arrayRestorePoint].pointInTime")
        VMPointType=$(echo "$veeamRestorePointsUrl" | jq --raw-output ".results[$arrayRestorePoint].type")
        gfsFlags=$(echo "$veeamRestorePointsUrl" | jq --raw-output ".results[$arrayRestorePoint].gfsFlags")
        
        # Prepare data for InfluxDB
        influxData="veeam_azure_restorepoints,serverName=$serverName,VMName=$VMName,JobType=$VMJobType,Jobid=$VMJobid,VMPointType=$VMPointType,gfsFlags=$gfsFlags JobSize=$VMJobSize,JobTime=\"$VMJobTime\""
        
        # Send data to InfluxDB
        echo "Writing veeam_azure_restorepoints to InfluxDB for Restore Point ID: $VMJobid"
        influx write \
            --host "$veeamInfluxDBURL:$veeamInfluxDBPort" \
            -t "$veeamInfluxDBToken" \
            -b "$veeamInfluxDBBucket" \
            -o "$veeamInfluxDBOrg" \
            -p s \
            --skip-verify \
            --format lp \
            "$influxData"
        
        arrayRestorePoint=$((arrayRestorePoint + 1))
    done   
    arrayinstances=$((arrayinstances + 1))    
done

# Write total number of protected VMs to InfluxDB
influxData="veeam_azure_vm_protected,serverName=$serverName TotalVMs=$arrayinstances"

echo "Writing veeam_azure_vm_protected to InfluxDB"
influx write \
    --host "$veeamInfluxDBURL:$veeamInfluxDBPort" \
    -t "$veeamInfluxDBToken" \
    -b "$veeamInfluxDBBucket" \
    -o "$veeamInfluxDBOrg" \
    -p s \
    --skip-verify \
    --format lp \
    "$influxData"

##
# Veeam Backup for Azure Instances. This part will check VBA and report all the unprotected Instances
##
echo "Collecting unprotected virtual machines information..."
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/$veeamAPIVersion/virtualMachines?ProtectionStatus=Unprotected"
veeamVBAUnprotectedUrl=$(curl -X GET "$veeamVBAURL" -H "Authorization: Bearer $veeamBearer" -H "accept: application/json" -k --silent)

# Declare associative arrays for regions and their geohashes
declare -A regions=(
    ["eastus"]="dq8hfn5y9wg"
    ["eastus2"]="dq8hfn5y9wg"
    ["centralus"]="9zmy1x8m433"
    ["northcentralus"]="dp04jyu9y1h"
    ["southcentralus"]="9v1zenczpg4"
    ["westcentralus"]="9x9ut88ncmn"
    ["westus"]="9qdc22t7bq5"
    ["westus2"]="c22ky4rr2tr"
    ["canadaeast"]="f2m4t3uwczv"
    ["canadacentral"]="dpz2ww8wjj1"
    ["brazilsouth"]="6ggzf5qgksb"
    ["northeurope"]="gc2xsdvte9v"
    ["westeurope"]="u16cn8kjdgh"
    ["francecentral"]="u09tgyd042t"
    ["francesouth"]="spey0yfznsg"
    ["ukwest"]="gcjsvrxnucs"
    ["uksouth"]="gcpv4s80b7q"
    ["germanycentral"]="u0yj1k6fn2k"
    ["germanynortheast"]="u320t9r2d24"
    ["germanynorth"]="u1wbwwp4nbh"
    ["germanywestcentral"]="u0yj1k6fn2k"
    ["switzerlandnorth"]="u0qj88v4pz6"
    ["switzerlandwest"]="u0hqg7m5zxh"
    ["norwayeast"]="ukq8sp6wbxj"
    ["southeastasia"]="u4exmjjkuqt"
    ["eastasia"]="w21xrz70d4w"
    ["australiaeast"]="wecp1v5pxcw"
    ["australiasoutheast"]="r4pt8re3et0"
    ["australiacentral"]="r1tb59hgjfe"
    ["australiacentral2"]="r3dp33jrs1y"
    ["chinaeast"]="wtw1tuk8sv2"
    ["chinanorth"]="wx4e4qdjbwz"
    ["centralindia"]="tek3rhq6efd"
    ["westindia"]="te7sx3b7wxb"
    ["southindia"]="tf2fnp23j4r"
    ["japaneast"]="xn7k24npyzm"
    ["japanwest"]="xn0m32yuw5f"
    ["koreacentral"]="wydjww8cwv6"
    ["koreasouth"]="wy78p980qyu"
    ["southafricawest"]="k3vp44hbv4f"
    ["southafricanorth"]="ke7gj78s7cv"
    ["uaecentral"]="thqdwrd35c1"
    ["uaenorth"]="thrntscegt6"
)

# Function to write unprotected VM counts to InfluxDB
write_unprotected_vm_count() {
    local region="$1"
    local count="$2"
    local geohash="$3"
    influxData="veeam_azure_vm_unprotected,VMRegion=\"$region\",geohash=\"$geohash\" UPVM=$count"

    echo "Writing unprotected VM count to InfluxDB for region: $region"
    influx write \
        --host "$veeamInfluxDBURL:$veeamInfluxDBPort" \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        --skip-verify \
        --format lp \
        "$influxData"
}

# Loop through each region and write unprotected VM counts to InfluxDB
for region in "${!regions[@]}"; do
    geohash="${regions[$region]}"
    count=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".results | map(select(.regionName==\"$region\")) | length")
    if [ "$count" -gt 0 ]; then
        write_unprotected_vm_count "$region" "$count" "$geohash"
    fi
done

# Collect details of each unprotected VM and write to InfluxDB
declare -i arrayUnprotected=0
for id in $(echo "$veeamVBAUnprotectedUrl" | jq -r '.results[].id'); do
    VMID=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".results[$arrayUnprotected].id")
    VMName=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".results[$arrayUnprotected].name" | awk '{gsub(/ /,"\\ ");print}')
    VMSize=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".results[$arrayUnprotected].totalSizeInGB")
    VMOSType=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".results[$arrayUnprotected].osType")
    VMType=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".results[$arrayUnprotected].vmSize")
    VMvirtualNetwork=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".results[$arrayUnprotected].virtualNetwork")
    VMsubnet=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".results[$arrayUnprotected].subnet")
    VMpublicIP=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".results[$arrayUnprotected].publicIP")
    VMprivateIP=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".results[$arrayUnprotected].privateIP")
    VMavailabilityZone=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".results[$arrayUnprotected].availabilityZone")
    VMRegion=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".results[$arrayUnprotected].regionName")
    VMOSType=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".results[$arrayUnprotected].osType")

    # Prepare data for InfluxDB
    influxData="veeam_azure_vm_unprotected,serverName=$serverName,VMID=$VMID,VMName=$VMName,VMType=$VMType,VMOSType=$VMOSType,VMRegion=$VMRegion,VMvirtualNetwork=$VMvirtualNetwork,VMsubnet=$VMsubnet,VMpublicIP=$VMpublicIP,VMprivateIP=$VMprivateIP VMSize=$VMSize"

    # Send data to InfluxDB
    echo "Writing veeam_azure_vm_unprotected to InfluxDB for VM: $VMName"
    influx write \
        --host "$veeamInfluxDBURL:$veeamInfluxDBPort" \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        --skip-verify \
        --format lp \
        "$influxData"

    arrayUnprotected=$((arrayUnprotected + 1))
done

# Write total number of unprotected VMs to InfluxDB
influxData="veeam_azure_vm_unprotected TotalVMs=$arrayUnprotected"
echo "Writing total number of unprotected VMs to InfluxDB"
influx write \
    --host "$veeamInfluxDBURL:$veeamInfluxDBPort" \
    -t "$veeamInfluxDBToken" \
    -b "$veeamInfluxDBBucket" \
    -o "$veeamInfluxDBOrg" \
    -p s \
    --skip-verify \
    --format lp \
    "$influxData"

##
# Veeam Backup for Azure Databases. This part will check VBA and report all the protected Databases
##
echo "Collecting protected databases information..."
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/$veeamAPIVersion/protectedItem/sql"
veeamVBADatabasesUrl=$(curl -X GET "$veeamVBAURL" -H "Authorization: Bearer $veeamBearer" -H "accept: application/json" -k --silent)

# Check if there are any protected databases
totalDatabases=$(echo "$veeamVBADatabasesUrl" | jq '.results | length')

if [ "$totalDatabases" -gt 0 ]; then
    declare -i arraydatabases=0
    for id in $(echo "$veeamVBADatabasesUrl" | jq -r '.results[].id'); do
        DatabaseID=$(echo "$veeamVBADatabasesUrl" | jq --raw-output ".results[$arraydatabases].id")
        DatabaseName=$(echo "$veeamVBADatabasesUrl" | jq --raw-output ".results[$arraydatabases].name" | awk '{gsub(/ /,"\\ ");print}')
        DatabaseSQLName=$(echo "$veeamVBADatabasesUrl" | jq --raw-output ".results[$arraydatabases].sqlServer.name" | awk '{gsub(/ /,"\\ ");print}')
        DatabaseSQLType=$(echo "$veeamVBADatabasesUrl" | jq --raw-output ".results[$arraydatabases].sqlServer.serverType")
        DatabaseEnvironment=$(echo "$veeamVBADatabasesUrl" | jq --raw-output ".results[$arraydatabases].azureEnvironment")
        DatabaseSize=$(echo "$veeamVBADatabasesUrl" | jq --raw-output ".results[$arraydatabases].sizeInMb")
        DatabaseRegion=$(echo "$veeamVBADatabasesUrl" | jq --raw-output ".results[$arraydatabases].region.name")

        # Send data to InfluxDB
        echo "Writing veeam_azure_vm_database to InfluxDB for Database: $DatabaseName"
        influx write \
            --host "$veeamInfluxDBURL:$veeamInfluxDBPort" \
            -t "$veeamInfluxDBToken" \
            -b "$veeamInfluxDBBucket" \
            -o "$veeamInfluxDBOrg" \
            -p s \
            --skip-verify \
            --format lp \
            "veeam_azure_vm_database,serverName=$serverName,DatabaseID=$DatabaseID,DatabaseName=$DatabaseName,DatabaseSQLName=$DatabaseSQLName,DatabaseSQLType=$DatabaseSQLType,DatabaseEnvironment=$DatabaseEnvironment,DatabaseRegion=$DatabaseRegion DatabaseSize=$DatabaseSize"

        arraydatabases=$((arraydatabases + 1))
    done
else
    echo "No protected SQL databases found."
fi

##
# Veeam Backup for Azure Policies. This part will check VBA VM Policies
##
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/$veeamAPIVersion/policies/virtualMachines"
veeamVBAPoliciesUrl=$(curl -X GET "$veeamVBAURL" -H "Authorization: Bearer $veeamBearer" -H "accept: application/json" -k --silent)

declare -i arraypolicies=0
for id in $(echo "$veeamVBAPoliciesUrl" | jq -r '.results[].id'); do
    PolicyID=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].id")
    TenantID=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].tenantId")
    PolicyStatus=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].isEnabled")
    PolicyName=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].name" | awk '{gsub(/ /,"\\ ");print}')
    PolicyDescription=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].description" | awk '{gsub(/ /,"\\ ");print}')
    if [ -z "$PolicyDescription" ]; then PolicyDescription="0"; fi
    PolicySnapshotCountDaily=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].dailySchedule.snapshotSchedule.snapshotsToKeep")
    if [[ $PolicySnapshotCountDaily == "null" ]]; then PolicySnapshotCountDaily=0; fi
    PolicySnapshotCountWeekly=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].weeklySchedule.snapshotSchedule.snapshotsToKeep")
    if [[ $PolicySnapshotCountWeekly == "null" ]]; then PolicySnapshotCountWeekly=0; fi
    PolicySnapshotCountMonthly=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].monthlySchedule.snapshotSchedule.snapshotsToKeep")
    if [[ $PolicySnapshotCountMonthly == "null" ]]; then PolicySnapshotCountMonthly=0; fi
    PolicySnapshotCountYearly=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].yearlySchedule.retentionYearsCount")
    if [[ $PolicySnapshotCountYearly == "null" ]]; then PolicySnapshotCountYearly=0; fi
    appaware=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].snapshotSettings.applicationAwareSnapshot")
    case $appaware in
    "false")
        PolicyAppAware="0"
        ;;
    "true")
        PolicyAppAware="1"
        ;;
    esac
    PolicyBackupRetention=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].dailySchedule.backupSchedule.retention.timeRetentionDuration")
    PolicyBackupRetentionType=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].dailySchedule.backupSchedule.retention.retentionDurationType")
    PolicyBackupRetentionType=$(echo "$PolicyBackupRetentionType" | awk '{gsub(/ /,"\\ ");print}')

    # Prepare InfluxDB line protocol data
    influxData="veeam_azure_policies,serverName=$serverName,PolicyID=$PolicyID,TenantID=$TenantID,PolicyStatus=$PolicyStatus,PolicyName=$PolicyName,PolicyDescription=$PolicyDescription,PolicyBackupRetentionType=$PolicyBackupRetentionType PolicySnapshotCountDaily=$PolicySnapshotCountDaily,PolicySnapshotCountWeekly=$PolicySnapshotCountWeekly,PolicySnapshotCountMonthly=$PolicySnapshotCountMonthly,PolicySnapshotCountYearly=$PolicySnapshotCountYearly,PolicyAppAware=$PolicyAppAware,PolicyBackupRetention=$PolicyBackupRetention"

    # Send data to InfluxDB
    echo "Writing veeam_azure_policies to InfluxDB"
    influx write \
        --host "$veeamInfluxDBURL:$veeamInfluxDBPort" \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        --skip-verify \
        --format lp \
        "$influxData"

    arraypolicies=$((arraypolicies + 1))
done


##
# Veeam Backup for Azure Policies. This part will check VBA Databases Policies
##
echo "Collecting SQL database policies information..."
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/$veeamAPIVersion/policies/sql"
veeamVBAPoliciesDBUrl=$(curl -X GET "$veeamVBAURL" -H "Authorization: Bearer $veeamBearer" -H "accept: application/json" -k --silent)

# Check if there are any SQL policies
totalPolicies=$(echo "$veeamVBAPoliciesDBUrl" | jq '.results | length')

if [ "$totalPolicies" -gt 0 ]; then
    declare -i arraydbpolicies=0
    for id in $(echo "$veeamVBAPoliciesDBUrl" | jq -r '.results[].id'); do
        PolicyID=$(echo "$veeamVBAPoliciesDBUrl" | jq --raw-output ".results[$arraydbpolicies].id")
        PolicyName=$(echo "$veeamVBAPoliciesDBUrl" | jq --raw-output ".results[$arraydbpolicies].name" | awk '{gsub(/ /,"\\ ");print}')
        PolicyDescription=$(echo "$veeamVBAPoliciesDBUrl" | jq --raw-output ".results[$arraydbpolicies].description" | awk '{gsub(/ /,"\\ ");print}')
        if [ -z "$PolicyDescription" ]; then PolicyDescription="0"; fi

        PolicyBackupRetentionDaily=$(echo "$veeamVBAPoliciesDBUrl" | jq --raw-output ".results[$arraydbpolicies].dailySchedule.backupSchedule.retention.timeRetentionDuration")
        if [[ "$PolicyBackupRetentionDaily" == "null" ]]; then PolicyBackupRetentionDaily=0; fi
        PolicyBackupRetentionWeekly=$(echo "$veeamVBAPoliciesDBUrl" | jq --raw-output ".results[$arraydbpolicies].weeklySchedule.backupSchedule.retention.timeRetentionDuration")
        if [[ "$PolicyBackupRetentionWeekly" == "null" ]]; then PolicyBackupRetentionWeekly=0; fi
        PolicyBackupRetentionMonthly=$(echo "$veeamVBAPoliciesDBUrl" | jq --raw-output ".results[$arraydbpolicies].monthlySchedule.backupSchedule.retention.timeRetentionDuration")
        if [[ "$PolicyBackupRetentionMonthly" == "null" ]]; then PolicyBackupRetentionMonthly=0; fi
        PolicyBackupRetentionYearly=$(echo "$veeamVBAPoliciesDBUrl" | jq --raw-output ".results[$arraydbpolicies].yearlySchedule.retentionYearsCount")
        if [[ "$PolicyBackupRetentionYearly" == "null" ]]; then PolicyBackupRetentionYearly=0; fi

        # Prepare InfluxDB line protocol data
        influxData="veeam_azure_policies,serverName=$serverName,PolicyID=$PolicyID,PolicyName=$PolicyName,PolicyDescription=$PolicyDescription PolicyBackupRetentionDaily=$PolicyBackupRetentionDaily,PolicyBackupRetentionWeekly=$PolicyBackupRetentionWeekly,PolicyBackupRetentionMonthly=$PolicyBackupRetentionMonthly,PolicyBackupRetentionYearly=$PolicyBackupRetentionYearly,PolicyAppAware=0"

        # Send data to InfluxDB
        echo "Writing veeam_azure_policies DB to InfluxDB for Policy: $PolicyName"
        influx write \
            --host "$veeamInfluxDBURL:$veeamInfluxDBPort" \
            -t "$veeamInfluxDBToken" \
            -b "$veeamInfluxDBBucket" \
            -o "$veeamInfluxDBOrg" \
            -p s \
            --skip-verify \
            --format lp \
            "$influxData"

        arraydbpolicies=$((arraydbpolicies + 1))
    done
else
    echo "No SQL database policies found."
fi

##
# Veeam Backup for Azure Policies. This part will check VBA File Share Policies
##
echo "Collecting file share policies information..."
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/$veeamAPIVersion/policies/fileShares"
veeamVBAPoliciesFSUrl=$(curl -X GET "$veeamVBAURL" -H "Authorization: Bearer $veeamBearer" -H "accept: application/json" -k --silent)

# Check if there are any file share policies
totalPolicies=$(echo "$veeamVBAPoliciesFSUrl" | jq '.results | length')

if [ "$totalPolicies" -gt 0 ]; then
    declare -i arrayfspolicies=0
    for id in $(echo "$veeamVBAPoliciesFSUrl" | jq -r '.results[].id'); do
        PolicyID=$(echo "$veeamVBAPoliciesFSUrl" | jq --raw-output ".results[$arrayfspolicies].id")
        PolicyName=$(echo "$veeamVBAPoliciesFSUrl" | jq --raw-output ".results[$arrayfspolicies].name" | awk '{gsub(/ /,"\\ ");print}')
        PolicyDescription=$(echo "$veeamVBAPoliciesFSUrl" | jq --raw-output ".results[$arrayfspolicies].description" | awk '{gsub(/ /,"\\ ");print}')
        if [ -z "$PolicyDescription" ]; then PolicyDescription="0"; fi

        # Extract snapshot counts from the policy schedules
        PolicySnapshotCountDaily=$(echo "$veeamVBAPoliciesFSUrl" | jq --raw-output ".results[$arrayfspolicies].dailySchedule.snapshotSchedule.snapshotsToKeep")
        if [[ "$PolicySnapshotCountDaily" == "null" ]]; then PolicySnapshotCountDaily=0; fi

        PolicySnapshotCountWeekly=$(echo "$veeamVBAPoliciesFSUrl" | jq --raw-output ".results[$arrayfspolicies].weeklySchedule.snapshotSchedule.snapshotsToKeep")
        if [[ "$PolicySnapshotCountWeekly" == "null" ]]; then PolicySnapshotCountWeekly=0; fi

        PolicySnapshotCountMonthly=$(echo "$veeamVBAPoliciesFSUrl" | jq --raw-output ".results[$arrayfspolicies].monthlySchedule.snapshotSchedule.snapshotsToKeep")
        if [[ "$PolicySnapshotCountMonthly" == "null" ]]; then PolicySnapshotCountMonthly=0; fi

        # Policy status
        PolicyStatus=$(echo "$veeamVBAPoliciesFSUrl" | jq --raw-output ".results[$arrayfspolicies].isEnabled")
        if [[ "$PolicyStatus" == "true" ]]; then PolicyStatus=1; else PolicyStatus=0; fi

        # Prepare InfluxDB line protocol data
        influxData="veeam_azure_policies,serverName=$serverName,PolicyID=$PolicyID,PolicyName=$PolicyName,PolicyDescription=$PolicyDescription,PolicyStatus=$PolicyStatus PolicySnapshotCountDaily=$PolicySnapshotCountDaily,PolicySnapshotCountWeekly=$PolicySnapshotCountWeekly,PolicySnapshotCountMonthly=$PolicySnapshotCountMonthly"

        # Send data to InfluxDB
        echo "Writing veeam_azure_policies to InfluxDB for Policy: $PolicyName"
        influx write \
            --host "$veeamInfluxDBURL:$veeamInfluxDBPort" \
            -t "$veeamInfluxDBToken" \
            -b "$veeamInfluxDBBucket" \
            -o "$veeamInfluxDBOrg" \
            -p s \
            --skip-verify \
            --format lp \
            "$influxData"

        arrayfspolicies=$((arrayfspolicies + 1))
    done
else
    echo "No file share policies found."
fi

##
# Veeam Backup for Azure Policies. This part will check VBA Cosmos DB Policies
##
echo "Collecting Cosmos DB policies information..."
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/$veeamAPIVersion/policies/cosmosDb"
veeamVBAPoliciesCosmosUrl=$(curl -X GET "$veeamVBAURL" -H "Authorization: Bearer $veeamBearer" -H "accept: application/json" -k --silent)

# Check if there are any Cosmos DB policies
totalPolicies=$(echo "$veeamVBAPoliciesCosmosUrl" | jq '.results | length')

if [ "$totalPolicies" -gt 0 ]; then
    declare -i arraycosmospolicies=0
    for id in $(echo "$veeamVBAPoliciesCosmosUrl" | jq -r '.results[].id'); do
        PolicyID=$(echo "$veeamVBAPoliciesCosmosUrl" | jq --raw-output ".results[$arraycosmospolicies].id")
        PolicyName=$(echo "$veeamVBAPoliciesCosmosUrl" | jq --raw-output ".results[$arraycosmospolicies].name" | awk '{gsub(/ /,"\\ ");print}')
        PolicyDescription=$(echo "$veeamVBAPoliciesCosmosUrl" | jq --raw-output ".results[$arraycosmospolicies].description" | awk '{gsub(/ /,"\\ ");print}')
        if [ -z "$PolicyDescription" ]; then PolicyDescription="0"; fi

        # Extract backup retention settings from the policy schedules
        PolicyBackupRetentionDaily=$(echo "$veeamVBAPoliciesCosmosUrl" | jq --raw-output ".results[$arraycosmospolicies].dailySchedule.backupSchedule.retention.timeRetentionDuration")
        if [[ "$PolicyBackupRetentionDaily" == "null" ]]; then PolicyBackupRetentionDaily=0; fi

        PolicyBackupRetentionWeekly=$(echo "$veeamVBAPoliciesCosmosUrl" | jq --raw-output ".results[$arraycosmospolicies].weeklySchedule.backupSchedule.retention.timeRetentionDuration")
        if [[ "$PolicyBackupRetentionWeekly" == "null" ]]; then PolicyBackupRetentionWeekly=0; fi

        PolicyBackupRetentionMonthly=$(echo "$veeamVBAPoliciesCosmosUrl" | jq --raw-output ".results[$arraycosmospolicies].monthlySchedule.backupSchedule.retention.timeRetentionDuration")
        if [[ "$PolicyBackupRetentionMonthly" == "null" ]]; then PolicyBackupRetentionMonthly=0; fi

        PolicyBackupRetentionYearly=$(echo "$veeamVBAPoliciesCosmosUrl" | jq --raw-output ".results[$arraycosmospolicies].yearlySchedule.retentionYearsCount")
        if [[ "$PolicyBackupRetentionYearly" == "null" ]]; then PolicyBackupRetentionYearly=0; fi

        # Policy status
        PolicyStatus=$(echo "$veeamVBAPoliciesCosmosUrl" | jq --raw-output ".results[$arraycosmospolicies].isEnabled")
        if [[ "$PolicyStatus" == "true" ]]; then PolicyStatus=1; else PolicyStatus=0; fi

        # Prepare InfluxDB line protocol data
        influxData="veeam_azure_policies,serverName=$serverName,PolicyID=$PolicyID,PolicyName=$PolicyName,PolicyDescription=$PolicyDescription,PolicyStatus=$PolicyStatus PolicyBackupRetentionDaily=$PolicyBackupRetentionDaily,PolicyBackupRetentionWeekly=$PolicyBackupRetentionWeekly,PolicyBackupRetentionMonthly=$PolicyBackupRetentionMonthly,PolicyBackupRetentionYearly=$PolicyBackupRetentionYearly"

        # Send data to InfluxDB
        echo "Writing veeam_azure_policies to InfluxDB for Policy: $PolicyName"
        influx write \
            --host "$veeamInfluxDBURL:$veeamInfluxDBPort" \
            -t "$veeamInfluxDBToken" \
            -b "$veeamInfluxDBBucket" \
            -o "$veeamInfluxDBOrg" \
            -p s \
            --skip-verify \
            --format lp \
            "$influxData"

        arraycosmospolicies=$((arraycosmospolicies + 1))
    done
else
    echo "No Cosmos DB policies found."
fi

##
# Veeam Backup for Azure Repositories. This part will check VBA Repositories
##
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/$veeamAPIVersion/repositories"
veeamVBAPoliciesUrl=$(curl -X GET "$veeamVBAURL" -H "Authorization: Bearer $veeamBearer" -H "accept: application/json" -k --silent)

declare -i arrayrepositories=0
for id in $(echo "$veeamVBAPoliciesUrl" | jq -r '.results[].id'); do
    RepositoryID=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrepositories].id")
    RepositoryName=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrepositories].name" | awk '{gsub(/ /,"\\ ");print}')
    RepositoryDescription=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrepositories].description" | awk '{gsub(/ /,"\\ ");print}')
    if [ "$RepositoryDescription" == "" ]; then RepositoryDescription="0"; fi
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
    RepositoryTier=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrepositories].storageTier")

    # Prepare InfluxDB line protocol data
    influxData="veeam_azure_repositories,serverName=$serverName,repoID=$RepositoryID,repoName=$RepositoryName,repoDescription=$RepositoryDescription,repoAccountName=$RepositoryAccountName,repoContainer=$RepositoryContainerName,repoAzureID=$RepositoryAzureID,repoStatus=$RepositoryStatus,RepositoryTier=$RepositoryTier repoEncryption=$encryption"

    # Send data to InfluxDB
    echo "Writing veeam_azure_repositories to InfluxDB"
    influx write \
        --host "$veeamInfluxDBURL:$veeamInfluxDBPort" \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        --skip-verify \
        --format lp \
        "$influxData"

    arrayrepositories=$((arrayrepositories + 1))
done

##
# Veeam Backup for Azure Sessions. This part will check VBA Sessions
##
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/$veeamAPIVersion/jobSessions?Types=ManualSnapshot&Types=PolicyBackup&Types=PolicySnapshot&Types=SnapshotBackup&Types=SqlPolicyBackup&Types=SqlPolicyArchive&Types=SqlManualBackup&Types=FileSharePolicySnapshot&Types=FileShareManualSnapshot&Types=ConfigurationBackupManual&Types=ConfigurationBackupScheduled&Types=VnetPolicyBackup&Types=CosmosDbPolicyBackup&Types=CosmosDbPolicyArchive&Types=CosmosDbManualBackup"
veeamVBASessionsBackupUrl=$(curl -X GET "$veeamVBAURL" -H "Authorization: Bearer $veeamBearer" -H "accept: application/json" -k --silent)

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
        *)
            jobStatus="0"
            ;;
    esac
    SessionType=$(echo "$veeamVBASessionsBackupUrl" | jq --raw-output ".results[$arraysessionsbackup].type")
    SessionDuration=$(echo "$veeamVBASessionsBackupUrl" | jq --raw-output ".results[$arraysessionsbackup].executionDuration")
    # Convert executionDuration to seconds (including fractions)
    SessionDurationS=$(echo "$SessionDuration" | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')
    SessionStopTime=$(echo "$veeamVBASessionsBackupUrl" | jq --raw-output ".results[$arraysessionsbackup].executionStopTime")
    SessionTimeStamp=$(date -d "${SessionStopTime}" '+%s')
    SessionPolicyID=$(echo "$veeamVBASessionsBackupUrl" | jq --raw-output ".results[$arraysessionsbackup].backupJobInfo.policyId")
    SessionPolicyName=$(echo "$veeamVBASessionsBackupUrl" | jq --raw-output ".results[$arraysessionsbackup].backupJobInfo.policyName" | awk '{gsub(/ /,"\\ ");print}')
    if [ -z "$SessionPolicyName" ]; then SessionPolicyName="0"; fi

    # Prepare data for InfluxDB
    influxData="veeam_azure_sessions,serverName=$serverName,sessionID=$SessionID,sessionType=$SessionType,sessionPolicyID=$SessionPolicyID,sessionPolicyName=$SessionPolicyName sessionStatus=$jobStatus,sessionDuration=$SessionDurationS $SessionTimeStamp"

    # Send data to InfluxDB
    echo "Writing veeam_azure_sessions to InfluxDB for Session ID: $SessionID"
    influx write \
        --host "$veeamInfluxDBURL:$veeamInfluxDBPort" \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        --skip-verify \
        --format lp \
        "$influxData"

    arraysessionsbackup=$((arraysessionsbackup + 1))
done


