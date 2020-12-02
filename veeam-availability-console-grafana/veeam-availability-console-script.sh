#!/bin/bash
##      .SYNOPSIS
##      Grafana Dashboard for Veeam Backup for Veeam Availability Console - Using RestAPI to InfluxDB Script
## 
##      .DESCRIPTION
##      This Script will query the Veeam Availability Console RestAPI and send the data directly to InfluxDB, which can be used to present it to Grafana. 
##      The Script and the Grafana Dashboard it is provided as it is, and bear in mind you can not open support Tickets regarding this project. It is a Community Project
##	
##      .Notes
##      NAME:  veeam-availability-console-script.sh
##      ORIGINAL NAME: veeam_availability-console-grafana.sh
##      LASTEDIT: 22/12/2018
##      VERSION: 0.1
##      KEYWORDS: Veeam, InfluxDB, Grafana
   
##      .Link
##      https://jorgedelacruz.es/
##      https://jorgedelacruz.uk/

##
# Configurations
##
# Endpoint URL for InfluxDB
InfluxDBURL="YOURINFLUXDB"
InfluxDBPort="8086" #Default Port
InfluxDB="telegraf" #Default Database

# Endpoint URL for login action
Username="YOURVACUSER"
Password="YOURVACPASSWORD"
RestServer="YOURVACURL"
RestPort="1281" #Default Port
Bearer=$(curl -X POST --header "Content-Type: application/x-www-form-urlencoded" --header "Accept: application/json" -d "grant_type=password&username=$Username&password=$Password" "$RestServer:$RestPort/token" -k --silent | jq -r '.access_token')

# Unix Epoc Time - Jan 1, 2030
# Used for those cases where there is no expirey, but things giving null causes problems
NoExpiration="1893456000"

##
# Veeam Availability Console - Licenses per Tenant. This section will check on every Tenant and retrieve Licensing Information
##
VACUrl="$RestServer:$RestPort/v2/tenants"
TenantUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $Bearer" "$VACUrl" 2>&1 -k --silent)

declare -i arraylicense=0
for id in $(echo "$TenantUrl" | jq -r ".[].id"); do
    TenantId=$(echo "$TenantUrl" | jq --raw-output ".[$arraylicense].id")
    TenantName=$(echo "$TenantUrl" | jq --raw-output ".[$arraylicense].name" | awk '{gsub(/ /,"\\ ");print}')
    TenantEnabled=$(echo "$TenantUrl" | jq --raw-output ".[$arraylicense].isEnabled")
    TenantmaxConcurrentTasks=$(echo "$TenantUrl" | jq --raw-output ".[$arraylicense].maxConcurrentTasks")
    TenantbandwidthThrottlingEnabled=$(echo "$TenantUrl" | jq --raw-output ".[$arraylicense].bandwidthThrottlingEnabled")
    TenantallowedBandwidth=$(echo "$TenantUrl" | jq --raw-output ".[$arraylicense].allowedBandwidth")
    TenantallowedBandwidthUnits=$(echo "$TenantUrl" | jq --raw-output ".[$arraylicense].allowedBandwidthUnits")
    TenantvMsBackedUp=$(echo "$TenantUrl" | jq --raw-output ".[$arraylicense].vMsBackedUp")
    TenantvMsReplicated=$(echo "$TenantUrl" | jq --raw-output ".[$arraylicense].vMsReplicated")
    TenantvMsBackedUpToCloud=$(echo "$TenantUrl" | jq --raw-output ".[$arraylicense].vMsBackedUpToCloud")
    TenantmanagedPhysicalWorkstations=$(echo "$TenantUrl" | jq --raw-output ".[$arraylicense].managedPhysicalWorkstations")
    TenantmanagedCloudWorkstations=$(echo "$TenantUrl" | jq --raw-output ".[$arraylicense].managedCloudWorkstations")
    TenantmanagedPhysicalServers=$(echo "$TenantUrl" | jq --raw-output ".[$arraylicense].managedPhysicalServers")
    TenantmanagedCloudServers=$(echo "$TenantUrl" | jq --raw-output ".[$arraylicense].managedCloudServers")
    TenantexpirationEnabled=$(echo "$TenantUrl" | jq --raw-output ".[$arraylicense].expirationEnabled")
    if [ "$TenantexpirationEnabled" = "true" ];then
        TenantexpirationDate=$(echo "$TenantUrl" | jq --raw-output ".[$arraylicense].expirationDate") 
        TenantexpirationDateUnix=$(date -d "$TenantexpirationDate" +"%s")
    else
        declare -i TenantexpirationDateUnix=$NoExpiration
    fi

    #echo "veeam_vac_tenant,companyName=$TenantName,enabled=$TenantEnabled,expirationEnabled=$TenantexpirationEnabled,expirationDate=$TenantexpirationDate maxConcurrentTasks=$TenantmaxConcurrentTasks,bandwidthThrottlingEnabled=$TenantbandwidthThrottlingEnabled,allowedBandwidth=$TenantallowedBandwidth,vMsBackedUp=$TenantvMsBackedUp,vMsReplicated=$TenantvMsReplicated,vMsBackedUpToCloud=$TenantvMsBackedUpToCloud,managedPhysicalWorkstations=$TenantmanagedPhysicalWorkstations,managedCloudWorkstations=$TenantmanagedCloudWorkstations,managedPhysicalServers=$TenantmanagedPhysicalServers,managedCloudServers=$TenantmanagedCloudServers"
    curl -i -XPOST "http://$InfluxDBURL:$InfluxDBPort/write?precision=s&db=$InfluxDB" --data-binary "veeam_vac_tenant,companyName=$TenantName,enabled=$TenantEnabled,expirationEnabled=$TenantexpirationEnabled,bandwidthThrottlingEnabled=$TenantbandwidthThrottlingEnabled expirationDate=$TenantexpirationDateUnix,maxConcurrentTasks=$TenantmaxConcurrentTasks,allowedBandwidth=$TenantallowedBandwidth,vMsBackedUp=$TenantvMsBackedUp,vMsReplicated=$TenantvMsReplicated,vMsBackedUpToCloud=$TenantvMsBackedUpToCloud,managedPhysicalWorkstations=$TenantmanagedPhysicalWorkstations,managedCloudWorkstations=$TenantmanagedCloudWorkstations,managedPhysicalServers=$TenantmanagedPhysicalServers,managedCloudServers=$TenantmanagedCloudServers"
    VACUrl="$RestServer:$RestPort/v2/tenants/$TenantId/backupResources"
    BackupResourcesUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $Bearer" "$VACUrl" 2>&1 -k --silent)
    declare -i arrayresources=0
    for id in $(echo "$BackupResourcesUrl" | jq -r ".[].id"); do
    cloudRepositoryName=$(echo "$BackupResourcesUrl" | jq --raw-output ".[$arrayresources].cloudRepositoryName"| awk '{gsub(/ /,"\\ ");print}')
    storageQuota=$(echo "$BackupResourcesUrl" | jq --raw-output ".[$arrayresources].storageQuota")
    storageQuotaUnits=$(echo "$BackupResourcesUrl" | jq --raw-output ".[$arrayresources].storageQuotaUnits")
    case $storageQuotaUnits in
        B)
            storageQuota=$(echo "scale=4; $storageQuota / 1048576" | bc -l)
        ;;
        KB)
            storageQuota=$(echo "scale=4; $storageQuota / 1024" | bc -l)
        ;;
        MB)
        ;;
        GB)
            storageQuota=$(echo "scale=4; $storageQuota * 1024" | bc -l)
        ;;
        TB)
            storageQuota=$(echo "scale=4; $storageQuota * 1048576" | bc -l)
        ;;
        esac
    vMsQuota=$(echo "$BackupResourcesUrl" | jq --raw-output ".[$arrayresources].vMsQuota")
    trafficQuota=$(echo "$BackupResourcesUrl" | jq --raw-output ".[$arrayresources].trafficQuota")
    trafficQuotaUnits=$(echo "$BackupResourcesUrl" | jq --raw-output ".[$arrayresources].trafficQuotaUnits")
    case $trafficQuotaUnits in
        B)
            trafficQuota=$(echo "scale=4; $trafficQuota / 1048576" | bc -l)
        ;;
        KB)
            trafficQuota=$(echo "scale=4; $trafficQuota / 1024" | bc -l)
        ;;
        MB)
        ;;
        GB)
            trafficQuota=$(echo "scale=4; $trafficQuota * 1024" | bc -l)
        ;;
        TB)
            trafficQuota=$(echo "scale=4; $trafficQuota * 1048576" | bc -l)
        ;;
        esac
    wanAccelerationEnabled=$(echo "$BackupResourcesUrl" | jq --raw-output ".[$arrayresources].wanAccelerationEnabled")
    usedStorageQuota=$(echo "$BackupResourcesUrl" | jq --raw-output ".[$arrayresources].usedStorageQuota")
    usedStorageQuotaUnits=$(echo "$BackupResourcesUrl" | jq --raw-output ".[$arrayresources].usedStorageQuotaUnits")
    case $usedStorageQuotaUnits in
        B)
            usedStorageQuota=$(echo "scale=4; $usedStorageQuota / 1048576" | bc -l)
        ;;
        KB)
            usedStorageQuota=$(echo "scale=4; $usedStorageQuota / 1024" | bc -l)
        ;;
        MB)
        ;;
        GB)
            usedStorageQuota=$(echo "scale=4; $usedStorageQuota * 1024" | bc -l)
        ;;
        TB)
            usedStorageQuota=$(echo "scale=4; $usedStorageQuota * 1048576" | bc -l)
        ;;
        esac
    usedTrafficQuota=$(echo "$BackupResourcesUrl" | jq --raw-output ".[$arrayresources].usedTrafficQuota")
    usedTrafficQuotaUnits=$(echo "$BackupResourcesUrl" | jq --raw-output ".[$arrayresources].usedTrafficQuotaUnits")
    case $usedTrafficQuotaUnits in
        B)
            usedTrafficQuota=$(echo "scale=4; $usedTrafficQuota / 1048576" | bc -l)
        ;;
        KB)
            usedTrafficQuota=$(echo "scale=4; $usedTrafficQuota / 1024" | bc -l)
        ;;
        MB)
        ;;
        GB)
            usedTrafficQuota=$(echo "scale=4; $usedTrafficQuota * 1024" | bc -l)
        ;;
        TB)
            usedTrafficQuota=$(echo "scale=4; $usedTrafficQuota * 1048576" | bc -l)
        ;;
        esac
    #echo "veeam_vac_backupresources,companyName=$TenantName,cloudRepositoryName=$cloudRepositoryName,wanAccelerationEnabled=$wanAccelerationEnabled storageQuota=$storageQuota,vMsQuota=$vMsQuota,trafficQuota=$trafficQuota,usedStorageQuota=$usedStorageQuota,usedTrafficQuota=$usedTrafficQuota"
    curl -i -XPOST "http://$InfluxDBURL:$InfluxDBPort/write?precision=s&db=$InfluxDB" --data-binary "veeam_vac_backupresources,companyName=$TenantName,cloudRepositoryName=$cloudRepositoryName,wanAccelerationEnabled=$wanAccelerationEnabled storageQuota=$storageQuota,vMsQuota=$vMsQuota,trafficQuota=$trafficQuota,usedStorageQuota=$usedStorageQuota,usedTrafficQuota=$usedTrafficQuota"
    arrayresources=$arrayresources+1
    done
    arraylicense=$arraylicense+1
done

##
# Veeam Availability Console, Cloud Connect and Veeam Backup & Replication Licensing - This section will retrieve the licensing of the Veeam Availability Console, Veeam Cloud Connect and every managed Veeam Backup & Replication Server
##

# Cloud Connect Licensing
VACUrl="$RestServer:$RestPort/v2/licensing/cloudconnectLicenses"
CloudConnectLicenseUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $Bearer" "$VACUrl" 2>&1 -k --silent)

CloudConnectLicensecontactPerson=$(echo "$CloudConnectLicenseUrl" | jq --raw-output ".[].contactPerson" | awk '{gsub(/ /,"\\ ");print}')
CloudConnectLicenseEdition=$(echo "$CloudConnectLicenseUrl" | jq --raw-output ".[].edition" | awk '{gsub(/ /,"\\ ");print}')
CloudConnectLicenselicensedTo=$(echo "$CloudConnectLicenseUrl" | jq --raw-output ".[].licensedTo" | awk '{gsub(/ /,"\\ ");print}')
CloudConnectLicenselicenseType=$(echo "$CloudConnectLicenseUrl" | jq --raw-output ".[].licenseType")
CloudConnectLicenselicensestatus=$(echo "$CloudConnectLicenseUrl" | jq --raw-output ".[].status")
CloudConnectLicenselicenseExpirationDate=$(echo "$CloudConnectLicenseUrl" | jq --raw-output ".[].licenseExpirationDate")
CloudConnectLicenselicenseExpirationDateUnix=$(date -d "$CloudConnectLicenselicenseExpirationDate" +"%s")
CloudConnectLicensesupportExpirationDate=$(echo "$CloudConnectLicenseUrl" | jq --raw-output ".[].supportExpirationDate")
if [[ $CloudConnectLicensesupportExpirationDate = "null" ]] ; then
        CloudConnectLicensesupportExpirationDate=$CloudConnectLicenselicenseExpirationDate
fi
CloudConnectLicensesupportExpirationDateUnix=$(date -d "$CloudConnectLicensesupportExpirationDate" +"%s")
CloudConnectLicenselicensedVMs=$(echo "$CloudConnectLicenseUrl" | jq --raw-output ".[].licensedVMs")
CloudConnectLicenseusedVMs=$(echo "$CloudConnectLicenseUrl" | jq --raw-output ".[].usedVMs")
CloudConnectLicensebackupServerName=$(echo "$CloudConnectLicenseUrl" | jq --raw-output ".[].backupServerName" | awk '{gsub(/ /,"\\ ");print}')
CloudConnectLicensecompanyName=$(echo "$CloudConnectLicenseUrl" | jq --raw-output ".[].companyName" | awk '{gsub(/ /,"\\ ");print}')
if [[ $CloudConnectLicenselicensedTo = "null" ]] ; then
        CloudConnectLicenselicensedTo="$CloudConnectLicensecompanyName"
fi
if [[ $CloudConnectLicensecontactPerson = "null" ]] ; then
        CloudConnectLicensecontactPerson="$CloudConnectLicenselicensedTo"
fi
CloudConnectLicenselicensedCloudconnectBackups=$(echo "$CloudConnectLicenseUrl" | jq --raw-output ".[].licensedCloudconnectBackups")
CloudConnectLicenseusedCloudconnectBackups=$(echo "$CloudConnectLicenseUrl" | jq --raw-output ".[].usedCloudconnectBackups")
CloudConnectLicenselicensedCloudconnectReplicas=$(echo "$CloudConnectLicenseUrl" | jq --raw-output ".[].licensedCloudconnectReplicas")
CloudConnectLicenseusedCloudconnectReplicas=$(echo "$CloudConnectLicenseUrl" | jq --raw-output ".[].usedCloudconnectReplicas")
CloudConnectLicenselicensedCloudconnectServers=$(echo "$CloudConnectLicenseUrl" | jq --raw-output ".[].licensedCloudconnectServers")
CloudConnectLicenseusedCloudconnectServers=$(echo "$CloudConnectLicenseUrl" | jq --raw-output ".[].usedCloudconnectServers")
CloudConnectLicenselicensedCloudconnectWorkstations=$(echo "$CloudConnectLicenseUrl" | jq --raw-output ".[].licensedCloudconnectWorkstations")
CloudConnectLicenseusedCloudconnectWorkstations=$(echo "$CloudConnectLicenseUrl" | jq --raw-output ".[].usedCloudconnectWorkstations")

#echo "veeam_vac_vcclicense,edition=$CloudConnectLicenseEdition,status=$CloudConnectLicenselicensestatus,type=$CloudConnectLicenselicenseType,contactPerson=$CloudConnectLicensecontactPerson,licenseExpirationDate=$CloudConnectLicenselicenseExpirationDate,supportExpirationDate=$CloudConnectLicensesupportExpirationDate,backupServerName=$CloudConnectLicensebackupServerName,companyName=$CloudConnectLicensecompanyName licensedCloudConnectBackups=$CloudConnectLicenselicensedCloudconnectBackups,usedCloudConnectBackups=$CloudConnectLicenseusedCloudconnectBackups,licensedCloudConnectReplicas=$CloudConnectLicenselicensedCloudconnectReplicas,usedCloudConnectReplicas=$CloudConnectLicenseusedCloudconnectReplicas,licensedCloudConnectServers=$CloudConnectLicenselicensedCloudconnectServers,usedCloudConnectServers=$CloudConnectLicenseusedCloudconnectServers,licensedCloudConnectWorkstations=$CloudConnectLicenselicensedCloudconnectWorkstations,usedCloudConnectWorkstations=$CloudConnectLicenseusedCloudconnectWorkstations"
curl -i -XPOST "http://$InfluxDBURL:$InfluxDBPort/write?precision=s&db=$InfluxDB" --data-binary "veeam_vac_vcclicense,edition=$CloudConnectLicenseEdition,status=$CloudConnectLicenselicensestatus,type=$CloudConnectLicenselicenseType,contactPerson=$CloudConnectLicensecontactPerson,backupServerName=$CloudConnectLicensebackupServerName,companyName=$CloudConnectLicensecompanyName licenseExpirationDate=$CloudConnectLicenselicenseExpirationDateUnix,supportExpirationDate=$CloudConnectLicensesupportExpirationDateUnix,licensedCloudConnectBackups=$CloudConnectLicenselicensedCloudconnectBackups,usedCloudConnectBackups=$CloudConnectLicenseusedCloudconnectBackups,licensedCloudConnectReplicas=$CloudConnectLicenselicensedCloudconnectReplicas,usedCloudConnectReplicas=$CloudConnectLicenseusedCloudconnectReplicas,licensedCloudConnectServers=$CloudConnectLicenselicensedCloudconnectServers,usedCloudConnectServers=$CloudConnectLicenseusedCloudconnectServers,licensedCloudConnectWorkstations=$CloudConnectLicenselicensedCloudconnectWorkstations,usedCloudConnectWorkstations=$CloudConnectLicenseusedCloudconnectWorkstations"

# Veeam Availability Console Licensing
VACUrl="$RestServer:$RestPort/v2/licenseSettings"
VACLicenseUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $Bearer" "$VACUrl" 2>&1 -k --silent)

VACLicenseproductName=$(echo "$VACLicenseUrl" | jq --raw-output ".productName" | awk '{gsub(/ /,"\\ ");print}')
VACLicenselicensedTo=$(echo "$VACLicenseUrl" | jq --raw-output ".licensedTo" | awk '{gsub(/ /,"\\ ");print}')
VACLicenselicenseType=$(echo "$VACLicenseUrl" | jq --raw-output ".type")
VACLicenselicensesCount=$(echo "$VACLicenseUrl" | jq --raw-output ".licensesCount")
VACLicenselicensesUsedCount=$(echo "$VACLicenseUrl" | jq --raw-output ".licensesUsedCount")
VACLicenselicenseExpirationDate=$(echo "$VACLicenseUrl" | jq --raw-output ".expirationDate")
VACLicenselicenseExpirationDateUnix=$(date -d "$VACLicenselicenseExpirationDate" +"%s")
VACLicensesupportExpirationDate=$(echo "$VACLicenseUrl" | jq --raw-output ".supportExpirationDate")
if [[ $VACLicensesupportExpirationDate = "null" ]] ; then
        VACLicensesupportExpirationDate=$VACLicenselicenseExpirationDate
fi
VACLicensesupportExpirationDateUnix=$(date -d "$VACLicensesupportExpirationDate" +"%s")
VACLicensesupportId=$(echo "$VACLicenseUrl" | jq --raw-output ".supportId")
VACLicensevmCount=$(echo "$VACLicenseUrl" | jq --raw-output ".vmCount")
VACLicenseworkstationCount=$(echo "$VACLicenseUrl" | jq --raw-output ".workstationCount")
VACLicenseserverCount=$(echo "$VACLicenseUrl" | jq --raw-output ".serverCount")
VACLicensecloudWorkstationCount=$(echo "$VACLicenseUrl" | jq --raw-output ".cloudWorkstationCount")
VACLicensecloudServerCount=$(echo "$VACLicenseUrl" | jq --raw-output ".cloudServerCount")
VACLicensecloudconnectBackupVmCount=$(echo "$VACLicenseUrl" | jq --raw-output ".cloudconnectBackupVmCount")
VACLicensecloudconnectBackupWorkstationCount=$(echo "$VACLicenseUrl" | jq --raw-output ".cloudconnectBackupWorkstationCount")
VACLicensecloudconnectBackupServerCount=$(echo "$VACLicenseUrl" | jq --raw-output ".cloudconnectBackupServerCount")
VACLicensecloudconnectReplicationVmCount=$(echo "$VACLicenseUrl" | jq --raw-output ".cloudconnectReplicationVmCount")
#echo "veeam_vac_vaclicense,productName=$VACLicenseproductName,licensedTo=$VACLicenselicensedTo,licenseType=$VACLicenselicenseType,licensesCount=$VACLicenselicensesCount,licensesUsedCount=$VACLicenselicensesUsedCount,supportID=$VACLicensesupportId,licenseExpirationDate=$VACLicenselicenseExpirationDate,supportExpirationDate=$VACLicensesupportExpirationDate licensevmCount=$VACLicensevmCount,licenseworkstationCount=$VACLicenseworkstationCount,licenseserverCount=$VACLicenseserverCount,licensecloudWorkstationCount=$VACLicensecloudWorkstationCount,licensecloudServerCount=$VACLicensecloudServerCount,licensecloudconnectBackupVmCount=$VACLicensecloudconnectBackupVmCount,cloudconnectBackupWorkstationCount=$VACLicensecloudconnectBackupWorkstationCount,cloudconnectBackupServerCount=$VACLicensecloudconnectBackupServerCount,cloudconnectReplicationVmCount=$VACLicensecloudconnectReplicationVmCount"
curl -i -XPOST "http://$InfluxDBURL:$InfluxDBPort/write?precision=s&db=$InfluxDB" --data-binary "veeam_vac_vaclicense,productName=$VACLicenseproductName,licensedTo=$VACLicenselicensedTo,licenseType=$VACLicenselicenseType,licensesCount=$VACLicenselicensesCount,licensesUsedCount=$VACLicenselicensesUsedCount,supportID=$VACLicensesupportId licenseExpirationDate=$VACLicenselicenseExpirationDateUnix,supportExpirationDate=$VACLicensesupportExpirationDateUnix,licensevmCount=$VACLicensevmCount,licenseworkstationCount=$VACLicenseworkstationCount,licenseserverCount=$VACLicenseserverCount,licensecloudWorkstationCount=$VACLicensecloudWorkstationCount,licensecloudServerCount=$VACLicensecloudServerCount,licensecloudconnectBackupVmCount=$VACLicensecloudconnectBackupVmCount,cloudconnectBackupWorkstationCount=$VACLicensecloudconnectBackupWorkstationCount,cloudconnectBackupServerCount=$VACLicensecloudconnectBackupServerCount,cloudconnectReplicationVmCount=$VACLicensecloudconnectReplicationVmCount"

# Veeam Backup & Replication Licensing
VACUrl="$RestServer:$RestPort/v2/licensing/backupserverLicenses"
TenantLicenseUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $Bearer" "$VACUrl" 2>&1 -k --silent)

declare -i arrayVBRLicense=0
for id in $(echo "$TenantLicenseUrl" | jq -r ".[].id"); do
    TenantLicenseEdition=$(echo "$TenantLicenseUrl" | jq --raw-output ".[$arrayVBRLicense].edition" | awk '{gsub(/ /,"\\ ");print}')
    TenantLicenseStatus=$(echo "$TenantLicenseUrl" | jq --raw-output ".[$arrayVBRLicense].status")
    TenantLicenseSupportID=$(echo "$TenantLicenseUrl" | jq --raw-output ".[$arrayVBRLicense].supportID")
    if [ "$TenantLicenseSupportID" == "" ];then
        declare -i TenantLicenseSupportID=0
    fi
    TenantLicenselicenseExpirationDate=$(echo "$TenantLicenseUrl" | jq --raw-output ".[$arrayVBRLicense].licenseExpirationDate")
    if [[ $TenantLicenselicenseExpirationDate = "null" ]] ; then
        TenantLicenselicenseExpirationDate=""
        TenantLicenselicenseExpirationDateUnix=$NoExpiration
    else
        TenantLicenselicenseExpirationDateUnix=$(date -d "$TenantLicenselicenseExpirationDate" +"%s")
    fi
    TenantLicensesupportExpirationDate=$(echo "$TenantLicenseUrl" | jq --raw-output ".[$arrayVBRLicense].supportExpirationDate")
    if [[ $TenantLicensesupportExpirationDate = "null" ]] ; then
        TenantLicensesupportExpirationDate=$TenantLicenselicenseExpirationDate
    fi
    TenantLicenselicenseExpirationDate=$(echo "$TenantLicenseUrl" | jq --raw-output ".[$arrayVBRLicense].licenseExpirationDate")
    TenantLicenselicenseExpirationDateUnix=$(date -d "$TenantLicenselicenseExpirationDate" +"%s")
    TenantLicensesupportExpirationDate=$(echo "$TenantLicenseUrl" | jq --raw-output ".[$arrayVBRLicense].supportExpirationDate")
    TenantLicensesupportExpirationDateUnix=$(date -d "$TenantLicensesupportExpirationDate" +"%s")
    TenantLicenselicensedSockets=$(echo "$TenantLicenseUrl" | jq --raw-output ".[$arrayVBRLicense].licensedSockets")
    TenantLicenseusedSockets=$(echo "$TenantLicenseUrl" | jq --raw-output ".[$arrayVBRLicense].usedSockets")
    TenantLicenselicensedVMs=$(echo "$TenantLicenseUrl" | jq --raw-output ".[$arrayVBRLicense].licensedVMs")
    TenantLicenseusedVMs=$(echo "$TenantLicenseUrl" | jq --raw-output ".[$arrayVBRLicense].usedVMs")
    TenantLicensebackupServerName=$(echo "$TenantLicenseUrl" | jq --raw-output ".[$arrayVBRLicense].backupServerName")
    TenantLicensecompanyName=$(echo "$TenantLicenseUrl" | jq --raw-output ".[$arrayVBRLicense].companyName" | awk '{gsub(/ /,"\\ ");print}')
    #echo "veeam_vac_vbrlicense,companyName=$TenantLicensecompanyName,edition=$TenantLicenseEdition,status=$TenantLicenseStatus,SupportID=$TenantLicenseSupportID,LicenseExpirationDate=$TenantLicenselicenseExpirationDate,SupportExpirationDate=$TenantLicensesupportExpirationDate,backupServerName=$TenantLicensebackupServerName licensedSockets=$TenantLicenselicensedSockets,usedSockets=$TenantLicenseusedSockets,licensedVMs=$TenantLicenselicensedVMs,usedVMs=$TenantLicenseusedVMs"
    curl -i -XPOST "http://$InfluxDBURL:$InfluxDBPort/write?precision=s&db=$InfluxDB" --data-binary "veeam_vac_vbrlicense,companyName=$TenantLicensecompanyName,edition=$TenantLicenseEdition,status=$TenantLicenseStatus,SupportID=$TenantLicenseSupportID,backupServerName=$TenantLicensebackupServerName licenseExpirationDate=$TenantLicenselicenseExpirationDateUnix,supportExpirationDate=$TenantLicensesupportExpirationDateUnix,licensedSockets=$TenantLicenselicensedSockets,usedSockets=$TenantLicenseusedSockets,licensedVMs=$TenantLicenselicensedVMs,usedVMs=$TenantLicenseusedVMs"
    arrayVBRLicense=$arrayVBRLicense+1
done

##
# Veeam Availability Backup Repositories per every Veeam Backup & Replication Server. This part will check the capacity and used space of the Backup Repositories
##
VACUrl="$RestServer:$RestPort/v2/backupRepositories"
BackupRepoLicenseUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $Bearer" "$VACUrl" 2>&1 -k --silent)

declare -i arrayVACRepo=0
for id in $(echo "$BackupRepoLicenseUrl" | jq -r ".[].id"); do
    BackupReponame=$(echo "$BackupRepoLicenseUrl" | jq --raw-output ".[$arrayVACRepo].name" | awk '{gsub(/ /,"\\ ");print}')
    BackupReposerverName=$(echo "$BackupRepoLicenseUrl" | jq --raw-output ".[$arrayVACRepo].serverName" | awk '{gsub(/ /,"\\ ");print}')
    BackupRepocompanyName=$(echo "$BackupRepoLicenseUrl" | jq --raw-output ".[$arrayVACRepo].companyName" | awk '{gsub(/ /,"\\ ");print}')
    BackupRepocapacity=$(echo "$BackupRepoLicenseUrl" | jq --raw-output ".[$arrayVACRepo].capacity")
    BackupRepocapacityUnits=$(echo "$BackupRepoLicenseUrl" | jq --raw-output ".[$arrayVACRepo].capacityUnits")
    case $BackupRepocapacityUnits in
        B)
            BackupRepocapacity=$(echo "scale=4; $BackupRepocapacity / 1048576" | bc -l)
        ;;
        KB)
            BackupRepocapacity=$(echo "scale=4; $BackupRepocapacity / 1024" | bc -l)
        ;;
        MB)
        ;;
        GB)
            BackupRepocapacity=$(echo "scale=4; $BackupRepocapacity * 1024" | bc -l)
        ;;
        TB)
            BackupRepocapacity=$(echo "scale=4; $BackupRepocapacity * 1048576" | bc -l)
        ;;
        esac
    BackupRepofreeSpace=$(echo "$BackupRepoLicenseUrl" | jq --raw-output ".[$arrayVACRepo].freeSpace")
    BackupRepofreeSpaceUnits=$(echo "$BackupRepoLicenseUrl" | jq --raw-output ".[$arrayVACRepo].freeSpaceUnits")
    case $BackupRepofreeSpaceUnits in
        B)
            BackupRepofreeSpace=$(echo "scale=4; $BackupRepofreeSpace / 1048576" | bc -l)
        ;;
        KB)
            BackupRepofreeSpace=$(echo "scale=4; $BackupRepofreeSpace / 1024" | bc -l)
        ;;
        MB)
        ;;
        GB)
            BackupRepofreeSpace=$(echo "scale=4; $BackupRepofreeSpace * 1024" | bc -l)
        ;;
        TB)
            BackupRepofreeSpace=$(echo "scale=4; $BackupRepofreeSpace * 1048576" | bc -l)
        ;;
        esac
    BackupRepobackupSize=$(echo "$BackupRepoLicenseUrl" | jq --raw-output ".[$arrayVACRepo].backupSize")
    BackupRepobackupSizeUnits=$(echo "$BackupRepoLicenseUrl" | jq --raw-output ".[$arrayVACRepo].backupSizeUnits")
    case $BackupRepobackupSizeUnits in
        B)
            BackupRepobackupSize=$(echo "scale=4; $BackupRepobackupSize / 1048576" | bc -l)
        ;;
        KB)
            BackupRepobackupSize=$(echo "scale=4; $BackupRepobackupSize / 1024" | bc -l)
        ;;
        MB)
        ;;
        GB)
            BackupRepobackupSize=$(echo "scale=4; $BackupRepobackupSize * 1024" | bc -l)
        ;;
        TB)
            BackupRepobackupSize=$(echo "scale=4; $BackupRepobackupSize * 1048576" | bc -l)
        ;;
        esac
    BackupRepobackuphealthstate=$(echo "$BackupRepoLicenseUrl" | jq --raw-output ".[$arrayVACRepo].healthState")
    #echo "veeam_vac_repositories,repoName=$BackupReponame,backupServerName=$BackupReposerverName capacity=$BackupRepocapacity,freeSpace=$BackupRepofreeSpace,backupsize=$BackupRepobackupSize"
    curl -i -XPOST "http://$InfluxDBURL:$InfluxDBPort/write?precision=s&db=$InfluxDB" --data-binary "veeam_vac_repositories,companyName=$BackupRepocompanyName,repoName=$BackupReponame,backupServerName=$BackupReposerverName capacity=$BackupRepocapacity,freeSpace=$BackupRepofreeSpace,backupsize=$BackupRepobackupSize"
    arrayVACRepo=$arrayVACRepo+1
done

##
# Veeam Availability Jobs per every Veeam Backup & Replication Server. This part will check the different Jobs, and the Job Sessions per every Job
##
VACUrl="$RestServer:$RestPort/v2/jobs"
veeamJobsUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $Bearer" "$VACUrl" 2>&1 -k --silent)

declare -i arrayJobs=0
for id in $(echo "$veeamJobsUrl" | jq -r '.[].id'); do
    nameJob=$(echo "$veeamJobsUrl" | jq --raw-output ".[$arrayJobs].name" | awk '{gsub(/ /,"\\ ");print}' | awk '{gsub(",","\\,");print}')
    idJob=$(echo "$veeamJobsUrl" | jq --raw-output ".[$arrayJobs].id")
    typeJob=$(echo "$veeamJobsUrl" | jq --raw-output ".[$arrayJobs].type" | awk '{gsub(/ /,"\\ ");print}')    
    lastRunJob=$(echo "$veeamJobsUrl" | jq --raw-output ".[$arrayJobs].lastRun")
    lastRunTimeUnix=$(date -d "$lastRunJob" +"%s")
    if [[ $lastRunTimeUnix < "0" ]]; then
            lastRunTimeUnix="1"
    fi
    totalDuration=$(echo "$veeamJobsUrl" | jq --raw-output ".[$arrayJobs].duration")
    status=$(echo "$veeamJobsUrl" | jq --raw-output ".[$arrayJobs].status")
    case $status in
        Success)
            jobStatus="1"
        ;;
        Warning)
            jobStatus="2"
        ;;
        Failed)
            jobStatus="3"
        ;;
        -)
            jobStatus="0"
        ;;
        esac
    processingRate=$(echo "$veeamJobsUrl" | jq --raw-output ".[$arrayJobs].processingRate")
    processingRateUnits=$(echo "$veeamJobsUrl" | jq --raw-output ".[$arrayJobs].processingRateUnits")
    case $processingRate in
        B/s)
            processingRate=$(echo "scale=4; $processingRate / 1048576" | bc -l)
        ;;
        KB/s)
            processingRate=$(echo "scale=4; $processingRate / 1024" | bc -l)
        ;;
        MB/s)
        ;;
        GB/s)
            processingRate=$(echo "scale=4; $processingRate * 1024" | bc -l)
        ;;
        TB/s)
            processingRate=$(echo "scale=4; $processingRate * 1048576" | bc -l)
        ;;
        esac    
    transferredData=$(echo "$veeamJobsUrl" | jq --raw-output ".[$arrayJobs].transferredData")
    transferredDataUnits=$(echo "$veeamJobsUrl" | jq --raw-output ".[$arrayJobs].transferredDataUnits")
    case $transferredData in
        B)
            transferredData=$(echo "scale=4; $transferredData / 1048576" | bc -l)
        ;;
        KB)
            transferredData=$(echo "scale=4; $transferredData / 1024" | bc -l)
        ;;
        MB)
        ;;
        GB)
            transferredData=$(echo "scale=4; $transferredData * 1024" | bc -l)
        ;;
        TB)
            transferredData=$(echo "scale=4; $transferredData * 1048576" | bc -l)
        ;;
        esac
    BackupReposerverName=$(echo "$veeamJobsUrl" | jq --raw-output ".[$arrayJobs].serverName")
    bottleneck=$(echo "$veeamJobsUrl" | jq --raw-output ".[$arrayJobs].bottleneck" | awk '{gsub(/ /,"\\ ");print}')
    isEnabled=$(echo "$veeamJobsUrl" | jq --raw-output ".[$arrayJobs].isEnabled")
    protectedVMs=$(echo "$veeamJobsUrl" | jq --raw-output ".[$arrayJobs].protectedVMs")
    #echo "veeam_vac_jobs,veeamjobname=$nameJob,backupServerName=$BackupReposerverName,bottleneck=$bottleneck,typeJob=$typeJob,isEnabled=$isEnabled totalDuration=$totalDuration,status=$jobStatus,processingRate=$processingRate,transferredData=$transferredData,protectedVMs=$protectedVMs $lastRunTimeUnix"
    curl -i -XPOST "http://$InfluxDBURL:$InfluxDBPort/write?precision=s&db=$InfluxDB" --data-binary "veeam_vac_jobs,veeamjobname=$nameJob,backupServerName=$BackupReposerverName,bottleneck=$bottleneck,typeJob=$typeJob,isEnabled=$isEnabled totalDuration=$totalDuration,status=$jobStatus,processingRate=$processingRate,transferredData=$transferredData,protectedVMs=$protectedVMs $lastRunTimeUnix"
    arrayJobs=$arrayJobs+1
done

##
# Logging off
##
#VACUrl="$RestServer:$RestPort/v2/accounts/logout"
#curl -X POST --header "Accept: application/json" --header "Authorization:Bearer $Bearer" "$VACUrl" -k --silent
