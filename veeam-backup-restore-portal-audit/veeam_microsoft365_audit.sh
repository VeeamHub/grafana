#!/bin/bash
##      .SYNOPSIS
##      Grafana Dashboard for Enhanced Auditing of the Veeam Backup for Microsoft 365 Portal - Using RestAPI to Azure AD Graph, VBM365, to InfluxDB Script
## 
##      .DESCRIPTION
##      This Script will query the Azure AD Graph, and the Veeam Backup for Microsoft 365 RestAPI and send the data directly to InfluxDB, which can be used to present it to Grafana. 
##      The Script and the Grafana Dashboard it is provided as it is, and bear in mind you can not open support Tickets regarding this project. It is a Community Project
##	
##      .Notes
##      NAME:  veeam_microsoft365_audit.sh
##      ORIGINAL veeam_microsoft365_audit.sh
##      LASTEDIT: 29/03/2022
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

# Endpoint Configuration for Azure AD
ApplicationID="YOURAPPLICATIONID" # You can find these on your VB365 Server, on the Restore Portal, or in Azure
TenatDomainName="YOURTENANTDOMAINNAME" # Easy to find this on the next URL - https://portal.azure.com/#blade/Microsoft_AAD_IAM/TenantPropertiesBlade
AccessSecret="YOURACCESSSECRET" # Create a new Client secret under your Veeam Restore Portal App registrations in Azure
GraphLoginURL="https://graph.microsoft.com/.default"
GraphToken=$(curl -X POST --header "Content-Type: application/x-www-form-urlencoded" \
--header "Accept: application/json" \
-d "grant_type=client_credentials&scope=$GraphLoginURL&client_id=$ApplicationID&client_secret=$AccessSecret" \
"https://login.microsoftonline.com/$TenatDomainName/oauth2/v2.0/token" -k --silent \
| jq -r '.access_token')

# Endpoint Configuration for Veeam Backup for Microsoft 365
veeamUsername="YOURVBOUSER"
veeamPassword="YOURVBOPASSWORD"
veeamRestServer="https://YOURVBOSERVERIP"
veeamRestPort="4443" #Default Port
veeamBearer=$(curl -X POST --header "Content-Type: application/x-www-form-urlencoded" --header "Accept: application/json" -d "grant_type=password&username=$veeamUsername&password=$veeamPassword&refresh_token=%27%27" "$veeamRestServer:$veeamRestPort/v6/token" -k --silent | jq -r '.access_token')

## AzureAD - Audit of Users accesing Veeam Restore Portal
GraphLogsURL="https://graph.microsoft.com/v1.0/auditLogs/signIns"

AzureADAudit=$(curl -X GET --header "Accept: application/json" \
--header "Authorization:Bearer $GraphToken" -k --silent \
$GraphLogsURL)

declare -i arrayaudit=0
for id in $(echo "$AzureADAudit" | jq -r '.value[].id'); do
    veeamVBMRPAppID=$(echo "$AzureADAudit" | jq --raw-output ".value[$arrayaudit].appId")
    if [[ "$veeamVBMRPAppID" == "$ApplicationID" ]]; then
    veeamVBMRPLoginDate=$(echo "$AzureADAudit" | jq --raw-output ".value[$arrayaudit].createdDateTime")
    veeamVBMRPLoginDateUnix=$(date -d "$veeamVBMRPLoginDate" +"%s")
    veeamVBMRPLoginID=$(echo "$AzureADAudit" | jq --raw-output ".value[$arrayaudit].id")
    veeamVBMRPUserPN=$(echo "$AzureADAudit" | jq --raw-output ".value[$arrayaudit].userPrincipalName")
    veeamVBMRPUserDN=$(echo "$AzureADAudit" | jq --raw-output ".value[$arrayaudit].userDisplayName" | awk '{gsub(/ /,"\\ ");print}')
    veeamVBMRPUserID=$(echo "$AzureADAudit" | jq --raw-output ".value[$arrayaudit].userId")
    veeamVBMRPAppDN=$(echo "$AzureADAudit" | jq --raw-output ".value[$arrayaudit].appDisplayName" | awk '{gsub(/ /,"\\ ");print}')
    veeamVBMRPLoginIP=$(echo "$AzureADAudit" | jq --raw-output ".value[$arrayaudit].ipAddress")
    veeamVBMRPLoginAppUsed=$(echo "$AzureADAudit" | jq --raw-output ".value[$arrayaudit].clientAppUsed" | awk '{gsub(/ /,"\\ ");print}')
    veeamVBMRPLoginStatus=$(echo "$AzureADAudit" | jq --raw-output ".value[$arrayaudit].status.errorCode")
    veeamVBMRPLoginFailureReason=$(echo "$AzureADAudit" | jq --raw-output ".value[$arrayaudit].status.failureReason" | awk '{gsub(/ /,"\\ ");print}' | tr ',' ' ')
    veeamVBMRPLoginDevice=$(echo "$AzureADAudit" | jq --raw-output ".value[$arrayaudit].deviceDetail.operatingSystem" | awk '{gsub(/ /,"\\ ");print}')
    [[ ! -z "$veeamVBMRPLoginDevice" ]] || veeamVBMRPLoginDevice="Terminal/CLI"
    veeamVBMRPLoginBrowser=$(echo "$AzureADAudit" | jq --raw-output ".value[$arrayaudit].deviceDetail.browser" | awk '{gsub(/ /,"\\ ");print}')
    veeamVBMRPLoginLocationCity=$(echo "$AzureADAudit" | jq --raw-output ".value[$arrayaudit].location.city")
    veeamVBMRPLoginLocationState=$(echo "$AzureADAudit" | jq --raw-output ".value[$arrayaudit].location.state" | awk '{gsub(/ /,"\\ ");print}')
    veeamVBMRPLoginLocationCountry=$(echo "$AzureADAudit" | jq --raw-output ".value[$arrayaudit].location.countryOrRegion")
    veeamVBMRPLoginLocationCityGEOLAT=$(echo "$AzureADAudit" | jq --raw-output ".value[$arrayaudit].location.geoCoordinates.latitude")
    veeamVBMRPLoginLocationCityGEOLONG=$(echo "$AzureADAudit" | jq --raw-output ".value[$arrayaudit].location.geoCoordinates.longitude")
    #echo "veeam_microsoft365_audit,veeamVBMRPAppID=$veeamVBMRPAppID,veeamVBMRPAppDN=$veeamVBMRPAppDN,veeamVBMRPUserPN=$veeamVBMRPUserPN,veeamVBMRPUserDN=$veeamVBMRPUserDN,veeamVBMRPUserID=$veeamVBMRPUserID,veeamVBMRPLoginIP=$veeamVBMRPLoginIP,veeamVBMRPLoginID=$veeamVBMRPLoginID,veeamVBMRPLoginAppUsed=$veeamVBMRPLoginAppUsed,veeamVBMRPLoginStatus=$veeamVBMRPLoginStatus,veeamVBMRPLoginFailureReason=$veeamVBMRPLoginFailureReason,veeamVBMRPLoginDevice=$veeamVBMRPLoginDevice,veeamVBMRPLoginBrowser=$veeamVBMRPLoginBrowser,veeamVBMRPLoginLocationCity=$veeamVBMRPLoginLocationCity,veeamVBMRPLoginLocationState=$veeamVBMRPLoginLocationState,veeamVBMRPLoginLocationCountry=$veeamVBMRPLoginLocationCountry veeamVBMRPLoginLocationCityGEOLAT=$veeamVBMRPLoginLocationCityGEOLAT,veeamVBMRPLoginLocationCityGEOLONG=$veeamVBMRPLoginLocationCityGEOLONG $veeamVBMRPLoginDateUnix"
    curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/api/v2/write?org=$veeamInfluxDBOrg&bucket=$veeamInfluxDBBucket&precision=s" -H "Authorization: Token $veeamInfluxDBToken" --data-binary "veeam_microsoft365_audit,veeamVBMRPAppID=$veeamVBMRPAppID,veeamVBMRPAppDN=$veeamVBMRPAppDN,veeamVBMRPUserPN=$veeamVBMRPUserPN,veeamVBMRPUserDN=$veeamVBMRPUserDN,veeamVBMRPUserID=$veeamVBMRPUserID,veeamVBMRPLoginIP=$veeamVBMRPLoginIP,veeamVBMRPLoginID=$veeamVBMRPLoginID,veeamVBMRPLoginAppUsed=$veeamVBMRPLoginAppUsed,veeamVBMRPLoginStatus=$veeamVBMRPLoginStatus,veeamVBMRPLoginFailureReason=$veeamVBMRPLoginFailureReason,veeamVBMRPLoginDevice=$veeamVBMRPLoginDevice,veeamVBMRPLoginBrowser=$veeamVBMRPLoginBrowser,veeamVBMRPLoginLocationCity=$veeamVBMRPLoginLocationCity,veeamVBMRPLoginLocationState=$veeamVBMRPLoginLocationState,veeamVBMRPLoginLocationCountry=$veeamVBMRPLoginLocationCountry veeamVBMRPLoginLocationCityGEOLAT=$veeamVBMRPLoginLocationCityGEOLAT,veeamVBMRPLoginLocationCityGEOLONG=$veeamVBMRPLoginLocationCityGEOLONG $veeamVBMRPLoginDateUnix"
    fi
    
    arrayaudit=$arrayaudit+1
done