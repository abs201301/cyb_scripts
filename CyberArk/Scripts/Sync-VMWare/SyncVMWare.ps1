function Add-Host {
  param ($Host)

  #Add and reconcile account
  $objName = ${Host.Name}-root
  $safe = $Host.SafeName
  $address = $Host.Name
  $platform = "Platform1"
  $res = Add-PASAccount -name $objName -address $address -userName 'root' -platformID $platform -SafeName $safe
  Invoke-PASCPMOperation -AccountID $res.id -ReconcileTask
  Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Added $objName to $safe with platform $platform")
}

function Remove-Host {
  param ($Account)

  Remove-PASAccount -Id $Account.id
  Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Removed $($Account.id): $($Account.Name) from safe: $($Account.SafeName)")
}

###################################################################################
## Main script starts here - script will terminate if any errors are encountered 
## Description - Syncs ESXi host root accounts with CyberArk
###################################################################################

Import-Module VMware.PowerCLI
Import-Module psPAS
$ErrorActionPreference = "stop"
Add-Type -AssemblyName System.Web

$PVWA = "<PVWA_FQDN>"
$logpath = ".\Sync-VMWare.log"
$APSafe = "Safe1"
$ENSafe = "Safe2"
$GlobalSafe = "Safe3"

# Variables used by AAM-CP.
$appID  = "<AppID>"
$safe  = "<APIUserSafe>"
$Object  = "<APIUserObjectName>"
$UserName = "<APIUserName>"
$CLIPath = "C:\Program Files\CyberArk\ApplicationPasswordSdk\CLIPasswordSDK64.exe"

# Retrieve API credentials using CP
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$response = & $CLIPath GetPassword /p AppDescs.AppID=$appID /p Query="Safe=$safe;Folder=Root;Object=$Object" /o Password
$securePassword = ConvertTo-SecureString $response -AsPlainText -Force
$apiCredentials = New-Object System.Management.Automation.PSCredential($UserName, $securePassword)

#Create log file if needed and start logging
if (!(Test-Path $logpath -Type Leaf)) {New-Item -Path $logpath -Type File}
Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Synchronization started")

# vCenter to Safe Mapping
$vCenterToSafeMap = @{
    "vcenter1.uk.fid-intl.com" = $APSafe
    "vcenter2.uk.fid-intl.com" = $ENSafe
    "vcenter3.uk.fid-intl.com" = $GlobalSafe
}
# List of vCenter servers
$vCenters = @(
    "vcenter1.uk.fid-intl.com",
    "vcenter2.uk.fid-intl.com",
    "vcenter3.uk.fid-intl.com"
)

try {

  #Create API session to vault
  $res = New-PASSession -Credential $apiCredentials -BaseURI $PVWAString -type LDAP -concurrentSession $true -ErrorAction Stop

  # Initialize list to store ESXi hosts
  $ESXiHosts = @()

  # Retrieve ESXi hosts from all vCenters
  foreach ($vCenter in $vCenters) {
      Write-Host "Connecting to $vCenter..."
	  Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Connecting to $vCenter...")
      try {
		Connect-VIServer -Server $vCenter -Credential $apiCredentials -ErrorAction Stop
        $hosts = Get-VMHost | Select-Object Name,
		@{Name = "vCenter"; Expression = { $vCenter }}
		@{Name = "SafeName"; Expression = { $vCenterToSafeMap[$vCenter] }}
        $ESXiHosts += $hosts
      }
      catch {
        Write-Warning "Failed to connect to ${vCenter}: $_"
		Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Failed to connect to ${vCenter}: $_")
      }
      finally {
          Disconnect-VIServer -Server $vCenter -Confirm:$false
      }
  }

  Write-Host "Retrieved $($ESXiHosts.Count) ESXi hosts."
  Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Retrieved $($ESXiHosts.Count) ESXi hosts.")

  # Fetch onboarded accounts from CyberArk
  $fAccounts  = Get-PASAccount -search 'root' -searchType startswith -safeName $APSafe
  $fAccounts += Get-PASAccount -search 'root' -searchType startswith -safeName $ENsafe
  $fAccounts += Get-PASAccount -search 'root' -searchType startswith -safeName $Globalsafe
  $existingAccounts = $fAccounts | Where-Object { $_.platformID -eq "Platform1" }
  $CybAccounts = $existingAccounts | Select-Object -Property address,id,safeName,platformID

  # Compare ESXi hosts with CyberArk accounts
  $ESXiHostNames = $ESXiHosts | ForEach-Object { $_.Name }
  $CybHostNames = $CybAccounts | ForEach-Object { $_.address }
  
  # Add new hosts
  $hostsToAdd = $ESXiHosts | Where-Object { $_ -notin $CybHostNames }
  foreach ($hostToAdd in $hostsToAdd) {Add-Host -Host $hostToAdd}
  
  # Remove obsolete hosts
  $hostsToRemove = $CybAccounts | Where-Object { $_ -notin $ESXiHostNames }
  foreach ($accountToRemove in $hostsToRemove) {Remove-Host -Account $accountToRemove}
  
 }
catch {
  #Write exception to log
  Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " An exception has occurred!")
  Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Exception Type: $($_.Exception.GetType().FullName)")
  Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Exception Message: $($_.Exception.Message)")
  $Body = " Dear CyberArk Admin, <br /> <br /> An exception has occurred!  Please review the Sync-VMWare.log on Tools Server <br /> Exception Type: $($_.Exception.GetType().FullName) <br /> Exception Message: $($_.Exception.Message) <br /> <br /> Thank You <br /><br /> Note: This is an automated system response. Do Not reply to this email message! <br />"
  Send-MailMessage -From $From -to $To -cc $CC -Subject "SyncVMWare Error" -Body $Body -BodyAsHtml -SmtpServer $SMTPServer -Port $SMTPPort
}
finally {
  #Close API session - run this to cleanup even if errors were encountered
  Close-PASSession
  Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Synchronization finished")
}
