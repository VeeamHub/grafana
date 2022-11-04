#!/bin/bash
##      .SYNOPSIS
##      Grafana Dashboard for Veeam Backup for Salesforce v1.0 - Using API to InfluxDB Script
## 
##      .DESCRIPTION
##      This Script will query the Veeam Backup for Salesforce UNSUPPORTED API and send the data directly to InfluxDB, which can be used to present it to Grafana. 
##      The Script and the Grafana Dashboard it is provided as it is, and bear in mind you can not open support Tickets regarding this project. It is a Community Project
##	
##      .Notes
##      NAME:  grafana_influxdb_veeam_backup_salesforce.sh
##      ORIGINAL NAME: grafana_influxdb_veeam_backup_salesforce.sh
##      LASTEDIT: 01/11/2022
##      VERSION: 1.0
##      KEYWORDS: Veeam, , Salesforce, InfluxDB, Grafana
   
##      .Link
##      https://jorgedelacruz.es/
##      https://jorgedelacruz.uk/

# Configurations
##
# Endpoint URL for InfluxDB
veeamInfluxDBURL="http://YOURINFLUXSERVERIP" #Your InfluxDB Server, http://FQDN or https://FQDN if using SSL
veeamInfluxDBPort="8086" #Default Port
veeamInfluxDBBucket="veeam" # InfluxDB bucket name (not ID)
veeamInfluxDBToken="TOKEN" # InfluxDB access token with read/write privileges for the bucket
veeamInfluxDBOrg="ORG NAME" # InfluxDB organisation name (not ID)

# Endpoint URL for login action
veeamUsername="YOURVEEAMBACKUPUSER"
veeamPassword="YOURVEEAMBACKUPPASS"
veeamBackupSalesforceServer="https://YOURVEEAMBACKUPIP"
veeamBackupSalesforcePort="443" #Default Port

veeamBearer=$(curl -X POST --header "Content-Type: application/x-www-form-urlencoded" --header "Accept: application/json" --header "x-api-version: 1.0-rev1" -d "username=$veeamUsername&password=$veeamPassword&grant_type=password" "$veeamBackupSalesforceServer:$veeamBackupSalesforcePort/oauth/token" -k --silent | jq -r '.access_token')

##
# Veeam Backup for Salesforce Overview. This part will check VBSF Version and License
##
veeamVBSFURL="$veeamBackupSalesforceServer:$veeamBackupSalesforcePort/api/v1/version"
veeamVBSFOverviewUrl=$(curl -X GET $veeamVBSFURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

    build_version=$(echo "$veeamVBSFOverviewUrl" | jq --raw-output ".build_version")
    mc_version=$(echo "$veeamVBSFOverviewUrl" | jq --raw-output ".mc_version")
    restoremodule_version=$(echo "$veeamVBSFOverviewUrl" | jq --raw-output ".restore_version")
    backup_version=$(echo "$veeamVBSFOverviewUrl" | jq --raw-output ".backup_version")
    instance_id=$(echo "$veeamVBSFOverviewUrl" | jq --raw-output ".instance_id")
    
    #echo "veeam_salesforce_overview,serverName=$veeamBackupSalesforceServer,build_version=$build_version,mc_version=$mc_version,restoremodule_version=$restoremodule_version,backup_version=$backup_version,instance_id=$instance_id VBSF=1"
    echo "Writing veeam_salesforce_overview to InfluxDB" 
    curl -i -XPOST "$veeamInfluxDBURL/api/v2/write?&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_salesforce_overview,serverName=$veeamBackupSalesforceServer,build_version=$build_version,mc_version=$mc_version,restoremodule_version=$restoremodule_version,backup_version=$backup_version,instance_id=$instance_id VBSF=1"

veeamVBSFURL="$veeamBackupSalesforceServer:$veeamBackupSalesforcePort/api/v1/license"
veeamVBSFOverviewUrl=$(curl -X GET $veeamVBSFURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

    licenseType=$(echo "$veeamVBSFOverviewUrl" | jq --raw-output ".license_type")
    licenseTotal=$(echo "$veeamVBSFOverviewUrl" | jq --raw-output ".users")
    licenseConsumption=$(echo "$veeamVBSFOverviewUrl" | jq --raw-output ".license_consumption")
    licenseStatus=$(echo "$veeamVBSFOverviewUrl" | jq --raw-output ".status")
    licensePackage=$(echo "$veeamVBSFOverviewUrl" | jq --raw-output ".package")
    
    #echo "veeam_salesforce_overview,serverName=$veeamBackupSalesforceServer,licenseType=$licenseType,licenseStatus=$licenseStatus,licensePackage=$licensePackage licenseTotal=$licenseTotal,licenseConsumption=$licenseTotal"
    echo "Writing veeam_salesforce_overview to InfluxDB" 
    curl -i -XPOST "$veeamInfluxDBURL/api/v2/write?&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_salesforce_overview,serverName=$veeamBackupSalesforceServer,licenseType=$licenseType,licenseStatus=$licenseStatus,licensePackage=$licensePackage licenseTotal=$licenseTotal,licenseConsumption=$licenseTotal"

##
# Veeam Backup for Salesforce Organizations. This part will check VBSF and report all the Organizations
##
veeamVBSFURL="$veeamBackupSalesforceServer:$veeamBackupSalesforcePort/api/v1/organization?update=false"
veeamVBSFOrganizationsUrl=$(curl -X GET $veeamVBSFURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

declare -i arrayorganizations=0
for id in $(echo "$veeamVBSFOrganizationsUrl" | jq -r '.organizations[].id'); do
    organizationCompanyID=$(echo "$veeamVBSFOrganizationsUrl" | jq --raw-output '.organizations['$arrayorganizations']."company.id"')
    organizationCompanyName=$(echo "$veeamVBSFOrganizationsUrl" | jq --raw-output '.organizations['$arrayorganizations']."company.name"' | awk '{gsub(/ /,"\\ ");print}')
    organizationName=$(echo "$veeamVBSFOrganizationsUrl" | jq --raw-output ".organizations[$arrayorganizations].name" | awk '{gsub(/ /,"\\ ");print}')
    organizationSFID=$(echo "$veeamVBSFOrganizationsUrl" | jq --raw-output ".organizations[$arrayorganizations].sf_instance_id")
    organizationSFInstanceName=$(echo "$veeamVBSFOrganizationsUrl" | jq --raw-output ".organizations[$arrayorganizations].sf_instance_name") 
    organizationSFOrgName=$(echo "$veeamVBSFOrganizationsUrl" | jq --raw-output ".organizations[$arrayorganizations].sf_org_name")
    organizationSFOrgType=$(echo "$veeamVBSFOrganizationsUrl" | jq --raw-output ".organizations[$arrayorganizations].sf_org_type" | awk '{gsub(/ /,"\\ ");print}')        
    organizationRepository=$(echo "$veeamVBSFOrganizationsUrl" | jq --raw-output ".organizations[$arrayorganizations].storage_location")
    organizationSFPublicID=$(echo "$veeamVBSFOrganizationsUrl" | jq --raw-output ".organizations[$arrayorganizations].org_id") 
    organizationSFPublicURL=$(echo "$veeamVBSFOrganizationsUrl" | jq --raw-output ".organizations[$arrayorganizations].org_url")    
    organizationSFlastmodified=$(echo "$veeamVBSFOrganizationsUrl" | jq --raw-output ".organizations[$arrayorganizations].vsf_last_modified_date")
    organizationSFlastmodifiedUnix=$(date -d "$organizationSFlastmodified" +"%s")
    organizationSFlastinsert=$(echo "$veeamVBSFOrganizationsUrl" | jq --raw-output ".organizations[$arrayorganizations].vsf_insert_date")
    organizationSFlastinsertUnix=$(date -d "$organizationSFlastinsert" +"%s")
    organizationDBID=$(echo "$veeamVBSFOrganizationsUrl" | jq --raw-output '.organizations['$arrayorganizations']."db_server.id"')
    organizationDBServerName=$(echo "$veeamVBSFOrganizationsUrl" | jq --raw-output '.organizations['$arrayorganizations']."db_server.name"')
    organizationDBName=$(echo "$veeamVBSFOrganizationsUrl" | jq --raw-output '.organizations['$arrayorganizations']."db_server.db_name"'  | awk '{gsub(/ /,"\\ ");print}')
    organizationDBURL=$(echo "$veeamVBSFOrganizationsUrl" | jq --raw-output '.organizations['$arrayorganizations']."db_server.url"')
    organizationDBPort=$(echo "$veeamVBSFOrganizationsUrl" | jq --raw-output '.organizations['$arrayorganizations']."db_server.port"')
    organizationStatus=$(echo "$veeamVBSFOrganizationsUrl" | jq --raw-output ".organizations[$arrayorganizations].is_valid")

    #echo "veeam_salesforce_organizations,serverName=$veeamBackupSalesforceServer,organizationCompanyID=$organizationCompanyID,organizationName=$organizationName,organizationCompanyName=$organizationCompanyName,organizationSFID=$organizationSFID,organizationSFInstanceName=$organizationSFInstanceName,organizationSFOrgName=$organizationSFOrgName,organizationSFOrgType=$organizationSFOrgType,organizationRepository=$organizationRepository,organizationSFPublicID=$organizationSFPublicID,organizationSFPublicURL=$organizationSFPublicURL,organizationDBServerName=$organizationDBServerName,organizationDBName=$organizationDBName,organizationDBURL=$organizationDBURL,organizationStatus=$organizationStatus organizationDBID=$organizationDBID,organizationSFlastmodified=$organizationSFlastmodifiedUnix,organizationSFlastinsert=$organizationSFlastinsertUnix,organizationDBPort=$organizationDBPort"
    echo "Writing veeam_salesforce_organizations to InfluxDB" 
    curl -i -XPOST "$veeamInfluxDBURL/api/v2/write?&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_salesforce_organizations,serverName=$veeamBackupSalesforceServer,organizationCompanyID=$organizationCompanyID,organizationName=$organizationName,organizationCompanyName=$organizationCompanyName,organizationSFID=$organizationSFID,organizationSFInstanceName=$organizationSFInstanceName,organizationSFOrgName=$organizationSFOrgName,organizationSFOrgType=$organizationSFOrgType,organizationRepository=$organizationRepository,organizationSFPublicID=$organizationSFPublicID,organizationSFPublicURL=$organizationSFPublicURL,organizationDBServerName=$organizationDBServerName,organizationDBName=$organizationDBName,organizationDBURL=$organizationDBURL,organizationStatus=$organizationStatus organizationDBID=$organizationDBID,organizationSFlastmodified=$organizationSFlastmodifiedUnix,organizationSFlastinsert=$organizationSFlastinsertUnix,organizationDBPort=$organizationDBPort"

    arrayorganizations=$arrayorganizations+1    
done

##
# Veeam Backup for Salesforce Companies. This part will check VBA and report all the Companies
##
veeamVBSFURL="$veeamBackupSalesforceServer:$veeamBackupSalesforcePort/api/v1/company"
veeamVBSFCompaniesUrl=$(curl -X GET $veeamVBSFURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

declare -i arraycompanies=0
for id in $(echo "$veeamVBSFCompaniesUrl" | jq -r '.companies[].id'); do
    companyID=$(echo "$veeamVBSFCompaniesUrl" | jq --raw-output ".companies[$arraycompanies].id")
    companyName=$(echo "$veeamVBSFCompaniesUrl" | jq --raw-output ".companies[$arraycompanies].name" | awk '{gsub(/ /,"\\ ");print}')
    companyUsers=$(echo "$veeamVBSFCompaniesUrl" | jq --raw-output ".companies[$arraycompanies].users")
    companyStorageSize=$(echo "$veeamVBSFCompaniesUrl" | jq --raw-output ".companies[$arraycompanies].data_size")
    companyDataSize=$(echo "$veeamVBSFCompaniesUrl" | jq --raw-output ".companies[$arraycompanies].storage_size")
    companySFOrg=$(echo "$veeamVBSFCompaniesUrl" | jq --raw-output ".companies[$arraycompanies].sf_org")

    #echo "veeam_salesforce_companies,serverName=$veeamBackupSalesforceServer,companyID=$companyID,companyName=$companyName companySFOrg=$companySFOrg,companyUsers=$companyUsers,companyStorageSize=$companyStorageSize,companyDataSize=$companyDataSize"
    echo "Writing veeam_salesforce_companies to InfluxDB" 
    curl -i -XPOST "$veeamInfluxDBURL/api/v2/write?&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_salesforce_companies,serverName=$veeamBackupSalesforceServer,companyID=$companyID,companyName=$companyName companySFOrg=$companySFOrg,companyUsers=$companyUsers,companyStorageSize=$companyStorageSize,companyDataSize=$companyDataSize"

    ##
    # Veeam Backup for Salesforce Databases. This part will check VBSF and report all the Databases
    ##
    veeamVBSFURL="$veeamBackupSalesforceServer:$veeamBackupSalesforcePort/api/v1/database/salesforce?company_id=$companyID"
    veeamVBSFDatabasesUrl=$(curl -X GET $veeamVBSFURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

    declare -i arraydatabases=0
    for id in $(echo "$veeamVBSFDatabasesUrl" | jq -r '.db[].id'); do
        databaseID=$(echo "$veeamVBSFDatabasesUrl" | jq --raw-output ".db[$arraydatabases].id")
        databaseName=$(echo "$veeamVBSFDatabasesUrl" | jq --raw-output ".db[$arraydatabases].db_name" | awk '{gsub(/ /,"\\ ");print}')
        databaseUsername=$(echo "$veeamVBSFDatabasesUrl" | jq --raw-output '.db['$arraydatabases']."db_user.name"')
        databaseConnection=$(echo "$veeamVBSFDatabasesUrl" | jq --raw-output ".db[$arraydatabases].connected")
        databaseStatus=$(echo "$veeamVBSFDatabasesUrl" | jq --raw-output ".db[$arraydatabases].db_state")
        databaseURL=$(echo "$veeamVBSFDatabasesUrl" | jq --raw-output ".db[$arraydatabases].url")
        databasePort=$(echo "$veeamVBSFDatabasesUrl" | jq --raw-output ".db[$arraydatabases].port")

        #echo "veeam_salesforce_databases,serverName=$veeamBackupSalesforceServer,companyID=$companyID,companyName=$companyName,databaseID=$databaseID,databaseName=$databaseName,databaseUsername=$databaseUsername,databaseConnection=$databaseConnection,databaseStatus=$databaseStatus,databaseURL=$databaseURL databasePort=$databasePort"
        echo "Writing veeam_salesforce_databases to InfluxDB" 
        curl -i -XPOST "$veeamInfluxDBURL/api/v2/write?&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_salesforce_databases,serverName=$veeamBackupSalesforceServer,companyID=$companyID,companyName=$companyName,databaseID=$databaseID,databaseName=$databaseName,databaseUsername=$databaseUsername,databaseConnection=$databaseConnection,databaseStatus=$databaseStatus,databaseURL=$databaseURL databasePort=$databasePort"

        arraydatabases=$arraydatabases+1  
    done

    ##
    # Veeam Backup for Salesforce Jobs. This part will check VBSF and report Jobs per Company
    ##
    veeamVBSFURL="$veeamBackupSalesforceServer:$veeamBackupSalesforcePort/api/v1/backup/job?&company_id=$companyID"
    veeamVBSFJobsUrl=$(curl -X GET $veeamVBSFURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

    declare -i arrayjobs=0
    for id in $(echo "$veeamVBSFJobsUrl" | jq -r '.job[].id'); do
        jobID=$(echo "$veeamVBSFJobsUrl" | jq --raw-output ".job[$arrayjobs].id")
        jobName=$(echo "$veeamVBSFJobsUrl" | jq --raw-output ".job[$arrayjobs].name" | awk '{gsub(/ /,"\\ ");print}')
        jobType=$(echo "$veeamVBSFJobsUrl" | jq --raw-output ".job[$arrayjobs].type")
        jobSchedule=$(echo "$veeamVBSFJobsUrl" | jq --raw-output ".job[$arrayjobs].scheduleName")
        jobState=$(echo "$veeamVBSFJobsUrl" | jq --raw-output ".job[$arrayjobs].is_disabled")
        jobStatus=$(echo "$veeamVBSFJobsUrl" | jq --raw-output ".job[$arrayjobs].status")
        jobCreation=$(echo "$veeamVBSFJobsUrl" | jq --raw-output ".job[$arrayjobs].vsf_insert_date")
        jobCreationUnix=$(date -d "$jobCreation" +"%s")
        jobLastRun=$(echo "$veeamVBSFJobsUrl" | jq --raw-output ".job[$arrayjobs].last_run_date")
        jobLastRunUnix=$(date -d "$jobLastRun" +"%s")

        #echo "veeam_salesforce_jobs,serverName=$veeamBackupSalesforceServer,companyID=$companyID,companyName=$companyName,jobID=$jobID,jobName=$jobName,jobType=$jobType,jobSchedule=$jobSchedule,jobState=$jobState,jobStatus=$jobStatus,jobCreation=$jobCreationUnix VBSFjob=1 $jobCreationUnix"
        echo "Writing veeam_salesforce_jobs to InfluxDB" 
        curl -i -XPOST "$veeamInfluxDBURL/api/v2/write?&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_salesforce_jobs,serverName=$veeamBackupSalesforceServer,companyID=$companyID,companyName=$companyName,jobID=$jobID,jobName=$jobName,jobType=$jobType,jobSchedule=$jobSchedule,jobState=$jobState,jobStatus=$jobStatus jobCreation=$jobCreationUnix,jobLastRunUnix=$jobLastRunUnix,VBSFjob=1 $jobCreationUnix"

           ##
            # Veeam Backup for Salesforce Jobs Details. This part will check VBSF and report Jobs details per Company and per Job
            ##
            veeamVBSFURL="$veeamBackupSalesforceServer:$veeamBackupSalesforcePort/api/v1/backup/job/$jobID/log"
            veeamVBSFJobslogUrl=$(curl -X GET $veeamVBSFURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

            declare -i arrayjobslogs=0
            for id in $(echo "$veeamVBSFJobslogUrl" | jq -r '.logs[].id'); do
                jobLogID=$(echo "$veeamVBSFJobslogUrl" | jq --raw-output ".logs[$arrayjobslogs].log_id")
                jobLogType=$(echo "$veeamVBSFJobslogUrl" | jq --raw-output ".logs[$arrayjobslogs].type")
                jobRowsLoaded=$(echo "$veeamVBSFJobslogUrl" | jq --raw-output ".logs[$arrayjobslogs].rows_loaded")
                jobRowsInserted=$(echo "$veeamVBSFJobslogUrl" | jq --raw-output ".logs[$arrayjobslogs].rows_inserted")
                jobRowsUpdated=$(echo "$veeamVBSFJobslogUrl" | jq --raw-output ".logs[$arrayjobslogs].rows_updated")
                jobRowsDeleted=$(echo "$veeamVBSFJobslogUrl" | jq --raw-output ".logs[$arrayjobslogs].rows_deleted")
                jobRowsFailed=$(echo "$veeamVBSFJobslogUrl" | jq --raw-output ".logs[$arrayjobslogs].rows_failed")
                jobAPICalls=$(echo "$veeamVBSFJobslogUrl" | jq --raw-output ".logs[$arrayjobslogs].api_calls_used")
                jobProccessedObjects=$(echo "$veeamVBSFJobslogUrl" | jq --raw-output ".logs[$arrayjobslogs].processed_objects")
                jobrunType=$(echo "$veeamVBSFJobslogUrl" | jq --raw-output ".logs[$arrayjobslogs].run_type")
                jobStatus=$(echo "$veeamVBSFJobslogUrl" | jq --raw-output ".logs[$arrayjobslogs].status")
                jobStart=$(echo "$veeamVBSFJobslogUrl" | jq --raw-output ".logs[$arrayjobslogs].start_time")
                jobStartUnix=$(date -d "$jobStart" +"%s")
                jobEnd=$(echo "$veeamVBSFJobslogUrl" | jq --raw-output ".logs[$arrayjobslogs].end_time")
                jobLastRunUnix=$(date -d "$jobEnd" +"%s")
                jobDuration=$(echo "$veeamVBSFJobslogUrl" | jq --raw-output ".logs[$arrayjobslogs].run_time")

                #echo "veeam_salesforce_jobslogs,serverName=$veeamBackupSalesforceServer,companyID=$companyID,companyName=$companyName,jobID=$jobID,jobName=$jobName,jobLogID=$jobLogID,jobLogType=$jobLogType,jobrunType=$jobrunType,jobStatus=$jobStatus,jobCreationUnix=$jobCreationUnix jobRowsLoaded=$jobRowsLoaded,jobRowsInserted=$jobRowsInserted,jobRowsUpdated=$jobRowsUpdated,jobRowsDeleted=$jobRowsDeleted,jobRowsFailed=$jobRowsFailed,jobAPICalls=$jobAPICalls,jobProccessedObjects=$jobProccessedObjects,jobDuration=$jobDuration  $jobStartUnix"
                echo "Writing veeam_salesforce_jobslogs to InfluxDB" 
                curl -i -XPOST "$veeamInfluxDBURL/api/v2/write?&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_salesforce_jobslogs,serverName=$veeamBackupSalesforceServer,companyID=$companyID,companyName=$companyName,jobID=$jobID,jobName=$jobName,jobLogID=$jobLogID,jobLogType=$jobLogType,jobrunType=$jobrunType,jobStatus=$jobStatus jobCreationUnix=$jobCreationUnix,jobRowsLoaded=$jobRowsLoaded,jobRowsInserted=$jobRowsInserted,jobRowsUpdated=$jobRowsUpdated,jobRowsDeleted=$jobRowsDeleted,jobRowsFailed=$jobRowsFailed,jobAPICalls=$jobAPICalls,jobProccessedObjects=$jobProccessedObjects,jobDuration=$jobDuration,jobStartUnix=$jobStartUnix,jobLastRunUnix=$jobLastRunUnix  $jobStartUnix"

                arrayjobslogs=$arrayjobslogs+1  
            done
        
        arrayjobs=$arrayjobs+1  
    done

    ##
    # Veeam Backup for Salesforce Retore Operations. This part will check VBSF and report all the Restores that had happened
    ##
    veeamVBSFURL="$veeamBackupSalesforceServer:$veeamBackupSalesforcePort/api/v1/restore/job?&company_id=$companyID"
    veeamVBSFRestoresUrl=$(curl -X GET $veeamVBSFURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)
    if [[ ! -z "$veeamVBSFRestoresUrl" ]] ; then
        declare -i arrayrestores=0
        for id in $(echo "$veeamVBSFRestoresUrl" | jq -r '.jobs[].id'); do
            restoreID=$(echo "$veeamVBSFRestoresUrl" | jq --raw-output '.jobs['$arrayrestores']."id"')
            restoreName=$(echo "$veeamVBSFRestoresUrl" | jq --raw-output '.jobs['$arrayrestores']."name"' | awk '{gsub(/ /,"\\ ");print}')
            restoreDescription=$(echo "$veeamVBSFRestoresUrl" | jq --raw-output '.jobs['$arrayrestores']."description"' | awk '{gsub(/ /,"\\ ");print}')
            if [ "$restoreDescription" == "" ]; then declare -i restoreDescription="None"; fi
            restoreStatus=$(echo "$veeamVBSFRestoresUrl" | jq --raw-output ".jobs[$arrayrestores].status")
            restoreType=$(echo "$veeamVBSFRestoresUrl" | jq --raw-output '.jobs['$arrayrestores']."restore_type_state.mode"') 
            restoreCreatedDate=$(echo "$veeamVBSFRestoresUrl" | jq --raw-output ".jobs[$arrayrestores].vsf_insert_date")
            restoreCreatedDateUnix=$(date -d "$restoreCreatedDate" +"%s")
            restoreStartDate=$(echo "$veeamVBSFRestoresUrl" | jq --raw-output ".jobs[$arrayrestores].start_date") 
            restoreStartDateUnix=$(date -d "$restoreStartDate" +"%s")
            restoreFinishDate=$(echo "$veeamVBSFRestoresUrl" | jq --raw-output ".jobs[$arrayrestores].finish_date")
            restoreFinishDateUnix=$(date -d "$restoreFinishDate" +"%s")
            restoreSFInstanceName=$(echo "$veeamVBSFRestoresUrl" | jq --raw-output '.jobs['$arrayrestores']."sf_instance.sandbox_name"') 
            
            veeamVBSFURL="$veeamBackupSalesforceServer:$veeamBackupSalesforcePort/api/v1/restore/job/$restoreID/log"
            veeamVBSFRestoresLogUrl=$(curl -X GET $veeamVBSFURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" 2>&1 -k --silent)

            restoreInserted=$(echo "$veeamVBSFRestoresLogUrl" | jq --raw-output '.rows_inserted')
            restoreUpdated=$(echo "$veeamVBSFRestoresLogUrl" | jq --raw-output '.rows_updated')
            restoreFailed=$(echo "$veeamVBSFRestoresLogUrl" | jq --raw-output '.rows_failed')
            restoreAPICalls=$(echo "$veeamVBSFRestoresLogUrl" | jq --raw-output '.api_calls_used')

            #echo "veeam_salesforce_restores,serverName=$veeamBackupSalesforceServer,companyID=$companyID,companyName=$companyName,restoreID=$restoreID,restoreName=$restoreName,restoreDescription=$restoreDescription,restoreStatus=$restoreStatus,restoreType=$restoreType,restoreCreatedDateUnix=$restoreCreatedDateUnix,restoreStartDateUnix=$restoreStartDateUnix,restoreFinishDateUnix=$restoreFinishDateUnix,restoreSFInstanceName=$restoreSFInstanceName restoreInserted=$restoreInserted,restoreUpdated=$restoreUpdated,restoreFailed=$restoreFailed,restoreAPICalls=$restoreAPICalls $restoreStartDateUnix"
            echo "Writing veeam_salesforce_restores to InfluxDB" 
            curl -i -XPOST "$veeamInfluxDBURL/api/v2/write?&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_salesforce_restores,serverName=$veeamBackupSalesforceServer,companyID=$companyID,companyName=$companyName,restoreID=$restoreID,restoreName=$restoreName,restoreDescription=$restoreDescription,restoreStatus=$restoreStatus,restoreType=$restoreType,restoreSFInstanceName=$restoreSFInstanceName restoreInserted=$restoreInserted,restoreUpdated=$restoreUpdated,restoreFailed=$restoreFailed,restoreAPICalls=$restoreAPICalls,restoreCreatedDateUnix=$restoreCreatedDateUnix,restoreStartDateUnix=$restoreStartDateUnix,restoreFinishDateUnix=$restoreFinishDateUnix $restoreStartDateUnix"

            arrayrestores=$arrayrestores+1    
        done
    fi

    arraycompanies=$arraycompanies+1    
done


