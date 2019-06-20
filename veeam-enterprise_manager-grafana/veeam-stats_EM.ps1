<#
        .SYNOPSIS
        Grafana, Telegraf and InfluxhDB Veeam Monitor
  
        .DESCRIPTION
        This Script will Report Statistics about Backups, Repositories usage and much more during the time interval selected on the configuration . It will then convert them into Influxdb output, ready to add into InfluxDB and show it with Grafana in an easier way
	
        .Notes
        NAME:  veeam-stats_EM.ps1
        ORIGINAL NAME: PRTG-Veeam-SessionStats.ps1
        LASTEDIT: 31/07/2017
        VERSION: 0.2
        KEYWORDS: Veeam, Grafana, InfluxDB, Telegraf
   
        .Link
        http://mycloudrevolution.com/
        Edits, InfluxDB output for Grafana, and Repository section by https://jorgedelacruz.es/
 
 #Requires Veeam Enterprise Manager, and access to the RESTfulAPI   
 #>
$user = "YOURUSER"
$password = "YOURPASS"
$BRHost = "YOURVEEAMENTERPRISEMANAGER"

# POST - Authorization
$Auth = @{uri = "http://" + $BRHost + ":9399/api/sessionMngr/?v=v1_2";
                   Method = 'POST'; #(or POST, or whatever)
                   Headers = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($user):$($password)"));
           } #end headers hash table
   } #end $params hash table

$AuthXML = Invoke-WebRequest @Auth

#region: GET - Session Statistics
$Sessions = @{uri = "http://" + $BRHost + ":9399/api/reports/summary/job_statistics";
                   Method = 'GET';
				   Headers = @{'X-RestSvcSessionId' = $AuthXML.Headers['X-RestSvcSessionId'];
           } #end headers hash table
	}

[xml]$SessionsXML = invoke-restmethod @Sessions

$SuccessfulJobRuns = $SessionsXML.JobStatisticsReportFrame.SuccessfulJobRuns
$WarningsJobRuns = $SessionsXML.JobStatisticsReportFrame.WarningsJobRuns
$FailedJobRuns = $SessionsXML.JobStatisticsReportFrame.FailedJobRuns
$RunningJobs = $SessionsXML.JobStatisticsReportFrame.RunningJobs

#region: GET - VM Statistics
$VMs = @{uri = "http://" + $BRHost + ":9399/api/reports/summary/vms_overview";
                   Method = 'GET';
				   Headers = @{'X-RestSvcSessionId' = $AuthXML.Headers['X-RestSvcSessionId'];
           } #end headers hash table
	}

[xml]$VMsXML = invoke-restmethod @VMs

$ProtectedVms = $VMsXML.VmsOverviewReportFrame.ProtectedVms
$SourceVmsSize = [Math]::round((($VMsXML.VmsOverviewReportFrame.SourceVmsSize) / 1073741824),0) 

#region: GET - Repository
$Repository = @{uri = "http://" + $BRHost + ":9399/api/reports/summary/repository";
                   Method = 'GET';
				   Headers = @{'X-RestSvcSessionId' = $AuthXML.Headers['X-RestSvcSessionId'];
           } #end headers hash table
	}

[xml]$RepositoryXML = invoke-restmethod @Repository

$Repos = $RepositoryXML.RepositoryReportFrame.Period

# InfluxDB Output for Telegraf
$body="veeamstats_EM successfuljobruns=$SuccessfulJobRuns"
Write-Host $body 
$body="veeamstats_EM protectedvms=$ProtectedVms"
Write-Host $body 
$body="veeamstats_EM sourcevmsize=$SourceVmsSize"
Write-Host $body 
$body="veeamstats_EM warningjobruns=$WarningsJobRuns"
Write-Host $body 
$body="veeamstats_EM failedjobruns=$FailedJobRuns"
Write-Host $body 
$body="veeamstats_EM runningjobs=$RunningJobs"
Write-Host $body 

foreach ($Repo in $Repos){
$Name = $Repo."Name"
$Name = $Name.replace(' ','_')
$FreeP = ($Repo."FreeSpace"/$Repo."Capacity").tostring("P")
$Free = $FreeP -replace '[%]',''
$Free = [math]::Round($Free)
$body="veeamstats_EM $Name=$Free"
Write-Host $body 
	}
#endregion