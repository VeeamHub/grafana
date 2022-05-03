Grafana Dashboard for Veeam Backup for Microsoft 365 Audit Restores
===================

![alt tag](https://jorgedelacruz.uk/wp-content/uploads/2022/05/grafana-vb365-restore-audit-001.jpg)

With Veeam Backup for Microsoft 365 v6.0, many enhancements and new features were released. Among tons of them, one of my favorites is the enhancements to the RESTful API, especially around the Restore Sessions. With the latest update, the holy grail has been unlocked, and now we can correctly retrieve the details of the Restore Sessions, like really deep. This project will download the latest Restore Sessions programmatically, with all levels of more information, and write them into InfluxDB so that you can visualize them quickly and more potent with Grafana.

----------

### Getting started
You can follow the steps on the next Blog Post - TBD

Or try with this simple steps:
* Download the veeam_backup_microsoft365_audit.sh file and change the parameters under Configuration, like username/password, etc. with your real data
* Make the script executable with the command chmod +x veeam_backup_microsoft365_audit.sh
* Run the veeam_backup_microsoft365_audit.sh and check on InfluxDB that you can retrieve the information properly
* Schedule the script execution, for example every hour using crontab
* Download the Veeam Backup for Microsoft 365 JSON file and import it into your Grafana
* Enjoy :)

----------

### Additional Information
* Nothing to add as of today

### Known issues 
Would love to see some known issues and keep opening and closing as soon as I have feedback from you guys. Fork this project, use it and please provide feedback.