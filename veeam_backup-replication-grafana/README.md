How to monitor a Veeam Environment using Powershell, Telegraf, InfluxDB and Grafana
===================

![alt tag](https://www.jorgedelacruz.es/wp-content/uploads/2017/02/27/veeam-grafana-004.png)

This project consists in a Powershell script to retrieve the Veeam Backup & Replication information about last jobs, etc, and save it into JSON which we send to InfluxDB using Telegraf, then in Grafana: a Dashboard is created to present all the information.

----------

### Getting started
You can follow the steps on the next Blog Post in Spanish - https://www.jorgedelacruz.es/2017/02/28/en-busca-del-dashboard-perfecto-influxdb-telegraf-y-grafana-parte-vi-monitorizando-veeam/

But in case you can't read Spanish:
* Download the veeam-stats.ps1 file and change the BRHost with your own fqdn or IP
* Run the veeam-stats.ps1 to check that you can retrieve the information properly
* Add the next to your telegraf.conf and restart the telegraf service. Mind the Script path, also if your environment is quite large, you need to tune the interval and timeout and set them higher times 600s for example
```
 [[inputs.exec]]
  commands = ["powershell C:/veeam-stats.ps1"]
  name_override = "veeamstats"
  interval = "60s"
  timeout = "60s"
  data_format = "influx"
```
* Download the grafana_veeam_dashboard JSON file and import it into your Grafana
* Change your hosts inside the Grafana and enjoy :)

----------

### Additional Information
* You can find the original code for PRTG here, thank you so much Markus Kraus: https://github.com/mycloudrevolution/Advanced-PRTG-Sensors/blob/master/Veeam/PRTG-VeeamBRStats.ps1
* Big thanks to Shawn, creating a awsome Reporting Script: http://blog.smasterson.com/2016/02/16/veeam-v9-my-veeam-report-v9-0-1/

I hope it helps you
