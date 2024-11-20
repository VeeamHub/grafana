Grafana Dashboard for Veeam Backup for Microsoft Azure
===================

![alt tag](https://jorgedelacruz.uk/wp-content/uploads/2024/11/grafana-vbazure-v7.jpg)

This project consists in a Bash Shell script to retrieve the Veeam Backup for Microsoft Azure information, directly from the RESTfulAPI, about last jobs, VMs and much more. The information is being saved it into InfluxDB output directly into the InfluxDB database using curl, then in Grafana: a Dashboard is created to present all the information.

We use Veeam Backup for Microsoft Azure RESTfulAPI to reduce the workload and increase the speed of script execution. 

----------

### Getting started
You can follow the steps on the next Blog Post - https://jorgedelacruz.uk/2018/12/17/looking-for-the-perfect-dashboard-influxdb-telegraf-and-grafana-part-xiii-veeam-backup-for-microsoft-office-365/

Or try with this simple steps:
* Download the veeam_azure.sh file and change the parameters under Configuration, like username/password, etc. with your real data
* Make the script executable with the command chmod +x veeam_azure.sh
* Run the veeam_azure.sh and check on Chronograf that you can retrieve the information properly
* Schedule the script execution, for example every 30 minutes using crontab
* Download the Veeam Backup for Microsoft Azure JSON file and import it into your Grafana
* Enjoy :)

**Extra**
You will need two extra grafana plugins, in case you do not have them, the pie-chart, and the Worldmap Panel, you can quickly install them with the next:

``grafana-cli plugins install grafana-worldmap-panel``

``grafana-cli plugins install grafana-piechart-panel``

``service grafana-server restart``


----------

### Additional Information
* Nothing to add as of today

### Known issues 
Would love to see some known issues and keep opening and closing as soon as I have feedback from you guys. Fork this project, use it and please provide feedback.