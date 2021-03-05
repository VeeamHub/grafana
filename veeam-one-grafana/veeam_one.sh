#!/bin/bash
##      .SYNOPSIS
##      Grafana Dashboard for Veeam ONE v11 - Using API to InfluxDB Script
## 
##      .DESCRIPTION
##      This Script will query the Veeam ONE v11 UNOFFICIAL AND UNSUPPORTED API and send the data directly to InfluxDB, which can be used to present it to Grafana. 
##      The Script and the Grafana Dashboard it is provided as it is, and bear in mind you can not open support Tickets regarding this project. It is a Community Project
##	
##      .Notes
##      NAME:  veeam_one.sh
##      ORIGINAL NAME: veeam_one.sh
##      LASTEDIT: 05/03/2021
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
veeamUsername="YOURVEEAMONEUSER" #Usually domain\user or user@domain.tld
veeamPassword="YOURVEEAMONEPASS"
veeamONEServer="https://YOURVEEAMONEIP" #You can use FQDN if you like as well
veeamONEPort="1239" #Default Port

veeamBearer=$(curl -X POST --header "Content-Type: application/x-www-form-urlencoded" --header "Accept: application/json" -H  "Content-Type: application/x-www-form-urlencoded" -d "username=$veeamUsername&password=$veeamPassword&rememberMe=&asCurrentUser=&grant_type=password&refresh_token=" "$veeamONEServer:$veeamONEPort/api/token" -k --silent | jq -r '.access_token')

##
# Building the ID to Query - Thanks, Sergey Zhukov
#
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v1/dashboards"
veeamONEFoundationUrl=$(curl -X GET $veeamONEURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)
    VBRDashboardID=$(echo "$veeamONEFoundationUrl" | jq --raw-output '.[] | select(.name | startswith("Veeam Backup and Replication")) | .dashboardId')

veeamONEURL="$veeamONEServer:$veeamONEPort/api/v1/dashboards/$VBRDashboardID"
veeamONEFoundationWidgetUrl=$(curl -X GET $veeamONEURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)
    VBRWBackupInfraID=$(echo "$veeamONEFoundationWidgetUrl" | jq --raw-output '.dashboardWidgets[] | select(.caption| startswith("Backup Infrastructure Inventory")) | .widgetId')    
    VBRWProtectedVMSID=$(echo "$veeamONEFoundationWidgetUrl" | jq --raw-output '.dashboardWidgets[] | select(.caption| startswith("Protected VMs Overview")) | .widgetId')    
    VBRWBackupWindowID=$(echo "$veeamONEFoundationWidgetUrl" | jq --raw-output '.dashboardWidgets[] | select(.caption| startswith("Backup Window")) | .widgetId')    
    VBRWTopJobsID=$(echo "$veeamONEFoundationWidgetUrl" | jq --raw-output '.dashboardWidgets[] | select(.caption| startswith("Top Jobs by Duration")) | .widgetId')    
    VBRWJobStatusID=$(echo "$veeamONEFoundationWidgetUrl" | jq --raw-output '.dashboardWidgets[] | select(.caption| startswith("Jobs Status")) | .widgetId')    
    VBRWTopReposID=$(echo "$veeamONEFoundationWidgetUrl" | jq --raw-output '.dashboardWidgets[] | select(.caption| startswith("Top Repositories by Used Space")) | .widgetId')    

veeamONEURL="$veeamONEServer:$veeamONEPort/api/v1/dashboards/$VBRDashboardID/widgets/$VBRWBackupInfraID/datasources"
veeamONEFounDSBKIUrl=$(curl -X GET $veeamONEURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)
    VBRWBackupInfraDSID=$(echo "$veeamONEFounDSBKIUrl" | jq --raw-output '.[].datasourceId')

veeamONEURL="$veeamONEServer:$veeamONEPort/api/v1/dashboards/$VBRDashboardID/widgets/$VBRWProtectedVMSID/datasources"
veeamONEFounDSPVMUrl=$(curl -X GET $veeamONEURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)
    VBRWProtectedVMSDSID=$(echo "$veeamONEFounDSPVMUrl" | jq --raw-output '.[].datasourceId')
    
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v1/dashboards/$VBRDashboardID/widgets/$VBRWBackupWindowID/datasources"
veeamONEFounDSBKWUrl=$(curl -X GET $veeamONEURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)
    VBRWBackupWindowDSID=$(echo "$veeamONEFounDSBKWUrl" | jq --raw-output '.[].datasourceId')
    
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v1/dashboards/$VBRDashboardID/widgets/$VBRWTopJobsID/datasources"
veeamONEFounDSTopJUrl=$(curl -X GET $veeamONEURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)
    VBRWTopJobsDSID=$(echo "$veeamONEFounDSTopJUrl" | jq --raw-output '.[].datasourceId')
    
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v1/dashboards/$VBRDashboardID/widgets/$VBRWJobStatusID/datasources"
veeamONEFounDSJobSUrl=$(curl -X GET $veeamONEURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)
    VBRWJobStatusDSID=$(echo "$veeamONEFounDSJobSUrl" | jq --raw-output '.[].datasourceId')
    
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v1/dashboards/$VBRDashboardID/widgets/$VBRWTopReposID/datasources"
veeamONEFounDSTopRUrl=$(curl -X GET $veeamONEURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)
    VBRWTopReposDSID=$(echo "$veeamONEFounDSTopRUrl" | jq --raw-output '.[].datasourceId')

##
# Veeam ONE About
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v1/about"
veeamONEAboutUrl=$(curl -X GET $veeamONEURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)
    version=$(echo "$veeamONEAboutUrl" | jq --raw-output ".version")
    voneserver=$(echo "$veeamONEAboutUrl" | jq --raw-output ".machine")
    
    #echo "$version $voneserver "

    ##Comment the Curl while debugging
    echo "Writing veeam_ONE_about to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=s&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_ONE_about,voneserver=$voneserver,voneversion=$version vone=1"

##
# Veeam Backup & Replication Overview. This part will check The VONE v11 VBR Overview
# Veeam Backup Window
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v1/dashboards/$VBRDashboardID/widgets/$VBRWBackupWindowID/datasources/$VBRWBackupWindowDSID/data?forceRefresh=false"
veeamONEOverviewUrl=$(curl -X GET $veeamONEURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

    declare -i arraybackupwindow=0
    for row in $(echo "$veeamONEOverviewUrl" | jq -r '.data[].backup'); do
        windowDate=$(echo "$veeamONEOverviewUrl" | jq --raw-output ".data[$arraybackupwindow].display_date")
        backupwindowdate=$(date -d "$windowDate" +"%s")
        windowbackup=$(echo "$veeamONEOverviewUrl" | jq --raw-output ".data[$arraybackupwindow].backup")
        windowreplica=$(echo "$veeamONEOverviewUrl" | jq --raw-output ".data[$arraybackupwindow].replica")
        windownas=$(echo "$veeamONEOverviewUrl" | jq --raw-output ".data[$arraybackupwindow].nas")
        
        #echo "veeam_ONE_backupwindow,voneserver=$voneserver windowbackup=$windowbackup,windowreplica=$windowreplica,windownas=$windownas $backupwindowdate"
        arraybackupwindow=$arraybackupwindow+1
        
        ##Comment the Curl while debugging
        echo "Writing veeam_ONE_backupwindow to InfluxDB"
        curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=s&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_ONE_backupwindow,voneserver=$voneserver windowbackup=$windowbackup,windowreplica=$windowreplica,windownas=$windownas $backupwindowdate"

    done 
    
    
##
# Veeam Backup & Replication Overview. This part will check The VONE v11 VBR Overview
# Protected VMs
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v1/dashboards/$VBRDashboardID/widgets/$VBRWProtectedVMSID/datasources/$VBRWProtectedVMSDSID/data?forceRefresh=false"
veeamONEProtectedVMsUrl=$(curl -X GET $veeamONEURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

    protectedvms=$(echo "$veeamONEProtectedVMsUrl" | jq --raw-output ".data[0].number")    
    backuedupvms=$(echo "$veeamONEProtectedVMsUrl" | jq --raw-output ".data[1].number")    
    replicatedvms=$(echo "$veeamONEProtectedVMsUrl" | jq --raw-output ".data[2].number")    
    unprotectedvms=$(echo "$veeamONEProtectedVMsUrl" | jq --raw-output ".data[3].number")    
    restorepoints=$(echo "$veeamONEProtectedVMsUrl" | jq --raw-output ".data[4].number")    
    fullbackups=$(echo "$veeamONEProtectedVMsUrl" | jq --raw-output ".data[5].number" | awk '{print $1}')
    fullbackupsMetric=$(echo "$veeamONEProtectedVMsUrl" | jq --raw-output ".data[5].number" | awk '{print $2}')
        case $fullbackupsMetric in
        MB)
            fullbackupsSize=$fullbackups
        ;;
        GB)
            fullbackupsSize=$(echo "$fullbackups * 1024" | bc)
        ;;
        TB)
            fullbackupsSize=$(echo "$fullbackups * 1048576" | bc)
        ;;
        PB)
            fullbackupsSize=$(echo "$fullbackups * 1073741824" | bc)
        ;;
        esac
    increments=$(echo "$veeamONEProtectedVMsUrl" | jq --raw-output ".data[6].number" | awk '{print $1}')
    incrementsMetric=$(echo "$veeamONEProtectedVMsUrl" | jq --raw-output ".data[6].number" | awk '{print $2}')
        case $incrementsMetric in
        MB)
            incrementsbackupsSize=$increments
        ;;
        GB)
            incrementsbackupsSize=$(echo "$increments * 1024" | bc)
        ;;
        TB)
            incrementsbackupsSize=$(echo "$increments * 1048576" | bc)
        ;;
        PB)
            incrementsbackupsSize=$(echo "$increments * 1073741824" | bc)
        ;;
        esac
    sourcevmsize=$(echo "$veeamONEProtectedVMsUrl" | jq --raw-output ".data[7].number" | awk '{print $1}')
    sourcevmsizeMetric=$(echo "$veeamONEProtectedVMsUrl" | jq --raw-output ".data[7].number" | awk '{print $2}')
        case $sourcevmsizeMetric in
        MB)
            sourceSize=$sourcevmsize
        ;;
        GB)
            sourceSize=$(echo "$sourcevmsize * 1024" | bc)
        ;;
        TB)
            sourceSize=$(echo "$sourcevmsize * 1048576" | bc)
        ;;
        PB)
            sourceSize=$(echo "$sourcevmsize * 1073741824" | bc)
        ;;
        esac
    successratio=$(echo "$veeamONEProtectedVMsUrl" | jq --raw-output ".data[8].number"| awk -F'%' '{print $1}')

        
    #echo "veeam_ONE_protectedvms,voneserver=$voneserver protectedvms=$protectedvms,backuedupvms=$backuedupvms,replicatedvms=$replicatedvms,unprotectedvms=$unprotectedvms,restorepoints=$restorepoints,fullbackups=$fullbackupsSize,increments=$incrementsbackupsSize,sourcevmsize=$sourceSize,successratio=$successratio"
    
    ##Comment the Curl while debugging
    echo "Writing veeam_ONE_protectedvms to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=s&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_ONE_protectedvms,voneserver=$voneserver protectedvms=$protectedvms,backuedupvms=$backuedupvms,replicatedvms=$replicatedvms,unprotectedvms=$unprotectedvms,restorepoints=$restorepoints,fullbackups=$fullbackupsSize,increments=$incrementsbackupsSize,sourcevmsize=$sourceSize,successratio=$successratio"

 

##
# Veeam Backup & Replication Overview. This part will check The VONE v11 VBR Overview
# Backup Infrastructure Inventory
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v1/dashboards/$VBRDashboardID/widgets/$VBRWBackupInfraID/datasources/$VBRWBackupInfraDSID/data?forceRefresh=false"
veeamONEInventoryUrl=$(curl -X GET $veeamONEURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

    totalvbr=$(echo "$veeamONEInventoryUrl" | jq --raw-output ".data[0].name" | awk -F"[()]" '{print $2}')    
    totalproxy=$(echo "$veeamONEInventoryUrl" | jq --raw-output ".data[1].name" | awk -F"[()]" '{print $2}')    
    totalrepo=$(echo "$veeamONEInventoryUrl" | jq --raw-output ".data[2].name" | awk -F"[()]" '{print $2}')    
    totalbackupjob=$(echo "$veeamONEInventoryUrl" | jq --raw-output ".data[3].name" | awk -F"[()]" '{print $2}')    
    totalreplicajob=$(echo "$veeamONEInventoryUrl" | jq --raw-output ".data[4].name" | awk -F"[()]" '{print $2}')    
    totalbackupcopyjob=$(echo "$veeamONEInventoryUrl" | jq --raw-output ".data[5].name" | awk -F"[()]" '{print $2}')    
    totalnasjob=$(echo "$veeamONEInventoryUrl" | jq --raw-output ".data[6].name" | awk -F"[()]" '{print $2}')    
    totalcdpolicy=$(echo "$veeamONEInventoryUrl" | jq --raw-output ".data[7].name" | awk -F"[()]" '{print $2}')    

        
    #echo "veeam_ONE_backupinfrastructure,voneserver=$voneserver totalvbr=$totalvbr,totalproxy=$totalproxy,totalrepo=$totalrepo,totalbackupjob=$totalbackupjob,totalreplicajob=$totalreplicajob,totalbackupcopyjob=$totalbackupcopyjob,totalnasjob=$totalnasjob,totalcdpolicy=$totalcdpolicy"

    ##Comment the Curl while debugging
    echo "Writing veeam_ONE_backupinfrastructure to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=s&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_ONE_backupinfrastructure,voneserver=$voneserver totalvbr=$totalvbr,totalproxy=$totalproxy,totalrepo=$totalrepo,totalbackupjob=$totalbackupjob,totalreplicajob=$totalreplicajob,totalbackupcopyjob=$totalbackupcopyjob,totalnasjob=$totalnasjob,totalcdpolicy=$totalcdpolicy"
 

##
# Veeam Backup & Replication Overview. This part will check The VONE v11 VBR Overview
# Jobs Status
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v1/dashboards/$VBRDashboardID/widgets/$VBRWJobStatusID/datasources/$VBRWJobStatusDSID/data?forceRefresh=false"
veeamONEJobsUrl=$(curl -X GET $veeamONEURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

declare -i arrayjobs=0
for row in $(echo "$veeamONEJobsUrl" | jq -r '.data[].fail'); do
    display_date=$(echo "$veeamONEJobsUrl" | jq --raw-output ".data[$arrayjobs].display_date")
    jobdate=$(date -d "$display_date" +"%s")
    jobsuccess=$(echo "$veeamONEJobsUrl" | jq --raw-output ".data[$arrayjobs].success")    
    jobwarning=$(echo "$veeamONEJobsUrl" | jq --raw-output ".data[$arrayjobs].warning")
    jobfail=$(echo "$veeamONEJobsUrl" | jq --raw-output ".data[$arrayjobs].fail")
    
    #echo "veeam_ONE_jobs,voneserver=$voneserver jobsuccess=$jobsuccess,jobwarning=$jobwarning,jobfail=$jobfail $jobdate"

    ##Comment the Curl while debugging
    echo "Writing veeam_ONE_jobs to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=s&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_ONE_jobs,voneserver=$voneserver jobsuccess=$jobsuccess,jobwarning=$jobwarning,jobfail=$jobfail $jobdate"

    arrayjobs=$arrayjobs+1
done  

##
# Veeam Backup & Replication Overview. This part will check The VONE v11 VBR Overview
# Top Jobs by Duration
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v1/dashboards/$VBRDashboardID/widgets/$VBRWTopJobsID/datasources/$VBRWTopJobsDSID/data?forceRefresh=false"
veeamONEJobsDurationUrl=$(curl -X GET $veeamONEURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

lastUpdateTime=$(echo "$veeamONEJobsDurationUrl" | jq --raw-output ".lastUpdateTimeUtc")
lastupdate=$(date -d "$lastUpdateTime" +"%s")
    
declare -i arrayjobduration=0
for row in $(echo "$veeamONEJobsDurationUrl" | jq -r '.data[].duration'); do
    jobname=$(echo "$veeamONEJobsDurationUrl" | jq --raw-output ".data[$arrayjobduration].name" | awk '{gsub(/ /,"\\ ");print}')
    if [[ $jobname = "null" ]]; then
        break
    else
    status=$(echo "$veeamONEJobsDurationUrl" | jq --raw-output ".data[$arrayjobduration].job_status")
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
    jobdurationH=$(echo "$veeamONEJobsDurationUrl" | jq --raw-output ".data[$arrayjobduration].duration" | awk '{print $1}')
    jobdurationM=$(echo "$veeamONEJobsDurationUrl" | jq --raw-output ".data[$arrayjobduration].duration" | awk '{print $3}')
    jobduration=$(echo "$jobdurationH * 60 + $jobdurationM" | bc)
    jobcompare=$(echo "$veeamONEJobsDurationUrl" | jq --raw-output ".data[$arrayjobduration].prev_dur")

    #echo "veeam_ONE_jobsduration,voneserver=$voneserver,jobname=$jobname,jobstatus=$jobStatus,jobduration=$jobduration trend=$jobcompare $lastupdate"

    ##Comment the Curl while debugging
    echo "Writing veeam_ONE_jobsduration to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=s&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_ONE_jobsduration,voneserver=$voneserver,jobname=$jobname,jobstatus=$jobStatus,jobduration=$jobduration trend=$jobcompare $lastupdate"
    
    arrayjobduration=$arrayjobduration+1
    fi
done  


##
# Veeam Backup & Replication Overview. This part will check The VONE v11 VBR Overview
# Top Repositories by Used Space
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v1/dashboards/$VBRDashboardID/widgets/$VBRWTopReposID/datasources/$VBRWTopReposDSID/data?forceRefresh=false"
veeamONERepositoriesUrl=$(curl -X GET $veeamONEURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

lastUpdateTime=$(echo "$veeamONERepositoriesUrl" | jq --raw-output ".lastUpdateTimeUtc")
lastupdate=$(date -d "$lastUpdateTime" +"%s")
    
declare -i arrayrepositories=0
for row in $(echo "$veeamONERepositoriesUrl" | jq -r '.data[].trend'); do
    backupsrvname=$(echo "$veeamONERepositoriesUrl" | jq --raw-output ".data[$arrayrepositories].backup_srv_name" | awk '{gsub(/ /,"\\ ");print}')    
    repositoryname=$(echo "$veeamONERepositoriesUrl" | jq --raw-output ".data[$arrayrepositories].repository_name" | awk '{gsub(/ /,"\\ ");print}')
    repocapacity=$(echo "$veeamONERepositoriesUrl" | jq --raw-output ".data[$arrayrepositories].capacity")    
    repofreespace=$(echo "$veeamONERepositoriesUrl" | jq --raw-output ".data[$arrayrepositories].free_space")
    repodaysleft=$(echo "$veeamONERepositoriesUrl" | jq --raw-output ".data[$arrayrepositories].days_to_die")    
    repocompare=$(echo "$veeamONERepositoriesUrl" | jq --raw-output ".data[$arrayrepositories].trend")

    #echo "veeam_ONE_repositories,voneserver=$voneserver,vbrserver=$backupsrvname,repositoryname=$repositoryname repocapacity=$repocapacity,repofreespace=$repofreespace,repodaysleft=$repodaysleft,trend=$repocompare $lastupdate"

    ##Comment the Curl while debugging
    echo "Writing veeam_ONE_repositories to InfluxDB"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=s&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_ONE_repositories,voneserver=$voneserver,vbrserver=$backupsrvname,repositoryname=$repositoryname repocapacity=$repocapacity,repofreespace=$repofreespace,repodaysleft=$repodaysleft,trend=$repocompare $lastupdate"

    arrayrepositories=$arrayrepositories+1
done
