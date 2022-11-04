 Grafana Dashboard for Veeam Backup for Salesforce
===================

![alt tag](https://jorgedelacruz.uk/wp-content/uploads/2022/11/grafana-veeam-salesforce-001-1.png)

This project consists in a Bash Shell script to retrieve the Veeam Backup for Salesforce information, directly from the RESTfulAPI (not documented, and unsupported API for now! Beware!), about last jobs, users and much more. The information is being saved it into InfluxDB output directly into the InfluxDB database using curl, then in Grafana: a Dashboard is created to present all the information.

We use Veeam Backup for Salesforce RESTfulAPI to reduce the workload and increase the speed of script execution.

----------

### Getting started
You can follow the steps on the next Blog Post - https://jorgedelacruz.uk/2022/11/02/looking-for-the-perfect-dashboard-influxdb-telegraf-and-grafana-part-xli-veeam-backup-for-salesforce/

Or try with this simple steps:
* Download the grafana_influxdb_veeam_backup_salesforce.sh file and change the parameters under Configuration, like username/password, etc. with your real data
* Make the script executable with the command chmod +x grafana_influxdb_veeam_backup_salesforce.sh
* Run the grafana_influxdb_veeam_backup_salesforce.sh and check on Chronograf that you can retrieve the information properly
* Schedule the script execution, for example every 30 minutes using crontab
* Download the Veeam Backup for Salesforce JSON file and import it into your Grafana
* Enjoy :)

----------

### Additional Information
* Nothing to add as of today

### Known issues 
Would love to see some known issues and keep opening and closing as soon as I have feedback from you guys. Fork this project, use it and please provide feedback.
