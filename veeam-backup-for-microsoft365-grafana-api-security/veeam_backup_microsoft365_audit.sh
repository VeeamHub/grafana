#!/bin/bash
##      .SYNOPSIS
##      Grafana Dashboard to recover Restore Sessions from Veeam Backup for Microsoft 365 v6.0 - Using RestAPI to InfluxDB Script
## 
##      .DESCRIPTION
##      This Script will query the Veeam Backup for Microsoft 365 RestAPI and send the data directly to InfluxDB, which can be used to present it to Grafana. 
##      The Script and the Grafana Dashboard it is provided as it is, and bear in mind you can not open support Tickets regarding this project. It is a Community Project
##	
##      .Notes
##      NAME:  veeam_backup_microsoft365_audit.sh
##      ORIGINAL veeam_backup_microsoft365_audit.sh
##      LASTEDIT: 03/05/2022
##      VERSION: 6.0
##      KEYWORDS: Veeam, InfluxDB, Grafana
   
##      .Link
##      https://jorgedelacruz.es/
##      https://jorgedelacruz.uk/

##
# Configurations
##
# System Variables
auditdays="7" #The number of days you want the Audit to look back (default last 7 days)
timestart=$(date --date="-$auditdays days" +%FT%TZ)

# Endpoint URL for InfluxDB
veeamInfluxDBURL="http://YOURINFLUXSERVERIP" #Your InfluxDB Server, http://FQDN or https://FQDN if using SSL
veeamInfluxDBPort="8086" #Default Port
veeamInfluxDBBucket="veeam" # InfluxDB bucket name (not ID)
veeamInfluxDBToken="TOKEN" # InfluxDB access token with read/write privileges for the bucket
veeamInfluxDBOrg="ORG NAME" # InfluxDB organisation name (not ID)

# Endpoint URL for login action
veeamUsername="YOURVBOUSER"
veeamPassword="YOURVBOPASSWORD"
veeamRestServer="https://YOURVBOSERVERIP"
veeamRestPort="4443" #Default Port
veeamBearer=$(curl -X POST --header "Content-Type: application/x-www-form-urlencoded" --header "Accept: application/json" \
-d "grant_type=password&username=$veeamUsername&password=$veeamPassword&refresh_token=%27%27" \
"$veeamRestServer:$veeamRestPort/v6/token" -k --silent | jq -r '.access_token')

##
# Veeam Backup for Microsoft 365 Version. This part will check the Veeam Backup for Microsoft 365 version
##
veeamVBOUrl="$veeamRestServer:$veeamRestPort/v6/ServiceInstance"
veeamVersionUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVBOUrl" 2>&1 -k --silent)
    
    veeamVersion=$(echo "$veeamVersionUrl" | jq --raw-output ".version")
    #echo "veeam_office365_version,veeamVersion=$veeamVersion,veeamServer=$veeamRestServer v=1"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_office365_version,veeamVersion=$veeamVersion,veeamServer=$veeamRestServer v=1"

##
# Veeam Backup for Microsoft 365 Organization. This part will check on our Organization and retrieve Licensing Information
##
veeamVBOUrl="$veeamRestServer:$veeamRestPort/v6/Organizations"
veeamOrgUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVBOUrl" 2>&1 -k --silent)

declare -i arrayorg=0
for id in $(echo "$veeamOrgUrl" | jq -r '.[].id'); do
    veeamOrgId=$(echo "$veeamOrgUrl" | jq --raw-output ".[$arrayorg].id")
    veeamOrgName=$(echo "$veeamOrgUrl" | jq --raw-output ".[$arrayorg].name" | awk '{gsub(/ /,"\\ ");print}')

    ## Licensing
    veeamVBOUrl="$veeamRestServer:$veeamRestPort/v6/Organizations/$veeamOrgId/LicensingInformation"
    veeamLicenseUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVBOUrl" 2>&1 -k --silent)
    licensedUsers=$(echo "$veeamLicenseUrl" | jq --raw-output '.licensedUsers')
    newUsers=$(echo "$veeamLicenseUrl" | jq --raw-output '.newUsers')
    
    #echo "veeam_office365_organization,veeamOrgName=$veeamOrgName licensedUsers=$licensedUsers,newUsers=$newUsers"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" \
    -H "Authorization: Token $veeamInfluxDBToken" \
    --data-binary "veeam_office365_organization,veeamOrgName=$veeamOrgName licensedUsers=$licensedUsers,newUsers=$newUsers"
    
    arrayorg=$arrayorg+1
done
 

##
# Veeam Backup for Microsoft 365 Restore Sessions - This part is going to check the last 24 hours restore sessions and add them to InfluxDB (omits duplicates by default)
##
veeamVBOUrl="$veeamRestServer:$veeamRestPort/v6/RestoreSessions?startTimeFrom=$timestart"
veeamRestoreSessionUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVBOUrl" 2>&1 -k --silent)

declare -i arrayRestoreSessions=0
for id in $(echo "$veeamRestoreSessionUrl" | jq -r '.results[].id'); do
    restoreSessionID=$(echo "$veeamRestoreSessionUrl" | jq --raw-output ".results[$arrayRestoreSessions].id")
    restoreSessionName=$(echo "$veeamRestoreSessionUrl" | jq --raw-output ".results[$arrayRestoreSessions].name" | awk '{gsub(/ /,"\\ ");print}'| awk '{gsub(/,/,"\\ ");print}'| awk '{gsub(/=/,"\\ ");print}')
    restoreSessionOrganization=$(echo "$veeamRestoreSessionUrl" | jq --raw-output ".results[$arrayRestoreSessions].organization")
    restoreSessionType=$(echo "$veeamRestoreSessionUrl" | jq --raw-output ".results[$arrayRestoreSessions].type")
    restoreSessionStartTime=$(echo "$veeamRestoreSessionUrl" | jq --raw-output ".results[$arrayRestoreSessions].creationTime")
    restoreSessionStopTime=$(echo "$veeamRestoreSessionUrl" | jq --raw-output ".results[$arrayRestoreSessions].endTime")
    startTimeUnix=$(date -d "$restoreSessionStartTime" +"%s")
    restoreSessionState=$(echo "$veeamRestoreSessionUrl" | jq --raw-output ".results[$arrayRestoreSessions].state")
    restoreSessionResult=$(echo "$veeamRestoreSessionUrl" | jq --raw-output ".results[$arrayRestoreSessions].result")
      case $restoreSessionResult in
        Success)
            rs_result="1"
        ;;
        Warning)
            rs_result="2"
        ;;
        Failed)
            rs_result="3"
        ;;
        esac
    restoreSessionInitiatedby=$(echo "$veeamRestoreSessionUrl" | jq --raw-output ".results[$arrayRestoreSessions].initiatedBy")
    restoreSessionDetails=$(echo "$veeamRestoreSessionUrl" | jq --raw-output ".results[$arrayRestoreSessions].details" | awk '{gsub(/ /,"\\ ");print}'| awk '{gsub(/,/,"\\ ");print}'| awk '{gsub(/=/,"\\ ");print}')
    restoreSessionScopeName=$(echo "$veeamRestoreSessionUrl" | jq --raw-output ".results[$arrayRestoreSessions].scopeName")
    [[ ! -z "$restoreSessionScopeName" ]] || restoreSessionScopeName="$restoreSessionInitiatedby"
    restoreSessionClientHost=$(echo "$veeamRestoreSessionUrl" | jq --raw-output ".results[$arrayRestoreSessions].clientHost" | awk 'match($0,/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/){print substr($0,RSTART,RLENGTH)}')
    restoreSessionReason=$(echo "$veeamRestoreSessionUrl" | jq --raw-output ".results[$arrayRestoreSessions].reason" | awk '{gsub(/ /,"\\ ");print}'| awk '{gsub(/,/,"\\ ");print}'| awk '{gsub(/=/,"\\ ");print}')
  
    #echo "veeam_microsoft365_audit,vb365_restoresession_id=$restoreSessionID,vb365_organization=$restoreSessionOrganization,vb365_restoresession_name=$restoreSessionName,vb365_restoresession_type=$restoreSessionType,vb365_restoresession_state=$restoreSessionState,vb365_restoresession_initiatedby=$restoreSessionInitiatedby,vb365_restoresession_details=$restoreSessionDetails,vb365_restoresession_scope=$restoreSessionScopeName,vb365_restoresession_clienthost=$restoreSessionClientHost,vb365_restoresession_reason=$restoreSessionReason vb365_restoresession_result=$rs_result $endTimeUnix"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" \
    -H "Authorization: Token $veeamInfluxDBToken" \
    --data-binary "veeam_m365_auditrestore,vb365_restoresession_id=$restoreSessionID,vb365_organization=$restoreSessionOrganization,vb365_restoresession_name=$restoreSessionName,vb365_restoresession_type=$restoreSessionType,vb365_restoresession_state=$restoreSessionState,vb365_restoresession_initiatedby=$restoreSessionInitiatedby,vb365_restoresession_details=$restoreSessionDetails,vb365_restoresession_scope=$restoreSessionScopeName,vb365_restoresession_clienthost=$restoreSessionClientHost,vb365_restoresession_reason=$restoreSessionReason vb365_restoresession_result=$rs_result $startTimeUnix"
    
    ##
    # Veeam Backup for Microsoft 365 Restore Sessions Events - This part is going to check the details per every restore session
    ##
    veeamRestoreEventsUrl="$veeamRestServer:$veeamRestPort/v6/RestoreSessions/$restoreSessionID/Events?offset=0"
    veeamRestoreSessionEventUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamRestoreEventsUrl" 2>&1 -k --silent)

    declare -i arrayRestoreEventsSessions=0
    for id in $(echo "$veeamRestoreSessionEventUrl" | jq -r '.results[].id'); do
        
        restoreeventSessionType=$(echo "$veeamRestoreSessionEventUrl" | jq --raw-output ".results[$arrayRestoreEventsSessions].type")
        if [[ "$restoreeventSessionType" != "None" ]]; then
            restoreeventSessionID=$(echo "$veeamRestoreSessionEventUrl" | jq --raw-output ".results[$arrayRestoreEventsSessions].id")
            restoreeventSessionitemName=$(echo "$veeamRestoreSessionEventUrl" | jq --raw-output ".results[$arrayRestoreEventsSessions].itemName")
            restoreeventSessionitemType=$(echo "$veeamRestoreSessionEventUrl" | jq --raw-output ".results[$arrayRestoreEventsSessions].itemType")
            restoreeventSessionitemSizeBytes=$(echo "$veeamRestoreSessionEventUrl" | jq --raw-output ".results[$arrayRestoreEventsSessions].itemSizeBytes")
            restoreeventSessionsource=$(echo "$veeamRestoreSessionEventUrl" | jq --raw-output ".results[$arrayRestoreEventsSessions].source" | awk '{gsub(/ /,"\\ ");print}'| awk '{gsub(/,/,"\\ ");print}'| awk '{gsub(/=/,"\\ ");print}')
            restoreeventSessiontarget=$(echo "$veeamRestoreSessionEventUrl" | jq --raw-output ".results[$arrayRestoreEventsSessions].target" | awk '{gsub(/ /,"\\ ");print}'| awk '{gsub(/,/,"\\ ");print}'| awk '{gsub(/=/,"\\ ");print}')
            restoreeventSessiontitle=$(echo "$veeamRestoreSessionEventUrl" | jq --raw-output ".results[$arrayRestoreEventsSessions].title" | awk '{gsub(/ /,"\\ ");print}'| awk '{gsub(/,/,"\\ ");print}'| awk '{gsub(/=/,"\\ ");print}')
            [[ ! -z "$restoreeventSessiontitle" ]] || restoreeventSessiontitle="None"
            restoreeventSessionmessage=$(echo "$veeamRestoreSessionEventUrl" | jq --raw-output ".results[$arrayRestoreEventsSessions].message" | awk '{gsub(/ /,"\\ ");print}'| awk '{gsub(/,/,"\\ ");print}'| awk '{gsub(/=/,"\\ ");print}')
            restoreeventSessiontime=$(echo "$veeamRestoreSessionEventUrl" | jq --raw-output ".results[$arrayRestoreEventsSessions].startTime")
            startTimeUnix=$(date -d "$restoreeventSessiontime" +"%s")

            #echo "veeam_microsoft365_audit_event,vb365_organization=$restoreSessionOrganization,vb365_restoresession_id=$restoreSessionID,vb365_restoresession_event_type=$restoreeventSessionType,vb365_restoresession_event_itemtype=$restoreeventSessionitemType,vb365_restoresession_event_source=$restoreeventSessionsource,vb365_restoresession_event_target=$restoreeventSessiontarget,vb365_restoresession_event_title=$restoreeventSessiontitle,vb365_restoresession_event_message=$restoreeventSessionmessage vb365_restoresession_event_SizeBytes=$restoreeventSessionitemSizeBytes $endTimeUnix" 
            curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" \
            -H "Authorization: Token $veeamInfluxDBToken" \
            --data-binary "veeam_m365_auditrestore_event,vb365_organization=$restoreSessionOrganization,vb365_restoresession_id=$restoreSessionID,vb365_restoresession_event_type=$restoreeventSessionType,vb365_restoresession_event_itemtype=$restoreeventSessionitemType,vb365_restoresession_event_source=$restoreeventSessionsource,vb365_restoresession_event_target=$restoreeventSessiontarget,vb365_restoresession_event_title=$restoreeventSessiontitle,vb365_restoresession_event_message=$restoreeventSessionmessage,vb365_restoresession_name=$restoreSessionName,vb365_restoresession_type=$restoreSessionType,vb365_restoresession_state=$restoreSessionState,vb365_restoresession_initiatedby=$restoreSessionInitiatedby,vb365_restoresession_details=$restoreSessionDetails,vb365_restoresession_scope=$restoreSessionScopeName,vb365_restoresession_clienthost=$restoreSessionClientHost,vb365_restoresession_reason=$restoreSessionReason vb365_restoresession_event_SizeBytes=$restoreeventSessionitemSizeBytes $startTimeUnix"
     
        fi

        arrayRestoreEventsSessions=$arrayRestoreEventsSessions+1
    done
    arrayRestoreSessions=$arrayRestoreSessions+1
done