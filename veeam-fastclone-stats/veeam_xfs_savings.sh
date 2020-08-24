#!/bin/bash
##      .SYNOPSIS
##      Grafana Dashboard for XFS reflink disk savings
## 
##      .DESCRIPTION
##      This Script will query all the backup folders inside your XFS Backup Repository and give you the total size, and the size with the reflink applied
##      The Script and the Grafana Dashboard it is provided as it is, and bear in mind you can not open support Tickets regarding this project. It is a Community Project
##	
##      .Notes
##      NAME:  veeam_xfs_savings.sh
##      ORIGINAL NAME: veeam_xfs_savings.sh
##      LASTEDIT: 22/08/2020
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
veeamXFSMount="/backups/" #Your XFS mount point
veeamRepoName="VEEAM-XFS-001" #Your XFS Repo Name in Veeam Backup & Replication Server
type="XFS"


for f in $veeamXFSMount*; do
    if [ -d "$f" ]; then
        backupjobname=$(echo $f | awk -F"$veeamXFSMount" '{print $2}')
        totaldisk=$(du $f | awk '{ print $1 }')
        totalconsumed=$(df $f | awk '$4 ~ /[[:digit:]]+/ { print $3 }')
        
        ##Un-comment the following echo for debugging
        #echo "veeam_fastclone_stats,repo=$veeamXFSMount,type=$type,backup=$backupjobname totaldisk=$totaldisk,savings=$savings,realconsumed=$totalconsumed"
        
        ##Comment the Curl while debugging
        echo "Writing veeam_xfs_savings to InfluxDB"
        curl -i -XPOST "$veeamInfluxDBURL:$veeamInfluxDBPort/write?precision=s&db=$veeamInfluxDB" -u "$veeamInfluxDBUser:$veeamInfluxDBPassword" --data-binary "veeam_fastclone_stats,repoxfs=$veeamRepoName,type=$type,backupxfs=$backupjobname totaldisk=$totaldisk,realconsumed=$totalconsumed"
    fi
done