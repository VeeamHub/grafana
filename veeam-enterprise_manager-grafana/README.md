How to monitor a Veeam Environment using Veeam Enterprise Manager, Powershell, Telegraf, InfluxDB and Grafana
===================

![alt tag](https://www.jorgedelacruz.es/wp-content/uploads/2017/07/veeam-grafana-restapi-002.png)

This project consists in a Powershell script to retrieve the Veeam Backup & Replication information, directly from the Veeam Enterprise Manager RESTfulAPI, about last jobs, etc, and save it into InfluxDB output which we send to InfluxDB using Telegraf, then in Grafana: a Dashboard is created to present all the information.

We use Veeam Enterprise Manager and the RESTfulAPI to reduce the workload and increase the speed of script execution, here is a comparison between same Script using VeeamPSSnapIn vs. RESTfulAPI:

![alt tag](https://www.jorgedelacruz.es/wp-content/uploads/2017/07/veeam-grafana-restapi-003.png)

----------

### Getting started
You can follow the steps on the next Blog Post - http://jorgedelacruz.uk/2017/07/26/looking-perfect-dashboard-influxdb-telegraf-grafana-part-viii-monitoring-veeam-using-veeam-enterprise-manager/

Or try with this simple steps:
* Download the veeam-stats_EM.ps1 file and change the BRHost, username and password with your real data
* Run the veeam-stats_EM.ps1 to check that you can retrieve the information properly
* Add the next content to your telegraf.conf and restart the telegraf service. Please be aware of path of the Script.
```
 [[inputs.exec]]
  commands = ["powershell C:/veeam-stats_EM.ps1"]
  name_override = "veeamstats_EM"
  interval = "60s"
  timeout = "60s"
  data_format = "influx"
```
* It's probably that you will need to change the Telegraf Service in Windows to be run by another user other than Local System

![alt tag](https://www.jorgedelacruz.es/wp-content/uploads/2017/07/telegraf-service.png)

* Download the grafana-enterprise_manager-dashboard JSON file and import it into your Grafana
* Change your data inside the Grafana and enjoy :)

----------

### Additional Information
* You can find the original code for PRTG here, thank you so much Markus Kraus: https://mycloudrevolution.com/2016/02/29/prtg-veeam-br-monitoring/

I hope it helps you

### Known issues 
If you don't change the Telegraf privileges to run as another user you might see the next error:
```
2017-07-31T09:32:33Z E! Error in plugin [inputs.exec]:  metric parsing error, reason: [missing field value], buffer: [veeamstats_EM successfuljobruns=]
```
Just follow the previous image about how to change the privileges on the Telegraf Windows Service