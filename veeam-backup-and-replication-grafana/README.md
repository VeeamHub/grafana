Grafana Dashboard for Veeam Backup & Replication REST API
===================

![alt tag](https://jorgedelacruz.uk/wp-content/uploads/2023/05/grafana-veeam-api-001-1.jpg)

This project consists in a Bash Shell script to retrieve the Veeam Backup & Replication information, directly from the RESTfulAPI, about last jobs, users and much more. The information is being saved it into InfluxDB output directly into the InfluxDB database using curl, then in Grafana: a Dashboard is created to present all the information.

We use Veeam Backup & Replication RESTfulAPI to reduce the workload and increase the speed of script execution. 

----------

### Getting started
You can follow the steps on the next Blog Post - https://jorgedelacruz.uk/2023/05/31/looking-for-the-perfect-dashboard-influxdb-telegraf-and-grafana-part-xliv-monitoring-veeam-backup-replication-api/

Or try with this simple steps:
* Download the veeam_backup_and_replication.sh file and change the parameters under Configuration, like username/password, etc. with your real data
* Make the script executable with the command chmod +x veeam_backup_and_replication.sh
* Run the veeam_backup_and_replication.sh and check on InfluxDB UI that you can retrieve the information properly
* Schedule the script execution, for example every 30 minutes using crontab
* Download the Veeam Backup & Replication JSON file and import it into your Grafana
* Enjoy :)

----------

### Additional Information
* Nothing to add as of today

### Known issues 
Would love to see some known issues and keep opening and closing as soon as I have feedback from you guys. Fork this project, use it and please provide feedback.