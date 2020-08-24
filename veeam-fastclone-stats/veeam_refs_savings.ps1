<#
        .SYNOPSIS
        Grafana, Telegraf and InfluxhDB Veeam Monitor for Microsoft ReFS Volumes
  
        .DESCRIPTION
        This Script will Report Statistics about the ReFS block cloning technology. It is based on the blockstat.exe from Timothy Dewin, and it is a pre-requisite to have it downloaded on a path.
        More information can be found here - https://github.com/tdewin/blockstat and here - http://dewin.me/refs/
        The download of the blockstat.exe can be done from here - http://dewin.me/static/blockstat.zip
	
        .Notes
        NAME:  veeam_refs_savings.ps1
        ORIGINAL NAME: blockcomparerefs.ps1
        LASTEDIT: 22/08/2020
        VERSION: 1.0
        KEYWORDS: Veeam, Grafana, InfluxDB, Telegraf
   
        .Link
        http://dewin.me/refs/
        Edits, InfluxDB output for Grafana by https://jorgedelacruz.es/
   
 #>

##
# Configurations
##
# Logical Volume with ReFS enabled
$dir = "T:\"
# Path to the blockstat.exe and for the output path
$exe = "C:\blockstat\blockstat.exe"
$listfilepath = "C:\blockstat\in.txt"
$outputpath = "C:\blockstat\out.xml"
$type="ReFS"

# Endpoint URL for InfluxDB
$veeamInfluxDBURL="http://YOURINFLUXSERVERIP" #Your InfluxDB Server, http://FQDN or https://FQDN if using SSL
$veeamInfluxDBPort="8086" #Default Port
$veeamInfluxDB="telegraf" #Default Database
$veeamInfluxDBUser="USER" #User for Database
$veeamInfluxDBPassword='PASSWORD' | ConvertTo-SecureString -asPlainText -Force

$cred = New-Object System.Management.Automation.PSCredential($veeamInfluxDBUser,$veeamInfluxDBPassword)
$uri = "${veeamInfluxDBURL}:${veeamInfluxDBPort}/write?db=$veeamInfluxDB"


function blockstatwrapper {
    param($exe,$listfilepath,$outputpath)
    $x = Start-Process -FilePath $exe -ArgumentList @("-x","-i",$listfilepath,"-o",$outputpath) -Wait -PassThru
    $result = [xml](Get-Content $outputpath)


    $fod = 0
    $result.result.shares.ChildNodes | % { $sl=$_;$fod+=([Int64]::Parse($sl.ratio)*[Int64]::Parse($sl.bytes))}
    $repo = $dir.Trim(':\')
    $savings = $result.result.totalshare.bytes
    $fragments= $result.result.fragments.count
    $backupjobname= $gr.Name -creplace '^[^\\]*\\', ''
    $body="veeam_fastclone_stats,reporefs=$repo,type=$type,backup=$backupjobname totaldisk=$fod,savings=$savings,fragments=$fragments"
    if (($savings -gt "0") -and ($savings -ne $null))
    { 
        write-Host $body 
        Invoke-RestMethod -Uri $uri -Method POST -Body $body -Credential $cred 
    }
    
}

#method one, list files, should be the easiest
function method1 {
    param($exe,$listfilepath,$outputpath)
    

    #$files = Get-ChildItem -Path $dir -Recurse -Depth 10 -file -Include "*.vbk","*.vib","*.vrb" | % { $_.FullName } 
    $filesgroup = Get-ChildItem -Path $dir -Recurse -Depth 10 -file -Include "*.vbk","*.vib","*.vrb" | Group-Object -Property directory
    foreach ($gr in $filesgroup) {

        $files = $gr.group | % { $_.FullName }
        $files | Set-Content -Path $listfilepath -Encoding Unicode
        blockstatwrapper -exe $exe -listfilepath $listfilepath -outputpath $outputpath

    }
    
}

method1 -exe $exe -listfilepath $listfilepath -outputpath $outputpath


#method 2, get files based on backup server data. 100% breakages on scaleout repo
function method2 {
    param($exe,$listfilepath,$outputpath,$backupserver)


    $session = New-PSSession $backupserver
    $filesgroup = Invoke-Command -Session $session -ScriptBlock {
        param($a)
        asnp veeampssnapin

        $gr = @{}
        Get-VBRBackup | % {
            $backup = $_
            $files = $backup.GetAllStorages() | % { $s = $_;$s.FilePath.ToString() }
            $gr[$backup.Name] = New-Object -TypeName psobject -Property @{Name=$backup.Name;Files=$files}
        }
        return $gr
    }  -ArgumentList @{jobname=$backupjob}
    $session | Remove-PSSession

    foreach($key in $filesgroup.Keys) {
        $files = $filesgroup[$key].Files
        $files | Set-Content -Path $listfilepath -Encoding Unicode
        blockstatwrapper -exe $exe -listfilepath $listfilepath -outputpath $outputpath
    }
}

#method2 -exe $exe -listfilepath $listfilepath -outputpath $outputpath -backupserver "localhost"

