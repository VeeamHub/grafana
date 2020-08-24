 Grafana Dashboard to check ReFS and XFS fast-clone disk savings from Veeam Backup & Replication
===================

![alt tag](https://www.jorgedelacruz.es/wp-content/uploads/2020/08/grafana-refs-xfs-001.png)

This project consists in a Bash Shell script, and a PowerShell Script and to retrieve the ReFS/XFS disk information and savings, for ReFS it does uses Timothy blockstat.exe. The information is being saved it into InfluxDB output directly into the InfluxDB database using curl, then in Grafana: a Dashboard is created to present all the information.

----------

### Getting started
You can follow the steps on the next Blog Post - [https://jorgedelacruz.uk/2020/08/24/looking-for-the-perfect-dashboard-influxdb-telegraf-and-grafana-part-xxvii-monitoring-refs-and-xfs-block-cloning-and-reflink/](https://jorgedelacruz.uk/2020/08/24/looking-for-the-perfect-dashboard-influxdb-telegraf-and-grafana-part-xxvii-monitoring-refs-and-xfs-block-cloning-and-reflink/)

Or try with this simple steps:
Just download the latest scripts for either your ReFS or XFS Repositories from GitHub [https://github.com/jorgedlcruz/veeam-fastclone-stats/raw/master/veeam_refs_savings.ps1](https://github.com/jorgedlcruz/veeam-fastclone-stats/raw/master/veeam_refs_savings.ps1) or [https://github.com/jorgedlcruz/veeam-fastclone-stats/raw/master/veeam_xfs_savings.sh](https://github.com/jorgedlcruz/veeam-fastclone-stats/raw/master/veeam_xfs_savings.sh) and change the Configuration section within your details:

For PowerShell

```
##
# Configurations
##
# Logical Volume with ReFS enabled
$dir = "T:\"
# Path to the blockstat.exe and for the output path
$exe = "C:\blockstat\blockstat.exe"
$listfilepath = "C:\blockstat\in.txt"
$outputpath = "C:\blockstat\out.xml"
$type="ReFS"

# Endpoint URL for InfluxDB
$veeamInfluxDBURL="http://YOURINFLUXSERVERIP" #Your InfluxDB Server, http://FQDN or https://FQDN if using SSL
$veeamInfluxDBPort="8086" #Default Port
$veeamInfluxDB="telegraf" #Default Database
$veeamInfluxDBUser="USER" #User for Database
$veeamInfluxDBPassword='PASSWORD' | ConvertTo-SecureString -asPlainText -Force
``` 

For the Bash Shell Script

```
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
``` 

Once the changes are done, make the script executable with chmod:

```
chmod +x veeam_xfs_savings.sh
``` 

The output of the command should be something like the next, without errors:

```
Writing veeam_xfs_savings to InfluxDB
HTTP/1.1 204 No Content
Content-Type: application/json
Request-Id: 98793b48-e51b-11ea-8307-dca632b112f7
X-Influxdb-Build: OSS
X-Influxdb-Version: 1.8.2
X-Request-Id: 98793b48-e51b-11ea-8307-dca632b112f7
Date: Sun, 23 Aug 2020 08:35:27 GMT

Writing veeam_xfs_savings to InfluxDB
HTTP/1.1 204 No Content
Content-Type: application/json
Request-Id: 9887b0af-e51b-11ea-8308-dca632b112f7
X-Influxdb-Build: OSS
X-Influxdb-Version: 1.8.2
X-Request-Id: 9887b0af-e51b-11ea-8308-dca632b112f7
Date: Sun, 23 Aug 2020 08:35:27 GMT
``` 

If so, please now add this script to your crontab, like for example every 24 hours:

```
0 3 * * * /home/oper/veeam_xfs_savings.sh >> /var/log/veeam_veeam_xfs_savings.log 2>&1
```
----------

### Additional Information
* Nothing to add as of today

### Known issues 
Would love to see some known issues and keep opening and closing as soon as I have feedback from you guys. Fork this project, use it and please provide feedback.
