function Export-ADPPAtoSQL {

  #Get accounts list from AD and upload to SQL (uses Out-DataTable function written by Chad Miller)
  try {
      Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $DatabaseName -Query "TRUNCATE TABLE [dbo].[CAFiles]" -TrustServerCertificate
      Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $DatabaseName -Query "TRUNCATE TABLE [dbo].[CASafes]" -TrustServerCertificate
      Start-Process -FilePath $FilePath -WorkingDirectory $WorkingDirectory -Wait
      Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $DatabaseName -Query "TRUNCATE TABLE [dbo].[ADPPA]" -TrustServerCertificate
      .$outDataTablePath
      $users = @()
      $searchOU = @($SApath, $GNpath, $WApath)
      ForEach ($OU in $searchOU) {
        $users += Get-ADUser -Filter * -SearchBase $OU -Property samAccountName, Enabled
      }
      $fusers = $users | Where-Object { $_.samAccountName -Match '^(?i)(sa|aa|na|ra|wa)\d{8}$' }
      $list = $fusers | Select-Object Name,UserPrincipalName,samAccountName,Enabled | ConvertTo-CSV | ConvertFrom-Csv
      $cs = "Data Source=$SqlInstance;Initial Catalog=CyberArk;Integrated Security=True;TrustServerCertificate=True;"
      $bc = New-Object ("Data.SqlClient.SqlBulkCopy") $cs
      $bc.DestinationTableName = $TargetTableName
      $dt = $list | Out-DataTable
      $bc.WriteToServer($dt)
      Return $true
  } catch {
      Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Failed to connect to SQL Server: $SqlInstance - Error: $($_.Exception.Message)")
      Return $false
  }
}

function Get-CyberArkSafes {
   $CyberArkSafes = Import-CSV -Path "${WorkingDirectory}\CSV-Output\SafesList.csv" | ForEach-Object {
        $newObject = @{}
        $_.PSObject.Properties | ForEach-Object {
            $cleanName = $_.Name -replace '[<>]', ''
            $newObject[$cleanName] = $_.Value
        }
        [PSCustomObject]$newObject
   }

   Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Fetching CyberArk safes from EVD CSV output...")
   $safeRegEx = "^A\d{8}-Admins$"
   $safesToReturn = $CyberArkSafes | Where-Object { $_.SafeName -match $safeRegEx }

   if ($safesToReturn.Count -gt 0) {
        return $safesToReturn | Select-Object SafeName
   } else {
        Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " No matching safes found using regex: $safeRegEx")
   }
}

# Function to get AD accounts
function Get-ADAccounts {

    $users = @()
    $searchOU = @($SApath, $SACANpath, $GNpath, $WApath)
    ForEach ($OU in $searchOU) {
        $users += Get-ADUser -Filter * -SearchBase $OU -Property samAccountName, Enabled  | Where-Object {$_.DistinguishedName -notlike "*OU=FMC*"}
    }
    $fusers = $users | Where-Object { $_.samAccountName -Match '^(?i)(sa|aa|na|ra|wa)\d{6}$' } |`
        ForEach-Object {
            [PSCustomObject]@{
                samAccountName = $_.samAccountName.ToUpper()
                Enabled        = $_.Enabled
            }
        }
    $list = $fusers | Select-Object samAccountName,Enabled
    return $list
}

# Function to get CyberArk accounts via API
function Get-CyberArkAccounts {
    $CyberArkAccounts = Import-CSV -Path "${WorkingDirectory}\CSV-Output\FilesList.csv" | ForEach-Object {
        [PSCustomObject]@{
            SafeID   = $_.'<SafeID>'
            SafeName = $_.'<SafeName>'
            FileID   = $_.'<FileID>'
            Name     = $_.'<FileName>'
            ID       = "$($_.'<SafeID>')_$($_.'<FileID>')"
            DeletedBy = $_.'<DeletedBy>'
        }
    }

    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Fetching CyberArk accounts from EVD CSV output...")
    $nameRegEx = "^acme-[ANRSW]A[0-9]{8}$"
    $safeRegEx = "^A[0-9]{8}-Admins$"
    $accountstoReturn = $CyberArkAccounts | Where-Object { $_.Name -match $nameRegEx -and $_.SafeName -match $safeRegEx -and [string]::IsNullOrWhiteSpace($_.DeletedBy) }

    if ($accountstoReturn -and $accountstoReturn.Count -gt 0) {
        return $accountstoReturn | Select-Object ID, SafeName, Name
    } else {
        Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " No matching accounts found using regex: $nameRegEx")
    }
}

function Create-Safe {
  param ($Safe)
  
  $createsafe = $Safe.safeName
  
  $res = Add-PASSafe -SafeName $createsafe -Description "Created by SyncADPPA script" -ManagingCPM PasswordManager31 -NumberOfDaysRetention 7 -AutoPurgeEnabled $true -ErrorAction Stop
  Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Created CyberArk Safe: $createsafe")
  
  $res = Add-QADGroupMember -Identity "CyberArkUsers" -Member $Safe.LANID
  Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Added $($Safe.LANID) to CyberArkUsers ")
  
  $res = Add-PASSafeMember -SafeName $createsafe -MemberName "SafeAdmin" -SearchIn Vault -UseAccounts $true -RetrieveAccounts $true -ListAccounts $true `
			-AddAccounts $true -UpdateAccountContent $true -UpdateAccountProperties $true -InitiateCPMAccountManagementOperations $true -SpecifyNextAccountContent $true -RenameAccounts $true `
			-DeleteAccounts $true -UnlockAccounts $true -ManageSafe $true -ManageSafeMembers $true -BackupSafe $true -ViewAuditLog $true -ViewSafeMembers $true -requestsAuthorizationLevel1 $true `
			-AccessWithoutConfirmation $true -CreateFolders $true -DeleteFolders $true -MoveAccountsAndFolders $true -ErrorAction Stop
			
  $res = Add-PASSafeMember -SafeName $createsafe -MemberName "CyberArkAdmins" -SearchIn $domainName -UseAccounts $false -RetrieveAccounts $false -ListAccounts $true `
			-AddAccounts $true -UpdateAccountContent $false -UpdateAccountProperties $true -InitiateCPMAccountManagementOperations $true -SpecifyNextAccountContent $false -RenameAccounts $true `
			-DeleteAccounts $false -UnlockAccounts $true -ManageSafe $true -ManageSafeMembers $true -BackupSafe $true -ViewAuditLog $true -ViewSafeMembers $true `
			-AccessWithoutConfirmation $false -CreateFolders $false -DeleteFolders $false -MoveAccountsAndFolders $true -ErrorAction Stop

  $res = Add-PASSafeMember -SafeName $createsafe -MemberName "CyberArkAPIUsers" -SearchIn $domainName -UseAccounts $false -RetrieveAccounts $false -ListAccounts $true `
			-AddAccounts $true -UpdateAccountContent $true -UpdateAccountProperties $true -InitiateCPMAccountManagementOperations $true -SpecifyNextAccountContent $true -RenameAccounts $true `
			-DeleteAccounts $true -UnlockAccounts $true -ManageSafe $false -ManageSafeMembers $false -BackupSafe $false -ViewAuditLog $false -ViewSafeMembers $true `
			-AccessWithoutConfirmation $false -CreateFolders $false -DeleteFolders $false -MoveAccountsAndFolders $true -ErrorAction Stop

  Start-Sleep -Seconds 10
			
  $res = Add-PASSafeMember -SafeName $createsafe -MemberName $Safe.LANID -SearchIn $domainName -UseAccounts $true -RetrieveAccounts $true -ListAccounts $true `
			-AddAccounts $false -UpdateAccountContent $false -UpdateAccountProperties $false -InitiateCPMAccountManagementOperations $true -SpecifyNextAccountContent $false -RenameAccounts $false `
			-DeleteAccounts $false -UnlockAccounts $false -ManageSafe $false -ManageSafeMembers $false -BackupSafe $false -ViewAuditLog $true -ViewSafeMembers $false `
			-AccessWithoutConfirmation $false -CreateFolders $false -DeleteFolders $false -MoveAccountsAndFolders $false -ErrorAction Stop
  
			
  Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Assigned safe permissions: safeadmin, CyberArkAdmins and $($Safe.LANID) ")
}
  
function Add-Account {
     param (
       [Parameter(Mandatory = $true)]
       [PSCustomObject]$Account
   )

  # Map account types to platform names
  $platformMap = @{
     "SA" = $SAPlatform
     "WA" = $WAPlatform
     "NA" = $NAPlatform
     "AA" = $AAPlatform
     "RA" = $RAPlatform
  }

  # Extract account type from username
  if ($Account.User -match '^(SA|WA|NA|AA|RA)') {
      $accountPrefix = $matches[1]
  } else {
      $accountPrefix = $null
  }

  if (-not $accountPrefix -or -not $platformMap.ContainsKey($accountPrefix)) {
     Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Invalid account type for user: $($Account.User)")
     return
  }

  #Add and reconcile account
  $safe = $Account.Safe
  $platform = $platformMap[$accountPrefix]
  $res = Add-PASAccount -name $Account.Name -address $Account.Address -userName $Account.User -platformID $platform -SafeName $safe -platformAccountProperties @{ 'LogonDomain'=$Account.LogonDomain }
  Invoke-PASCPMOperation -AccountID $res.id -ReconcileTask
  Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Added $($Account.Name) to $safe with platform $platform")

}

function Remove-Account {
  param ([PSCustomObject]$Account)

  Remove-PASAccount -Id $Account.ID
  Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Removed $($Account.ID): $($Account.Name) from safe: $($Account.SafeName)")
}

function Remove-APIUser {
  param ([PSCustomObject]$Safe)

	$res = Remove-PASSafeMember -SafeName $Safe.safeName -MemberName $UserName -ErrorAction Stop	
	Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Removed API user from safe: $($Safe.safeName)")
}

# Function to get ServiceNow token
function Get-ServiceNowToken {
   param(
       [string]$ClientID,
       [string]$ClientSecret
   )
   $uri = "https://$SNOWInstance/oauth_token.do"
   $headers = @{
       "Content-Type" = "application/x-www-form-urlencoded"
   }
   $body = @{
       grant_type    = "client_credentials"
       client_id     = $ClientID
       client_secret = $ClientSecret
   }
   try {
       $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $body -ErrorAction Stop
       return $response.access_token
   } catch {
       Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Failed to retrieve SNOW OAuth token: $($_.Exception.Message)")
       return $null
   }
}

# Function to create incident ticket in SNOW
function New-ServiceNowIncident {
   param(
       [string]$Token,
       [string]$ShortDescription,
       [string]$Description
   )
   if (-not $Token) {
       Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Cannot create SNOW ticket, missing OAuth token.")
       return
   }
   $uri = "https://$SNOWInstance/api/now/v1"
   $headers = @{
       Authorization = "Bearer $Token"
       "Content-Type" = "application/json"
       Accept = "application/json"
   }
   $body = @{
       caller_id         = $sys_id
       opened_by         = $sys_id
       short_description = $ShortDescription
       description       = $Description
       category          = "Applications"
       subcategory       = $ShortDescription
       urgency           = "4"
       impact            = "4"
       assignment_group  = "Acme CyberArk Admins"
       contact_type      = "Email"
   } | ConvertTo-Json -Depth 3
   try {
       $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $body -ErrorAction Stop
       Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " ServiceNow ticket created: $($response.display_value)")
       Return $($response.display_value)
   } catch {
       Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Failed to create ServiceNow ticket: $($_.Exception.Message)")
   }
}

###################################################################################
## Main script starts here - script will terminate if any errors are encountered 
## Description - Syncs AD PPA accounts with CyberArk
## Uses psPAS Powershell module and EVD exported into SQL database
## The script is months of thinking and a week's programming. Enjoy coding!!
## Values used against variables are for example purposes only. Update accordingly
###################################################################################
Import-Module psPAS
$ErrorActionPreference = "stop"
Add-Type -AssemblyName System.Web


#Variables used by ADPPA
$PVWA = "acme.corp"
$logpath = ".\Sync-ADPPA.log"
$domainName = "acme"
$apiuser = "acme\APIUser"
$PVWAString = "https://" + $PVWA
$FilePath = "D:\EVD\UploadFileListToSQL.cmd"
$CSVPath = "D:\EVD\UploadFileListToCSV.cmd"
$WorkingDirectory = "D:\EVD"
$SAPlatform = "ServerAdmin-Account"
$WAPlatform = "WorkstationAdmin-Account"
$NAPlatform = "NetworkAdmin-Account"
$AAPlatform = "ApplicationAdmin-Account"
$RAPlatform = "ADAdmin-Account"

#Variables used by SMTP notification
$From = "SyncADPPA<acme-SyncADPPA@acme.corp>"
$To = "pam@acme.corp"
$CC = "abhishek.singh@acme.corp"
$SMTPServer = "mailgateway.acme.corp"
$SMTPPort = "25"

# Variables used by MSSQL
$SqlInstance = "CybDatabaseServer\SQLInstance,51433"
$DatabaseName = "CyberArk"
$TargetTableName = "ADPPA"
$TargetSchema = "dbo"
$GNpath = "OU=GenericAccounts,DC=acme,DC=corp"
$SApath = "OU=ServerAdmin,DC=acme,DC=corp"
$WApath = "OU=Workstation Admin,DC=acme,DC=corp"
$outDataTablePath = ".\Out-DataTable.ps1"

# Variables used by AAM-CP.

$appID  = "CybApp"
$safe  = "CybSafe"
$Object  = "acme-APIUser"
$UserName = "APIUser"
$CLIPath = "C:\Program Files\CyberArk\ApplicationPasswordSdk\CLIPasswordSDK64.exe"

# Variables for ServiceNow OAuth
$SNOWInstance = "acmeprod.service-now.com"
$SNOWObject = "ServiceNow-PAMClientID"
$sys_id = "<sys_id>"

# Retrieve API credentials using CP
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$response = & $CLIPath GetPassword /p AppDescs.AppID=$appID /p Query=”Safe=$safe;Folder=Root;Object=$Object” /o Password
$securePassword = ConvertTo-SecureString $response -AsPlainText -Force
$apiCredentials = New-Object System.Management.Automation.PSCredential($UserName, $securePassword)
$Credentials  = New-Object System.Management.Automation.PSCredential($apiuser, $securePassword)
$SNClientID = "<ClientID>"
$SNClientSecret = & $CLIPath GetPassword /p AppDescs.AppID=$appID /p Query=”Safe=$safe;Folder=Root;Object=$SNOWObject” /o Password

#Create log file if needed and start logging
if (!(Test-Path $logpath -Type Leaf)) {New-Item -Path $logpath -Type File}
Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Synchronization started")

try {

	#Connect to Quest ARS
	$null = Connect-QADService -service ARSServer.acme.corp -Proxy -Credential $Credentials

  #Create API session to vault
	$res = New-PASSession -Credential $apiCredentials -BaseURI $PVWAString -type LDAP -concurrentSession $true -ErrorAction Stop

    If (Export-ADPPAtoSQL) {
        Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Connected to SQL Server. Using SQL procedures")
        $safesToCreate = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $DatabaseName -Query "EXEC usp_GetSafesToCreate" -TrustServerCertificate
        $accountsToAdd = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $DatabaseName -Query "EXEC usp_GetAccountsToAdd" -TrustServerCertificate
        $accountsToRemove = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $DatabaseName -Query "EXEC usp_GetAccountsToRemove" -TrustServerCertificate
        $RemoveAPIfromSafes = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $DatabaseName -Query "EXEC usp_GetSafesToCreate" -TrustServerCertificate

    } else {
        Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Failed to connect to SQL server. Falling back to EVD CSV outputs")
        Start-Process -FilePath $CSVPath -WorkingDirectory $WorkingDirectory -Wait
        $cyberArkSafes = Get-CyberArkSafes
        $cyberArkAccounts = Get-CyberArkAccounts
        $adAccounts = Get-ADAccounts
        $EnabledAccounts = $adaccounts | Where-Object { $_.Enabled -eq $true }
        $DisabledAccounts = $adaccounts | Where-Object { $_.Enabled -eq $false }

        # Creates hash-table to store distinct values in our $safestoCreate collection. Similar as SQL's SELECT DISTINCT.
        $SelectDistinct = @{}
        $safesToCreate = $EnabledAccounts | ForEach-Object {
            $safeName = $_.samAccountName.Substring(1) + "-Admins"
            $LANID = $_.samAccountName.Substring(1)
            if (-not $SelectDistinct.ContainsKey($safeName) -and $safeName -notin $cyberArkSafes.SafeName) {
                $SelectDistinct[$safeName] = [PSCustomObject]@{
                    samAccountName = $_.samAccountName
                    safeName       = $safeName
                    LANID            = $LANID
                }
            }
        }
        $safesToCreate = $SelectDistinct.Values

        $accountsToAdd = $EnabledAccounts | ForEach-Object {
            $safeName = $_.samAccountName.Substring(1) + "-Admins"
            $Name = "acme-" + $_.samAccountName
            $Address = "acme.corp"
            if (("acme-" + $_.samAccountName -notin $cyberArkAccounts.Name) -and ($_.samAccountName -match "^[ANRSW]A\d{8}$")) {
                [PSCustomObject]@{
                    Name     = $Name
                    User     =  $_.samAccountName
                    Address  = $Address
                    Safe     = $safeName
                    LogonDomain = "acme"
                }
            }
        }
          
        $accountsToRemove = $cyberArkAccounts | ForEach-Object {
            $username = $_.Name -replace "^acme-", ""
            If ((-not ($adAccounts.samAccountName -contains $username)) -or ($DisabledAccounts.samAccountName -contains $username)) {
                if ($_.SafeName -match "Admins$" -and $_.Name -match "^acme-[ANRSW]A\d{8}$") {
                    [PSCustomObject]@{
                        ID       = $_.ID
                        Name     = $_.Name
                        SafeName = $_.SafeName
                    }
                }
            }
        }

        $SelectDistinct = @{}
        $RemoveAPIfromSafes = $EnabledAccounts | ForEach-Object {
            $safeName = $_.samAccountName.Substring(1) + "-Admins"
            $LANID = $_.samAccountName.Substring(1)
            if (-not $SelectDistinct.ContainsKey($safeName) -and $safeName -notin $cyberArkSafes.SafeName) {
                $SelectDistinct[$safeName] = [PSCustomObject]@{
                    samAccountName = $_.samAccountName
                    safeName       = $safeName
                    LANID            = $LANID
                }
            }
        }
        $RemoveAPIfromSafes = $SelectDistinct.Values
    }

	#Create new safes
    If ($safesToCreate) {
        foreach ($safeToCreate in $safesToCreate) {Create-Safe -Safe $safeToCreate}
    }

	#Add new accounts
    If ($accountsToAdd) {
        foreach ($accountToAdd in $accountsToAdd) {Add-Account -Account $accountToAdd}
    }
  
	#Remove obsolete accounts
    If ($accountsToRemove) {
        foreach ($accountToRemove in $accountsToRemove) {Remove-Account -Account $accountToRemove}
    }
  
	#Remove API user from safe
    if ($RemoveAPIfromSafes) {
        foreach ($RemoveAPIfromSafe in  $RemoveAPIfromSafes) {Remove-APIUser -Safe $RemoveAPIfromSafe}
    }
  
	#Write successful runtime to SQL DB
	#Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $DatabaseName -Query "UPDATE dbo.ProcessRunTimes SET LastRunTime = '$(Get-Date)' WHERE Process = 'Sync-ADPPA'" -TrustServerCertificate
}
catch {
	#Write exception to log
	Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " An exception has occurred!")
	Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Exception Type: $($_.Exception.GetType().FullName)")
	Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Exception Message: $($_.Exception.Message)")
  Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Stack Trace: $($_.Exception.StackTrace)")
    if ($_.Exception.InnerException) {
        Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Inner Exception: $($_.Exception.InnerException.Message)")
    }
    # === ServiceNow ticket creation ===
    $SNToken = Get-ServiceNowToken -ClientID $SNClientID -ClientSecret $SNClientSecret
    $SNShort = "SyncADPPA Script Failure"
    $SNDesc  = "Exception Type: $($_.Exception.GetType().FullName)`nException Message: $($_.Exception.Message)`nStack Trace: $($_.Exception.StackTrace)"
    if ($_.Exception.InnerException) {
          $SNDesc += "`nInner Exception: $($_.Exception.InnerException.Message)"
    }
  $TicketNumber = New-ServiceNowIncident -Token $SNToken -ShortDescription $SNShort -Description $SNDesc
	$Body = " Dear CyberArk Admin, <br /> <br /> An exception has occurred!  Please review the Sync-ADPPA.log on automation Server <br /> Exception Type: $($_.Exception.GetType().FullName) <br /> Exception Message: $($_.Exception.Message). $TicketNumber has been created and assigned for further action. <br /> <br /> Thank You <br /><br /> Note: This is an automated system response. Do Not reply to this email message! <br />"
	Send-MailMessage -From $From -to $To -cc $CC -Subject "SyncADPPA Error" -Body $Body -BodyAsHtml -SmtpServer $SMTPServer -Port $SMTPPort
}
finally {
	#Close API session - run this to cleanup even if errors were encountered
	Close-PASSession
	Disconnect-QADService
	Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Synchronization finished")
}
