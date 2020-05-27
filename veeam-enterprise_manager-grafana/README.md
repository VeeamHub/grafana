How to monitor a Veeam Environment using Veeam Enterprise Manager, Telegraf, InfluxDB and Grafana
===================
![Veeam Grafana Dashboard for Enterprise Manager](https://www.jorgedelacruz.es/wp-content/uploads/2020/01/veeam-grafana-em-001.png)

Thanks for the interest on this project. You will find two different ways to retrieve the information, a very old v0.1 using PowerShell, which it has limitations, and a brand new way to take the information from the Veeam Enterprise Manager RESTful API using a Bash Shell Script directly from your InfluxDB Server, which it is the recommended one.

We use Veeam Enterprise Manager and the RESTfulAPI to reduce the workload and increase the speed of script execution, here is a comparison between same Script using VeeamPSSnapIn vs. RESTfulAPI:

![alt tag](https://www.dropbox.com/s/7eqts8kuukhrmqd/2020-05-26_16-40-49.png?dl=1)
----------
### Getting started
For the new Bash Shell Script, please follow the steps on the next Blog Post - 
For PowerShell old version, not recommended, follow the steps on the next Blog Post - http://jorgedelacruz.uk/2017/07/26/looking-perfect-dashboard-influxdb-telegraf-grafana-part-viii-monitoring-veeam-using-veeam-enterprise-manager/

Or try with this simple steps:
* Download the veeam-enterprisemanager.sh file and change the parameters under Configuration, like username/password, etc. with your real data
* Make the script executable with the command chmod +x veeam-enterprisemanager.sh
* Run the veeam-enterprisemanager.sh and check on Chronograf that you can retrieve the information properly
* Schedule the script execution, for example every 30 minutes using crontab -e
* Download the Veeam Enterprise Manager JSON Dashboard file and import it into your Grafana
* Enjoy :)

**Important:** For the section called Veeam Backup Performance, you will need to [install the Telegraf Agent for Windows](https://github.com/influxdata/telegraf/blob/master/docs/WINDOWS_SERVICE.md) on the Veeam Backup & Replication Server. Additionally, you will need to edit the hostname on the telegraf.conf for this VBR Server, and use the proper FQDN, like this:

      ## Override default hostname, if empty use os.Hostname()
      hostname = "yourvbr.yourdomain.com"

----------

### Additional Information
* The old PowerShell way to retrieve data was thanks to Markus Kraus: https://mycloudrevolution.com/2016/02/29/prtg-veeam-br-monitoring/

### Known issues 
Would love to see some known issues and keep opening and closing as soon as I have feedback from you guys. Fork this project, use it and please provide feedback.