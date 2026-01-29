#!/bin/bash
##      .SYNOPSIS
##      Grafana Dashboard for Veeam Enterprise Manager v13 - Using RestAPI to InfluxDB Script
## 
##      .DESCRIPTION
##      This Script will query the Veeam Enterprise Manager RestAPI and send the data directly to InfluxDB, which can be used to present it to Grafana. 
##      The Script and the Grafana Dashboard it is provided as it is, and bear in mind you can not open support Tickets regarding this project. It is a Community Project
##
##      .THANKS
##      Thank you to tigattack - https://github.com/tigattack for the help moving the Veeam scripts to InfluxDB v2
##	
##      .Notes
##      NAME:  veeam_enterprisemanager.sh
##      ORIGINAL NAME: veeam_enterprisemanager.sh
##      LASTEDIT: 29/01/2026
##      VERSION: 13
##      KEYWORDS: Veeam, InfluxDB, Grafana
   
##      .Link
##      https://jorgedelacruz.es/
##      https://jorgedelacruz.uk/

##
# Configurations
##
veeamDebug="true" # Set to true to enable raw JSON output debugging
# Endpoint URL for InfluxDB
veeamInfluxDBURL="http://YOURINFLUXSERVERIP" #Your InfluxDB Server, http://FQDN or https://FQDN if using SSL
veeamInfluxDBPort="8086" #Default Port
veeamInfluxDBBucket="veeam" # InfluxDB bucket name (not ID)
veeamInfluxDBToken="TOKEN" # InfluxDB access token with read/write privileges for the bucket
veeamInfluxDBOrg="ORG NAME" # InfluxDB organisation name (not ID)

# Endpoint URL for login action
veeamUsername="YOUREMUSER" #Your username, if using domain based account, please add it like user@domain.com (if you use domain\account it is not going to work!)
veeamPassword='YOUREMPASSWORD'
veeamJobSessions="100"
veeamAuth=$(echo -ne "$veeamUsername:$veeamPassword" | base64);
veeamRestServer="YOUREMSERVERIP"
veeamRestPort="9398" #Default Port

# Get the SessionId and HTTP status code
response=$(curl -X POST "https://$veeamRestServer:$veeamRestPort/api/sessionMngr/?v=latest" \
    -H "Authorization:Basic $veeamAuth" \
    -H "Content-Length: 0" \
    -H "Accept: application/json" \
    -k --silent \
    -D headers.txt \
    -w "%{http_code}" -o response.json)

http_status=$response
veeamSessionIdTmp=$(cat response.json | awk 'NR==1{sub(/^\xef\xbb\xbf/,"")}1')
rm response.json

case $http_status in
    200|201)
        veeamSessionId=$(echo "$veeamSessionIdTmp" | jq --raw-output ".sessionId")
        if [ -n "$veeamSessionId" ] && [ "$veeamSessionId" != "null" ]; then
            echo "Successfully obtained SessionId from Body"
            veeamXRestSvcSessionId=$(echo -ne "$veeamSessionId" | base64);
        else
            # Try to fetch from headers if body fails
            headerToken=$(grep -i "X-RestSvcSessionId:" headers.txt | awk '{print $2}' | tr -d '\r\n')
            if [ -n "$headerToken" ]; then
                echo "Successfully obtained SessionId from Headers"
                veeamXRestSvcSessionId=$headerToken
            else
                echo "SessionId was not found in the response body or headers."
                echo "DEBUG: Response Body: $veeamSessionIdTmp"
                echo "DEBUG: Headers:"
                cat headers.txt
                rm headers.txt
                exit 1
            fi
        fi
        rm headers.txt
        ;;
    400)
        errorMessage=$(echo "$veeamSessionIdTmp" | jq -r '.message')
        echo "Bad request: $errorMessage"
        echo "DEBUG: Response Body: $veeamSessionIdTmp"
        rm headers.txt
        exit 1
        ;;
    401)
        errorMessage=$(echo "$veeamSessionIdTmp" | jq -r '.message')
        echo "Unauthorized: $errorMessage"
        rm headers.txt
        exit 1
        ;;
    403)
        errorMessage=$(echo "$veeamSessionIdTmp" | jq -r '.message')
        echo "Forbidden: $errorMessage"
        rm headers.txt
        exit 1
        ;;
    500)
        errorMessage=$(echo "$veeamSessionIdTmp" | jq -r '.message')
        echo "Internal server error: $errorMessage"
        rm headers.txt
        exit 1
        ;;
    *)
        echo "An unexpected error occurred with HTTP status code: $http_status."
        echo "DEBUG: Response Body: $veeamSessionIdTmp"
        rm headers.txt
        exit 1
        ;;
esac

timestart=$(date --date="-1 days" +%FT%TZ)

##
# Veeam Enterprise Manager Overview. Overview of Backup Infrastructure and Job Status
##
veeamEMUrl="https://$veeamRestServer:$veeamRestPort/api/reports/summary/overview"
veeamEMOUrl=$(curl -X GET "$veeamEMUrl" -H "Accept:application/json" -H "X-RestSvcSessionId: $veeamXRestSvcSessionId" -H "Cookie: X-RestSvcSessionId=$veeamXRestSvcSessionId" -H "Content-Length: 0" 2>&1 -k --silent | awk 'NR==1{sub(/^\xef\xbb\xbf/,"")}1')

    if [[ "$veeamDebug" == "true" ]]; then
        echo "DEBUG: Querying $veeamEMUrl"
        echo "DEBUG: Response: $veeamEMOUrl"
    fi

    veeamBackupServers=$(echo "$veeamEMOUrl" | jq --raw-output ".backupServers")
    veeamProxyServers=$(echo "$veeamEMOUrl" | jq --raw-output ".proxyServers")    
    veeamRepositoryServers=$(echo "$veeamEMOUrl" | jq --raw-output ".repositoryServers")
    veeamRunningJobs=$(echo "$veeamEMOUrl" | jq --raw-output ".runningJobs")    
    veeamScheduledJobs=$(echo "$veeamEMOUrl" | jq --raw-output ".scheduledJobs")
    veeamSuccessfulVmLastestStates=$(echo "$veeamEMOUrl" | jq --raw-output ".successfulVmLastestStates")    
    veeamWarningVmLastestStates=$(echo "$veeamEMOUrl" | jq --raw-output ".warningVmLastestStates")
    veeamFailedVmLastestStates=$(echo "$veeamEMOUrl" | jq --raw-output ".failedVmLastestStates")
    
    ##Un-comment the following echo for debugging    
    #echo "veeam_em_overview,host=$veeamRestServer veeamBackupServers=$veeamBackupServers,veeamProxyServers=$veeamProxyServers,veeamRepositoryServers=$veeamRepositoryServers,veeamRunningJobs=$veeamRunningJobs,veeamScheduledJobs=$veeamScheduledJobs,veeamSuccessfulVmLastestStates=$veeamSuccessfulVmLastestStates,veeamWarningVmLastestStates=$veeamWarningVmLastestStates,veeamFailedVmLastestStates=$veeamFailedVmLastestStates"
    
    ##Comment the influx write while debugging
    echo "Writing veeam_em_overview to InfluxDB"
    influx write \
    -t "$veeamInfluxDBToken" \
    -b "$veeamInfluxDBBucket" \
    -o "$veeamInfluxDBOrg" \
    -p s \
    "veeam_em_overview,host=$veeamRestServer veeamBackupServers=$veeamBackupServers,veeamProxyServers=$veeamProxyServers,veeamRepositoryServers=$veeamRepositoryServers,veeamRunningJobs=$veeamRunningJobs,veeamScheduledJobs=$veeamScheduledJobs,veeamSuccessfulVmLastestStates=$veeamSuccessfulVmLastestStates,veeamWarningVmLastestStates=$veeamWarningVmLastestStates,veeamFailedVmLastestStates=$veeamFailedVmLastestStates"
##
# Veeam Enterprise Manager Overview. Overview of Virtual Machines
##
veeamEMUrl="https://$veeamRestServer:$veeamRestPort/api/reports/summary/vms_overview"
veeamEMOVMUrl=$(curl -X GET "$veeamEMUrl" -H "Accept:application/json" -H "X-RestSvcSessionId: $veeamXRestSvcSessionId" -H "Cookie: X-RestSvcSessionId=$veeamXRestSvcSessionId" -H "Content-Length: 0" 2>&1 -k --silent | awk 'NR==1{sub(/^\xef\xbb\xbf/,"")}1')

    if [[ "$veeamDebug" == "true" ]]; then
        echo "DEBUG: Querying $veeamEMUrl"
        echo "DEBUG: Response: $veeamEMOVMUrl"
    fi

    veeamProtectedVms=$(echo "$veeamEMOVMUrl" | jq --raw-output ".protectedVms")
    veeamBackedUpVms=$(echo "$veeamEMOVMUrl" | jq --raw-output ".backedUpVms")    
    veeamReplicatedVms=$(echo "$veeamEMOVMUrl" | jq --raw-output ".replicatedVms")
    veeamRestorePoints=$(echo "$veeamEMOVMUrl" | jq --raw-output ".restorePoints")    
    veeamFullBackupPointsSize=$(echo "$veeamEMOVMUrl" | jq --raw-output ".fullBackupPointsSize")
    veeamIncrementalBackupPointsSize=$(echo "$veeamEMOVMUrl" | jq --raw-output ".incrementalBackupPointsSize")    
    veeamReplicaRestorePointsSize=$(echo "$veeamEMOVMUrl" | jq --raw-output ".replicaRestorePointsSize")
    veeamSourceVmsSize=$(echo "$veeamEMOVMUrl" | jq --raw-output ".sourceVmsSize")    
    veeamSuccessBackupPercents=$(echo "$veeamEMOVMUrl" | jq --raw-output ".successBackupPercents")
    
    #echo "veeam_em_overview_vms,host=$veeamRestServer veeamProtectedVms=$veeamProtectedVms,veeamBackedUpVms=$veeamBackedUpVms,veeamReplicatedVms=$veeamReplicatedVms,veeamRestorePoints=$veeamRestorePoints,veeamFullBackupPointsSize=$veeamFullBackupPointsSize,veeamIncrementalBackupPointsSize=$veeamIncrementalBackupPointsSize,veeamReplicaRestorePointsSize=$veeamReplicaRestorePointsSize,veeamSourceVmsSize=$veeamSourceVmsSize,veeamSuccessBackupPercents=$veeamSuccessBackupPercents"
    
    ##Comment the influx write while debugging
    echo "Writing veeam_em_overview_vms to InfluxDB"    
        influx write \
    -t "$veeamInfluxDBToken" \
    -b "$veeamInfluxDBBucket" \
    -o "$veeamInfluxDBOrg" \
    -p s \
    "veeam_em_overview_vms,host=$veeamRestServer veeamProtectedVms=$veeamProtectedVms,veeamBackedUpVms=$veeamBackedUpVms,veeamReplicatedVms=$veeamReplicatedVms,veeamRestorePoints=$veeamRestorePoints,veeamFullBackupPointsSize=$veeamFullBackupPointsSize,veeamIncrementalBackupPointsSize=$veeamIncrementalBackupPointsSize,veeamReplicaRestorePointsSize=$veeamReplicaRestorePointsSize,veeamSourceVmsSize=$veeamSourceVmsSize,veeamSuccessBackupPercents=$veeamSuccessBackupPercents"

##
# Veeam Enterprise Manager Overview. Overview of Job Statistics
##
veeamEMUrl="https://$veeamRestServer:$veeamRestPort/api/reports/summary/job_statistics"
veeamEMOJobUrl=$(curl -X GET "$veeamEMUrl" -H "Accept:application/json" -H "X-RestSvcSessionId: $veeamXRestSvcSessionId" -H "Cookie: X-RestSvcSessionId=$veeamXRestSvcSessionId" -H "Content-Length: 0" 2>&1 -k --silent | awk 'NR==1{sub(/^\xef\xbb\xbf/,"")}1')

    if [[ "$veeamDebug" == "true" ]]; then
        echo "DEBUG: Querying $veeamEMUrl"
        echo "DEBUG: Response: $veeamEMOJobUrl"
    fi

    veeamRunningJobs=$(echo "$veeamEMOJobUrl" | jq --raw-output ".runningJobs")
    veeamScheduledJobs=$(echo "$veeamEMOJobUrl" | jq --raw-output ".scheduledJobs")    
    veeamScheduledBackupJobs=$(echo "$veeamEMOJobUrl" | jq --raw-output ".scheduledBackupJobs")
    veeamScheduledReplicaJobs=$(echo "$veeamEMOJobUrl" | jq --raw-output ".scheduledReplicaJobs")    
    veeamTotalJobRuns=$(echo "$veeamEMOJobUrl" | jq --raw-output ".totalJobRuns")
    veeamSuccessfulJobRuns=$(echo "$veeamEMOJobUrl" | jq --raw-output ".successfulJobRuns")    
    veeamWarningsJobRuns=$(echo "$veeamEMOJobUrl" | jq --raw-output ".warningsJobRuns")
    veeamFailedJobRuns=$(echo "$veeamEMOJobUrl" | jq --raw-output ".failedJobRuns")    
    veeamMaxJobDuration=$(echo "$veeamEMOJobUrl" | jq --raw-output ".maxJobDuration")    
    veeamMaxBackupJobDuration=$(echo "$veeamEMOJobUrl" | jq --raw-output ".maxBackupJobDuration")    
    veeamMaxReplicaJobDuration=$(echo "$veeamEMOJobUrl" | jq --raw-output ".maxReplicaJobDuration")
    veeamMaxDurationBackupJobName=$(echo "$veeamEMOJobUrl" | jq --raw-output ".maxDurationBackupJobName" | awk '{gsub(/ /,"\\ ");print}')
    [[ ! -z "$veeamMaxDurationBackupJobName" ]] || veeamMaxDurationBackupJobName="None"
    veeamMaxDurationReplicaJobName=$(echo "$veeamEMOJobUrl" | jq --raw-output ".maxDurationReplicaJobName" | awk '{gsub(/ /,"\\ ");print}')
    [[ ! -z "$veeamMaxDurationReplicaJobName" ]] || veeamMaxDurationReplicaJobName="None"
    
    #echo "veeam_em_overview_jobs,host=$veeamRestServer,veeamMaxDurationBackupJobName=$veeamMaxDurationBackupJobName,veeamMaxDurationReplicaJobName=$veeamMaxDurationReplicaJobName veeamRunningJobs=$veeamRunningJobs,veeamScheduledJobs=$veeamScheduledJobs,veeamScheduledBackupJobs=$veeamScheduledBackupJobs,veeamScheduledReplicaJobs=$veeamScheduledReplicaJobs,veeamTotalJobRuns=$veeamTotalJobRuns,veeamSuccessfulJobRuns=$veeamSuccessfulJobRuns,veeamWarningsJobRuns=$veeamWarningsJobRuns,veeamFailedJobRuns=$veeamFailedJobRuns,veeamMaxJobDuration=$veeamMaxJobDuration,veeamMaxBackupJobDuration=$veeamMaxBackupJobDuration,veeamMaxReplicaJobDuration=$veeamMaxReplicaJobDuration"
    
    ##Comment the influx write while debugging
    echo "Writing veeam_em_overview_jobs to InfluxDB"     
    influx write \
    -t "$veeamInfluxDBToken" \
    -b "$veeamInfluxDBBucket" \
    -o "$veeamInfluxDBOrg" \
    -p s \
    "veeam_em_overview_jobs,host=$veeamRestServer,veeamMaxDurationBackupJobName=$veeamMaxDurationBackupJobName,veeamMaxDurationReplicaJobName=$veeamMaxDurationReplicaJobName veeamRunningJobs=$veeamRunningJobs,veeamScheduledJobs=$veeamScheduledJobs,veeamScheduledBackupJobs=$veeamScheduledBackupJobs,veeamScheduledReplicaJobs=$veeamScheduledReplicaJobs,veeamTotalJobRuns=$veeamTotalJobRuns,veeamSuccessfulJobRuns=$veeamSuccessfulJobRuns,veeamWarningsJobRuns=$veeamWarningsJobRuns,veeamFailedJobRuns=$veeamFailedJobRuns,veeamMaxJobDuration=$veeamMaxJobDuration,veeamMaxBackupJobDuration=$veeamMaxBackupJobDuration,veeamMaxReplicaJobDuration=$veeamMaxReplicaJobDuration"

##
# Veeam Enterprise Manager Repositories. Overview of Repositories
##
veeamEMUrl="https://$veeamRestServer:$veeamRestPort/api/repositories?format=Entity"
veeamEMORepoUrl=$(curl -X GET "$veeamEMUrl" -H "Accept:application/json" -H "X-RestSvcSessionId: $veeamXRestSvcSessionId" -H "Cookie: X-RestSvcSessionId=$veeamXRestSvcSessionId" -H "Content-Length: 0" 2>&1 -k --silent | awk 'NR==1{sub(/^\xef\xbb\xbf/,"")}1')

    if [[ "$veeamDebug" == "true" ]]; then
        echo "DEBUG: Querying $veeamEMUrl"
        echo "DEBUG: Response: $veeamEMORepoUrl"
    fi

declare -i arrayrepo=0
for Kind in $(echo "$veeamEMORepoUrl" | jq -r '.repositories[].kind'); do
    veeamRepositoryName=$(echo "$veeamEMORepoUrl" | jq --raw-output ".repositories[$arrayrepo].name" | awk '{gsub(/ /,"\\ ");print}')
    veeamVBR=$(echo "$veeamEMORepoUrl" | jq --raw-output ".repositories[$arrayrepo].links[0].name" | awk '{gsub(/ /,"\\ ");print}') 
    veeamRepositoryCapacity=$(echo "$veeamEMORepoUrl" | jq --raw-output ".repositories[$arrayrepo].capacity")
    veeamRepositoryFreeSpace=$(echo "$veeamEMORepoUrl" | jq --raw-output ".repositories[$arrayrepo].freeSpace")    
    veeamRepositoryKind=$(echo "$veeamEMORepoUrl" | jq --raw-output ".repositories[$arrayrepo].kind")
  
    #echo "veeam_em_overview_repositories,host=$veeamRestServer,veeamRepositoryName=$veeamRepositoryName veeamRepositoryCapacity=$veeamRepositoryCapacity,veeamRepositoryFreeSpace=$veeamRepositoryFreeSpace,veeamRepositoryBackupSize=$veeamRepositoryBackupSize"
    
    ##Comment the influx write while debugging
    echo "Writing veeam_em_overview_repositories to InfluxDB"      
    influx write \
    -t "$veeamInfluxDBToken" \
    -b "$veeamInfluxDBBucket" \
    -o "$veeamInfluxDBOrg" \
    -p s \
    "veeam_em_overview_repositories,veeamVBR=$veeamVBR,veeamRepositoryName=$veeamRepositoryName,veeamRepositoryKind=$veeamRepositoryKind veeamRepositoryCapacity=$veeamRepositoryCapacity,veeamRepositoryFreeSpace=$veeamRepositoryFreeSpace"
  arrayrepo=$arrayrepo+1
done

##
# Veeam Enterprise Manager Backup Servers. Overview of Backup Repositories
##
veeamEMUrl="https://$veeamRestServer:$veeamRestPort/api/backupServers?format=Entity"
veeamEMOBackupServersUrl=$(curl -X GET "$veeamEMUrl" -H "Accept:application/json" -H "X-RestSvcSessionId: $veeamXRestSvcSessionId" -H "Cookie: X-RestSvcSessionId=$veeamXRestSvcSessionId" -H "Content-Length: 0" 2>&1 -k --silent | awk 'NR==1{sub(/^\xef\xbb\xbf/,"")}1')

    if [[ "$veeamDebug" == "true" ]]; then
        echo "DEBUG: Querying $veeamEMUrl"
        echo "DEBUG: Response: $veeamEMOBackupServersUrl"
    fi

declare -i arraybackupservers=0
for Name in $(echo "$veeamEMOBackupServersUrl" | jq -r '.backupServers[].name'); do
    veeamVBR=$(echo "$veeamEMOBackupServersUrl" | jq --raw-output ".backupServers[$arraybackupservers].name" | awk '{gsub(/ /,"\\ ");print}')
    veeamBackupServersPort=$(echo "$veeamEMOBackupServersUrl" | jq --raw-output ".backupServers[$arraybackupservers].port")
    veeamBackupServersVersion=$(echo "$veeamEMOBackupServersUrl" | jq --raw-output ".backupServers[$arraybackupservers].version" | awk '{gsub(/ /,"\\ ");print}')
       case $veeamBackupServersVersion in
        "13.0.1.1071")
            veeamBackupServersVersionM="13.0.1\ P1"
        ;;
        "13.0.1.180")
            veeamBackupServersVersionM="13.0.1"
        ;;
        "13.0.0.4967")
            veeamBackupServersVersionM="13.0"
        ;;
        "12.3.2.4165")
            veeamBackupServersVersionM="12.3.2\ Patch"
        ;;
        "12.3.2.3617")
            veeamBackupServersVersionM="12.3.2"
        ;;
        "12.3.1.1139")
            veeamBackupServersVersionM="12.3.1"
        ;;
        "12.3.0.310")
            veeamBackupServersVersionM="12.3"
        ;;
        "12.2.0.334")
            veeamBackupServersVersionM="12.2"
        ;;
        "12.1.2.172")
            veeamBackupServersVersionM="12.1.2"
        ;;
        "12.1.1.56")
            veeamBackupServersVersionM="12.1.1"
        ;; 
        "12.1.0.2131")
            veeamBackupServersVersionM="12.1\ GA"
        ;;
        "12.0.0.1420 P20230718")
            veeamBackupServersVersionM="12.0.0.1420\ P20230718"
        ;; 
        "12.0.0.1420 P20230412")
            veeamBackupServersVersionM="12.0.0.1420\ P20230412"
        ;; 
        "12.0.0.1420 P20230223")
            veeamBackupServersVersionM="12.0.0.1420\ P20230223"
        ;;  
        "12.0.0.1420")
            veeamBackupServersVersionM="12.0\ GA"
        ;; 
        "12.0.0.1402")
            veeamBackupServersVersionM="12.0\ RTM"
        ;;  
        "11.0.1.1261 P20240304")
            veeamBackupServersVersionM="11.0a\ P20240304"
        ;;
        "11.0.1.1261 P20230227")
            veeamBackupServersVersionM="11.0a\ P20230227"
        ;;
        "11.0.1.1261 P20220302")
            veeamBackupServersVersionM="11.0a\ P20220302"
        ;; 
        "11.0.1.1261 P20211211")
            veeamBackupServersVersionM="11.0a\ P20211211"
        ;; 
        "11.0.1.1261 P20211123")
            veeamBackupServersVersionM="11.0a\ P20211123"
        ;;  
        "11.0.1.1261")
            veeamBackupServersVersionM="11.0a\ GA"
        ;;        
        "11.0.0.837")
            veeamBackupServersVersionM="11.0\ GA"
        ;;
        "11.0.0.825")
            veeamBackupServersVersionM="11.0\ RTM"
        ;;
        "10.0.1.4854")
            veeamBackupServersVersionM="10.0a\ GA"
        ;;
        "10.0.1.4848")
            veeamBackupServersVersionM="10.0a\ RTM"
        ;;
        "10.0.0.4461")
            veeamBackupServersVersionM="10.0\ GA"
        ;;
        "10.0.0.4442")
            veeamBackupServersVersionM="10.0\ RTM"
        ;;
        "9.5.4.2866")
            veeamBackupServersVersionM="9.5\ U4b\ GA"
        ;;
        "9.5.4.2753")
            veeamBackupServersVersionM="9.5\ U4a\ GA"
        ;;
        "9.5.4.2615")
            veeamBackupServersVersionM="9.5\ U4\ GA"
        ;;
        "9.5.4.2399")
            veeamBackupServersVersionM="9.5\ U4\ RTM"
        ;;
        "9.5.0.1922")
            veeamBackupServersVersionM="9.5\ U3a"
        ;;
        "9.5.0.1536")
            veeamBackupServersVersionM="9.5\ U3"
        ;;
        "9.5.0.1038")
            veeamBackupServersVersionM="9.5\ U2"
        ;;
        "9.5.0.823")
            veeamBackupServersVersionM="9.5\ U1"
        ;;
        "9.5.0.802")
            veeamBackupServersVersionM="9.5\ U1\ RC"
        ;;
        "9.5.0.711")
            veeamBackupServersVersionM="9.5\ GA"
        ;;
        "9.5.0.580")
            veeamBackupServersVersionM="9.5\ RTM"
        ;;
        "9.0.0.1715")
            veeamBackupServersVersionM="9.0\ U2"
        ;;
        "9.0.0.1491")
            veeamBackupServersVersionM="9.0\ U1"
        ;;
        "9.0.0.902")
            veeamBackupServersVersionM="9.0\ GA"
        ;;
        "9.0.0.773")
            veeamBackupServersVersionM="9.0\ RTM"
        ;;
        "8.0.0.2084")
            veeamBackupServersVersionM="8.0\ U3"
        ;;
        "8.0.0.2030")
            veeamBackupServersVersionM="8.0\ U2b"
        ;;
        "8.0.0.2029")
            veeamBackupServersVersionM="8.0\ U2a"
        ;;
        "8.0.0.2021")
            veeamBackupServersVersionM="8.0\ U2\ GA"
        ;;
        "8.0.0.2018")
            veeamBackupServersVersionM="8.0\ U2\RTM"
        ;;
        "8.0.0.917")
            veeamBackupServersVersionM="8.0\ P1"
        ;;
        "8.0.0.817")
            veeamBackupServersVersionM="8.0\ GA"
        ;;
        "8.0.0.807")
            veeamBackupServersVersionM="8.0\ RTM"
        ;;
        "7.0.0.871")
            veeamBackupServersVersionM="7.0\ P4a"
        ;;
        "7.0.0.870")
            veeamBackupServersVersionM="7.0\ P4"
        ;;
        "7.0.0.839")
            veeamBackupServersVersionM="7.0\ P3a"
        ;;
        "7.0.0.833")
            veeamBackupServersVersionM="7.0\ P3"
        ;;
        "7.0.0.771")
            veeamBackupServersVersionM="7.0\ R2a"
        ;;
        "7.0.0.764")
            veeamBackupServersVersionM="7.0\ R2"
        ;;
        "7.0.0.715")
            veeamBackupServersVersionM="7.0\ P1"
        ;;
        "7.0.0.690")
            veeamBackupServersVersionM="7.0\ GA"
        ;;
        "6.5.0.144")
            veeamBackupServersVersionM="6.5\ P3"
        ;;
        "6.5.0.128")
            veeamBackupServersVersionM="6.5\ P1"
        ;;
        "6.5.0.109")
            veeamBackupServersVersionM="6.5\ GA"
        ;;
        "6.5.0.106")
            veeamBackupServersVersionM="6.5\ RTM"
        ;;
        "6.1.0.205")
            veeamBackupServersVersionM="6.1\ P1a"
        ;;
        "6.1.0.204")
            veeamBackupServersVersionM="6.1\ P1"
        ;;
        "6.1.0.181")
            veeamBackupServersVersionM="6.1\ GA"
        ;;
        "6.0.0.181")
            veeamBackupServersVersionM="6.0\ P3"
        ;;
        "6.0.0.164")
            veeamBackupServersVersionM="6.0\ P2"
        ;;
        "6.0.0.158")
            veeamBackupServersVersionM="6.0\ P1"
        ;;
        "6.0.0.153")
            veeamBackupServersVersionM="6.0\ GA"
        ;;
        "5.0.2.230")
            veeamBackupServersVersionM="5.0.2\ U2"
        ;;
        "5.0.2.224")
            veeamBackupServersVersionM="5.0.2"
        ;;
        "5.0.1.198")
            veeamBackupServersVersionM="5.0.1"
        ;;
        "5.0.0.179")
            veeamBackupServersVersionM="5.0.0"
        ;;
        "4.1.2.125")
            veeamBackupServersVersionM="4.1.2"
        ;;
        "4.1.1.105")
            veeamBackupServersVersionM="4.1.1"
        ;;
        "4.1.0.96")
            veeamBackupServersVersionM="4.1.0"
        ;;
        "4.0.0.80")
            veeamBackupServersVersionM="4.0"
        ;;
        "3.0.1.251")
            veeamBackupServersVersionM="3.0.1"
        ;;
        "3.0.0.238")
            veeamBackupServersVersionM="3.0"
        ;;
        "2.0.0.152")
            veeamBackupServersVersionM="2.0"
        ;;
        "1.0.1.76")
            veeamBackupServersVersionM="1.0.1"
        ;;
        "1.0.0.64")
            veeamBackupServersVersionM="1.0"
        ;;
        esac

    #echo "veeam_em_backup_servers,veeamVBR=$veeamVBR,veeamBackupServersVersion=$veeamBackupServersVersion,veeamBackupServersVersionM=$veeamBackupServersVersionM veeamBackupServersPort=$veeamBackupServersPort"
    ##Comment the influx write while debugging
    echo "Writing veeam_em_backup_servers to InfluxDB"          
    influx write \
    -t "$veeamInfluxDBToken" \
    -b "$veeamInfluxDBBucket" \
    -o "$veeamInfluxDBOrg" \
    -p s \
    "veeam_em_backup_servers,veeamVBR=$veeamVBR,veeamBackupServersVersion=$veeamBackupServersVersion,veeamBackupServersVersionM=$veeamBackupServersVersionM veeamBackupServersPort=$veeamBackupServersPort"
  arraybackupservers=$arraybackupservers+1
done

##
# Veeam Enterprise Manager Backup Job Sessions. Overview of Backup Job Sessions
##
veeamEMUrl="https://$veeamRestServer:$veeamRestPort/api/backupSessions?format=Entity"
veeamEMJobSessionsUrl=$(curl -X GET "$veeamEMUrl" -H "Accept:application/json" -H "X-RestSvcSessionId: $veeamXRestSvcSessionId" -H "Cookie: X-RestSvcSessionId=$veeamXRestSvcSessionId" -H "Content-Length: 0" 2>&1 -k --silent | awk 'NR==1{sub(/^\xef\xbb\xbf/,"")}1' | jq '[.backupJobSessions[] | select(.creationTimeUTC> "'$timestart'")]')

    if [[ "$veeamDebug" == "true" ]]; then
        echo "DEBUG: Querying $veeamEMUrl"
        echo "DEBUG: Response: $veeamEMJobSessionsUrl"
    fi

declare -i arrayjobsessions=0
if [[ "$veeamEMJobSessionsUrl" == "[]" ]]; then
    echo "There are not new veeam_em_job_sessions since $timestart"
else
    for JobUid in $(echo "$veeamEMJobSessionsUrl" | jq -r '.[].jobUid'); do
        veeamBackupSessionsName=$(echo "$veeamEMJobSessionsUrl" | jq --raw-output ".[$arrayjobsessions].jobName" | awk '{gsub(/ /,"\\ ");print}')
        veeamVBR=$(echo "$veeamEMJobSessionsUrl" | jq --raw-output ".[$arrayjobsessions].links[0].name" | awk '{gsub(/ /,"\\ ");print}') 
        veeamBackupSessionsJobType=$(echo "$veeamEMJobSessionsUrl" | jq --raw-output ".[$arrayjobsessions].jobType") 
        veeamBackupSessionsJobState=$(echo "$veeamEMJobSessionsUrl" | jq --raw-output ".[$arrayjobsessions].state")
        veeamBackupSessionsJobResult=$(echo "$veeamEMJobSessionsUrl" | jq --raw-output ".[$arrayjobsessions].result")     
        case $veeamBackupSessionsJobResult in
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
        veeamBackupSessionsTime=$(echo "$veeamEMJobSessionsUrl" | jq --raw-output ".[$arrayjobsessions].creationTimeUTC")
        creationTimeUnix=$(date -d "$veeamBackupSessionsTime" +"%s")
        veeamBackupSessionsTimeEnd=$(echo "$veeamEMJobSessionsUrl" | jq --raw-output ".[$arrayjobsessions].endTimeUTC")
        endTimeUnix=$(date -d "$veeamBackupSessionsTimeEnd" +"%s")
        veeamBackupSessionsTimeDuration=$(($endTimeUnix-$creationTimeUnix))

        #echo "veeam_em_job_sessions,veeamBackupSessionsName=$veeamBackupSessionsName,veeamVBR=$veeamVBR,veeamBackupSessionsJobType=$veeamBackupSessionsJobType,veeamBackupSessionsJobState=$veeamBackupSessionsJobState veeamBackupSessionsJobResult=$jobStatus $creationTimeUnix"

        ##Comment the influx write while debugging
        echo "Writing veeam_em_job_sessions to InfluxDB"      
        influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "veeam_em_job_sessions,veeamBackupSessionsName=$veeamBackupSessionsName,veeamVBR=$veeamVBR,veeamBackupSessionsJobType=$veeamBackupSessionsJobType,veeamBackupSessionsJobState=$veeamBackupSessionsJobState veeamBackupSessionsJobResult=$jobStatus,veeamBackupSessionsTimeDuration=$veeamBackupSessionsTimeDuration $creationTimeUnix"
        if [[ $arrayjobsessions = $veeamJobSessions ]]; then
            break
            else
                arrayjobsessions=$arrayjobsessions+1
        fi
    done
fi

##
# Veeam Enterprise Manager Backup Job Sessions per VM. Overview of Backup Job Sessions per VM. Really useful to display if a VM it is protected or not
##
veeamEMUrl="https://$veeamRestServer:$veeamRestPort/api/backupTaskSessions?format=Entity"
veeamEMJobSessionsVMUrl=$(curl -X GET "$veeamEMUrl" -H "Accept:application/json" -H "X-RestSvcSessionId: $veeamXRestSvcSessionId" -H "Cookie: X-RestSvcSessionId=$veeamXRestSvcSessionId" -H "Content-Length: 0" 2>&1 -k --silent | awk 'NR==1{sub(/^\xef\xbb\xbf/,"")}1' | jq '[.backupTaskSessions[] | select(.creationTimeUTC> "'$timestart'")]')

    if [[ "$veeamDebug" == "true" ]]; then
        echo "DEBUG: Querying $veeamEMUrl"
        echo "DEBUG: Response: $veeamEMJobSessionsVMUrl"
    fi

declare -i arrayjobsessionsvm=0
if [[ "$veeamEMJobSessionsVMUrl" == "[]" ]]; then
    echo "There are not new veeam_em_job_sessionsvm since $timestart"
else
    for JobSessionUid in $(echo "$veeamEMJobSessionsVMUrl" | jq -r '.[].jobSessionUid'); do
        veeamBackupSessionsVmDisplayName=$(echo "$veeamEMJobSessionsVMUrl" | jq --raw-output ".[$arrayjobsessionsvm].vmDisplayName" | awk '{gsub(/ /,"\\ ");print}')
        veeamVBR=$(echo "$veeamEMJobSessionsVMUrl" | jq --raw-output ".[$arrayjobsessionsvm].links[0].name" | awk '{gsub(/ /,"\\ ");print}') 
        veeamBackupSessionsTotalSize=$(echo "$veeamEMJobSessionsVMUrl" | jq --raw-output ".[$arrayjobsessionsvm].totalSize")    
        veeamBackupSessionsJobVMState=$(echo "$veeamEMJobSessionsVMUrl" | jq --raw-output ".[$arrayjobsessionsvm].state")
        veeamBackupSessionsJobVMResult=$(echo "$veeamEMJobSessionsVMUrl" | jq --raw-output ".[$arrayjobsessionsvm].result") 
        case $veeamBackupSessionsJobVMResult in
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
        veeamBackupSessionsVMTime=$(echo "$veeamEMJobSessionsVMUrl" | jq --raw-output ".[$arrayjobsessionsvm].creationTimeUTC")
        creationTimeUnix=$(date -d "$veeamBackupSessionsVMTime" +"%s")
        veeamBackupSessionsVMTimeEnd=$(echo "$veeamEMJobSessionsVMUrl" | jq --raw-output ".[$arrayjobsessionsvm].endTimeUTC")
        endTimeUnix=$(date -d "$veeamBackupSessionsVMTimeEnd" +"%s")
        veeamBackupSessionsVMDuration=$(($endTimeUnix-$creationTimeUnix))

        #echo "veeam_em_job_sessionsvm,veeamBackupSessionsVmDisplayName=$veeamBackupSessionsVmDisplayName,veeamVBR=$veeamVBR,veeamBackupSessionsJobVMState=$veeamBackupSessionsJobVMState veeamBackupSessionsTotalSize=$veeamBackupSessionsTotalSize,veeamBackupSessionsJobVMResult=$jobStatus $creationTimeUnix"

        ##Comment the influx write while debugging
        echo "Writing veeam_em_job_sessionsvm to InfluxDB"     
        influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "veeam_em_job_sessionsvm,veeamBackupSessionsVmDisplayName=$veeamBackupSessionsVmDisplayName,veeamVBR=$veeamVBR,veeamBackupSessionsJobVMState=$veeamBackupSessionsJobVMState veeamBackupSessionsTotalSize=$veeamBackupSessionsTotalSize,veeamBackupSessionsJobVMResult=$jobStatus,veeamBackupSessionsVMDuration=$veeamBackupSessionsVMDuration $creationTimeUnix"
      arrayjobsessionsvm=$arrayjobsessionsvm+1
    done
fi

##
# Veeam Enterprise Manager Replica Job Sessions. Overview of Replica Job Sessions
##
veeamEMUrl="https://$veeamRestServer:$veeamRestPort/api/replicaSessions?format=Entity"
veeamEMJobReplicaSessionsUrl="$(curl -X GET "$veeamEMUrl" -H "Accept:application/json" -H "X-RestSvcSessionId: $veeamXRestSvcSessionId" -H "Cookie: X-RestSvcSessionId=$veeamXRestSvcSessionId" -H "Content-Length: 0" 2>&1 -k --silent | awk 'NR==1{sub(/^\xef\xbb\xbf/,"")}1' | jq '[.replicaJobSessions[] | select(.creationTimeUTC> "'$timestart'")]')"

    if [[ "$veeamDebug" == "true" ]]; then
        echo "DEBUG: Querying $veeamEMUrl"
        echo "DEBUG: Response: $veeamEMJobReplicaSessionsUrl"
    fi

declare -i arrayjobrepsessions=0
if [[ "$veeamEMJobReplicaSessionsUrl" == "[]" ]]; then
    echo "There are not new veeam_em_job_sessions since $timestart"
else
    for JobUid in $(echo "$veeamEMJobReplicaSessionsUrl" | jq -r '.[].jobUid'); do
        veeamReplicaSessionsName=$(echo "$veeamEMJobReplicaSessionsUrl" | jq --raw-output ".[$arrayjobrepsessions].jobName" | awk '{gsub(/ /,"\\ ");print}')
        veeamVBR=$(echo "$veeamEMJobReplicaSessionsUrl" | jq --raw-output ".[$arrayjobrepsessions].links[0].name" | awk '{gsub(/ /,"\\ ");print}') 
        veeamReplicaSessionsJobType=$(echo "$veeamEMJobReplicaSessionsUrl" | jq --raw-output ".[$arrayjobrepsessions].jobType") 
        veeamReplicaSessionsJobState=$(echo "$veeamEMJobReplicaSessionsUrl" | jq --raw-output ".[$arrayjobrepsessions].state")
        veeamReplicaSessionsJobResult=$(echo "$veeamEMJobReplicaSessionsUrl" | jq --raw-output ".[$arrayjobrepsessions].result")     
        case $veeamReplicaSessionsJobResult in
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
        veeamReplicaSessionsTime=$(echo "$veeamEMJobReplicaSessionsUrl" | jq --raw-output ".[$arrayjobrepsessions].creationTimeUTC")
        creationTimeUnix=$(date -d "$veeamReplicaSessionsTime" +"%s")
        veeamReplicaSessionsTimeEnd=$(echo "$veeamEMJobReplicaSessionsUrl" | jq --raw-output ".[$arrayjobrepsessions].endTimeUTC")
        endTimeUnix=$(date -d "$veeamReplicaSessionsTimeEnd" +"%s")
        veeamReplicaSessionsDuration=$(($endTimeUnix-$creationTimeUnix))

        #echo "veeam_em_job_sessions,veeamReplicaSessionsName=$veeamReplicaSessionsName,veeamVBR=$veeamVBR,veeamReplicaSessionsJobType=$veeamReplicaSessionsJobType,veeamReplicaSessionsJobState=$veeamReplicaSessionsJobState veeamReplicaSessionsJobResult=$jobStatus $creationTimeUnix"

        ##Comment the influx write while debugging
        echo "Writing veeam_em_job_sessions Replica to InfluxDB"     
        influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "veeam_em_job_sessions,veeamReplicaSessionsName=$veeamReplicaSessionsName,veeamVBR=$veeamVBR,veeamReplicaSessionsJobType=$veeamReplicaSessionsJobType,veeamReplicaSessionsJobState=$veeamReplicaSessionsJobState veeamReplicaSessionsJobResult=$jobStatus,veeamReplicaSessionsDuration=$veeamReplicaSessionsDuration $creationTimeUnix"
      arrayjobrepsessions=$arrayjobrepsessions+1
    done
fi

##
# Veeam Enterprise Manager Replica Job Sessions per VM. Overview of Replica Job Sessions per VM. Really useful to display if a VM it is protected or not
##
veeamEMUrl="https://$veeamRestServer:$veeamRestPort/api/replicaTaskSessions?format=Entity"
veeamEMJobReplicaSessionsVMUrl=$(curl -X GET "$veeamEMUrl" -H "Accept:application/json" -H "X-RestSvcSessionId: $veeamXRestSvcSessionId" -H "Cookie: X-RestSvcSessionId=$veeamXRestSvcSessionId" -H "Content-Length: 0" 2>&1 -k --silent | awk 'NR==1{sub(/^\xef\xbb\xbf/,"")}1' | jq '[.replicaTaskSessions[] | select(.creationTimeUTC> "'$timestart'")]')

    if [[ "$veeamDebug" == "true" ]]; then
        echo "DEBUG: Querying $veeamEMUrl"
        echo "DEBUG: Response: $veeamEMJobReplicaSessionsVMUrl"
    fi

declare -i arrayjobrepsessionsvm=0
if [[ "$veeamEMJobReplicaSessionsVMUrl" == "[]" ]]; then
    echo "There are not new veeam_em_job_sessionsvm since $timestart"
else
    for JobSessionUid in $(echo "$veeamEMJobReplicaSessionsVMUrl" | jq -r '.[].jobSessionUid'); do
        veeamReplicaSessionsJobUid=$(echo "$veeamEMJobReplicaSessionsVMUrl" | jq --raw-output ".[$arrayjobrepsessionsvm].jobSessionUid")
        veeamReplicaSessionsJobVMState=$(echo "$veeamEMJobReplicaSessionsVMUrl" | jq --raw-output ".[$arrayjobrepsessionsvm].state")
        if [[ "$veeamReplicaSessionsJobVMState" == "InProgress" ]]; then
            echo "The Replica with ID:$veeamReplicaSessionsJobUid is in progress, will collect data later."
        else
        veeamReplicaSessionsVmDisplayName=$(echo "$veeamEMJobReplicaSessionsVMUrl" | jq --raw-output ".[$arrayjobrepsessionsvm].vmDisplayName" | awk '{gsub(/ /,"\\ ");print}')
        veeamVBR=$(echo "$veeamEMJobReplicaSessionsVMUrl" | jq --raw-output ".[$arrayjobrepsessionsvm].links[0].name" | awk '{gsub(/ /,"\\ ");print}') 
        veeamReplicaSessionsTotalSize=$(echo "$veeamEMJobReplicaSessionsVMUrl" | jq --raw-output ".[$arrayjobrepsessionsvm].totalSize")    
        
        veeamReplicaSessionsJobVMResult=$(echo "$veeamEMJobReplicaSessionsVMUrl" | jq --raw-output ".[$arrayjobrepsessionsvm].result") 
        case $veeamReplicaSessionsJobVMResult in
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
        veeamReplicaSessionsVMTime=$(echo "$veeamEMJobReplicaSessionsVMUrl" | jq --raw-output ".[$arrayjobrepsessionsvm].creationTimeUTC")
        creationTimeUnix=$(date -d "$veeamReplicaSessionsVMTime" +"%s")
        veeamReplicaSessionsVMTimeEnd=$(echo "$veeamEMJobReplicaSessionsVMUrl" | jq --raw-output ".[$arrayjobrepsessionsvm].endTimeUTC")
        endTimeUnix=$(date -d "$veeamReplicaSessionsVMTimeEnd" +"%s")
        veeamReplicaSessionsVMDuration=$(($endTimeUnix-$creationTimeUnix))

        #echo "veeam_em_job_sessionsvm,veeamReplicaSessionsVmDisplayName=$veeamReplicaSessionsVmDisplayName,veeamVBR=$veeamVBR,veeamReplicaSessionsJobVMState=$veeamReplicaSessionsJobVMState veeamReplicaSessionsTotalSize=$veeamReplicaSessionsTotalSize,veeamReplicaSessionsJobVMResult=$jobStatus $creationTimeUnix"

        ##Comment the influx write while debugging
        echo "Writing veeam_em_job_sessionsvm Replica to InfluxDB"     
        influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "veeam_em_job_sessionsvm,veeamReplicaSessionsVmDisplayName=$veeamReplicaSessionsVmDisplayName,veeamVBR=$veeamVBR,veeamReplicaSessionsJobVMState=$veeamReplicaSessionsJobVMState veeamReplicaSessionsTotalSize=$veeamReplicaSessionsTotalSize,veeamReplicaSessionsJobVMResult=$jobStatus,veeamReplicaSessionsVMDuration=$veeamReplicaSessionsVMDuration $creationTimeUnix"
      fi
      arrayjobrepsessionsvm=$arrayjobrepsessionsvm+1
    done
fi

##
# Veeam Enterprise Manager Backup Agent Status. Overview of the Veeam Agents. Really useful to display if an Agent it is uo to date and also the status
##
veeamEMUrl="https://$veeamRestServer:$veeamRestPort/api/agents/discoveredComputers?format=Entity"
veeamEMAgentUrl=$(curl -X GET "$veeamEMUrl" -H "Accept:application/json" -H "X-RestSvcSessionId: $veeamXRestSvcSessionId" -H "Cookie: X-RestSvcSessionId=$veeamXRestSvcSessionId" -H "Content-Length: 0" 2>&1 -k --silent | awk 'NR==1{sub(/^\xef\xbb\xbf/,"")}1')

    if [[ "$veeamDebug" == "true" ]]; then
        echo "DEBUG: Querying $veeamEMUrl"
        echo "DEBUG: Response: $veeamEMAgentUrl"
    fi

declare -i arrayagent=0
for JobSessionUid in $(echo "$veeamEMAgentUrl" | jq -r '.discoveredComputers[].uid'); do
    veeamAgentName=$(echo "$veeamEMAgentUrl" | jq --raw-output ".discoveredComputers[$arrayagent].name" | awk '{gsub(/ /,"\\ ");print}')
    veeamVBR=$(echo "$veeamEMAgentUrl" | jq --raw-output ".discoveredComputers[$arrayagent].links[0].name" | awk '{gsub(/ /,"\\ ");print}') 
    veeamAgentHostStatusCheck=$(echo "$veeamEMAgentUrl" | jq --raw-output ".discoveredComputers[$arrayagent].hostStatus")
    case $veeamAgentHostStatusCheck in
        "Online")
            veeamAgentHostStatus="1"
        ;;
        "Offline")
            veeamAgentHostStatus="2"
        ;;
        "Unknown")
            veeamAgentHostStatus="3"
        ;;
        esac
    veeamAgentStatusCheck=$(echo "$veeamEMAgentUrl" | jq --raw-output ".discoveredComputers[$arrayagent].agentStatus")
    case $veeamAgentStatusCheck in
        "Installed")
            veeamAgentStatus="1"
        ;;
        "Warning")
            veeamAgentStatus="2"
        ;;
        "Inaccessible")
            veeamAgentStatus="3"
        ;;
        "Not Installed")
            veeamAgentStatus="4"
        ;;
        "NotInitialized")
            veeamAgentStatus="5"
        ;;
        esac
    veeamAgentVersion=$(echo "$veeamEMAgentUrl" | jq --raw-output ".discoveredComputers[$arrayagent].agentVersion" | awk '{gsub(/ /,"\\ ");print}') 
    veeamAgentOsVersion=$(echo "$veeamEMAgentUrl" | jq --raw-output ".discoveredComputers[$arrayagent].osVersion" | awk -F',' '{$3=i; print}' | awk '{gsub(/ /,"\\ ");print}')
   
    #echo "veeam_em_agents,veeamAgentName=$veeamAgentName,veeamVBR=$veeamVBR,veeamAgentVersion=$veeamAgentVersion,veeamAgentOsVersion=$veeamAgentOsVersion veeamAgentStatus=$veeamAgentStatus,veeamAgentHostStatus=$veeamAgentHostStatus"
    
    ##Comment the influx write while debugging
    echo "Writing veeam_em_agents to InfluxDB"      
    influx write \
    -t "$veeamInfluxDBToken" \
    -b "$veeamInfluxDBBucket" \
    -o "$veeamInfluxDBOrg" \
    -p s \
    "veeam_em_agents,veeamAgentName=$veeamAgentName,veeamAgentOsVersion=$veeamAgentOsVersion,veeamVBR=$veeamVBR,veeamAgentVersion=$veeamAgentVersion veeamAgentStatus=$veeamAgentStatus,veeamAgentHostStatus=$veeamAgentHostStatus"
  arrayagent=$arrayagent+1
done

##
# Veeam Enterprise Manager NAS Jobs. Overview of the NAS Jobs. Really useful to display the NAS Jobs
##
veeamEMUrl="https://$veeamRestServer:$veeamRestPort/api/nas/jobs?format=Entity"
veeamEMNASJobsUrl=$(curl -X GET "$veeamEMUrl" -H "Accept:application/json" -H "X-RestSvcSessionId: $veeamXRestSvcSessionId" -H "Cookie: X-RestSvcSessionId=$veeamXRestSvcSessionId" -H "Content-Length: 0" 2>&1 -k --silent | awk 'NR==1{sub(/^\xef\xbb\xbf/,"")}1')

    if [[ "$veeamDebug" == "true" ]]; then
        echo "DEBUG: Querying $veeamEMUrl"
        echo "DEBUG: Response: $veeamEMNASJobsUrl"
    fi

declare -i arrayNASJobs=0
for JobSessionUid in $(echo "$veeamEMNASJobsUrl" | jq -r '.nasJobs[].uid'); do
    veeamNASJobName=$(echo "$veeamEMNASJobsUrl" | jq --raw-output ".nasJobs[$arrayNASJobs].name" | awk '{gsub(/ /,"\\ ");print}')
    veeamVBR=$(echo "$veeamEMNASJobsUrl" | jq --raw-output ".nasJobs[$arrayNASJobs].links[0].name" | awk '{gsub(/ /,"\\ ");print}')
    veeamNASJobShortTerm=$(echo "$veeamEMNASJobsUrl" | jq --raw-output ".nasJobs[$arrayNASJobs].storageOptions.shorttermRetentionPeriod")
    veeamNASJobShortTermType=$(echo "$veeamEMNASJobsUrl" | jq --raw-output ".nasJobs[$arrayNASJobs].storageOptions.shorttermRetentionType")
   
    #echo "veeam_em_nas_jobs,veeamNASJobName=$veeamNASJobName,veeamVBR=$veeamVBR,veeamNASJobShortTermType=$veeamNASJobShortTermType veeamNASJobShortTerm=$veeamNASJobShortTerm"
    
    ##Comment the influx write while debugging
    echo "Writing veeam_em_nas_jobs to InfluxDB"       
    influx write \
    -t "$veeamInfluxDBToken" \
    -b "$veeamInfluxDBBucket" \
    -o "$veeamInfluxDBOrg" \
    -p s \
     "veeam_em_nas_jobs,veeamNASJobName=$veeamNASJobName,veeamVBR=$veeamVBR,veeamNASJobShortTermType=$veeamNASJobShortTermType veeamNASJobShortTerm=$veeamNASJobShortTerm"
  arrayNASJobs=$arrayNASJobs+1
done


##
# Veeam Enterprise Manager NAS Jobs Sessions. Overview of the NAS Jobs Sessions. Really useful to display the NAS Jobs Sessions
##
veeamEMUrl="https://$veeamRestServer:$veeamRestPort/api/nas/backupSessions?format=Entity"
veeamEMNASJobsSessionsUrl=$(curl -X GET "$veeamEMUrl" -H "Accept:application/json" -H "X-RestSvcSessionId: $veeamXRestSvcSessionId" -H "Cookie: X-RestSvcSessionId=$veeamXRestSvcSessionId" -H "Content-Length: 0" 2>&1 -k --silent | awk 'NR==1{sub(/^\xef\xbb\xbf/,"")}1'| jq '[.backupJobSessions[] | select(.creationTimeUTC> "'$timestart'")]')

    if [[ "$veeamDebug" == "true" ]]; then
        echo "DEBUG: Querying $veeamEMUrl"
        echo "DEBUG: Response: $veeamEMNASJobsSessionsUrl"
    fi

declare -i arrayNASJobsSessions=0
if [[ "$veeamEMNASJobsSessionsUrl" == "[]" ]]; then
    echo "There are not new veeam_em_nas_sessions since $timestart"
else
    for JobSessionUid in $(echo "$veeamEMNASJobsSessionsUrl" | jq -r '.[].jobUid'); do
        veeamNASJobName=$(echo "$veeamEMNASJobsSessionsUrl" | jq --raw-output ".[$arrayNASJobsSessions].jobName" | awk '{gsub(/ /,"\\ ");print}')
        veeamVBR=$(echo "$veeamEMNASJobsSessionsUrl" | jq --raw-output ".[$arrayNASJobsSessions].links[0].name" | awk '{gsub(/ /,"\\ ");print}')
        veeamNASJobResult=$(echo "$veeamEMNASJobsSessionsUrl" | jq --raw-output ".[$arrayNASJobsSessions].result") 
        case $veeamNASJobResult in
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
        veeamNASJobTime=$(echo "$veeamEMNASJobsSessionsUrl" | jq --raw-output ".[$arrayNASJobsSessions].creationTimeUTC")
        creationTimeUnix=$(date -d "$veeamNASJobTime" +"%s")
        veeamNASJobimeEnd=$(echo "$veeamEMNASJobsSessionsUrl" | jq --raw-output ".[$arrayNASJobsSessions].endTimeUTC")
        endTimeUnix=$(date -d "$veeamNASJobimeEnd" +"%s")
        veeamNASJobDuration=$(($endTimeUnix-$creationTimeUnix))   

        #echo "veeam_em_nas_sessions,veeamNASJobName=$veeamNASJobName,veeamVBR=$veeamVBR veeamNASJobResult=$jobStatus $creationTimeUnix"

        ##Comment the influx write while debugging
        echo "Writing veeam_em_nas_sessions to InfluxDB"    
        influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "veeam_em_nas_sessions,veeamNASJobName=$veeamNASJobName,veeamVBR=$veeamVBR veeamNASJobResult=$jobStatus,veeamNASJobDuration=$veeamNASJobDuration $creationTimeUnix"
      arrayNASJobsSessions=$arrayNASJobsSessions+1
    done
fi