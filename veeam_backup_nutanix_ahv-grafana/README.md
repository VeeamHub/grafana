Grafana Dashboard for Veeam Backup for Nutanix AHV
===================

![alt tag](https://www.jorgedelacruz.es/wp-content/uploads/2020/08/grafana-nutanix-001-1.png)

This project consists in a Bash Shell script to retrieve the Veeam Backup for Nutanix AHV information, directly from the RESTfulAPI, about last jobs, VMs and much more. The information is being saved it into InfluxDB output directly into the InfluxDB database using curl, then in Grafana: a Dashboard is created to present all the information.

We use Veeam Backup for Nutanix AHV v2.0 RESTfulAPI (not officially supported) to reduce the workload and increase the speed of script execution. 

----------

### Getting started
You can follow the steps on the next Blog Post - [https://jorgedelacruz.uk/2020/08/18/looking-for-the-perfect-dashboard-influxdb-telegraf-and-grafana-part-xxvi-monitoring-veeam-backup-for-nutanix/](https://jorgedelacruz.uk/2020/08/18/looking-for-the-perfect-dashboard-influxdb-telegraf-and-grafana-part-xxvi-monitoring-veeam-backup-for-nutanix/)

Or try with this simple steps:
* Download the veeam_nutanixahv.sh file and change the parameters under Configuration, like username/password, etc. with your real data
* Make the script executable with the command chmod +x veeam_nutanixahv.sh
* Run the veeam_nutanixahv.sh and check on Chronograf that you can retrieve the information properly
* Schedule the script execution, for example every 30 minutes using crontab
* Download the Veeam Backup for Nutanix AHV JSON file and import it into your Grafana
* Enjoy :)

----------

### Additional Information
* Nothing to add as of today

### Known issues 
Would love to see some known issues and keep opening and closing as soon as I have feedback from you guys. Fork this project, use it and please provide feedback.