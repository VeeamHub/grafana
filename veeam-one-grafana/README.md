Grafana Dashboard for Veeam ONE (experimental)
===================

![alt tag](https://www.jorgedelacruz.es/wp-content/uploads/2021/02/vone-grafana-001-1.png)

This project consists in a Bash Shell script to retrieve the Veeam ONE information, directly from the RESTfulAPI, about last jobs, VMs and much more. The information is being saved it into InfluxDB output directly into the InfluxDB database using curl, then in Grafana: a Dashboard is created to present all the information.

We use Veeam ONE internal RESTfulAPI to reduce the workload and increase the speed of script execution.

This API is for internal purposes, and therefore all this project is considered experimental and unsupported, use it under your own responsibility.

----------

### Getting started
You can follow the steps on the next Blog Post - https://www.jorgedelacruz.es/2021/03/01/en-busca-del-dashboard-perfecto-influxdb-telegraf-y-grafana-parte-xxxii-monitorizando-veeam-one-experimental/

Or try with this simple steps:
* Download the veeam_one.sh file and change the parameters under Configuration, like username/password, etc. with your real data
* Make the script executable with the command chmod +x veeam_one.sh
* Run the veeam_one.sh and check on Chronograf/Grafana Explorer that you can retrieve the information properly
* Schedule the script execution, for example every 30 minutes using crontab
* Download the Veeam ONE JSON file and import it into your Grafana
* Enjoy :)

----------

### Additional Information
* Nothing to add as of today

### Known issues 
Would love to see some known issues and keep opening and closing as soon as I have feedback from you guys. Fork this project, use it and please provide feedback.