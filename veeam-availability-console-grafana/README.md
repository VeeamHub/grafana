Grafana Dashboard for Veeam Availability Console
===================

![alt tag](https://jorgedelacruz.uk/wp-content/uploads/2019/01/veeam-vac-grafana-001.png)

This project consists in a Bash Shell script to retrieve the Veeam Availability Console information, directly from the RESTfulAPI, about last jobs, tenants and much more. The information is being saved it into InfluxDB output directly into the InfluxDB database using curl, then in Grafana: a Dashboard is created to present all the information.

We use Veeam Availability Console RESTfulAPI to reduce the workload and increase the speed of script execution.

----------

### Getting started
You can follow the steps on the next Blog Post - https://jorgedelacruz.uk/2019/01/18/looking-for-the-perfect-dashboard-influxdb-telegraf-and-grafana-part-xiv-veeam-availability-console/

Or try with this simple steps:
* Download the veeam-availability-console-script.sh file and change the parameters under Configuration, like username/password, etc. with your real data
* Make the script executable with the command chmod +x veeam-availability-console-script.sh
* Run the veeam-availability-console-script.sh and check on Chronograf that you can retrieve the information properly
* Schedule the script execution, for example every 30 minutes using crontab
* Download the two Grafana Dashboards JSON files and import it into your Grafana
* Enjoy :)

----------

### Additional Information
* Nothing to add as of today

### Known issues 
Would love to see some known issues and keep opening and closing as soon as I have feedback from you guys. Fork this project, use it and please provide feedback.