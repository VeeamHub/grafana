Grafana Dashboard for Veeam Backup for Microsoft 365
===================

![alt tag](https://jorgedelacruz.uk/wp-content/uploads/2022/03/veeam-office365-grafana-2022.jpg)

This project consists in a Bash Shell script to retrieve the Veeam Backup for Microsoft 365 information, directly from the RESTfulAPI, about last jobs, users and much more. The information is being saved it into InfluxDB output directly into the InfluxDB database using curl, then in Grafana: a Dashboard is created to present all the information.

We use Veeam Backup for Microsoft 365 RESTfulAPI to reduce the workload and increase the speed of script execution. Object Storage information it is pulled as well as a new funcionality 

----------

### Getting started
You can follow the steps on the next Blog Post - https://jorgedelacruz.uk/2018/12/17/looking-for-the-perfect-dashboard-influxdb-telegraf-and-grafana-part-xiii-veeam-backup-for-microsoft-office-365/

Or try with this simple steps:
* Download the veeam_microsoft365.sh file and change the parameters under Configuration, like username/password, etc. with your real data
* Make the script executable with the command chmod +x veeam_microsoft365.sh
* Run the veeam_microsoft365.sh and check on Chronograf that you can retrieve the information properly
* Schedule the script execution, for example every 30 minutes using crontab
* Download the Veeam Backup for Microsoft 365 JSON file and import it into your Grafana
* Enjoy :)

----------

### Additional Information
* Nothing to add as of today

### Known issues 
Would love to see some known issues and keep opening and closing as soon as I have feedback from you guys. Fork this project, use it and please provide feedback.