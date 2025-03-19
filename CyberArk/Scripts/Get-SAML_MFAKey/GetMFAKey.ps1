function Get-SAMLResponse{

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

########################################################
# Main Script starts here
# Uses native Edge WebView to create browser session
# © Abhishek Singh
# Script will terminate if any errors are encountered
########################################################

$Idp_Url = "https://launcher.myapps.microsoft.com/api/signin/<EntraID>?tenantId=<TenantID>"
$Base_Url = "https://<PVWA>/PasswordVault/API"
$username = (whoami) -split '\\' | Select-Object -Last 1
$OutputKeyPath = "C:\Users\$username\<PathToFolder>\CAMFAkey.ppk"

try {
    Write-Host "Getting SAMLResponse"
    $SAMLResponse = Get-SAMLResponse -Verbose
    Write-Host $SAMLResponse
    Write-Host "Authenticating with CyberArk..."
    $headers = @{'Content-Type' = 'application/x-www-form-urlencoded'}
    $body = @{
        concurrentSession='true'
        apiUse='true'
        SAMLResponse = $SAMLResponse
    }
    $sToken = Invoke-RestMethod -Uri "${Base_Url}/auth/SAML/Logon" -Method POST -Headers $headers -Body $body

    # Generate Passphrase on the fly and write-output  
    $env:Passphrase = Generate-Passphrase -Length 14 

    Write-Output "Generated Passphrase: $Passphrase"
    Write-Host "Requesting MFA caching SSH key..."

    $headers = @{'Authorization' = $sToken}
    $body = @{ formats = @("PPK") ; keyPassword = $Passphrase} | ConvertTo-Json
    $sKey = Invoke-RestMethod "${Base_Url}/Users/Secret/SSHKeys/Cache/" -Method POST -Headers $headers -ContentType application/json -Body $body

    Write-Host "Saving the SSH Key"
    $pKey = ($sKey.value | Where-Object { $_.format -eq "PPK" }).privateKey
    $sFile = $pKey | Out-File -FilePath $OutputKeyPath -Encoding ascii
    Write-Host "SSH Key saved at: $OutputKeyPath"

} catch {
    Write-Host " Exception Type: $($_.Exception.GetType().FullName)"
    Write-Host " Exception Message: $($_.Exception.Message)"
}
