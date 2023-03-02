#!/bin/bash
##      .SYNOPSIS
##      Grafana Dashboard for Veeam Backup for Microsoft 365 v6.0 - Using RestAPI to InfluxDB Script
## 
##      .DESCRIPTION
##      This Script will query the Veeam Backup for Microsoft 365 RestAPI and send the data directly to InfluxDB, which can be used to present it to Grafana. 
##      The Script and the Grafana Dashboard it is provided as it is, and bear in mind you can not open support Tickets regarding this project. It is a Community Project
##	
##      .Notes
##      NAME:  veeam_microsoft365.sh
##      ORIGINAL veeam_microsoft365.sh
##      LASTEDIT: 29/09/2022
##      VERSION: 6.0
##      KEYWORDS: Veeam, InfluxDB, Grafana
   
##      .Link
##      https://jorgedelacruz.es/
##      https://jorgedelacruz.uk/

##
# Configurations
##
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
veeamBearer=$(curl -X POST --header "Content-Type: application/x-www-form-urlencoded" --header "Accept: application/json" -d "grant_type=password&username=$veeamUsername&password=$veeamPassword&refresh_token=%27%27" "$veeamRestServer:$veeamRestPort/v6/token" -k --silent | jq -r '.access_token')


##
# Veeam Backup for Microsoft 365 Version. This part will check the Veeam Backup for Microsoft 365 version
##
veeamVBOUrl="$veeamRestServer:$veeamRestPort/v6/ServiceInstance"
veeamVersionUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVBOUrl" 2>&1 -k --silent)
    
    veeamVersion=$(echo "$veeamVersionUrl" | jq --raw-output ".version")
    echo "veeam_office365_version,veeamVersion=$veeamVersion,veeamServer=$veeamRestServer v=1"
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
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_office365_organization,veeamOrgName=$veeamOrgName licensedUsers=$licensedUsers,newUsers=$newUsers"
    
    ##
    # Veeam Backup for Microsoft 365 Users. This part will check the total Users and if they are protected or not
    ##
    veeamVBOUrl="$veeamRestServer:$veeamRestPort/v6/LicensedUsers"
    veeamUsersUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVBOUrl" 2>&1 -k --silent)
    declare -i arrayLicensed=0
    for id in $(echo "$veeamUsersUrl" | jq -r '.results[].id'); do
    veeamUserId=$(echo "$veeamUsersUrl" | jq --raw-output ".results[$arrayLicensed].id")
    veeamUserName=$(echo "$veeamUsersUrl" | jq --raw-output ".results[$arrayLicensed].name" | awk '{gsub(/ /,"\\ ");print}')
    veeamUserBackup=$(echo "$veeamUsersUrl" | jq --raw-output ".results[$arrayLicensed].isBackedUp")   
      case $veeamUserBackup in
        "true")
            protectedUser="1"
        ;;
        "false")
            protectedUser="2"
        ;;
        esac
     veeamLicensedType=$(echo "$veeamUsersUrl" | jq --raw-output ".results[$arrayLicensed].licenseState")   
      case $veeamLicensedType in
        "Licensed")
            LicensedUser="1"
        ;;
        "Unlicensed")
            LicensedUser="2"
        ;;
        esac
    
    #echo "veeam_office365_overview_OD,veeamOrgName=$veeamOrgName,veeamUserName=$veeamUserName protectedUser=$protectedUser,licensedUser=$LicensedUser"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_office365_overview_OD,veeamOrgName=$veeamOrgName,veeamUserName=$veeamUserName protectedUser=$protectedUser,licensedUser=$LicensedUser"
    arrayLicensed=$arrayLicensed+1
    done

    arrayorg=$arrayorg+1
done
 

##
# Veeam Backup for Microsoft 365 Backup Repositories. This part will check the capacity and used space of the Backup Repositories
##
veeamVBOUrl="$veeamRestServer:$veeamRestPort/v6/BackupRepositories"
veeamRepoUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVBOUrl" 2>&1 -k --silent)

declare -i arrayrepo=0
for id in $(echo "$veeamRepoUrl" | jq -r '.[].id'); do
  repository=$(echo "$veeamRepoUrl" | jq --raw-output ".[$arrayrepo].name" | awk '{gsub(/ /,"\\ ");print}')
  capacity=$(echo "$veeamRepoUrl" | jq --raw-output ".[$arrayrepo].capacityBytes")
  freeSpace=$(echo "$veeamRepoUrl" | jq --raw-output ".[$arrayrepo].freeSpaceBytes")
  objectStorageId=$(echo "$veeamRepoUrl" | jq --raw-output ".[$arrayrepo].objectStorageId")
  objectStorageEncryptionEnabled=$(echo "$veeamRepoUrl" | jq --raw-output ".[$arrayrepo].objectStorageEncryptionEnabled")
  
  #echo "veeam_office365_repository,repository=$repository capacity=$capacity,freeSpace=$freeSpace"
  curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_office365_repository,repository=$repository capacity=$capacity,freeSpace=$freeSpace"
  if [[ "$objectStorageId" == "null" ]]; then
        echo "It seems you are not using Object Storage offload on the Repository $repository, that's fine."
  else  
  ##
  # Veeam Backup for Microsoft 365 Object Storage Repositories. This part will check the capacity and used space of the Object Storage Repositories
  ##
  veeamVBOUrl="$veeamRestServer:$veeamRestPort/v6/objectstoragerepositories/$objectStorageId"
  veeamObjectUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVBOUrl" 2>&1 -k --silent)

        objectName=$(echo "$veeamObjectUrl" | jq --raw-output ".name" | awk '{gsub(/ /,"\\ ");print}')
        usedSpaceGB=$(echo "$veeamObjectUrl" | jq --raw-output ".usedSpaceBytes")
        type=$(echo "$veeamObjectUrl" | jq --raw-output ".type")
        # Bucket information
        case $type in
        "AmazonS3Compatible")
            bucketname=$(echo "$veeamObjectUrl" | jq --raw-output ".amazonBucketS3Compatible.name" | awk '{gsub(/ /,"\\ ");print}')
            servicePoint=$(echo "$veeamObjectUrl" | jq --raw-output ".amazonBucketS3Compatible.servicePoint" | awk '{gsub(/ /,"\\ ");print}')
            customRegionId=$(echo "$veeamObjectUrl" | jq --raw-output ".amazonBucketS3Compatible.customRegionId" | awk '{gsub(/ /,"\\ ");print}')
        ;;
        "AmazonS3")
            bucketname=$(echo "$veeamObjectUrl" | jq --raw-output ".amazonBucketS3Aws.name" | awk '{gsub(/ /,"\\ ");print}')
            servicePoint=$(echo "$veeamObjectUrl" | jq --raw-output ".amazonBucketS3Aws.regionId" | awk '{gsub(/ /,"\\ ");print}')
            customRegionId=$(echo "$veeamObjectUrl" | jq --raw-output ".amazonBucketS3Aws.regionName" | awk '{gsub(/ /,"\\ ");print}')
        ;;
        "AzureBlob")
            bucketname=$(echo "$veeamObjectUrl" | jq --raw-output ".azureContainer.name" | awk '{gsub(/ /,"\\ ");print}')
            servicePoint="AzureBlob"
            customRegionId=$(echo "$veeamObjectUrl" | jq --raw-output ".azureContainer.regionType" | awk '{gsub(/ /,"\\ ");print}')
        ;;
        esac

        #echo "veeam_office365_objectstorage,objectname=$objectName,type=$type,bucketname=$bucketname,servicePoint=$servicePoint,customRegionId=$customRegionId,objectStorageEncryptionEnabled=$objectStorageEncryptionEnabled usedSpaceGB=$usedSpaceGB"
        curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_office365_objectstorage,objectname=$objectName,type=$type,bucketname=$bucketname,servicePoint=$servicePoint,customRegionId=$customRegionId,objectStorageEncryptionEnabled=$objectStorageEncryptionEnabled usedSpaceGB=$usedSpaceGB"
    fi
    arrayrepo=$arrayrepo+1
done


##
# Veeam Backup for Microsoft 365 Backup Proxies. This part will check the Name and Threads Number of the Backup Proxies
##
veeamVBOUrl="$veeamRestServer:$veeamRestPort/v6/Proxies"
veeamProxyUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVBOUrl" 2>&1 -k --silent)

declare -i arrayprox=0
for id in $(echo "$veeamProxyUrl" | jq -r '.[].id'); do
    hostName=$(echo "$veeamProxyUrl" | jq --raw-output ".[$arrayprox].hostName" | awk '{gsub(/ /,"\\ ");print}')
    threadsNumber=$(echo "$veeamProxyUrl" | jq --raw-output ".[$arrayprox].threadsNumber")
    status=$(echo "$veeamProxyUrl" | jq --raw-output ".[$arrayprox].status")
    
    #echo "veeam_office365_proxies,proxies=$hostName,status=$status threadsNumber=$threadsNumber"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_office365_proxies,proxies=$hostName,status=$status threadsNumber=$threadsNumber"
    arrayprox=$arrayprox+1
done

##
# Veeam Backup for Microsoft 365 Backup Jobs. This part will check the different Jobs, and the Job Sessions per every Job
##
veeamVBOUrl="$veeamRestServer:$veeamRestPort/v6/Jobs"
veeamJobsUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVBOUrl" 2>&1 -k --silent)

declare -i arrayJobs=0
for id in $(echo "$veeamJobsUrl" | jq -r '.[].id'); do
    nameJob=$(echo "$veeamJobsUrl" | jq --raw-output ".[$arrayJobs].name" | awk '{gsub(/ /,"\\ ");print}')
    idJob=$(echo "$veeamJobsUrl" | jq --raw-output ".[$arrayJobs].id")
    
    # Backup Job Sessions
    veeamVBOUrl="$veeamRestServer:$veeamRestPort/v6/Jobs/$idJob/JobSessions"
    veeamJobSessionsUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVBOUrl" 2>&1 -k --silent)
    declare -i arrayJobsSessions=0
    for id in $(echo "$veeamJobSessionsUrl" | jq -r '.results[].id'); do
        status=$(echo "$veeamJobSessionsUrl" | jq --raw-output ".results[$arrayJobsSessions].status")
        if [[ "$status" != "Running" ]]; then
            creationTime=$(echo "$veeamJobSessionsUrl" | jq --raw-output ".results[$arrayJobsSessions].creationTime")
            creationTimeUnix=$(date -d "$creationTime" +"%s")
            endTime=$(echo "$veeamJobSessionsUrl" | jq --raw-output ".results[$arrayJobsSessions].endTime")
            endTimeUnix=$(date -d "$endTime" +"%s")
            totalDuration=$(($endTimeUnix - $creationTimeUnix))
      
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
            processingRate=$(echo "$veeamJobSessionsUrl" | jq --raw-output ".results[$arrayJobsSessions].statistics.processingRateBytesPS")
            readRate=$(echo "$veeamJobSessionsUrl" | jq --raw-output ".results[$arrayJobsSessions].statistics.readRateBytesPS")
            writeRate=$(echo "$veeamJobSessionsUrl" | jq --raw-output ".results[$arrayJobsSessions].statistics.writeRateBytesPS")
            transferredData=$(echo "$veeamJobSessionsUrl" | jq --raw-output ".results[$arrayJobsSessions].statistics.transferredDataBytes")
            processedObjects=$(echo "$veeamJobSessionsUrl" | jq --raw-output ".results[$arrayJobsSessions].statistics.processedObjects")
            bottleneck=$(echo "$veeamJobSessionsUrl" | jq --raw-output ".results[$arrayJobsSessions].statistics.bottleneck")
      
            #echo "veeam_office365_jobs,veeamjobname=$nameJob,bottleneck=$bottleneck totalDuration=$totalDuration,status=$jobStatus,processingRate=$processingRate,readRate=$readRate,writeRate=$writeRate,transferredData=$transferredData,processedObjects=$processedObjects $endTimeUnix"
            curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_office365_jobs,veeamjobname=$nameJob,bottleneck=$bottleneck totalDuration=$totalDuration,status=$jobStatus,processingRate=$processingRate,readRate=$readRate,writeRate=$writeRate,transferredData=$transferredData,processedObjects=$processedObjects $endTimeUnix"
            if [[ $arrayJobsSessions = "1000" ]]; then
                break
            else
            arrayJobsSessions=$arrayJobsSessions+1
        fi
    fi
    done
    arrayJobs=$arrayJobs+1
done

##
# Veeam Backup for Microsoft 365 Restore Portal. This part will check the if Restore Portal is enabled
##
veeamVBOUrl="$veeamRestServer:$veeamRestPort/v6/RestorePortalSettings"
veeamRestorePortalUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVBOUrl" 2>&1 -k --silent)

    restorePortalAppId=$(echo "$veeamRestorePortalUrl" | jq --raw-output ".applicationId")
    restorePortalEnabled=$(echo "$veeamRestorePortalUrl" | jq --raw-output ".isEnabled")
    case $restorePortalEnabled in
        false)
            restorePortal="1"
        ;;
        true)
            restorePortal="2"
        ;;
    esac

    #echo "veeam_office365_restoreportal,organization=$organization,restorePortalAppId=$restorePortalAppId restorePortalEnabled=$restorePortal"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_office365_restoreportal,organization=$organization,restorePortalAppId=$restorePortalAppId restorePortalEnabled=$restorePortal"

##
# Veeam Backup for Microsoft 365 RBAC Roles. This part will check the the RBAC Roles, and what privileges they have
##
veeamVBOUrl="$veeamRestServer:$veeamRestPort/v6/RbacRoles"
veeamRbacRoleUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVBOUrl" 2>&1 -k --silent)

declare -i arrayRbacRoles=0
for id in $(echo "$veeamRbacRoleUrl" | jq -r '.[].id'); do
    rbacRoleId=$(echo "$veeamRbacRoleUrl" | jq --raw-output ".[$arrayRbacRoles].id")
    rbacRoleName=$(echo "$veeamRbacRoleUrl" | jq --raw-output ".[$arrayRbacRoles].name" | awk '{gsub(/ /,"\\ ");print}')
    rbacRoleDescription=$(echo "$veeamRbacRoleUrl" | jq --raw-output ".[$arrayRbacRoles].description" | awk '{gsub(/ /,"\\ ");print}')
    rbacRoleType=$(echo "$veeamRbacRoleUrl" | jq --raw-output ".[$arrayRbacRoles].roleType" | awk '{gsub(/ /,"\\ ");print}')
    rbacRoleOrganizationId=$(echo "$veeamRbacRoleUrl" | jq --raw-output ".[$arrayRbacRoles].organizationId")

    ## Getting the Organization Name
    veeamVBOrbacUrl="$veeamRestServer:$veeamRestPort/v6/Organizations/$rbacRoleOrganizationId"
    veeamVBOrbacUrlresult=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVBOrbacUrl" 2>&1 -k --silent)
    rbacOrganization=$(echo "$veeamVBOrbacUrlresult" | jq --raw-output '.name')


    ## Check the RBAC Restore Operators
    veeamVBOUrl="$veeamRestServer:$veeamRestPort/v6/RbacRoles/$rbacRoleId/operators"
    veeamRbacRoleOperatorUrl=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVBOUrl" 2>&1 -k --silent)

    declare -i arrayRbacRolesOperators=0
    for id in $(echo "$veeamRbacRoleOperatorUrl" | jq -r '.[].type'); do
        rbacRoleScopeType=$(echo "$veeamRbacRoleOperatorUrl" | jq --raw-output ".[$arrayRbacRolesOperators].type")

        case $rbacRoleScopeType in
        User)
            rbacROName=$(echo "$veeamRbacRoleOperatorUrl" | jq --raw-output ".[$arrayRbacRolesOperators].user.displayName" | awk '{gsub(/ /,"\\ ");print}')
            rbacRO365Name=$(echo "$veeamRbacRoleOperatorUrl" | jq --raw-output ".[$arrayRbacRolesOperators].user.name" | awk '{gsub(/ /,"\\ ");print}')
            #echo "veeam_office365_rbac_operators,organization=$rbacOrganization,rbacRoleName=$rbacRoleName,type=User,rbacROName=$rbacROName,rbacRO365Name=$rbacRO365Name rbacRoleAdminId=$arrayRbacRolesOperators"
            curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_office365_rbac_operators,organization=$rbacOrganization,rbacRoleName=$rbacRoleName,type=User,rbacROName=$rbacROName,rbacRO365Name=$rbacRO365Name rbacRoleAdminId=$arrayRbacRolesOperators"
        ;;
        Group)
            rbacROName=$(echo "$veeamRbacRoleOperatorUrl" | jq --raw-output ".[$arrayRbacRolesOperators].group.displayName" | awk '{gsub(/ /,"\\ ");print}')
            rbacRO365Name=$(echo "$veeamRbacRoleOperatorUrl" | jq --raw-output ".[$arrayRbacRolesOperators].group.name" | awk '{gsub(/ /,"\\ ");print}')
            rbacRO365Type=$(echo "$veeamRbacRoleOperatorUrl" | jq --raw-output ".[$arrayRbacRolesOperators].group.type")
            #echo "veeam_office365_rbac_operators,organization=$rbacOrganization,rbacRoleName=$rbacRoleName,type=$rbacRoleScope365Type,rbacROName=$rbacROName,rbacRO365Name=$rbacRO365Name rbacRoleAdminId=$arrayRbacRolesOperators"
            curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_office365_rbac_operators,organization=$rbacOrganization,rbacRoleName=$rbacRoleName,type=$rbacRO365Type,rbacROName=$rbacROName,rbacRO365Name=$rbacRO365Name rbacRoleAdminId=$arrayRbacRolesOperators"
        ;;
        esac
        arrayRbacRolesOperators=$arrayRbacRolesOperators+1
    done
    echo $rbacRoleType
    if [[ "$rbacRoleType" != "EntireOrganization" ]]; then
    ## Check the RBAC Selected Items per Role
    veeamVBOUrl="$veeamRestServer:$veeamRestPort/v6/RbacRoles/$rbacRoleId/selectedItems"
    veeamRbacRoleUrlScope=$(curl -X GET --header "Accept:application/json" --header "Authorization:Bearer $veeamBearer" "$veeamVBOUrl" 2>&1 -k --silent)
    
    declare -i arrayRbacRolesScope=0
    for id in $(echo "$veeamRbacRoleUrlScope" | jq -r '.[].type'); do
        rbacRoleScopeType=$(echo "$veeamRbacRoleUrlScope" | jq --raw-output ".[$arrayRbacRolesScope].type")

        case $rbacRoleScopeType in
        User)
            rbacRoleScopeName=$(echo "$veeamRbacRoleUrlScope" | jq --raw-output ".[$arrayRbacRolesScope].user.displayName" | awk '{gsub(/ /,"\\ ");print}')
            rbacRoleScope365Name=$(echo "$veeamRbacRoleUrlScope" | jq --raw-output ".[$arrayRbacRolesScope].user.name" | awk '{gsub(/ /,"\\ ");print}')
            #echo "veeam_office365_rbac_scope,organization=$rbacOrganization,rbacRoleName=$rbacRoleName,type=User,rbacRoleScopeName=$rbacRoleScopeName,rbacRoleScope365Name=$rbacRoleScope365Name rbacRoleScopeId=$arrayRbacRoles"
            curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_office365_rbac_scope,organization=$rbacOrganization,rbacRoleName=$rbacRoleName,type=User,rbacRoleScopeName=$rbacRoleScopeName,rbacRoleScope365Name=$rbacRoleScope365Name rbacRoleScopeId=$arrayRbacRoles"
        ;;
        Group)
            rbacRoleScopeName=$(echo "$veeamRbacRoleUrlScope" | jq --raw-output ".[$arrayRbacRolesScope].group.displayName" | awk '{gsub(/ /,"\\ ");print}')
            rbacRoleScope365Name=$(echo "$veeamRbacRoleUrlScope" | jq --raw-output ".[$arrayRbacRolesScope].group.name" | awk '{gsub(/ /,"\\ ");print}')
            rbacRoleScope365Type=$(echo "$veeamRbacRoleUrlScope" | jq --raw-output ".[$arrayRbacRolesScope].group.type")
            #echo "veeam_office365_rbac_scope,organization=$rbacOrganization,rbacRoleName=$rbacRoleName,type=$rbacRoleScope365Type,rbacRoleScopeName=$rbacRoleScopeName,rbacRoleScope365Name=$rbacRoleScope365Name rbacRoleScopeId=$arrayRbacRoles"
            curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_office365_rbac_scope,organization=$rbacOrganization,rbacRoleName=$rbacRoleName,type=$rbacRoleScope365Type,rbacRoleScopeName=$rbacRoleScopeName,rbacRoleScope365Name=$rbacRoleScope365Name rbacRoleScopeId=$arrayRbacRoles"
        ;;
        Site)
            rbacRoleScopeName=$(echo "$veeamRbacRoleUrlScope" | jq --raw-output ".[$arrayRbacRolesScope].site.title" | awk '{gsub(/ /,"\\ ");print}')
            #echo "veeam_office365_rbac_scope,organization=$rbacOrganization,rbacRoleName=$rbacRoleName,type=Site,rbacRoleScopeName=$rbacRoleScopeName,rbacRoleScope365Name=$rbacRoleScopeName rbacRoleScopeId=$arrayRbacRoles"
            curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_office365_rbac_scope,organization=$rbacOrganization,rbacRoleName=$rbacRoleName,type=Site,rbacRoleScopeName=$rbacRoleScopeName,rbacRoleScope365Name=$rbacRoleScopeName rbacRoleScopeId=$arrayRbacRoles"
        ;;
        esac
        arrayRbacRolesScope=$arrayRbacRolesScope+1
    done
    elif [[ "$rbacRoleType" = "EntireOrganization" ]]; then
        echo "veeam_office365_rbac_scope,organization=$rbacOrganization,rbacRoleName=$rbacRoleName,type=EntireOrganization,rbacRoleScopeName="EntireOrganization",rbacRoleScope365Name=$EntireOrganization rbacRoleScopeId=$arrayRbacRoles"
        curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_office365_rbac_scope,organization=$rbacOrganization,rbacRoleName=$rbacRoleName,type=EntireOrganization,rbacRoleScopeName="EntireOrganization",rbacRoleScope365Name="EntireOrganization" rbacRoleScopeId=$arrayRbacRoles"
    fi     
    #echo "veeam_office365_rbac_roles,organization=$rbacOrganization,rbacRoleId=$rbacRoleId,rbacRoleName=$rbacRoleName,rbacRoleDescription=$rbacRoleDescription,rbacRoleType=$rbacRoleType rbacRoleAdminId=$arrayRbacRoles"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_office365_rbac_roles,organization=$rbacOrganization,rbacRoleId=$rbacRoleId,rbacRoleName=$rbacRoleName,rbacRoleDescription=$rbacRoleDescription,rbacRoleType=$rbacRoleType rbacRoleAdminId=$arrayRbacRoles"
    arrayRbacRoles=$arrayRbacRoles+1
done