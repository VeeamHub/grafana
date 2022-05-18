Grafana Dashboard for Veeam Backup for GCP
===================

![alt tag](https://jorgedelacruz.uk/wp-content/uploads/2021/12/veeam-grafana-gcp-001.jpg)

This project consists in a Bash Shell script to retrieve the Veeam Backup for GCP information, directly from the RESTfulAPI, about last jobs, VMs and much more. The information is being saved it into InfluxDB output directly into the InfluxDB database using curl, then in Grafana: a Dashboard is created to present all the information.

We use Veeam Backup for GCP v2.0 RESTfulAPI to reduce the workload and increase the speed of script execution. 

----------

### Getting started
You can follow the steps on the next Blog Post - TBD

Or try with this simple steps:
* Download the veeam_gcp.sh file and change the parameters under Configuration, like username/password, etc. with your real data
* Make the script executable with the command chmod +x veeam_gcp.sh
* Run the veeam_gcp.sh and check on Chronograf that you can retrieve the information properly
* Schedule the script execution, for example every 30 minutes using crontab
* Download the Veeam Backup for GCP JSON file and import it into your Grafana
* Enjoy :)

**Extra**
You will need an extra grafana plugins, in case you do not have it, the pie-chart, you can quickly install them with the next:

``grafana-cli plugins install grafana-piechart-panel``

``service grafana-server restart``


----------

### Additional Information
* Nothing to add as of today

### Known issues 
Would love to see some known issues and keep opening and closing as soon as I have feedback from you guys. Fork this project, use it and please provide feedback.
