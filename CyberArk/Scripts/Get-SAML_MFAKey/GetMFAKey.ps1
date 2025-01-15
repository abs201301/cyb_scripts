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
       Write-Output $global:SAMLResponse
       Remove-Variable -Name SAMLResponse -Scope Global -ErrorAction SilentlyContinue
    } else {
       throw "SAMLResponse not found in the network payload."
   }
}

########################################################
# Main Script starts here
# Uses native Edge WebView to create browser session
# © Abhishek Singh
# Script will terminate if any errors are encountered
########################################################

$Idp_Url = "https://<Microsoft_Online_URL>"
$PVWA_Url = "https://<PVWA>/PasswordVault/API/auth/SAML/Logon"
$MfaKey_Url = "https://<PVWA>/PasswordVault/API/Users/Secret/SSHKeys/Cache/"
$username = (whoami) -split '\\' | Select-Object -Last 1
$OutputKeyPath = "C:\Users\$username\<FoldeRName>\CAMFAkey.ppk"

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
    $sToken = Invoke-RestMethod -Uri $PVWA_Url -Method POST -Headers $headers -Body $body

    # Generate Passphrase on the fly and write-output
    $upper = Get-Random -InputObject "ABCDEFGHIJKLMNOPQRSTUVWXYZ".ToCharArray()
    $lower = Get-Random -InputObject "abcdefghijklmnopqrstuvwxyz".ToCharArray()
    $number = Get-Random -Maximum 10
    $PassPhrase = ([System.Web.Security.Membership]::GeneratePassword(12,2)) + $upper + $lower + $number

    Write-Output "Generated Passphrase: $PassPhrase"
    Write-Host "Requesting MFA caching SSH key..."

    $headers = @{'Authorization' = $sToken}
    $body = @{ formats = @("PPK") ; keyPassword = $PassPhrase} | ConvertTo-Json
    $sKey = Invoke-RestMethod $MfaKey_Url -Method POST -Headers $headers -ContentType application/json -Body $body

    Write-Host "Saving the SSH Key"
    $pKey = ($sKey.value | Where-Object { $_.format -eq "PPK" }).privateKey
    $sFile = $pKey | Out-File -FilePath $OutputKeyPath -Encoding ascii
    Write-Host "SSH Key saved at: $OutputKeyPath"

} catch {
    Write-Host " Exception Type: $($_.Exception.GetType().FullName)"
    Write-Host " Exception Message: $($_.Exception.Message)"
}
