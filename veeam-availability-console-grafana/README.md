Grafana Dashboard for Veeam Availability Console
===================

![alt tag](https://jorgedelacruz.uk/wp-content/uploads/2019/01/veeam-vac-grafana-001.png)
![image](https://user-images.githubusercontent.com/36752644/197901132-b3d6315a-a4f0-4362-9dfc-0839a8ba0dee.png)
Job History             | Repository History
:-------------------------:|:-------------------------:
![image](https://user-images.githubusercontent.com/36752644/197901423-3da1a416-efca-4b5b-b171-0d2a91a3b48b.png) |  ![image](https://user-images.githubusercontent.com/36752644/197902231-9adc345e-1ab0-42ca-996f-df6e9e49ba8e.png)
Click on a job to see its History | Click on a Repo to see its history





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
* Download the Grafana Dashboards JSON files 
* Import the JSON files into your Grafana
* Edit the links on the repository and jobs panels to point to the relevant imported dashboards instead of "yourinstance.com", but keep the URL params at the end of the link
* Enjoy :)

----------

### Additional Information
* Nothing to add as of today

### Known issues 
Would love to see some known issues and keep opening and closing as soon as I have feedback from you guys. Fork this project, use it and please provide feedback.
