#!/bin/bash
##      .SYNOPSIS
##      Grafana Dashboard for Veeam Backup Azure v3.0 - Using API to InfluxDB Script
## 
##      .DESCRIPTION
##      This Script will query the Veeam Backup for Azure API and send the data directly to InfluxDB, which can be used to present it to Grafana. 
##      The Script and the Grafana Dashboard it is provided as it is, and bear in mind you can not open support Tickets regarding this project. It is a Community Project
##	
##      .Notes
##      NAME:  veeam_azure.sh
##      ORIGINAL NAME: veeam_azure.sh
##      LASTEDIT: 14/12/2021
##      VERSION: 3.0
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

veeamBearer=$(curl -X POST --header "Content-Type: application/x-www-form-urlencoded" --header "Accept: application/json" -d "Username=$veeamUsername&Password=$veeamPassword&refresh_token=&grant_type=Password&mfa_token=&mfa_code=" "$veeamBackupAzureServer:$veeamBackupAzurePort/api/oauth2/token" -k --silent | jq -r '.access_token')

##
# Veeam Backup for Azure Overview. This part will check VBA Overview
##
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/v3/system/about"
veeamVBAOverviewUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

    version=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".serverVersion")
    workerversion=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".workerVersion")
    
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/v3/statistics/summary"
veeamVBAOverviewUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

    VMsCount=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".instancesCount")
    VMsProtected=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".protectedInstancesCount")
    PoliciesCount=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".policiesCount")
    RepositoriesCount=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".repositoriesCount")

veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/v3/system/serverInfo"
veeamVBAOverviewUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

    serverName=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".serverName")
    azureRegion=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".azureRegion")

veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/v3/license"
veeamVBAOverviewUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

    licenseType=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".licenseType")
    instancesUses=$(echo "$veeamVBAOverviewUrl" | jq --raw-output ".instancesUses")
    
    #echo "veeam_azure_overview,serverName=$serverName,version=$version,azureRegion=$azureRegion,workerversion=$workerversion,licenseType=$licenseType,instancesUses=$instancesUses VMs=$VMsCount,VMsProtected=$VMsProtected,Policies=$PoliciesCount,Repositories=$RepositoriesCount"
    echo "Writing veeam_azure_overview  to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_overview,serverName=$serverName,version=$version,azureRegion=$azureRegion,workerversion=$workerversion,licenseType=$licenseType,instancesUses=$instancesUses VMs=$VMsCount,VMsProtected=$VMsProtected,Policies=$PoliciesCount,Repositories=$RepositoriesCount"
    
##
# Veeam Backup for Azure Instances. This part will check VBA and report all the protected Instances
##
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/v3/virtualMachines?ProtectionStatus=Protected"
veeamVBAInstancesUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

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
    veeamVBAVMURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/v3/policies?virtualMachineId=$VMID"
    veeamVBAInstancesPolicyUrl=$(curl -X GET $veeamVBAVMURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)
    VMPolicy=$(echo "$veeamVBAInstancesPolicyUrl" | jq --raw-output ".results[0].name" | awk '{gsub(/ /,"\\ ");print}')   
 
    #echo "veeam_azure_vm,serverName=$serverName,VMID=$VMID,VMName=$VMName,VMType=$VMType,VMPolicy=$VMPolicy,VMOSType=$VMOSType,VMRegion=$VMRegion,VMvirtualNetwork=$VMvirtualNetwork,VMsubnet=$VMsubnet,VMpublicIP=$VMpublicIP,VMprivateIP=$VMprivateIP VMSize=$VMSize"
    echo "Writing veeam_azure_vm  to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm,serverName=$serverName,VMID=$VMID,VMName=$VMName,VMType=$VMType,VMPolicy=$VMPolicy,VMOSType=$VMOSType,VMRegion=$VMRegion,VMvirtualNetwork=$VMvirtualNetwork,VMsubnet=$VMsubnet,VMpublicIP=$VMpublicIP,VMprivateIP=$VMprivateIP VMSize=$VMSize"
    
    # Restore Points per Instance
    veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/v3/restorePoints?virtualMachineId=$VMID&onlyLatest=False"
    veeamRestorePointsUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)
    
    declare -i arrayRestorePoint=0
    for id in $(echo "$veeamRestorePointsUrl" | jq -r '.results[].id'); do
      VMJobType=$(echo "$veeamRestorePointsUrl" | jq --raw-output ".results[$arrayRestorePoint].backupDestination")
      VMJobid=$(echo "$veeamRestorePointsUrl" | jq --raw-output ".results[$arrayRestorePoint].id")
      VMJobSize=$(echo "$veeamRestorePointsUrl" | jq --raw-output ".results[$arrayRestorePoint].backupSizeBytes")
      VMJobTime=$(echo "$veeamRestorePointsUrl" | jq --raw-output ".results[$arrayRestorePoint].pointInTime")
    
        echo "Writing veeam_azure_restorepoints  to InfluxDB"
        #echo "veeam_azure_restorepoints,serverName=$serverName,VMName=$VMName,JobType=$VMJobType,Jobid=$VMJobid,JobTime=$VMJobTime JobSize=$VMJobSize"
        curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_restorepoints,serverName=$serverName,VMName=$VMName,JobType=$VMJobType,Jobid=$VMJobid,JobTime=$VMJobTime JobSize=$VMJobSize"
        
        arrayRestorePoint=$arrayRestorePoint+1
    done   
    arrayinstances=$arrayinstances+1    
done
    echo "Writing veeam_azure_vm_protected  to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_protected TotalVMs=$arrayinstances"

##
# Veeam Backup for Azure Instances. This part will check VBA and report all the unprotected Instances
##
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/v3/virtualMachines?ProtectionStatus=Unprotected"
veeamVBAUnprotectedUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

    #Looking at each region and counting the unprotected VMs
    eastus=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="eastus")) | length')    
    eastus2=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="eastus2")) | length')    
    centralus=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="centralus")) | length')    
    northcentralus=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="northcentralus")) | length') 
    southcentralus=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="southcentralus")) | length')    
    westcentralus=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="westcentralus")) | length')    
    westus=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="westus")) | length')    
    westus2=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="westus2")) | length')    
    canadaeast=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="canadaeast")) | length')    
    canadacentral=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="canadacentral")) | length')    
    brazilsouth=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="brazilsouth")) | length')    
    northeurope=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="northeurope")) | length') 
    westeurope=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="westeurope")) | length')    
    francecentral=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="francecentral")) | length')    
    francesouth=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="francesouth")) | length')    
    ukwest=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="ukwest")) | length')    
    uksouth=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="uksouth")) | length')    
    germanycentral=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="germanycentral")) | length')    
    germanynortheast=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="germanynortheast")) | length')    
    germanynorth=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="germanynorth")) | length')    
    germanywestcentral=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="germanywestcentral")) | length')    
    switzerlandnorth=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="switzerlandnorth")) | length') 
    switzerlandwest=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="switzerlandwest")) | length')    
    norwayeast=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="norwayeast")) | length')    
    southeastasia=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="southeastasia")) | length')    
    eastasia=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="eastasia")) | length')   
    australiaeast=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="australiaeast")) | length')    
    australiasoutheast=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="australiasoutheast")) | length')    
    australiacentral=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="australiacentral")) | length')    
    australiacentral2=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="australiacentral2")) | length')    
    chinaeast=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="chinaeast")) | length')    
    chinanorth=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="chinanorth")) | length')    
    centralindia=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="centralindia")) | length') 
    westindia=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="westindia")) | length')    
    southindia=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="southindia")) | length')    
    japaneast=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="japaneast")) | length')    
    japanwest=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="japanwest")) | length')    
    koreacentral=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="koreacentral")) | length')    
    koreasouth=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="koreasouth")) | length')    
    southafricawest=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="southafricawest")) | length') 
    southafricanorth=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="southafricanorth")) | length')    
    uaecentral=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="uaecentral")) | length')    
    uaenorth=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output '.results | map(select(.regionName=="uaenorth")) | length')    

    echo "Writing veeam_azure_vm_unprotected  to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="eastus",geohash="dq8hfn5y9wg" UPVM=$eastus"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="eastus2",geohash="dq8hfn5y9wg" UPVM=$eastus2"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="centralus",geohash="9zmy1x8m433" UPVM=$centralus"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="northcentralus",geohash="dp04jyu9y1h" UPVM=$northcentralus"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="southcentralus",geohash="9v1zenczpg4" UPVM=$southcentralus"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="westcentralus",geohash="9x9ut88ncmn" UPVM=$westcentralus"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="westus",geohash="9qdc22t7bq5" UPVM=$westus"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="westus2",geohash="c22ky4rr2tr" UPVM=$westus2"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="canadaeast",geohash="f2m4t3uwczv" UPVM=$canadaeast"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="canadacentral",geohash="dpz2ww8wjj1" UPVM=$canadacentral"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="brazilsouth",geohash="6ggzf5qgksb" UPVM=$brazilsouth"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="northeurope",geohash="gc2xsdvte9v" UPVM=$northeurope"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="westeurope",geohash="u16cn8kjdgh" UPVM=$westeurope"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="francecentral",geohash="u09tgyd042t" UPVM=$francecentral"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="francesouth",geohash="spey0yfznsg" UPVM=$francesouth"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="ukwest",geohash="gcjsvrxnucs" UPVM=$ukwest"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="uksouth",geohash="gcpv4s80b7q" UPVM=$uksouth"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="germanycentral",geohash="u0yj1k6fn2k" UPVM=$germanycentral"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="germanynortheast",geohash="u320t9r2d24" UPVM=$germanynortheast"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="germanynorth",geohash="u1wbwwp4nbh" UPVM=$germanynorth"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="germanywestcentral",geohash="u0yj1k6fn2k" UPVM=$germanywestcentral"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="switzerlandnorth",geohash="u0qj88v4pz6" UPVM=$switzerlandnorth"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="switzerlandwest",geohash="u0hqg7m5zxh" UPVM=$switzerlandwest"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="norwayeast",geohash="ukq8sp6wbxj" UPVM=$norwayeast"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="southeastasia",geohash="u4exmjjkuqt" UPVM=$southeastasia"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="eastasia",geohash="w21xrz70d4w" UPVM=$eastasia"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="australiaeast",geohash="wecp1v5pxcw" UPVM=$australiaeast"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="australiasoutheast",geohash="r4pt8re3et0" UPVM=$australiasoutheast"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="australiacentral",geohash="r1tb59hgjfe" UPVM=$australiacentral"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="australiacentral2",geohash="r3dp33jrs1y" UPVM=$australiacentral2"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="chinaeast",geohash="wtw1tuk8sv2" UPVM=$chinaeast"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="chinanorth",geohash="wx4e4qdjbwz" UPVM=$chinanorth"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="centralindia",geohash="tek3rhq6efd" UPVM=$centralindia"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="westindia",geohash="te7sx3b7wxb" UPVM=$westindia"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="southindia",geohash="tf2fnp23j4r" UPVM=$southindia"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="japaneast",geohash="xn7k24npyzm" UPVM=$japaneast"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="japanwest",geohash="xn0m32yuw5f" UPVM=$japanwest"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="koreacentral",geohash="wydjww8cwv6" UPVM=$koreacentral"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="koreasouth",geohash="wy78p980qyu" UPVM=$koreasouth"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="southafricawest",geohash="k3vp44hbv4f" UPVM=$southafricawest"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="southafricanorth",geohash="ke7gj78s7cv" UPVM=$southafricanorth"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="uaecentral",geohash="thqdwrd35c1" UPVM=$uaecentral"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,VMRegion="uaenorth",geohash="thrntscegt6" UPVM=$uaenorth"

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
    VMOSType=$(echo "$veeamVBAUnprotectedUrl" | jq --raw-output ".results[$arrayUnprotected].osType")   
    
    #echo "veeam_azure_vm_unprotected,serverName=$serverName,VMID=$VMID,VMName=$VMName,VMType=$VMType,VMOSType=$VMOSType,VMRegion=$VMRegion,VMvirtualNetwork=$VMvirtualNetwork,VMsubnet=$VMsubnet,VMpublicIP=$VMpublicIP,VMprivateIP=$VMprivateIP VMSize=$VMSize"
    echo "Writing veeam_azure_vm_unprotected to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected,serverName=$serverName,VMID=$VMID,VMName=$VMName,VMType=$VMType,VMOSType=$VMOSType,VMRegion=$VMRegion,VMvirtualNetwork=$VMvirtualNetwork,VMsubnet=$VMsubnet,VMpublicIP=$VMpublicIP,VMprivateIP=$VMprivateIP VMSize=$VMSize"
           
    arrayUnprotected=$arrayUnprotected+1
done
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_unprotected TotalVMs=$arrayUnprotected"
    
##
# Veeam Backup for Azure Databases. This part will check VBA and report all the protected Databases
##
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/v3/protectedItem/sql"
veeamVBADatabasesUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

declare -i arraydatabases=0
for id in $(echo "$veeamVBADatabasesUrl" | jq -r '.results[].id'); do
    DatabaseID=$(echo "$veeamVBADatabasesUrl" | jq --raw-output ".results[$arraydatabases].id")
    DatabaseName=$(echo "$veeamVBADatabasesUrl" | jq --raw-output ".results[$arraydatabases].name" | awk '{gsub(/ /,"\\ ");print}')    
    DatabaseSQLName=$(echo "$veeamVBADatabasesUrl" | jq --raw-output ".results[$arraydatabases].sqlServer.name" | awk '{gsub(/ /,"\\ ");print}')    
    DatabaseSQLType=$(echo "$veeamVBADatabasesUrl" | jq --raw-output ".results[$arraydatabases].sqlServer.serverType")    
    DatabaseEnvironment=$(echo "$veeamVBADatabasesUrl" | jq --raw-output ".results[$arraydatabases].azureEnvironment")
    DatabaseSize=$(echo "$veeamVBADatabasesUrl" | jq --raw-output ".results[$arraydatabases].sizeInMb")
    DatabaseRegion=$(echo "$veeamVBADatabasesUrl" | jq --raw-output ".results[$arraydatabases].region.name")        

    #echo "veeam_azure_vm_database,serverName=$serverName,DatabaseID=$DatabaseID,DatabaseName=$DatabaseName,DatabaseSQLName=$DatabaseSQLName,DatabaseSQLType=$DatabaseSQLType,DatabaseEnvironment=$DatabaseEnvironment,DatabaseRegion=$DatabaseRegion DatabaseSize=$DatabaseSize
    echo "Writing veeam_azure_vm_database to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_vm_database,serverName=$serverName,DatabaseID=$DatabaseID,DatabaseName=$DatabaseName,DatabaseSQLName=$DatabaseSQLName,DatabaseSQLType=$DatabaseSQLType,DatabaseEnvironment=$DatabaseEnvironment,DatabaseRegion=$DatabaseRegion DatabaseSize=$DatabaseSize"
    
    arraydatabases=$arraydatabases+1    
done

##
# Veeam Backup for Azure Policies. This part will check VBA VM Policies
##
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/v3/policies"
veeamVBAPoliciesUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

declare -i arraypolicies=0
for id in $(echo "$veeamVBAPoliciesUrl" | jq -r '.results[].id'); do
    PolicyID=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].id")
    TenantID=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].tenantId")
    PolicyStatus=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].isEnabled")
    PolicyName=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].name" | awk '{gsub(/ /,"\\ ");print}')
    PolicyDescription=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arraypolicies].description" | awk '{gsub(/ /,"\\ ");print}')
    if [ "$PolicyDescription" == "" ]; then declare -i PolicyDescription=0; fi
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

    #echo "veeam_azure_policies,serverName=$serverName,PolicyID=$PolicyID,TenantID=$TenantID,PolicyStatus=$PolicyStatus,PolicyName=$PolicyName,PolicyDescription=$PolicyDescription PolicySnapshotCountDaily=$PolicySnapshotCountDaily,PolicySnapshotCountWeekly=$PolicySnapshotCountWeekly,PolicySnapshotCountMonthly=$PolicySnapshotCountMonthly,PolicySnapshotCountYearly=$PolicySnapshotCountYearly,appaware=$appaware"
    echo "Writing veeam_azure_policies to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_policies,serverName=$serverName,PolicyID=$PolicyID,TenantID=$TenantID,PolicyStatus=$PolicyStatus,PolicyName=$PolicyName,PolicyDescription=$PolicyDescription,PolicyBackupRetentionType=$PolicyBackupRetentionType PolicySnapshotCountDaily=$PolicySnapshotCountDaily,PolicySnapshotCountWeekly=$PolicySnapshotCountWeekly,PolicySnapshotCountMonthly=$PolicySnapshotCountMonthly,PolicySnapshotCountYearly=$PolicySnapshotCountYearly,PolicyAppAware=$PolicyAppAware,PolicyBackupRetention=$PolicyBackupRetention"
    
    arraypolicies=$arraypolicies+1
done

##
# Veeam Backup for Azure Policies. This part will check VBA Databases Policies
##
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/v3/policies/sql"
veeamVBAPoliciesDBUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

declare -i arraydbpolicies=0
for id in $(echo "$veeamVBAPoliciesDBUrl" | jq -r '.results[].id'); do
    PolicyID=$(echo "$veeamVBAPoliciesDBUrl" | jq --raw-output ".results[$arraydbpolicies].id")
    PolicyName=$(echo "$veeamVBAPoliciesDBUrl" | jq --raw-output ".results[$arraydbpolicies].name" | awk '{gsub(/ /,"\\ ");print}')
    if [ "$PolicyDescription" == "" ]; then declare -i PolicyDescription=0; fi
    PolicyBackupRetentionDaily=$(echo "$veeamVBAPoliciesDBUrl" | jq --raw-output ".results[$arraydbpolicies].dailySchedule.backupSchedule.retention.timeRetentionDuration")
    if [[ $PolicyBackupRetentionDaily == "null" ]]; then declare -i PolicyBackupRetentionDaily=0; fi    
    PolicyBackupRetentionWeekly=$(echo "$veeamVBAPoliciesDBUrl" | jq --raw-output ".results[$arraydbpolicies].weeklySchedule.backupSchedule.retention.timeRetentionDuration")
    if [[ $PolicyBackupRetentionWeekly == "null" ]]; then declare -i PolicyBackupRetentionWeekly=0; fi
    PolicyBackupRetentionMonthly=$(echo "$veeamVBAPoliciesDBUrl" | jq --raw-output ".results[$arraydbpolicies].monthlySchedule.backupSchedule.retention.timeRetentionDuration")
    if [[ $PolicyBackupRetentionMonthly == "null" ]]; then declare -i PolicyBackupRetentionMonthly=0; fi    
    PolicyBackupRetentionYearly=$(echo "$veeamVBAPoliciesDBUrl" | jq --raw-output ".results[$arraydbpolicies].yearlySchedule.retentionYearsCount")
    if [[ $PolicyBackupRetentionYearly == "null" ]]; then declare -i PolicyBackupRetentionYearly=0; fi

    #echo "veeam_azure_policies,serverName=$serverName,PolicyID=$PolicyID,PolicyName=$PolicyName,PolicyDescription=$PolicyDescription PolicyBackupRetentionDaily=$PolicyBackupRetentionDaily,PolicyBackupRetentionWeekly=$PolicyBackupRetentionWeekly,PolicyBackupRetentionMonthly=$PolicyBackupRetentionMonthly,PolicyBackupRetentionYearly=$PolicyBackupRetentionYearly,PolicyAppAware=0"
    echo "Writing veeam_azure_policies DB to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_policies,serverName=$serverName,PolicyID=$PolicyID,PolicyName=$PolicyName PolicySnapshotCountDaily=$PolicyBackupRetentionDaily,PolicySnapshotCountWeekly=$PolicyBackupRetentionWeekly,PolicySnapshotCountMonthly=$PolicyBackupRetentionMonthly,PolicySnapshotCountYearly=$PolicyBackupRetentionYearly,PolicyAppAware=0"
    
    arraydbpolicies=$arraydbpolicies+1
done

##
# Veeam Backup for Azure Repositories. This part will check VBA Repositories
##
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/v3/repositories"
veeamVBAPoliciesUrl=$(curl -X GET $veeamVBAURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

declare -i arrayrepositories=0
for id in $(echo "$veeamVBAPoliciesUrl" | jq -r '.results[].id'); do
    RepositoryID=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrepositories].id")
    RepositoryName=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrepositories].name" | awk '{gsub(/ /,"\\ ");print}')
    RepositoryDescription=$(echo "$veeamVBAPoliciesUrl" | jq --raw-output ".results[$arrayrepositories].description" | awk '{gsub(/ /,"\\ ");print}')
    if [ "$PolicyDescription" == "" ]; then declare -i PolicyDescription=0; fi
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

    #echo "veeam_azure_repositories,serverName=$serverName,repoID=$RepositoryID,repoName=$RepositoryName,repoDescription=$RepositoryDescription,repoAccountName=$RepositoryAccountName,repoContainer=$RepositoryContainerName,repoAzureID=$RepositoryAzureID,repoStatus=$RepositoryStatus repoEncryption=$encryption"
    echo "Writing veeam_azure_repositories to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_repositories,serverName=$serverName,repoID=$RepositoryID,repoName=$RepositoryName,repoDescription=$RepositoryDescription,repoAccountName=$RepositoryAccountName,repoContainer=$RepositoryContainerName,repoAzureID=$RepositoryAzureID,repoStatus=$RepositoryStatus,RepositoryTier=$RepositoryTier repoEncryption=$encryption"
    
    arrayrepositories=$arrayrepositories+1
done

##
# Veeam Backup for Azure Sessions. This part will check VBA Sessions
##
veeamVBAURL="$veeamBackupAzureServer:$veeamBackupAzurePort/api/v3/jobSessions?Types=ManualSnapshot&Types=PolicyBackup&Types=PolicySnapshot&Types=SqlPolicyBackup&Types=SqlManualBackup"
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
    if [ "$veeamVBASessionPolicyName" == "" ]; then declare -i veeamVBASessionPolicyName=0; fi

    #echo "veeam_azure_sessions,serverName=$serverName,sessionID=$SessionID,sessionType=$SessionType,sessionPolicyID=$SessionPolicyID,sessionPolicyName=$SessionPolicyName sessionStatus=$jobStatus,sessionDuration=$SessionDurationS $SessionTimeStamp"
    echo "Writing veeam_azure_sessions to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_azure_sessions,serverName=$serverName,sessionID=$SessionID,sessionType=$SessionType,sessionPolicyID=$SessionPolicyID,sessionPolicyName=$SessionPolicyName sessionStatus=$jobStatus,sessionDuration=$SessionDurationS $SessionTimeStamp"
    
    arraysessionsbackup=$arraysessionsbackup+1
done