#!/bin/bash
##      .SYNOPSIS
##      Grafana Dashboard for Veeam Backup for Microsoft Office 365 v3.0 - Using RestAPI to InfluxDB Script
## 
##      .DESCRIPTION
##      This Script will query the Veeam Backup for Microsoft Office 365 RestAPI and send the data directly to InfluxDB, which can be used to present it to Grafana. 
##      The Script and the Grafana Dashboard it is provided as it is, and bear in mind you can not open support Tickets regarding this project. It is a Community Project
##	
##      .Notes
##      NAME:  veeam_office365v3.sh
##      ORIGINAL NAME: veeam_office365v3.sh
##      LASTEDIT: 05/04/2019
##      VERSION: 1.0
##      KEYWORDS: Veeam, InfluxDB, Grafana
   
##      .Link
##      https://jorgedelacruz.es/
##      https://jorgedelacruz.uk/

##
# Configurations
##
# Endpoint URL for InfluxDB
veeamInfluxDBURL="YOURINFLUXSERVERIP"
veeamInfluxDBPort="8086" #Default Port
veeamInfluxDB="telegraf" #Default Database
veeamInfluxDBUser="USER" #User for Database
veeamInfluxDBPassword="PASSWORD" #Password for Database

# Endpoint URL for login action
veeamUsername="YOURVBOUSER"
veeamPassword="YOURVBOPASSWORD"
veeamRestServer="https://YOURVBOSERVERIP"
veeamRestPort="4443" #Default Port
veeamBearer=$(curl -X POST --header "Content-Type: application/x-www-form-urlencoded" --header "Accept: application/json" -d "grant_type=password&username=$veeamUsername&password=$veeamPassword&refresh_token=%27%27" "$veeamRestServer:$veeamRestPort/v3/token" -k --silent | jq -r '.access_token')

##
# Veeam Backup for Microsoft Office 365 Organization. This part will check on our Organization and retrieve Licensing Information
##
veeamVBOUrl="$veeamRestServer:$veeamRestPort/v3/Organizations"
veeamOrgUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVBOUrl" 2>&1 -k --silent)

declare -i arrayorg=0
for id in $(echo "$veeamOrgUrl" | jq -r '.[].id'); do
    veeamOrgId=$(echo "$veeamOrgUrl" | jq --raw-output ".[$arrayorg].id")
    veeamOrgName=$(echo "$veeamOrgUrl" | jq --raw-output ".[$arrayorg].name")

    ## Licensing
    veeamVBOUrl="$veeamRestServer:$veeamRestPort/v3/Organizations/$veeamOrgId/LicensingInformation"
    veeamLicenseUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVBOUrl" 2>&1 -k --silent)
    licensedUsers=$(echo "$veeamLicenseUrl" | jq --raw-output '.licensedUsers')
    newUsers=$(echo "$veeamLicenseUrl" | jq --raw-output '.newUsers')
    
    #echo "veeam_office365_organization,veeamOrgName=$veeamOrgName licensedUsers=$licensedUsers,newUsers=$newUsers"
    curl -i -XPOST "http://$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=ms&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_office365_organization,veeamOrgName=$veeamOrgName licensedUsers=$licensedUsers,newUsers=$newUsers"
    arrayorg=$arrayorg+1
done
 

##
# Veeam Backup for Microsoft Office 365 Backup Repositories. This part will check the capacity and used space of the Backup Repositories
##
veeamVBOUrl="$veeamRestServer:$veeamRestPort/v3/BackupRepositories"
veeamRepoUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVBOUrl" 2>&1 -k --silent)

declare -i arrayrepo=0
for id in $(echo "$veeamRepoUrl" | jq -r '.[].id'); do
  repository=$(echo "$veeamRepoUrl" | jq --raw-output ".[$arrayrepo].name" | awk '{gsub(/ /,"\\ ");print}')
  capacity=$(echo "$veeamRepoUrl" | jq --raw-output ".[$arrayrepo].capacityBytes")
  freeSpace=$(echo "$veeamRepoUrl" | jq --raw-output ".[$arrayrepo].freeSpaceBytes")
  
  #echo "veeam_office365_repository,repository=$repository capacity=$capacity,freeSpace=$freeSpace"
  curl -i -XPOST "http://$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=ms&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_office365_repository,repository=$repository capacity=$capacity,freeSpace=$freeSpace"
  arrayrepo=$arrayrepo+1
done

##
# Veeam Backup for Microsoft Office 365 Backup Proxies. This part will check the Name and Threads Number of the Backup Proxies
##
veeamVBOUrl="$veeamRestServer:$veeamRestPort/v3/Proxies"
veeamProxyUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVBOUrl" 2>&1 -k --silent)

declare -i arrayprox=0
for id in $(echo "$veeamProxyUrl" | jq -r '.[].id'); do
    hostName=$(echo "$veeamProxyUrl" | jq --raw-output ".[$arrayprox].hostName" | awk '{gsub(/ /,"\\ ");print}')
    threadsNumber=$(echo "$veeamProxyUrl" | jq --raw-output ".[$arrayprox].threadsNumber")
    status=$(echo "$veeamProxyUrl" | jq --raw-output ".[$arrayprox].status")
    
    #echo "veeam_office365_proxies,proxies=$hostName,status=$status threadsNumber=$threadsNumber"
    curl -i -XPOST "http://$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=ms&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_office365_proxies,proxies=$hostName,status=$status threadsNumber=$threadsNumber"
    arrayprox=$arrayprox+1
done

##
# Veeam Backup for Microsoft Office 365 Backup Jobs. This part will check the different Jobs, and the Job Sessions per every Job
##
veeamVBOUrl="$veeamRestServer:$veeamRestPort/v3/Jobs"
veeamJobsUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVBOUrl" 2>&1 -k --silent)

declare -i arrayJobs=0
for id in $(echo "$veeamJobsUrl" | jq -r '.[].id'); do
    nameJob=$(echo "$veeamJobsUrl" | jq --raw-output ".[$arrayJobs].name" | awk '{gsub(/ /,"\\ ");print}')
    idJob=$(echo "$veeamJobsUrl" | jq --raw-output ".[$arrayJobs].id")
    
    # Backup Job Sessions
    veeamVBOUrl="$veeamRestServer:$veeamRestPort/v3/Jobs/$idJob/jobsessions"
    veeamJobSessionsUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVBOUrl" 2>&1 -k --silent)
    declare -i arrayJobsSessions=0
    for id in $(echo "$veeamJobSessionsUrl" | jq -r '.[].id'); do
      creationTime=$(echo "$veeamJobSessionsUrl" | jq --raw-output ".[$arrayJobsSessions].creationTime")
      creationTimeUnix=$(date -d "$creationTime" +"%s")
      endTime=$(echo "$veeamJobSessionsUrl" | jq --raw-output ".[$arrayJobsSessions].endTime")
      endTimeUnix=$(date -d "$endTime" +"%s")
      totalDuration=$(($endTimeUnix - $creationTimeUnix))
      status=$(echo "$veeamJobSessionsUrl" | jq --raw-output ".[$arrayJobsSessions].status")
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
        esac
      processingRate=$(echo "$veeamJobSessionsUrl" | jq --raw-output ".[$arrayJobsSessions].statistics.processingRateBytesPS")
      readRate=$(echo "$veeamJobSessionsUrl" | jq --raw-output ".[$arrayJobsSessions].statistics.readRateBytesPS")
      writeRate=$(echo "$veeamJobSessionsUrl" | jq --raw-output ".[$arrayJobsSessions].statistics.writeRateBytesPS")
      transferredData=$(echo "$veeamJobSessionsUrl" | jq --raw-output ".[$arrayJobsSessions].statistics.transferredDataBytes")
      processedObjects=$(echo "$veeamJobSessionsUrl" | jq --raw-output ".[$arrayJobsSessions].statistics.processedObjects")
      bottleneck=$(echo "$veeamJobSessionsUrl" | jq --raw-output ".[$arrayJobsSessions].statistics.bottleneck")
      
      #echo "veeam_office365_jobs,veeamjobname=$nameJob,bottleneck=$bottleneck totalDuration=$totalDuration,status=$jobStatus,processingRate=$processingRate,readRate=$readRate,writeRate=$writeRate,transferredData=$transferredData,processedObjects=$processedObjects $endTimeUnix"
      curl -i -XPOST "http://$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=s&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_office365_jobs,veeamjobname=$nameJob,bottleneck=$bottleneck totalDuration=$totalDuration,status=$jobStatus,processingRate=$processingRate,readRate=$readRate,writeRate=$writeRate,transferredData=$transferredData,processedObjects=$processedObjects $endTimeUnix"
    if [[ $arrayJobsSessions = "1000" ]]; then
        break
        else
            arrayJobsSessions=$arrayJobsSessions+1
    fi
    done
    arrayJobs=$arrayJobs+1
done

##
# Veeam Backup for Microsoft Office 365 Restore Sessions. This part will check the Number of Restore Sessions
##
veeamVBOUrl="$veeamRestServer:$veeamRestPort/v3/RestoreSessions"
veeamRestoreSessionsUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVBOUrl" 2>&1 -k --silent)

declare -i arrayRestoreSessions=0
for id in $(echo "$veeamRestoreSessionsUrl" | jq -r '.results[].id'); do
    name=$(echo "$veeamRestoreSessionsUrl" | jq --raw-output ".results[$arrayRestoreSessions].name" | awk '{gsub(/ /,"\\ ");print}')
    nameJob=$(echo $name | awk -v FS="[()]" '{print $1}')
    organization=$(echo "$veeamRestoreSessionsUrl" | jq --raw-output ".results[$arrayRestoreSessions].organization" | awk '{gsub(/ /,"\\ ");print}') 
    type=$(echo "$veeamRestoreSessionsUrl" | jq --raw-output ".results[$arrayRestoreSessions].type")
    endTime=$(echo "$veeamRestoreSessionsUrl" | jq --raw-output ".results[$arrayRestoreSessions].endTime")
    endTimeUnix=$(date -d "$endTime" +"%s")
    result=$(echo "$veeamRestoreSessionsUrl" | jq --raw-output ".results[$arrayRestoreSessions].result")
    initiatedBy=$(echo "$veeamRestoreSessionsUrl" | jq --raw-output ".results[$arrayRestoreSessions].initiatedBy")
    details=$(echo "$veeamRestoreSessionsUrl" | jq --raw-output ".results[$arrayRestoreSessions].details")
    itemsProcessed=$(echo $details | awk '//{ print $1 }')
    [[ ! -z "$itemsProcessed" ]] || itemsProcessed="0"
    itemsSuccess=$(echo $details | awk '//{ print $4 }' | awk '{gsub(/\(|\)/,"");print $1}')
    [[ ! -z "$itemsSuccess" ]] || itemsSuccess="0"
    
    #echo "veeam_office365_restoresession,organization=$organization,veeamjobname=$nameJob,type=$type,result=$result,initiatedBy=$initiatedBy itemsProcessed=$itemsProcessed,itemsSuccess=$itemsSuccess $endTimeUnix"
    curl -i -XPOST "http://$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=s&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_office365_restoresession,organization=$organization,veeamjobname=$nameJob,type=$type,result=$result,initiatedBy=$initiatedBy itemsProcessed=$itemsProcessed,itemsSuccess=$itemsSuccess $endTimeUnix"
    arrayRestoreSessions=$arrayRestoreSessions+1
done