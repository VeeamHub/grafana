Grafana Dashboard for Veeam Backup for Microsoft Office 365 - Advanced Security and Performance Monitoring
===================

![alt tag](https://www.jorgedelacruz.es/wp-content/uploads/2019/06/veeam-grafana-o365-001.png)

This project leverages Telegraf for Microsoft Windows in order to retrieve performance counters and parse logs from Veeam Backup for Microsoft Office 365 using logparse. The information is being saved it into InfluxDB output directly into the InfluxDB database, then in Grafana: a Dashboard is created to present all the information.

We use Veeam the latest version of Telegraf for Microsoft Windows, and parse the Veeam Backup for Microsoft Windows from the default paths.

----------

### Getting started
You can follow the steps on the next Blog Post - https://jorgedelacruz.uk/2019/06/18/looking-for-perfect-dashboard-influxdb-telegraf-and-grafana-part-xvi-performance-and-advanced-security-of-veeam-backup-for-microsoft-office-365/

Or try with this simple steps:
* Download telegraf for Microsoft Windows, install it as a Windows Service and open the telegraf.conf and change the parameters under output, like username/password, etc. with your real data
* Add the collector extra information added after this bullet point list
* Download the Veeam Backup for Microsoft Office 365 Grafana Dashboard JSON file and import it into your Grafana
* Enjoy :)

Collector data

```
# # Read and parse Logs from Veeam Explorer for Exchange Online
# Operator who opened the VEX
[[inputs.logparser]]
  files = ["C:/ProgramData/Veeam/Backup/ExchangeExplorer/Logs/*.log"]
  from_beginning = true
  name_override = "veeam_office365_audit_vex"
  watch_method = "poll"

[inputs.logparser.grok]
patterns = ['%{DATESTAMP_AMPM:timestamp:ts-"1/2/2006 3:04:05 PM"} %{SPACE} %{NUMBER} \(%{NUMBER}\) Account:%{GREEDYDATA:operator}']
custom_patterns = "DATESTAMP_AMPM %{DATESTAMP} (AM|PM)"

# Items to restore
[[inputs.logparser]]
  files = ["C:/ProgramData/Veeam/Backup/ExchangeExplorer/Logs/*.log"]
  from_beginning = true
  name_override = "veeam_office365_audit_vex"
  watch_method = "poll"

[inputs.logparser.grok]
patterns = ['%{DATESTAMP_AMPM:timestamp:ts-"1/2/2006 3:04:05 PM"} %{SPACE} %{NUMBER} \(%{NUMBER}\) Restoring message:%{GREEDYDATA:exchangeobject}']
custom_patterns = "DATESTAMP_AMPM %{DATESTAMP} (AM|PM)"

# Restore From:
[[inputs.logparser]]
  files = ["C:/ProgramData/Veeam/Backup/ExchangeExplorer/Logs/*.log"]
  from_beginning = true
  name_override = "veeam_office365_audit_vex"
  watch_method = "poll"

[inputs.logparser.grok]
patterns = ['%{DATESTAMP_AMPM:timestamp:ts-"1/2/2006 3:04:05 PM"} %{SPACE} %{NUMBER} \(%{NUMBER}\) %{SPACE} From:%{GREEDYDATA:restorefrom}']
custom_patterns = "DATESTAMP_AMPM %{DATESTAMP} (AM|PM)"

# Restore To:
[[inputs.logparser]]
  files = ["C:/ProgramData/Veeam/Backup/ExchangeExplorer/Logs/*.log"]
  from_beginning = true
  name_override = "veeam_office365_audit_vex"
  watch_method = "poll"

[inputs.logparser.grok]
patterns = ['%{DATESTAMP_AMPM:timestamp:ts-"1/2/2006 3:04:05 PM"} %{SPACE} %{NUMBER} \(%{NUMBER}\) %{SPACE} To:%{GREEDYDATA:restoreto}']
custom_patterns = "DATESTAMP_AMPM %{DATESTAMP} (AM|PM)"

# Bytes Restored
[[inputs.logparser]]
  files = ["C:/ProgramData/Veeam/Backup/ExchangeExplorer/Logs/*.log"]
  from_beginning = true
  name_override = "veeam_office365_audit_vex"
  watch_method = "poll"

[inputs.logparser.grok]
patterns = ['%{DATESTAMP_AMPM:timestamp:ts-"1/2/2006 3:04:05 PM"} %{SPACE} %{NUMBER} \(%{NUMBER}\) Creating %{GREEDYDATA} %{NUMBER:bytesrestored:int}']
custom_patterns = "DATESTAMP_AMPM %{DATESTAMP} (AM|PM)"

# # Read and parse Logs from Veeam Backup for Microsoft Office 365 RESTFulAPI
# REST KEY ID
[[inputs.logparser]]
  files = ["C:/ProgramData/Veeam/Backup365/Logs/Veeam.Archiver.REST*.log"]
  from_beginning = true
  name_override = "veeam_office365_audit_rest"
  watch_method = "poll"

[inputs.logparser.grok]
patterns = ['%{DATESTAMP_AMPM:timestamp:ts-"1/2/2006 3:04:05 PM"} %{SPACE} %{NUMBER} \(%{NUMBER}\) Adding new backup server session%{GREEDYDATA} %{GREEDYDATA:restkey}']
custom_patterns = "DATESTAMP_AMPM %{DATESTAMP} (AM|PM)"

# REST REFRESH KEY ID
[[inputs.logparser]]
  files = ["C:/ProgramData/Veeam/Backup365/Logs/Veeam.Archiver.REST*.log"]
  from_beginning = true
  name_override = "veeam_office365_audit_rest"
  watch_method = "poll"

[inputs.logparser.grok]
patterns = ['%{DATESTAMP_AMPM:timestamp:ts-"1/2/2006 3:04:05 PM"} %{SPACE} %{NUMBER} \(%{NUMBER}\) Credentials refreshed%{GREEDYDATA} \(key=%{GREEDYDATA:restkey}\)']
custom_patterns = "DATESTAMP_AMPM %{DATESTAMP} (AM|PM)"

# REST ACTIONS
[[inputs.logparser]]
  files = ["C:/ProgramData/Veeam/Backup365/Logs/Veeam.Archiver.REST*.log"]
  from_beginning = true
  name_override = "veeam_office365_audit_rest"
  watch_method = "poll"

[inputs.logparser.grok]
patterns = ['%{DATESTAMP_AMPM:timestamp:ts-"1/2/2006 3:04:05 PM"} %{SPACE} %{NUMBER} \(%{NUMBER}\) Action started:%{GREEDYDATA:restaction}']
custom_patterns = "DATESTAMP_AMPM %{DATESTAMP} (AM|PM)"

# # Read and parse Logs from Veeam Explorer for OneDrive for Business
# Operator who opened the VXONE
[[inputs.logparser]]
  files = ["C:/ProgramData/Veeam/Backup/OneDriveExplorer/Logs/*.log"]
  from_beginning = true
  name_override = "veeam_office365_audit_vone"
  watch_method = "poll"

[inputs.logparser.grok]
patterns = ['%{DATESTAMP_AMPM:timestamp:ts-"1/2/2006 3:04:05 PM"} %{SPACE} %{NUMBER} \(%{NUMBER}\) Account:%{GREEDYDATA:operator}']
custom_patterns = "DATESTAMP_AMPM %{DATESTAMP} (AM|PM)"

# Global monitoring for VXONE
[[inputs.logparser]]
  files = ["C:/ProgramData/Veeam/Backup/OneDriveExplorer/Logs/*.log"]
  from_beginning = true
  name_override = "veeam_office365_audit_vone"
  watch_method = "poll"

[inputs.logparser.grok]
patterns = ['%{DATESTAMP_AMPM:timestamp:ts-"1/2/2006 3:04:05 PM"} %{SPACE} %{NUMBER} \(%{NUMBER}\) %{GREEDYDATA:message}']
custom_patterns = "DATESTAMP_AMPM %{DATESTAMP} (AM|PM)"

# # Read and parse Logs from Veeam Explorer for SharePoint Online
# Operator who opened the VXSPO
[[inputs.logparser]]
  files = ["C:/ProgramData/Veeam/Backup/SharePointExplorer/Logs/*.log"]
  from_beginning = true
  name_override = "veeam_office365_audit_vspo"
  watch_method = "poll"

[inputs.logparser.grok]
patterns = ['%{DATESTAMP_AMPM:timestamp:ts-"1/2/2006 3:04:05 PM"} %{SPACE} %{NUMBER} \(%{NUMBER}\) Account:%{GREEDYDATA:operator}']
custom_patterns = "DATESTAMP_AMPM %{DATESTAMP} (AM|PM)"

# Global monitoring for VXSPO
[[inputs.logparser]]
  files = ["C:/ProgramData/Veeam/Backup/SharePointExplorer/Logs/*.log"]
  from_beginning = true
  name_override = "veeam_office365_audit_vspo"
  watch_method = "poll"

[inputs.logparser.grok]
patterns = ['%{DATESTAMP_AMPM:timestamp:ts-"1/2/2006 3:04:05 PM"} %{SPACE} %{NUMBER} \(%{NUMBER}\) %{GREEDYDATA:message}']
custom_patterns = "DATESTAMP_AMPM %{DATESTAMP} (AM|PM)"


# # Ping and latency between the Veeam Backup for Microsoft Office 365 Server and Exchange Online on Office 365
# Ping input
[[inputs.ping]]
interval = "60s"
urls = ["outlook.office365.com"]
count = 4
timeout = 2.0
```

----------

### Additional Information
* Nothing to add as of today

### Known issues 
Would love to see some known issues and keep opening and closing as soon as I have feedback from you guys. Fork this project, use it and please provide feedback.