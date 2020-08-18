#!/bin/bash
##      .SYNOPSIS
##      Grafana Dashboard for Veeam Backup for Nutanix AHV - Using RestAPI to InfluxDB Script
## 
##      .DESCRIPTION
##      This Script will query the Veeam Backup for Nutanix AHV RestAPI and send the data directly to InfluxDB, which can be used to present it to Grafana. 
##      The Script and the Grafana Dashboard it is provided as it is, and bear in mind you can not open support Tickets regarding this project. It is a Community Project
##	
##      .Notes
##      NAME:  veeam_nutanixahv.sh
##      ORIGINAL NAME: veeam_nutanixahv.sh
##      LASTEDIT: 17/08/2020
##      VERSION: 1.0
##      KEYWORDS: Veeam, InfluxDB, Grafana, Nutanix
   
##      .Link
##      https://jorgedelacruz.es/
##      https://jorgedelacruz.uk/

##
# Configurations
##
# Endpoint URL for InfluxDB
veeamInfluxDBURL="http://YOURINFLUXSERVERIP" #Your InfluxDB Server, http://FQDN or https://FQDN if using SSL
veeamInfluxDBPort="8086" #Default Port
veeamInfluxDB="telegraf" #Default Database
veeamInfluxDBUser="USER" #User for Database
veeamInfluxDBPassword='PASSWORD' #Password for Database

# Endpoint URL for login action
veeamUsername="YOURUSER"
veeamPassword="YOURPASS"
veeamRestServer="https://YOURVEEAMAHVPROXY"
veeamRestPort="8100" #Default Port
veeamBearer=$(curl -X POST  -H "accept: application/json" -H "Content-Type: application/json-patch+json" -d "{ \"userName\": \"$veeamUsername\", \"password\": \"$veeamPassword\", \"longExpDate\": true, \"description\": \"string\", \"memberId\": \"string\", \"oem\": { \"@odata.id\": \"string\" }, \"@odata.context\": \"string\", \"@Copyright\": \"string\", \"@odata.type\": \"string\", \"name\": \"string\"}" "$veeamRestServer:$veeamRestPort/api/v1/Account/login" -k --silent | jq -r '.token' | awk '{print $2}')


#Veeam Backup for Nutanix AHV Information
veeamVANUrl="$veeamRestServer:$veeamRestPort/api/v1"
veeamDashboardUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVANUrl" 2>&1 -k --silent)

  veeamAHVBackupname=$(echo "$veeamDashboardUrl" | jq --raw-output ".name" | awk '{gsub(/ /,"\\ ");print}')  
  veeamAHVBackupbuild=$(echo "$veeamDashboardUrl" | jq --raw-output ".build" | awk '{print $1}')  
  veeamAHVBackupversion=$(echo "$veeamDashboardUrl" | jq --raw-output ".version")  
  veeamAHVBackupoperationMode=$(echo "$veeamDashboardUrl" | jq --raw-output ".operationMode")   
  veeamAHVBackupdescription=$(echo "$veeamDashboardUrl" | jq --raw-output ".description")
  
veeamVANUrl="$veeamRestServer:$veeamRestPort/api/v1/networksettings"
veeamDashboardUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVANUrl" 2>&1 -k --silent)  
  veeamAHVBackuphostname=$(echo "$veeamDashboardUrl" | jq --raw-output ".hostName" | awk '{gsub(/ /,"\\ ");print}') 
  veeamAHVBackupIP=$(echo "$veeamDashboardUrl" | jq --raw-output ".ipAddress")
  
  ##Un-comment the following echo for debugging
  #echo "veeam_nutanix_version,vanhostname=$veeamAHVBackuphostname,vanip=$veeamAHVBackupIP,vandescription=$veeamAHVBackupdescription,vanoperation=$veeamAHVBackupoperationMode,vanversion=$veeamAHVBackupversion,vanbuild=$veeamAHVBackupbuild,vanname=$veeamAHVBackupname"  
  
  ##Comment the Curl while debugging
  echo "Writing veeam_nutanix_version to InfluxDB"
  curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=s&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_nutanix_version,vanhostname=$veeamAHVBackuphostname,vanip=$veeamAHVBackupIP,vandescription=$veeamAHVBackupdescription,vanoperation=$veeamAHVBackupoperationMode,vanversion=$veeamAHVBackupversion,vanname=$veeamAHVBackupname vanbuild=$veeamAHVBackupbuild"

##
# Veeam Backup for Nutanix AHV Dashboard. This part will obtain the info from the Dashboard
##
veeamVANUrl="$veeamRestServer:$veeamRestPort/api/v1/Dashboard/protstatus"
veeamDashboardUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVANUrl" 2>&1 -k --silent)

  veeamAHVBackupServerId=$(echo "$veeamDashboardUrl" | jq --raw-output ".Id") 
  totalVMsCount=$(echo "$veeamDashboardUrl" | jq --raw-output ".totalVmsCount")  
  protectedVmsCount=$(echo "$veeamDashboardUrl" | jq --raw-output ".protectedVmsCount")  
  protectedVmsWithSnapshotsCount=$(echo "$veeamDashboardUrl" | jq --raw-output ".protectedVmsWithSnapshotsCount")  
  notProtectedVmsCount=$(echo "$veeamDashboardUrl" | jq --raw-output ".notProtectedVmsCount")
  
veeamVANUrl="$veeamRestServer:$veeamRestPort/api/v1/Dashboard/jobstatus"
veeamDashboardUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVANUrl" 2>&1 -k --silent)

  totalJobsCount=$(echo "$veeamDashboardUrl" | jq --raw-output ".totalJobsCount")  

veeamVANUrl="$veeamRestServer:$veeamRestPort/api/v1/Dashboard/repstatus"
veeamDashboardUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVANUrl" 2>&1 -k --silent)

  totalRepositoriesCount=$(echo "$veeamDashboardUrl" | jq --raw-output ".totalRepositoriesCount")   
  repositoriesOutOfSpaceCount=$(echo "$veeamDashboardUrl" | jq --raw-output ".repositoriesOutOfSpaceCount")  
  repositoriesLowOnSpaceCount=$(echo "$veeamDashboardUrl" | jq --raw-output ".repositoriesLowOnSpaceCount")     

veeamVANUrl="$veeamRestServer:$veeamRestPort/api/v1/Dashboard/backupserverstatus"
veeamDashboardUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVANUrl" 2>&1 -k --silent)

  backupServerAvaliability=$(echo "$veeamDashboardUrl" | jq --raw-output ".backupServerAvaliability")
  case $backupServerAvaliability in
    "Available")
        backupavailable="1"
    ;;
    "Not Available")
        backupavailable="2"
    ;;
    esac
   
veeamVANUrl="$veeamRestServer:$veeamRestPort/api/v1/Dashboard/clusterstatus"
veeamDashboardUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVANUrl" 2>&1 -k --silent)

  clusterAvaliability=$(echo "$veeamDashboardUrl" | jq --raw-output ".clusterAvaliability") 
    case $clusterAvaliability in
    "Available")
        clusteravailable="1"
    ;;
    "Not Available")
        clusteravailable="2"
    ;;
    esac
  
    ##Un-comment the following echo for debugging
    #echo "veeam_nutanix_dashboard,veeamahvId=$veeamAHVBackupServerId totalVMsCount=$totalVMsCount,protectedVmsCount=$protectedVmsCount,protectedVmsWithSnapshotsCount=$protectedVmsWithSnapshotsCount,notProtectedVmsCount=$notProtectedVmsCount,totalJobsCount=$totalJobsCount,totalRepositoriesCount=$totalRepositoriesCount,repositoriesOutOfSpaceCount=$repositoriesOutOfSpaceCount,repositoriesLowOnSpaceCount=$repositoriesLowOnSpaceCount,backupServerAvaliability=$backupServerAvaliability,clusterAvaliability=$clusterAvaliability"

    ##Comment the Curl while debugging
    echo "Writing veeam_nutanix_dashboard to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=s&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_nutanix_dashboard,veeamahvId=$veeamAHVBackupServerId totalVMsCount=$totalVMsCount,protectedVmsCount=$protectedVmsCount,protectedVmsWithSnapshotsCount=$protectedVmsWithSnapshotsCount,notProtectedVmsCount=$notProtectedVmsCount,totalJobsCount=$totalJobsCount,totalRepositoriesCount=$totalRepositoriesCount,repositoriesOutOfSpaceCount=$repositoriesOutOfSpaceCount,repositoriesLowOnSpaceCount=$repositoriesLowOnSpaceCount,backupServerAvaliability=$backupavailable,clusterAvaliability=$clusteravailable"


##
# Veeam Backup for Nutanix AHV Policies. This part will check all the sessions 
##
veeamVANUrl="$veeamRestServer:$veeamRestPort/api/v1/Sync/policySessions"
veeamBackupUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVANUrl" 2>&1 -k --silent)

declare -i arraysessions=0

for id in $(echo "$veeamBackupUrl" | jq -r '.[].policyId'); do
    veeamPolicyId=$(echo "$veeamBackupUrl" | jq --raw-output ".[$arraysessions].policyId")    
    veeamPolicyName=$(echo "$veeamBackupUrl" | jq --raw-output ".[$arraysessions].policyName" | awk '{gsub(/ /,"\\ ");print}')
    veeamPolicyResult=$(echo "$veeamBackupUrl" | jq --raw-output ".[$arraysessions].result")
        case $veeamPolicyResult in
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
    veeamPolicyBytesSecond=$(echo "$veeamBackupUrl" | jq --raw-output ".[$arraysessions].processingRateBytesPerSecond")    
    veeamPolicyTransferred=$(echo "$veeamBackupUrl" | jq --raw-output ".[$arraysessions].transferredDataBytes")    
    veeamPolicyProcessed=$(echo "$veeamBackupUrl" | jq --raw-output ".[$arraysessions].processedDataBytes")    
    veeamPolicyRead=$(echo "$veeamBackupUrl" | jq --raw-output ".[$arraysessions].readDataBytes")    
    veeamPolicyStart=$(echo "$veeamBackupUrl" | jq --raw-output ".[$arraysessions].startTimeUtc")
    creationTimeUnix=$(date -d "$veeamPolicyStart" +"%s")
    veeamPolicyEnd=$(echo "$veeamBackupUrl" | jq --raw-output ".[$arraysessions].endTimeUtc")
    endTimeUnix=$(date -d "$veeamPolicyEnd" +"%s")
    veeamPolicyDuration=$(($endTimeUnix-$creationTimeUnix))

    ##Un-comment the following echo for debugging
    #echo "veeam_nutanix_sessions,policyname=$veeamPolicyName bytessecond=$veeamPolicyBytesSecond,bytestransferred=$veeamPolicyTransferred,bytesprocessed=$veeamPolicyProcessed,bytesread=$veeamPolicyRead,duration=$veeamPolicyDuration $creationTimeUnix"

    ##Comment the Curl while debugging
    echo "Writing veeam_nutanix_sessions to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=s&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_nutanix_sessions,policyname=$veeamPolicyName veeamBackupSessionsJobResult=$jobStatus,bytessecond=$veeamPolicyBytesSecond,bytestransferred=$veeamPolicyTransferred,bytesprocessed=$veeamPolicyProcessed,bytesread=$veeamPolicyRead,duration=$veeamPolicyDuration $creationTimeUnix"

    arraysessions=$arraysessions+1   
done


##
# Veeam Backup for Nutanix AHV per VM. Overview of the VM. Really useful to display if a VM it is protected or not
##
veeamVANUrl="$veeamRestServer:$veeamRestPort/api/v1/Vms"
veeamBackupUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVANUrl" 2>&1 -k --silent)

declare -i arrayvms=0

for id in $(echo "$veeamBackupUrl" | jq -r '.Members[]."@odata.id"'); do
    veeamVMId=$(echo "$veeamBackupUrl" | jq -r '.Members['$arrayvms']."@odata.id"' | awk -F/ '{print $5}')
    
    veeamVANUrl="$veeamRestServer:$veeamRestPort/api/v1/Vms/$veeamVMId"
    veeamVMUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVANUrl" 2>&1 -k --silent)
    
    veeamVMName=$(echo "$veeamVMUrl" | jq -r '.name' | awk '{gsub(/ /,"\\ ");print}')
    veeamVMSnapshots=$(echo "$veeamVMUrl" | jq -r ".snapshots")     
    veeamVMBackups=$(echo "$veeamVMUrl" | jq -r ".backups")    
    veeamVMCluster=$(echo "$veeamVMUrl" | jq -r ".clusterName")     
    veeamVMLastProtection=$(echo "$veeamVMUrl" | jq -r ".lastProtection")
    lastprotectionUnix=$(date -d "$veeamVMLastProtection" +"%s")
   
   ##Un-comment the following echo for debugging
   #echo "veeam_nutanix_vms,vmname=$veeamVMName,vmcluster=$veeamVMCluster vmsnapshots=$veeamVMSnapshots,vmbackups=$veeamVMBackups $lastprotectionUnix"

    ##Comment the Curl while debugging
    echo "Writing veeam_nutanix_vms to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=s&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_nutanix_vms,vmname=$veeamVMName,vmcluster=$veeamVMCluster vmsnapshots=$veeamVMSnapshots,vmbackups=$veeamVMBackups $lastprotectionUnix"

    arrayvms=$arrayvms+1   
done    


##
# Veeam Backup for Nutanix AHV Veeam Backup Server. This part will check the Veeam Backup Server
##
veeamVANUrl="$veeamRestServer:$veeamRestPort/api/v1/BackupServers"
veeamBackupUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVANUrl" 2>&1 -k --silent)

declare -i arraybackupserver=0

for id in $(echo "$veeamBackupUrl" | jq -r '.[].id'); do
    veeamBackupServerId=$(echo "$veeamBackupUrl" | jq --raw-output ".[$arraybackupserver].Id")
    veeamBackupServerPort=$(echo "$veeamBackupUrl" | jq --raw-output ".[$arraybackupserver].port")
    veeamBackupServerStatus=$(echo "$veeamBackupUrl" | jq --raw-output ".[$arraybackupserver].status")
    veeamBackupServerVersion=$(echo "$veeamBackupUrl" | jq --raw-output ".[$arraybackupserver].version")
    veeamBackupServerDescription=$(echo "$veeamBackupUrl" | jq --raw-output ".[$arraybackupserver].description" | awk '{gsub(/ /,"\\ ");print}')
    
    ##Un-comment the following echo for debugging
    #echo "veeam_nutanix_server,ServerId=$veeamBackupServerId,ServerStatus=$veeamBackupServerStatus,ServerVersion=$veeamBackupServerVersion,ServerDescription=$veeamBackupServerDescription ServerPort=$veeamBackupServerPort"
    
    ##Comment the Curl while debugging
    echo "Writing veeam_nutanix_server to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=s&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_nutanix_server,ServerId=$veeamBackupServerId,ServerStatus=$veeamBackupServerStatus,ServerVersion=$veeamBackupServerVersion,ServerDescription=$veeamBackupServerDescription ServerPort=$veeamBackupServerPort"
    
    ## Veeam Backup for Nutanix AHV Repositories
    veeamVANUrl="$veeamRestServer:$veeamRestPort/api/v1/BackupServers/$veeamBackupServerId/repositories"
    veeamRepositoriesUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVANUrl" 2>&1 -k --silent)

    declare -i arrayvanrepo=0
    for id in $(echo "$veeamRepositoriesUrl" | jq -r '.Members[]."@odata.id"'); do
    veeamRepoId=$(echo "$veeamRepositoriesUrl" | jq -r '.Members['$arrayvanrepo']."@odata.id"' | awk -F/ '{print $3}')

    veeamVANRepoUrl="$veeamRestServer:$veeamRestPort/api/v1/BackupServers/$veeamBackupServerId/repositories/$veeamRepoId"
    veeamRepositoryUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVANRepoUrl" 2>&1 -k --silent)
 
    veeamRepoName=$(echo "$veeamRepositoryUrl" | jq --raw-output ".name" | awk '{gsub(/ /,"\\ ");print}')
    veeamRepoFreeSpace=$(echo "$veeamRepositoryUrl" | jq --raw-output ".freeSpace")
    veeamRepoTotalSpace=$(echo "$veeamRepositoryUrl" | jq --raw-output ".totalSpace")
    
    ##Un-comment the following echo for debugging
    #echo "veeam_nutanix_repository,repoName=$veeamRepoName,repoID=$veeamRepoId repoFreeSpace=$veeamRepoFreeSpace,repoTotalSpace=$veeamRepoTotalSpace"
    
    ##Comment the Curl while debugging
    echo "Writing veeam_nutanix_repository to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=s&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_nutanix_repository,repoName=$veeamRepoName,repoID=$veeamRepoId repoFreeSpace=$veeamRepoFreeSpace,repoTotalSpace=$veeamRepoTotalSpace"
    
    arrayvanrepo=$arrayvanrepo+1
    done

    arraybackupserver=$arraybackupserver+1   
done
    

##
# Veeam Backup for Nutanix AHV Storage Containers. This part will check the Nutanix Cluster Storage Containers
##
veeamVANUrl="$veeamRestServer:$veeamRestPort/api/v1/Vms/storagecontainers"
veeamBackupUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVANUrl" 2>&1 -k --silent)

declare -i arrayahvcontainers=0

for id in $(echo "$veeamBackupUrl" | jq -r '.[].Id'); do
    veeamContainerName=$(echo "$veeamBackupUrl" | jq --raw-output ".[$arrayahvcontainers].name")    
    veeamContainerMaxCapacity=$(echo "$veeamBackupUrl" | jq --raw-output ".[$arrayahvcontainers].maxCapacity")    
    veeamContainerReservedCapacity=$(echo "$veeamBackupUrl" | jq --raw-output ".[$arrayahvcontainers].reservedCapacity")    
    veeamContainerUsedSpace=$(echo "$veeamBackupUrl" | jq --raw-output ".[$arrayahvcontainers].usedSpace")
    
    ##Un-comment the following echo for debugging
    #echo "veeam_nutanix_container,containername=$veeamContainerName containercapacity=$veeamContainerMaxCapacity,containerreserved=$veeamContainerReservedCapacity,containerused=$veeamContainerUsedSpace"
   
    ##Comment the Curl while debugging
    echo "Writing veeam_nutanix_repository to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=s&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_nutanix_container,containername=$veeamContainerName containercapacity=$veeamContainerMaxCapacity,containerreserved=$veeamContainerReservedCapacity,containerused=$veeamContainerUsedSpace"
    
    arrayahvcontainers=$arrayahvcontainers+1   
done   
