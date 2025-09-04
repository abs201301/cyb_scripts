###################################################################################
## Main script starts here - script will terminate if any errors are encountered 
## Author: Abhishek Singh
## Description: Deletes EPV users who've been inactive for six months
## Uses CAUsers Table from EVD exported to MSSQL database
## Uses psPAS Powershell module for easy to use cmdlets
###################################################################################
Import-Module psPAS
$ErrorActionPreference = "stop"
Add-Type -AssemblyName System.Web

# Variables used for API session
$PVWA = "acme.corp"
$PVWAString = "https://" + $PVWA

# Variables used by MSSQL
$SqlInstance = "CybDatabaseServer\SQLInstance,51433"
$DatabaseName = "CyberArk"
$FilePath = "D:\EVD\UploadCAUsersToSQL.cmd"
$WorkingDirectory = "D:\EVD"

# Variables used by AAM-CP.
$appID  = "AIMAppID"
$safe  = "APIUserSafe"
$Object  = "APIUser"
$UserName = "APIUser"
$CLIPath = "C:\Program Files\CyberArk\ApplicationPasswordSdk\CLIPasswordSDK64.exe"
$logpath = ".\Purge-Users.log"

# Retrieve API credentials using CCP
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$response = & $CLIPath GetPassword /p AppDescs.AppID=$appID /p Query=”Safe=$safe;Folder=Root;Object=$Object” /o Password
$securePassword = ConvertTo-SecureString $response -AsPlainText -Force
$apiCredentials = New-Object System.Management.Automation.PSCredential($UserName, $securePassword)


#Create log file if needed and start logging
if (!(Test-Path $logpath -Type Leaf)) {New-Item -Path $logpath -Type File}
Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Purge started")

try {
  #Create API session
  $token = New-PASSession -Credential $apiCredentials -BaseURI $PVWAString -type LDAP -concurrentSession $true -ErrorAction Stop

  #Retrieve list of users to remove from SQL DB and remove them
  Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $DatabaseName -Query "TRUNCATE TABLE [dbo].[CAUsers]" -TrustServerCertificate
  Start-Process -FilePath $FilePath -WorkingDirectory $WorkingDirectory -Wait
  $users = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $DatabaseName -TrustServerCertificate -Query "SELECT DISTINCT CAUUserName, CAUUserID, CAULastLogonDate FROM CAUsers WHERE CAUMapID = 8292 AND CAULastLogonDate < DATEADD(week, -24, GETDATE()) ORDER BY CAULastLogonDate"
  foreach ($user in $users) {
    Remove-PASUser -id $user.CAUUserID
    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " EPV User: $($user.CAUUserName) with ID: $($user.CAUUserID) (last logged in $($user.CAULastLogonDate)) removed")
  }
}
catch {
  Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " An exception has occurred!")
  Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Exception Type: $($_.Exception.GetType().FullName)")
  Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Exception Message: $($_.Exception.Message)")
  
}
finally {
  #Close API session - run this to cleanup even if errors were encountered
  Close-PASSession
  Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Purge finished")
}
