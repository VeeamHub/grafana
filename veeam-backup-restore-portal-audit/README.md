 Grafana Dashboard to audit User Logins, and Restores on VBM365 Restore Portal
===================

![alt tag](https://jorgedelacruz.uk/wp-content/uploads/2022/03/veeam-microsoft-365-audit-001.jpg)

This project consists in a Bash Shell script to retrieve the Logins to the Veeam Backup for Microsoft 365 Restore Portal, directly from the Azure Graph. The information is being saved it into InfluxDB output directly into the InfluxDB database using curl, then in Grafana: a Dashboard is created to present all the information.

We use Azure Graph to reduce the workload and increase the speed of script execution.

----------

### Getting started
You can follow the steps on the next Blog Post - TBD

Or try with this simple steps:
* Download the veeam_microsoft365_audit.sh file and change the parameters under Configuration, like username/password, etc. with your real data
* Make the script executable with the command chmod +x veeam_microsoft365_audit.sh
* Run the veeam_microsoft365_audit.sh and check on Chronograf that you can retrieve the information properly
* Schedule the script execution, for example every 15 minutes using crontab
* Download the Grafana Dashboard for User Audit VB365 JSON file and import it into your Grafana
* Enjoy :)

----------

### Additional Information
* Nothing to add as of today

### Known issues 
Would love to see some known issues and keep opening and closing as soon as I have feedback from you guys. Fork this project, use it and please provide feedback.
