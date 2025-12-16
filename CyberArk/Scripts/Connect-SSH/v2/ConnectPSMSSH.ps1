$ErrorActionPreference = "Stop"
# Function to generate MFA caching SSH key in CyberArk
function Get-MFAKey {
   try {
       Write-Host "Fetching new SSH key from CyberArk..."
       $psi = New-Object System.Diagnostics.ProcessStartInfo
       # Set the Environment variable for embedded python.exe
       $psi.FileName = "$env:Embedded_Python"
       $psi.Arguments = "GetSAMLResponse.py $Idp_Url"
       $psi.RedirectStandardOutput = $true
       $psi.RedirectStandardError = $true
       $psi.UseShellExecute = $false
       $psi.CreateNoWindow = $true
       $process = New-Object System.Diagnostics.Process
       $process.StartInfo = $psi
       $process.Start() | Out-Null

       $SAMLResponse = $null

       while (-not $process.StandardOutput.EndOfStream) {
           $line = $process.StandardOutput.ReadLine()
           if ($line) {
              if ($line -match "^SAML_RESPONSE:(.+)$") {
                 $SAMLResponse = $matches[1].Trim()
              } else {
                 Write-Host $line
              }
           }
       }
       if (-not $SAMLResponse) {
           throw "Failed to capture SAML Response from Python script"
       }
       Write-Host "Captured SAMLResponse successfully."
       Write-Host "Authenticating with CyberArk..."
       $headers = @{'Content-Type' = 'application/x-www-form-urlencoded'}
       $body = @{
           concurrentSession='true'
           apiUse='true'
           SAMLResponse = $SAMLResponse
       }
       $sToken = Invoke-RestMethod -Uri "${Base_Url}/auth/SAML/Logon" -Method POST -Headers $headers -Body $body
       $env:Passphrase = Generate-Passphrase -Length 14
       $securePassphrase = $env:Passphrase
       $securePassphrase = ConvertTo-SecureString $securePassphrase -AsPlainText -Force
       $securePassphrase | Export-Clixml -Path $passphraseFile
       Write-Host "Requesting MFA caching SSH key..."
       $headers = @{'Authorization' = $sToken}
       $body = @{ formats = @("OpenSSH") ; keyPassword = $Passphrase} | ConvertTo-Json
       $sKey = Invoke-RestMethod "${Base_Url}/Users/Secret/SSHKeys/Cache/" -Method POST -Headers $headers -ContentType application/json -Body $body
       Write-Host "Saving the SSH Key"
       $pKey = ($sKey.value | Where-Object { $_.format -eq "OpenSSH" }).privateKey
       $sFile = $pKey | Out-File -FilePath $sshKeyPath -Encoding ascii
       Write-Host "SSH Key saved at: $sshKeyPath"
   } catch {
       Write-Host " Exception Type: $($_.Exception.GetType().FullName)"
       Write-Host " Exception Message: $($_.Exception.Message)"
   }
}

# Function to generate Passphrase
function Generate-Passphrase {
   param (
       [int]$Length = 14
   )
   $lower = "abcdefghijklmnopqrstuvwxyz"
   $upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
   $number = "0123456789"
   $Passphrase = @(
       (Get-Random -InputObject $upper.ToCharArray())
       '@'
   )
   $allChars = $lower + $number + $upper
   $remaining = -join ((1..($Length - $Passphrase.Count)) | ForEach-Object { Get-Random -InputObject $allChars.ToCharArray() })
   $Passphrase += $remaining.ToCharArray()
   $Passphrase = -join (Get-Random -InputObject $Passphrase -Count $Passphrase.Length)
   return $Passphrase
}

########################################################
# Main Script starts here
# Used for PSMP SSH connection in Powershell
# © Abhishek Singh
# Script will terminate if any errors are encountered
########################################################
# Initialize variables
$username = (whoami) -split '\\' | Select-Object -Last 1
$BaseLocation = "C:\Users\${username}\Connect-SSH"
$Idp_Url = "https://launcher.myapps.microsoft.com/api/signin/<>?tenantId=<>"
$Base_Url = "https://pvwa.acme.corp/PasswordVault/API"
$sshKeyPath = "${BaseLocation}\CAMFAkey.openssh"
$passphraseFile = "${BaseLocation}\Passphrase.xml"
$psmp = "psmp.acme.corp"
$domain = "acme.corp"
$timeout = 4
$ticketingSystem = "ServiceNow"
# Check if the SSH key exists and if it is older than the timeout period
if (Test-Path $sshKeyPath) {
  $lastModified = (Get-Item $sshKeyPath).LastWriteTime
  $age = (Get-Date) - $lastModified
  if ($age.TotalHours -gt $timeout) {
      Write-Host "The SSH key is older than 4 hours. Downloading a new key..."
      Get-MFAKey
  } else {
      Write-Host "SSH key is still valid. Proceeding to connection..."
      if (Test-Path $passphraseFile) {
           $securePassphrase = Import-Clixml -Path $passphraseFile
           $env:Passphrase = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassphrase))
      } else {
           Write-Output "Passphrase file not found!"
      }
  }
} else {
  Write-Host "SSH key does not exist. Downloading a new key..."
  Get-MFAKey
}

# Prepare list of hosts with their connection string
$hostsFile = "${BaseLocation}\Hosts.json"
if (Test-Path $hostsFile) {
  $hosts = Get-Content -Path $hostsFile | ConvertFrom-Json
} else {
  Write-Host "Hosts file not found. Please check the path: $hostsFile" -ForegroundColor Red
  exit
}

# Prompt to select target host
Write-Host "Please choose a host to connect to:"
for ($i = 0; $i -lt $hosts.Hosts.Count; $i++) {
   Write-Host "$($i + 1). $($hosts.Hosts[$i].Name) [$($hosts.Hosts[$i].Environment) - $($hosts.Hosts[$i].Component)]"
}
$selection = Read-Host "Enter your choice (1-$($hosts.Hosts.Count))"
# Validate the input
if ($selection -match "^\d+$" -and [int]$selection -ge 1 -and [int]$selection -le $hosts.Hosts.Count) {
  $selectedHost = $hosts.Hosts[[int]$selection - 1]
  $HostName = $selectedHost.Name
  $AccountName = $selectedHost.Account
  Write-Host "Connecting to $($hosts[[int]$selection - 1].Name)..."
  If ($($selectedHost.Environment) -eq "Prod") {
       $TicketID = Read-Host "Enter SNOW ticket number"      
       If ($($selectedHost.Component) -eq "PSMP") {            
           $ConnectionString = "+vu+${username}+tu+${AccountName}+da+${domain}+ta+${HostName}+ti+${TicketID}+ts+${ticketingSystem}@${psmp}"
       } else {
           $ConnectionString = "+vu+${username}+tu+${AccountName}+ta+${HostName}+ti+${TicketID}+ts+${ticketingSystem}@$psmp"        
       }
   } else {      
       If ($($selectedHost.Component) -eq "PSMP") {        
           $ConnectionString = "${username}@${AccountName}#${domain}@${HostName}@${psmp}"
       } else {
           $ConnectionString = "${username}@${AccountName}@${HostName}@${psmp}"
       }      
  }
  Clear-Host
  Start-Process -NoNewWindow -FilePath "ssh.exe" -ArgumentList "-q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=no -i `"$sshKeyPath`" $ConnectionString" > $null 2>&1
} else {
  Write-Host "Invalid choice. Exiting." -ForegroundColor Red
  exit
}
