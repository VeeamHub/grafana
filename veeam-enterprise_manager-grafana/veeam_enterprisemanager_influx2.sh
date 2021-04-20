#!/bin/bash
##      .SYNOPSIS
##      Grafana Dashboard for Veeam Enterprise Manager v10a - Using RestAPI to InfluxDB Script
##
##      .DESCRIPTION
##      This Script will query the Veeam Enterprise Manager RestAPI and send the data directly to InfluxDB, which can be used to present it to Grafana. 
##      The Script and the Grafana Dashboard it is provided as it is, and bear in mind you can not open support Tickets regarding this project. It is a Community Project
##
##      .Notes
##      NAME:  veeam_enterprisemanager_influx2.sh
##      ORIGINAL NAME: veeam_enterprisemanager_influx2.sh
##      LASTEDIT: 20/04/2021
##      VERSION: 1.0
##      KEYWORDS: Veeam, InfluxDB, Grafana
##
##      .Link
##      https://jorgedelacruz.es/
##      https://jorgedelacruz.uk/

##
# Configurations
##
# Endpoint URL for InfluxDB
veeamInfluxDBURL="http://YOURINFLUXSERVERIP" # Your InfluxDB Server, http://FQDN or https://FQDN if using SSL
veeamInfluxDBPort="8086" # Default Port
veeamInfluxDBBucket="veeam" # InfluxDB bucket name (not ID)
veeamInfluxDBToken='TOKEN' # InfluxDB access token with read/write privileges for the bucket
veeamInfluxDBOrg='ORG NAME' # InfluxDB organisation name (not ID)

# Endpoint URL for login action
veeamUsername="YOUREMUSER" # Your username, if using domain based account, please add it like user@domain.com (if you use domain\account it is not going to work!)
veeamPassword='YOUREMPASSWORD'
veeamRestServer="YOUREMSERVER" # IP or FQDN
veeamRestPort="9398" # Default Port
veeamJobSessions="100"
veeamAuth=$(echo -ne "$veeamUsername:$veeamPassword" | base64);
veeamSessionId=$(curl -X POST "https://$veeamRestServer:$veeamRestPort/api/sessionMngr/?v=latest" -H "Authorization:Basic $veeamAuth" -H "Content-Length: 0" -H "Accept: application/json" -k --silent | awk 'NR==1{sub(/^\xef\xbb\xbf/,"")}1' | jq --raw-output ".SessionId")
veeamXRestSvcSessionId=$(echo -ne "$veeamSessionId" | base64);

timestart=$(date --date="-1 days" +%FT%TZ)

##
# Veeam Enterprise Manager Overview. Overview of Backup Infrastructure and Job Status
##
veeamEMUrl="https://$veeamRestServer:$veeamRestPort/api/reports/summary/overview"
veeamEMOUrl=$(curl -X GET "$veeamEMUrl" -H "Accept:application/json" -H "X-RestSvcSessionId: $veeamXRestSvcSessionId" -H "Cookie: X-RestSvcSessionId=$veeamXRestSvcSessionId" -H "Content-Length: 0" 2>&1 -k --silent | awk 'NR==1{sub(/^\xef\xbb\xbf/,"")}1')

    veeamBackupServers=$(echo "$veeamEMOUrl" | jq --raw-output ".BackupServers")
    veeamProxyServers=$(echo "$veeamEMOUrl" | jq --raw-output ".ProxyServers")    
    veeamRepositoryServers=$(echo "$veeamEMOUrl" | jq --raw-output ".RepositoryServers")
    veeamRunningJobs=$(echo "$veeamEMOUrl" | jq --raw-output ".RunningJobs")    
    veeamScheduledJobs=$(echo "$veeamEMOUrl" | jq --raw-output ".ScheduledJobs")
    veeamSuccessfulVmLastestStates=$(echo "$veeamEMOUrl" | jq --raw-output ".SuccessfulVmLastestStates")    
    veeamWarningVmLastestStates=$(echo "$veeamEMOUrl" | jq --raw-output ".WarningVmLastestStates")
    veeamFailedVmLastestStates=$(echo "$veeamEMOUrl" | jq --raw-output ".FailedVmLastestStates")
    
    ##Un-comment the following echo for debugging    
    #echo "veeam_em_overview,host=$veeamRestServer veeamBackupServers=$veeamBackupServers,veeamProxyServers=$veeamProxyServers,veeamRepositoryServers=$veeamRepositoryServers,veeamRunningJobs=$veeamRunningJobs,veeamScheduledJobs=$veeamScheduledJobs,veeamSuccessfulVmLastestStates=$veeamSuccessfulVmLastestStates,veeamWarningVmLastestStates=$veeamWarningVmLastestStates,veeamFailedVmLastestStates=$veeamFailedVmLastestStates"
    
    ##Comment the Curl while debugging
    echo "Writing veeam_em_overview to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_em_overview,host=$veeamRestServer veeamBackupServers=$veeamBackupServers,veeamProxyServers=$veeamProxyServers,veeamRepositoryServers=$veeamRepositoryServers,veeamRunningJobs=$veeamRunningJobs,veeamScheduledJobs=$veeamScheduledJobs,veeamSuccessfulVmLastestStates=$veeamSuccessfulVmLastestStates,veeamWarningVmLastestStates=$veeamWarningVmLastestStates,veeamFailedVmLastestStates=$veeamFailedVmLastestStates"

##
# Veeam Enterprise Manager Overview. Overview of Virtual Machines
##
veeamEMUrl="https://$veeamRestServer:$veeamRestPort/api/reports/summary/vms_overview"
veeamEMOVMUrl=$(curl -X GET "$veeamEMUrl" -H "Accept:application/json" -H "X-RestSvcSessionId: $veeamXRestSvcSessionId" -H "Cookie: X-RestSvcSessionId=$veeamXRestSvcSessionId" -H "Content-Length: 0" 2>&1 -k --silent | awk 'NR==1{sub(/^\xef\xbb\xbf/,"")}1')

    veeamProtectedVms=$(echo "$veeamEMOVMUrl" | jq --raw-output ".ProtectedVms")
    veeamBackedUpVms=$(echo "$veeamEMOVMUrl" | jq --raw-output ".BackedUpVms")    
    veeamReplicatedVms=$(echo "$veeamEMOVMUrl" | jq --raw-output ".ReplicatedVms")
    veeamRestorePoints=$(echo "$veeamEMOVMUrl" | jq --raw-output ".RestorePoints")    
    veeamFullBackupPointsSize=$(echo "$veeamEMOVMUrl" | jq --raw-output ".FullBackupPointsSize")
    veeamIncrementalBackupPointsSize=$(echo "$veeamEMOVMUrl" | jq --raw-output ".IncrementalBackupPointsSize")    
    veeamReplicaRestorePointsSize=$(echo "$veeamEMOVMUrl" | jq --raw-output ".ReplicaRestorePointsSize")
    veeamSourceVmsSize=$(echo "$veeamEMOVMUrl" | jq --raw-output ".SourceVmsSize")    
    veeamSuccessBackupPercents=$(echo "$veeamEMOVMUrl" | jq --raw-output ".SuccessBackupPercents")
    
    #echo "veeam_em_overview_vms,host=$veeamRestServer veeamProtectedVms=$veeamProtectedVms,veeamBackedUpVms=$veeamBackedUpVms,veeamReplicatedVms=$veeamReplicatedVms,veeamRestorePoints=$veeamRestorePoints,veeamFullBackupPointsSize=$veeamFullBackupPointsSize,veeamIncrementalBackupPointsSize=$veeamIncrementalBackupPointsSize,veeamReplicaRestorePointsSize=$veeamReplicaRestorePointsSize,veeamSourceVmsSize=$veeamSourceVmsSize,veeamSuccessBackupPercents=$veeamSuccessBackupPercents"
    
    ##Comment the Curl while debugging
    echo "Writing veeam_em_overview_vms to InfluxDB"    
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_em_overview_vms,host=$veeamRestServer veeamProtectedVms=$veeamProtectedVms,veeamBackedUpVms=$veeamBackedUpVms,veeamReplicatedVms=$veeamReplicatedVms,veeamRestorePoints=$veeamRestorePoints,veeamFullBackupPointsSize=$veeamFullBackupPointsSize,veeamIncrementalBackupPointsSize=$veeamIncrementalBackupPointsSize,veeamReplicaRestorePointsSize=$veeamReplicaRestorePointsSize,veeamSourceVmsSize=$veeamSourceVmsSize,veeamSuccessBackupPercents=$veeamSuccessBackupPercents"

##
# Veeam Enterprise Manager Overview. Overview of Job Statistics
##
veeamEMUrl="https://$veeamRestServer:$veeamRestPort/api/reports/summary/job_statistics"
veeamEMOJobUrl=$(curl -X GET "$veeamEMUrl" -H "Accept:application/json" -H "X-RestSvcSessionId: $veeamXRestSvcSessionId" -H "Cookie: X-RestSvcSessionId=$veeamXRestSvcSessionId" -H "Content-Length: 0" 2>&1 -k --silent | awk 'NR==1{sub(/^\xef\xbb\xbf/,"")}1')

    veeamRunningJobs=$(echo "$veeamEMOJobUrl" | jq --raw-output ".RunningJobs")
    veeamScheduledJobs=$(echo "$veeamEMOJobUrl" | jq --raw-output ".ScheduledJobs")    
    veeamScheduledBackupJobs=$(echo "$veeamEMOJobUrl" | jq --raw-output ".ScheduledBackupJobs")
    veeamScheduledReplicaJobs=$(echo "$veeamEMOJobUrl" | jq --raw-output ".ScheduledReplicaJobs")    
    veeamTotalJobRuns=$(echo "$veeamEMOJobUrl" | jq --raw-output ".TotalJobRuns")
    veeamSuccessfulJobRuns=$(echo "$veeamEMOJobUrl" | jq --raw-output ".SuccessfulJobRuns")    
    veeamWarningsJobRuns=$(echo "$veeamEMOJobUrl" | jq --raw-output ".WarningsJobRuns")
    veeamFailedJobRuns=$(echo "$veeamEMOJobUrl" | jq --raw-output ".FailedJobRuns")    
    veeamMaxJobDuration=$(echo "$veeamEMOJobUrl" | jq --raw-output ".MaxJobDuration")    
    veeamMaxBackupJobDuration=$(echo "$veeamEMOJobUrl" | jq --raw-output ".MaxBackupJobDuration")    
    veeamMaxReplicaJobDuration=$(echo "$veeamEMOJobUrl" | jq --raw-output ".MaxReplicaJobDuration")
    veeamMaxDurationBackupJobName=$(echo "$veeamEMOJobUrl" | jq --raw-output ".MaxDurationBackupJobName" | awk '{gsub(/ /,"\\ ");print}')
    [[ ! -z "$veeamMaxDurationBackupJobName" ]] || veeamMaxDurationBackupJobName="None"
    veeamMaxDurationReplicaJobName=$(echo "$veeamEMOJobUrl" | jq --raw-output ".MaxDurationReplicaJobName" | awk '{gsub(/ /,"\\ ");print}')
    [[ ! -z "$veeamMaxDurationReplicaJobName" ]] || veeamMaxDurationReplicaJobName="None"
    
    #echo "veeam_em_overview_jobs,host=$veeamRestServer,veeamMaxDurationBackupJobName=$veeamMaxDurationBackupJobName,veeamMaxDurationReplicaJobName=$veeamMaxDurationReplicaJobName veeamRunningJobs=$veeamRunningJobs,veeamScheduledJobs=$veeamScheduledJobs,veeamScheduledBackupJobs=$veeamScheduledBackupJobs,veeamScheduledReplicaJobs=$veeamScheduledReplicaJobs,veeamTotalJobRuns=$veeamTotalJobRuns,veeamSuccessfulJobRuns=$veeamSuccessfulJobRuns,veeamWarningsJobRuns=$veeamWarningsJobRuns,veeamFailedJobRuns=$veeamFailedJobRuns,veeamMaxJobDuration=$veeamMaxJobDuration,veeamMaxBackupJobDuration=$veeamMaxBackupJobDuration,veeamMaxReplicaJobDuration=$veeamMaxReplicaJobDuration"
    
    ##Comment the Curl while debugging
    echo "Writing veeam_em_overview_jobs to InfluxDB"     
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_em_overview_jobs,host=$veeamRestServer,veeamMaxDurationBackupJobName=$veeamMaxDurationBackupJobName,veeamMaxDurationReplicaJobName=$veeamMaxDurationReplicaJobName veeamRunningJobs=$veeamRunningJobs,veeamScheduledJobs=$veeamScheduledJobs,veeamScheduledBackupJobs=$veeamScheduledBackupJobs,veeamScheduledReplicaJobs=$veeamScheduledReplicaJobs,veeamTotalJobRuns=$veeamTotalJobRuns,veeamSuccessfulJobRuns=$veeamSuccessfulJobRuns,veeamWarningsJobRuns=$veeamWarningsJobRuns,veeamFailedJobRuns=$veeamFailedJobRuns,veeamMaxJobDuration=$veeamMaxJobDuration,veeamMaxBackupJobDuration=$veeamMaxBackupJobDuration,veeamMaxReplicaJobDuration=$veeamMaxReplicaJobDuration"

##
# Veeam Enterprise Manager Repositories. Overview of Repositories
##
veeamEMUrl="https://$veeamRestServer:$veeamRestPort/api/repositories?format=Entity"
veeamEMORepoUrl=$(curl -X GET "$veeamEMUrl" -H "Accept:application/json" -H "X-RestSvcSessionId: $veeamXRestSvcSessionId" -H "Cookie: X-RestSvcSessionId=$veeamXRestSvcSessionId" -H "Content-Length: 0" 2>&1 -k --silent | awk 'NR==1{sub(/^\xef\xbb\xbf/,"")}1')

declare -i arrayrepo=0
for Kind in $(echo "$veeamEMORepoUrl" | jq -r '.Repositories[].Kind'); do
    veeamRepositoryName=$(echo "$veeamEMORepoUrl" | jq --raw-output ".Repositories[$arrayrepo].Name" | awk '{gsub(/ /,"\\ ");print}')
    veeamVBR=$(echo "$veeamEMORepoUrl" | jq --raw-output ".Repositories[$arrayrepo].Links[0].Name" | awk '{gsub(/ /,"\\ ");print}') 
    veeamRepositoryCapacity=$(echo "$veeamEMORepoUrl" | jq --raw-output ".Repositories[$arrayrepo].Capacity")
    veeamRepositoryFreeSpace=$(echo "$veeamEMORepoUrl" | jq --raw-output ".Repositories[$arrayrepo].FreeSpace")    
    veeamRepositoryKind=$(echo "$veeamEMORepoUrl" | jq --raw-output ".Repositories[$arrayrepo].Kind")
  
    #echo "veeam_em_overview_repositories,host=$veeamRestServer,veeamRepositoryName=$veeamRepositoryName veeamRepositoryCapacity=$veeamRepositoryCapacity,veeamRepositoryFreeSpace=$veeamRepositoryFreeSpace,veeamRepositoryBackupSize=$veeamRepositoryBackupSize"
    
    ##Comment the Curl while debugging
    echo "Writing veeam_em_overview_repositories to InfluxDB"      
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_em_overview_repositories,veeamVBR=$veeamVBR,veeamRepositoryName=$veeamRepositoryName,veeamRepositoryKind=$veeamRepositoryKind veeamRepositoryCapacity=$veeamRepositoryCapacity,veeamRepositoryFreeSpace=$veeamRepositoryFreeSpace"
  arrayrepo=$arrayrepo+1
done

##
# Veeam Enterprise Manager Backup Servers. Overview of Backup Repositories
##
veeamEMUrl="https://$veeamRestServer:$veeamRestPort/api/backupServers?format=Entity"
veeamEMOBackupServersUrl=$(curl -X GET "$veeamEMUrl" -H "Accept:application/json" -H "X-RestSvcSessionId: $veeamXRestSvcSessionId" -H "Cookie: X-RestSvcSessionId=$veeamXRestSvcSessionId" -H "Content-Length: 0" 2>&1 -k --silent | awk 'NR==1{sub(/^\xef\xbb\xbf/,"")}1')

declare -i arraybackupservers=0
for Name in $(echo "$veeamEMOBackupServersUrl" | jq -r '.BackupServers[].Name'); do
    veeamVBR=$(echo "$veeamEMOBackupServersUrl" | jq --raw-output ".BackupServers[$arraybackupservers].Name" | awk '{gsub(/ /,"\\ ");print}')
    veeamBackupServersPort=$(echo "$veeamEMOBackupServersUrl" | jq --raw-output ".BackupServers[$arraybackupservers].Port")
    veeamBackupServersVersion=$(echo "$veeamEMOBackupServersUrl" | jq --raw-output ".BackupServers[$arraybackupservers].Version" | awk '{gsub(/ /,"\\ ");print}')
       case $veeamBackupServersVersion in
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
        esac

        #echo "veeam_em_backup_servers,veeamVBR=$veeamVBR,veeamBackupServersVersion=$veeamBackupServersVersion,veeamBackupServersVersionM=$veeamBackupServersVersionM veeamBackupServersPort=$veeamBackupServersPort"
        ##Comment the Curl while debugging
        echo "Writing veeam_em_backup_servers to InfluxDB"          
        curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_em_backup_servers,veeamVBR=$veeamVBR,veeamBackupServersVersion=$veeamBackupServersVersion,veeamBackupServersVersionM=$veeamBackupServersVersionM veeamBackupServersPort=$veeamBackupServersPort"
  arraybackupservers=$arraybackupservers+1
done

##
# Veeam Enterprise Manager Backup Job Sessions. Overview of Backup Job Sessions
##
veeamEMUrl="https://$veeamRestServer:$veeamRestPort/api/backupSessions?format=Entity"
veeamEMJobSessionsUrl=$(curl -X GET "$veeamEMUrl" -H "Accept:application/json" -H "X-RestSvcSessionId: $veeamXRestSvcSessionId" -H "Cookie: X-RestSvcSessionId=$veeamXRestSvcSessionId" -H "Content-Length: 0" 2>&1 -k --silent | awk 'NR==1{sub(/^\xef\xbb\xbf/,"")}1' | jq '[.BackupJobSessions[] | select(.CreationTimeUTC> "'$timestart'")]')

declare -i arrayjobsessions=0
if [[ "$veeamEMJobSessionsUrl" == "[]" ]]; then
    echo "There are not new veeam_em_job_sessions since $timestart"
else
    for JobUid in $(echo "$veeamEMJobSessionsUrl" | jq -r '.[].JobUid'); do
        veeamBackupSessionsName=$(echo "$veeamEMJobSessionsUrl" | jq --raw-output ".[$arrayjobsessions].JobName" | awk '{gsub(/ /,"\\ ");print}')
        veeamVBR=$(echo "$veeamEMJobSessionsUrl" | jq --raw-output ".[$arrayjobsessions].Links[0].Name" | awk '{gsub(/ /,"\\ ");print}') 
        veeamBackupSessionsJobType=$(echo "$veeamEMJobSessionsUrl" | jq --raw-output ".[$arrayjobsessions].JobType") 
        veeamBackupSessionsJobState=$(echo "$veeamEMJobSessionsUrl" | jq --raw-output ".[$arrayjobsessions].State")
        veeamBackupSessionsJobResult=$(echo "$veeamEMJobSessionsUrl" | jq --raw-output ".[$arrayjobsessions].Result")     
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
        veeamBackupSessionsTime=$(echo "$veeamEMJobSessionsUrl" | jq --raw-output ".[$arrayjobsessions].CreationTimeUTC")
        creationTimeUnix=$(date -d "$veeamBackupSessionsTime" +"%s")
        veeamBackupSessionsTimeEnd=$(echo "$veeamEMJobSessionsUrl" | jq --raw-output ".[$arrayjobsessions].EndTimeUTC")
        endTimeUnix=$(date -d "$veeamBackupSessionsTimeEnd" +"%s")
        veeamBackupSessionsTimeDuration=$(($endTimeUnix-$creationTimeUnix))

        #echo "veeam_em_job_sessions,veeamBackupSessionsName=$veeamBackupSessionsName,veeamVBR=$veeamVBR,veeamBackupSessionsJobType=$veeamBackupSessionsJobType,veeamBackupSessionsJobState=$veeamBackupSessionsJobState veeamBackupSessionsJobResult=$jobStatus $creationTimeUnix"

        ##Comment the Curl while debugging
        echo "Writing veeam_em_job_sessions to InfluxDB"      
        curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_em_job_sessions,veeamBackupSessionsName=$veeamBackupSessionsName,veeamVBR=$veeamVBR,veeamBackupSessionsJobType=$veeamBackupSessionsJobType,veeamBackupSessionsJobState=$veeamBackupSessionsJobState veeamBackupSessionsJobResult=$jobStatus,veeamBackupSessionsTimeDuration=$veeamBackupSessionsTimeDuration $creationTimeUnix"
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
veeamEMJobSessionsVMUrl=$(curl -X GET "$veeamEMUrl" -H "Accept:application/json" -H "X-RestSvcSessionId: $veeamXRestSvcSessionId" -H "Cookie: X-RestSvcSessionId=$veeamXRestSvcSessionId" -H "Content-Length: 0" 2>&1 -k --silent | awk 'NR==1{sub(/^\xef\xbb\xbf/,"")}1' | jq '[.BackupTaskSessions[] | select(.CreationTimeUTC> "'$timestart'")]')

declare -i arrayjobsessionsvm=0
if [[ "$veeamEMJobSessionsVMUrl" == "[]" ]]; then
    echo "There are not new veeam_em_job_sessionsvm since $timestart"
else
    for JobSessionUid in $(echo "$veeamEMJobSessionsVMUrl" | jq -r '.[].JobSessionUid'); do
        veeamBackupSessionsVmDisplayName=$(echo "$veeamEMJobSessionsVMUrl" | jq --raw-output ".[$arrayjobsessionsvm].VmDisplayName" | awk '{gsub(/ /,"\\ ");print}')
        veeamVBR=$(echo "$veeamEMJobSessionsVMUrl" | jq --raw-output ".[$arrayjobsessionsvm].Links[0].Name" | awk '{gsub(/ /,"\\ ");print}') 
        veeamBackupSessionsTotalSize=$(echo "$veeamEMJobSessionsVMUrl" | jq --raw-output ".[$arrayjobsessionsvm].TotalSize")    
        veeamBackupSessionsJobVMState=$(echo "$veeamEMJobSessionsVMUrl" | jq --raw-output ".[$arrayjobsessionsvm].State")
        veeamBackupSessionsJobVMResult=$(echo "$veeamEMJobSessionsVMUrl" | jq --raw-output ".[$arrayjobsessionsvm].Result") 
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
        veeamBackupSessionsVMTime=$(echo "$veeamEMJobSessionsVMUrl" | jq --raw-output ".[$arrayjobsessionsvm].CreationTimeUTC")
        creationTimeUnix=$(date -d "$veeamBackupSessionsVMTime" +"%s")
        veeamBackupSessionsVMTimeEnd=$(echo "$veeamEMJobSessionsVMUrl" | jq --raw-output ".[$arrayjobsessionsvm].EndTimeUTC")
        endTimeUnix=$(date -d "$veeamBackupSessionsVMTimeEnd" +"%s")
        veeamBackupSessionsVMDuration=$(($endTimeUnix-$creationTimeUnix))

        #echo "veeam_em_job_sessionsvm,veeamBackupSessionsVmDisplayName=$veeamBackupSessionsVmDisplayName,veeamVBR=$veeamVBR,veeamBackupSessionsJobVMState=$veeamBackupSessionsJobVMState veeamBackupSessionsTotalSize=$veeamBackupSessionsTotalSize,veeamBackupSessionsJobVMResult=$jobStatus $creationTimeUnix"

        ##Comment the Curl while debugging
        echo "Writing veeam_em_job_sessionsvm to InfluxDB"     
        curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_em_job_sessionsvm,veeamBackupSessionsVmDisplayName=$veeamBackupSessionsVmDisplayName,veeamVBR=$veeamVBR,veeamBackupSessionsJobVMState=$veeamBackupSessionsJobVMState veeamBackupSessionsTotalSize=$veeamBackupSessionsTotalSize,veeamBackupSessionsJobVMResult=$jobStatus,veeamBackupSessionsVMDuration=$veeamBackupSessionsVMDuration $creationTimeUnix"
      arrayjobsessionsvm=$arrayjobsessionsvm+1
    done
fi

##
# Veeam Enterprise Manager Replica Job Sessions. Overview of Replica Job Sessions
##
veeamEMUrl="https://$veeamRestServer:$veeamRestPort/api/replicaSessions?format=Entity"
veeamEMJobReplicaSessionsUrl="$(curl -X GET "$veeamEMUrl" -H "Accept:application/json" -H "X-RestSvcSessionId: $veeamXRestSvcSessionId" -H "Cookie: X-RestSvcSessionId=$veeamXRestSvcSessionId" -H "Content-Length: 0" 2>&1 -k --silent | awk 'NR==1{sub(/^\xef\xbb\xbf/,"")}1' | jq '[.ReplicaJobSessions[] | select(.CreationTimeUTC> "'$timestart'")]')"

declare -i arrayjobrepsessions=0
if [[ "$veeamEMJobReplicaSessionsUrl" == "[]" ]]; then
    echo "There are not new veeam_em_job_sessions since $timestart"
else
    for JobUid in $(echo "$veeamEMJobReplicaSessionsUrl" | jq -r '.[].JobUid'); do
        veeamReplicaSessionsName=$(echo "$veeamEMJobReplicaSessionsUrl" | jq --raw-output ".[$arrayjobrepsessions].JobName" | awk '{gsub(/ /,"\\ ");print}')
        veeamVBR=$(echo "$veeamEMJobReplicaSessionsUrl" | jq --raw-output ".[$arrayjobrepsessions].Links[0].Name" | awk '{gsub(/ /,"\\ ");print}') 
        veeamReplicaSessionsJobType=$(echo "$veeamEMJobReplicaSessionsUrl" | jq --raw-output ".[$arrayjobrepsessions].JobType") 
        veeamReplicaSessionsJobState=$(echo "$veeamEMJobReplicaSessionsUrl" | jq --raw-output ".[$arrayjobrepsessions].State")
        veeamReplicaSessionsJobResult=$(echo "$veeamEMJobReplicaSessionsUrl" | jq --raw-output ".[$arrayjobrepsessions].Result")     
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
        veeamReplicaSessionsTime=$(echo "$veeamEMJobReplicaSessionsUrl" | jq --raw-output ".[$arrayjobrepsessions].CreationTimeUTC")
        creationTimeUnix=$(date -d "$veeamReplicaSessionsTime" +"%s")
        veeamReplicaSessionsTimeEnd=$(echo "$veeamEMJobReplicaSessionsUrl" | jq --raw-output ".[$arrayjobrepsessions].EndTimeUTC")
        endTimeUnix=$(date -d "$veeamReplicaSessionsTimeEnd" +"%s")
        veeamReplicaSessionsDuration=$(($endTimeUnix-$creationTimeUnix))

        #echo "veeam_em_job_sessions,veeamReplicaSessionsName=$veeamReplicaSessionsName,veeamVBR=$veeamVBR,veeamReplicaSessionsJobType=$veeamReplicaSessionsJobType,veeamReplicaSessionsJobState=$veeamReplicaSessionsJobState veeamReplicaSessionsJobResult=$jobStatus $creationTimeUnix"

        ##Comment the Curl while debugging
        echo "Writing veeam_em_job_sessions Replica to InfluxDB"     
        curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_em_job_sessions,veeamReplicaSessionsName=$veeamReplicaSessionsName,veeamVBR=$veeamVBR,veeamReplicaSessionsJobType=$veeamReplicaSessionsJobType,veeamReplicaSessionsJobState=$veeamReplicaSessionsJobState veeamReplicaSessionsJobResult=$jobStatus,veeamReplicaSessionsDuration=$veeamReplicaSessionsDuration $creationTimeUnix"
      arrayjobrepsessions=$arrayjobrepsessions+1
    done
fi

##
# Veeam Enterprise Manager Replica Job Sessions per VM. Overview of Replica Job Sessions per VM. Really useful to display if a VM it is protected or not
##
veeamEMUrl="https://$veeamRestServer:$veeamRestPort/api/replicaTaskSessions?format=Entity"
veeamEMJobReplicaSessionsVMUrl=$(curl -X GET "$veeamEMUrl" -H "Accept:application/json" -H "X-RestSvcSessionId: $veeamXRestSvcSessionId" -H "Cookie: X-RestSvcSessionId=$veeamXRestSvcSessionId" -H "Content-Length: 0" 2>&1 -k --silent | awk 'NR==1{sub(/^\xef\xbb\xbf/,"")}1' | jq '[.ReplicaTaskSessions[] | select(.CreationTimeUTC> "'$timestart'")]')

declare -i arrayjobrepsessionsvm=0
if [[ "$veeamEMJobReplicaSessionsVMUrl" == "[]" ]]; then
    echo "There are not new veeam_em_job_sessionsvm since $timestart"
else
    for JobSessionUid in $(echo "$veeamEMJobReplicaSessionsVMUrl" | jq -r '.[].JobSessionUid'); do
        veeamReplicaSessionsVmDisplayName=$(echo "$veeamEMJobReplicaSessionsVMUrl" | jq --raw-output ".[$arrayjobrepsessionsvm].VmDisplayName" | awk '{gsub(/ /,"\\ ");print}')
        veeamVBR=$(echo "$veeamEMJobReplicaSessionsVMUrl" | jq --raw-output ".[$arrayjobrepsessionsvm].Links[0].Name" | awk '{gsub(/ /,"\\ ");print}') 
        veeamReplicaSessionsTotalSize=$(echo "$veeamEMJobReplicaSessionsVMUrl" | jq --raw-output ".[$arrayjobrepsessionsvm].TotalSize")    
        veeamReplicaSessionsJobVMState=$(echo "$veeamEMJobReplicaSessionsVMUrl" | jq --raw-output ".[$arrayjobrepsessionsvm].State")
        veeamReplicaSessionsJobVMResult=$(echo "$veeamEMJobReplicaSessionsVMUrl" | jq --raw-output ".[$arrayjobrepsessionsvm].Result") 
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
        veeamReplicaSessionsVMTime=$(echo "$veeamEMJobReplicaSessionsVMUrl" | jq --raw-output ".[$arrayjobrepsessionsvm].CreationTimeUTC")
        creationTimeUnix=$(date -d "$veeamReplicaSessionsVMTime" +"%s")
        veeamReplicaSessionsVMTimeEnd=$(echo "$veeamEMJobReplicaSessionsVMUrl" | jq --raw-output ".[$arrayjobrepsessionsvm].EndTimeUTC")
        endTimeUnix=$(date -d "$veeamReplicaSessionsVMTimeEnd" +"%s")
        veeamReplicaSessionsVMDuration=$(($endTimeUnix-$creationTimeUnix))

        #echo "veeam_em_job_sessionsvm,veeamReplicaSessionsVmDisplayName=$veeamReplicaSessionsVmDisplayName,veeamVBR=$veeamVBR,veeamReplicaSessionsJobVMState=$veeamReplicaSessionsJobVMState veeamReplicaSessionsTotalSize=$veeamReplicaSessionsTotalSize,veeamReplicaSessionsJobVMResult=$jobStatus $creationTimeUnix"

        ##Comment the Curl while debugging
        echo "Writing veeam_em_job_sessionsvm Replica to InfluxDB"     
        curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_em_job_sessionsvm,veeamReplicaSessionsVmDisplayName=$veeamReplicaSessionsVmDisplayName,veeamVBR=$veeamVBR,veeamReplicaSessionsJobVMState=$veeamReplicaSessionsJobVMState veeamReplicaSessionsTotalSize=$veeamReplicaSessionsTotalSize,veeamReplicaSessionsJobVMResult=$jobStatus,veeamReplicaSessionsVMDuration=$veeamReplicaSessionsVMDuration $creationTimeUnix"
      arrayjobrepsessionsvm=$arrayjobrepsessionsvm+1
    done
fi

##
# Veeam Enterprise Manager Backup Agent Status. Overview of the Veeam Agents. Really useful to display if an Agent it is uo to date and also the status
##
veeamEMUrl="https://$veeamRestServer:$veeamRestPort/api/agents/discoveredComputers?format=Entity"
veeamEMAgentUrl=$(curl -X GET "$veeamEMUrl" -H "Accept:application/json" -H "X-RestSvcSessionId: $veeamXRestSvcSessionId" -H "Cookie: X-RestSvcSessionId=$veeamXRestSvcSessionId" -H "Content-Length: 0" 2>&1 -k --silent | awk 'NR==1{sub(/^\xef\xbb\xbf/,"")}1')

declare -i arrayagent=0
for JobSessionUid in $(echo "$veeamEMAgentUrl" | jq -r '.DiscoveredComputers[].UID'); do
    veeamAgentName=$(echo "$veeamEMAgentUrl" | jq --raw-output ".DiscoveredComputers[$arrayagent].Name" | awk '{gsub(/ /,"\\ ");print}')
    veeamVBR=$(echo "$veeamEMAgentUrl" | jq --raw-output ".DiscoveredComputers[$arrayagent].Links[0].Name" | awk '{gsub(/ /,"\\ ");print}') 
    veeamAgentHostStatusCheck=$(echo "$veeamEMAgentUrl" | jq --raw-output ".DiscoveredComputers[$arrayagent].HostStatus")
    case $veeamAgentHostStatusCheck in
        "Online")
            veeamAgentHostStatus="1"
        ;;
        "Offline")
            veeamAgentHostStatus="2"
        ;;
        esac
    veeamAgentStatusCheck=$(echo "$veeamEMAgentUrl" | jq --raw-output ".DiscoveredComputers[$arrayagent].AgentStatus")
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
        esac
    veeamAgentVersion=$(echo "$veeamEMAgentUrl" | jq --raw-output ".DiscoveredComputers[$arrayagent].AgentVersion" | awk '{gsub(/ /,"\\ ");print}') 
    veeamAgentOsVersion=$(echo "$veeamEMAgentUrl" | jq --raw-output ".DiscoveredComputers[$arrayagent].OsVersion" | awk -F',' '{$3=i; print}' | awk '{gsub(/ /,"\\ ");print}')
   
    #echo "veeam_em_agents,veeamAgentName=$veeamAgentName,veeamVBR=$veeamVBR,veeamAgentVersion=$veeamAgentVersion,veeamAgentOsVersion=$veeamAgentOsVersion veeamAgentStatus=$veeamAgentStatus,veeamAgentHostStatus=$veeamAgentHostStatus"
    
    ##Comment the Curl while debugging
    echo "Writing veeam_em_agents to InfluxDB"      
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_em_agents,veeamAgentName=$veeamAgentName,veeamAgentOsVersion=$veeamAgentOsVersion,veeamVBR=$veeamVBR,veeamAgentVersion=$veeamAgentVersion veeamAgentStatus=$veeamAgentStatus,veeamAgentHostStatus=$veeamAgentHostStatus"
  arrayagent=$arrayagent+1
done


##
# Veeam Enterprise Manager NAS Jobs. Overview of the NAS Jobs. Really useful to display the NAS Jobs
##
veeamEMUrl="https://$veeamRestServer:$veeamRestPort/api/nas/jobs?format=Entity"
veeamEMNASJobsUrl=$(curl -X GET "$veeamEMUrl" -H "Accept:application/json" -H "X-RestSvcSessionId: $veeamXRestSvcSessionId" -H "Cookie: X-RestSvcSessionId=$veeamXRestSvcSessionId" -H "Content-Length: 0" 2>&1 -k --silent | awk 'NR==1{sub(/^\xef\xbb\xbf/,"")}1')

declare -i arrayNASJobs=0
for JobSessionUid in $(echo "$veeamEMNASJobsUrl" | jq -r '.NASJobs[].UID'); do
    veeamNASJobName=$(echo "$veeamEMNASJobsUrl" | jq --raw-output ".NASJobs[$arrayNASJobs].Name" | awk '{gsub(/ /,"\\ ");print}')
    veeamNASJobPath=$(echo "$veeamEMNASJobsUrl" | jq --raw-output ".NASJobs[$arrayNASJobs].Includes.NASObjects[].FileOrFolder" | awk '{gsub(/ /,"\\ ");print}')
    veeamNASJobExclusions=$(echo "$veeamEMNASJobsUrl" | jq --raw-output ".NASJobs[$arrayNASJobs].Includes.NASObjects[].InclusionMask.Extensions[]" | awk '{gsub(/ /,"\\ ");print}')
    veeamVBR=$(echo "$veeamEMNASJobsUrl" | jq --raw-output ".NASJobs[$arrayNASJobs].Links[0].Name" | awk '{gsub(/ /,"\\ ");print}')
    veeamNASJobShortTerm=$(echo "$veeamEMNASJobsUrl" | jq --raw-output ".NASJobs[$arrayNASJobs].StorageOptions.ShorttermRetentionPeriod")
    veeamNASJobShortTermType=$(echo "$veeamEMNASJobsUrl" | jq --raw-output ".NASJobs[$arrayNASJobs].StorageOptions.ShorttermRetentionType")
   
    #echo "veeam_em_nas_jobs,veeamNASJobName=$veeamNASJobName,veeamVBR=$veeamVBR,veeamNASJobPath=$veeamNASJobPath,veeamNASJobExclusions=$veeamNASJobExclusions"
    
    ##Comment the Curl while debugging
    echo "Writing veeam_em_nas_jobs to InfluxDB"       
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_em_nas_jobs,veeamNASJobName=$veeamNASJobName,veeamVBR=$veeamVBR,veeamNASJobPath=$veeamNASJobPath,veeamNASJobExclusions=$veeamNASJobExclusions,veeamNASJobShortTermType=$veeamNASJobShortTermType veeamNASJobShortTerm=$veeamNASJobShortTerm"
  arrayNASJobs=$arrayNASJobs+1
done


##
# Veeam Enterprise Manager NAS Jobs Sessions. Overview of the NAS Jobs Sessions. Really useful to display the NAS Jobs Sessions
##
veeamEMUrl="https://$veeamRestServer:$veeamRestPort/api/nas/backupSessions?format=Entity"
veeamEMNASJobsSessionsUrl=$(curl -X GET "$veeamEMUrl" -H "Accept:application/json" -H "X-RestSvcSessionId: $veeamXRestSvcSessionId" -H "Cookie: X-RestSvcSessionId=$veeamXRestSvcSessionId" -H "Content-Length: 0" 2>&1 -k --silent | awk 'NR==1{sub(/^\xef\xbb\xbf/,"")}1'| jq '[.BackupJobSessions[] | select(.CreationTimeUTC> "'$timestart'")]')

declare -i arrayNASJobsSessions=0
if [[ "$veeamEMNASJobsSessionsUrl" == "[]" ]]; then
    echo "There are not new veeam_em_nas_sessions since $timestart"
else
    for JobSessionUid in $(echo "$veeamEMNASJobsSessionsUrl" | jq -r '.[].JobUid'); do
        veeamNASJobName=$(echo "$veeamEMNASJobsSessionsUrl" | jq --raw-output ".[$arrayNASJobsSessions].JobName" | awk '{gsub(/ /,"\\ ");print}')
        veeamVBR=$(echo "$veeamEMNASJobsSessionsUrl" | jq --raw-output ".[$arrayNASJobsSessions].Links[0].Name" | awk '{gsub(/ /,"\\ ");print}')
        veeamNASJobResult=$(echo "$veeamEMNASJobsSessionsUrl" | jq --raw-output ".[$arrayNASJobsSessions].Result") 
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
        veeamNASJobTime=$(echo "$veeamEMNASJobsSessionsUrl" | jq --raw-output ".[$arrayNASJobsSessions].CreationTimeUTC")
        creationTimeUnix=$(date -d "$veeamNASJobTime" +"%s")
        veeamNASJobimeEnd=$(echo "$veeamEMNASJobsSessionsUrl" | jq --raw-output ".[$arrayNASJobsSessions].EndTimeUTC")
        endTimeUnix=$(date -d "$veeamNASJobimeEnd" +"%s")
        veeamNASJobDuration=$(($endTimeUnix-$creationTimeUnix))   

        #echo "veeam_em_nas_sessions,veeamNASJobName=$veeamNASJobName,veeamVBR=$veeamVBR veeamNASJobResult=$jobStatus $creationTimeUnix"

        ##Comment the Curl while debugging
        echo "Writing veeam_em_nas_sessions to InfluxDB"    
        curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_em_nas_sessions,veeamNASJobName=$veeamNASJobName,veeamVBR=$veeamVBR veeamNASJobResult=$jobStatus,veeamNASJobDuration=$veeamNASJobDuration $creationTimeUnix"
      arrayNASJobsSessions=$arrayNASJobsSessions+1
    done
fi
