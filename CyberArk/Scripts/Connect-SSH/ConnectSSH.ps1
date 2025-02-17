
# Function to get SAMLResponse from network payload
function Get-SAMLResponse {
   Add-Type -AssemblyName System.Windows.Forms
   $RegEx = '(?i)name="SAMLResponse"(?: type="hidden")? value="(.*?)"'
   $form = New-Object Windows.Forms.Form
   $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
   $form.Width = 800
   $form.Height = 600
   $form.Text = "SAML Authentication"
   # Initialize Edge WebView
   $webView = New-Object Windows.Forms.WebBrowser
   $webView.Dock = 'Fill'
   $webView.ScriptErrorsSuppressed = $true
   $form.Controls.Add($webView)
   $webView.Navigate($Idp_Url)
   $webView.Add_Navigating({
       if ($webView.DocumentText -match "SAMLResponse") {
           $_.Cancel = $true
           if ($webView.DocumentText -match $RegEx) {
               $global:SAMLResponse = ($Matches[1] -replace '&#x2b;', '+') -replace '&#x3d;', '='
               $form.Close()
           }
       }
   })
   [System.Windows.Forms.Application]::Run($form)
   if ($global:SAMLResponse) {
       $result = $global:SAMLResponse
       Remove-Variable -Name SAMLResponse -Scope Global -ErrorAction SilentlyContinue
       return $result
   } else {
       throw "SAMLResponse not found in the network payload."
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

# Function to generate MFA caching SSH key in CyberArk
function Get-MFAKey {
    try {
        Write-Host "Fetching new SSH key from CyberArk..."
        $SAMLResponse = Get-SAMLResponse
        Write-Host "Authenticating with CyberArk..."

        $headers = @{'Content-Type' = 'application/x-www-form-urlencoded'}
        $body = @{
            concurrentSession='true'
            apiUse='true'
            SAMLResponse = $SAMLResponse
        }
        $sToken = Invoke-RestMethod -Uri "${Base_Url}/auth/SAML/Logon" -Method POST -Headers $headers -Body $body

        #$Passphrase = Read-Host "Enter Passphrase"
        $env:Passphrase = Generate-Passphrase -Length 14

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

########################################################
# Main Script starts here
# Used for PSMP SSH connection in Powershell
# © Abhishek Singh
# Script will terminate if any errors are encountered
########################################################

# Initialize variables
$username = (whoami) -split '\\' | Select-Object -Last 1
$BaseLocation = "C:\Users\${username}\Connect-SSH"
$Idp_Url = "https://launcher.myapps.microsoft.com/api/signin/<>"
$Base_Url = "https://<PVWA>/PasswordVault/API"
$sshKeyPath = "${BaseLocation}\CAMFAkey.openssh"
$psmp = "<PSMP>"
$domain = "<Domain>"
$npAccount = "<Account1>"
$pAccount = "<Account2>"
$gwAccount = "<Account3>"
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
   }
} else {
   Write-Host "SSH key does not exist. Downloading a new key..."
   Get-MFAKey
}


# Prepare list of hosts with their connection string
$hosts = @(
   @{ Name = "Host1"; Environment = "<ENV>"; Component = "<HostType>" },
   @{ Name = "Host2"; Environment = "<ENV>"; Component = "<HostType>" },
   @{ Name = "Host3"; Environment = "<ENV>"; Component = "<HostType>" },
   @{ Name = "Host4"; Environment = "<ENV>"; Component = "<HostType>" }
)


# Prompt to select target host
Write-Host "Please choose a host to connect to:"
for ($i = 0; $i -lt $hosts.Count; $i++) {
   Write-Host "$($i + 1). $($Hosts[$i]["Name"])"
}
$selection = Read-Host "Enter your choice (1-$($hosts.Count))"
# Validate the input
if ($selection -match "^\d+$" -and [int]$selection -ge 1 -and [int]$selection -le $hosts.Count) {
   $selectedHost = $hosts[[int]$selection - 1]
   $HostName = $selectedHost["Name"]
   Write-Host "Connecting to $($hosts[[int]$selection - 1].Name)..."
   If ($($selectedHost.Environment) -eq "<ENV>") {
        $TicketID = Read-Host "Enter SNOW ticket number"      
        If ($($selectedHost.Component) -eq "<HostType>") {            
            $ConnectionString = "+vu+${username}+tu+${pAccount}+da+${domain}+ta+${HostName}+ti+${TicketID}+ts+${ticketingSystem}@${psmp}"
        } else {
            $ConnectionString = "+vu+${username}+tu+${gwAccount}+ta+${HostName}+ti+${TicketID}+ts+${ticketingSystem}@$psmp"         
        }
    } else {      
        If ($($selectedHost.Component) -eq "<HostType>") {         
            $ConnectionString = "${username}@${npAccount}#${domain}@${HostName}@${psmp}"
        } else {
            $ConnectionString = "${username}@${gwAccount}@${HostName}@${psmp}"
        }      
           
   }
   Clear-Host
   Start-Process -NoNewWindow -FilePath "ssh.exe" -ArgumentList "-q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=no -i `"$sshKeyPath`" $ConnectionString" > $null 2>&1
} else {
   Write-Host "Invalid choice. Exiting." -ForegroundColor Red
   exit
}
