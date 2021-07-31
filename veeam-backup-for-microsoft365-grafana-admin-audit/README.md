Grafana Dashboard for Veeam Backup for Microsoft Office 365 - Backup Admin Audit Log
===================

![alt tag](https://jorgedelacruz.uk/wp-content/uploads/2021/07/veeam-blog-office-audit-002.jpg)

This project leverages Telegraf for Microsoft Windows in order to parse logs from Veeam Backup for Microsoft 365 using tail. The information is being saved it into InfluxDB output directly into the InfluxDB database, then in Grafana: a Dashboard is created to present all the information.

----------

### Getting started
You can follow the steps on the next Blog Post - TBD

Or try with this simple steps:
* Download telegraf for Microsoft Windows, install it as a Windows Service and open the telegraf.conf and change the parameters under output, like username/password, etc. with your real data
* Add the collector extra information added after this bullet point list
* Download the Veeam Backup for Microsoft 365 Grafana Dashboard JSON file and import it into your Grafana
* Enjoy :)

Collector data

```
# Audit for Job Creation
[[inputs.tail]]
  files = ["C:\\ProgramData\\Veeam\\Backup365\\Logs\\Veeam.Archiver.Shell*.log"]
  from_beginning = true
  name_override = "veeam_microsoft365audit_jobs"
  watch_method = "poll"

    grok_patterns = ['%{DATESTAMP_AMPM:timestamp:ts-"1/2/2006 3:04:05 PM"} %{SPACE} %{NUMBER} \(%{NUMBER:nroper}\) Account:%{GREEDYDATA:operator:tag}', '%{DATESTAMP_AMPM:timestamp:ts-"1/2/2006 3:04:05 PM"} %{SPACE} %{NUMBER} \(%{NUMBER:nrjob}\) Notification from service: Job %{GREEDYDATA:action:tag}: %{GREEDYDATA:veeamjobname:tag} \(ID: %{GREEDYDATA:veeamjobid}\)']
    grok_custom_patterns = "DATESTAMP_AMPM %{DATESTAMP} (AM|PM)"
    data_format = "grok"

# Audit for Job Edit/Deletion
[[inputs.tail]]
  files = ["C:\\ProgramData\\Veeam\\Backup365\\Logs\\Veeam.Archiver.Shell*.log"]
  from_beginning = true
  name_override = "veeam_microsoft365audit_jobs"
  watch_method = "poll"

    grok_patterns = ['%{DATESTAMP_AMPM:timestamp:ts-"1/2/2006 3:04:05 PM"} %{SPACE} %{NUMBER} \(%{NUMBER:nroper}\) Account:%{GREEDYDATA:operator:tag}', '%{DATESTAMP_AMPM:timestamp:ts-"1/2/2006 3:04:05 PM"} %{SPACE} %{NUMBER} \(%{NUMBER:nrjob}\) %{GREEDYDATA:action:tag} job: %{GREEDYDATA:veeamjobname:tag}...']
    grok_custom_patterns = "DATESTAMP_AMPM %{DATESTAMP} (AM|PM)"
    data_format = "grok"
```

----------

### Additional Information
* Nothing to add as of today

### Known issues 
Would love to see some known issues and keep opening and closing as soon as I have feedback from you guys. Fork this project, use it and please provide feedback.
