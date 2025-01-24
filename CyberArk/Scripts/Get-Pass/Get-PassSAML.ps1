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
    $webView.Navigate($Idp_URL)
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

$Idp_URL = "idpurl"
$Base_URL = "https://PVWA/PasswordVault/API"
$Object = "objectname" #Specify Name property of your account here

try {

    $SAMLResponse = Get-SAMLResponse -Verbose
    $headers = @{'Content-Type' = 'application/x-www-form-urlencoded'}
    $body = @{
        concurrentSession='true'
        apiUse='true'
        SAMLResponse = $SAMLResponse
    }
    $sToken = Invoke-RestMethod -Uri "$Base_URL/auth/SAML/Logon" -Method POST -Headers $headers -Body $body
    $headers = @{
        'Authorization' = $sToken
    }

    $response = Invoke-RestMethod -Uri "$Base_URL/Accounts?search=$Object" -Method Get -Headers $headers -ContentType 'application/json'
    $accountID = $response.value[0].id

    $body = @{ 
        reason = "BAU"
    } | ConvertTo-Json

    $sPass = Invoke-RestMethod -Uri "$Base_URL/Accounts/$accountID/Password/Retrieve/" -Method POST -Headers $headers -ContentType 'application/json' -Body $body
    Write-Host "Password: $sPass"

} catch {
    Write-Host " Exception Type: $($_.Exception.GetType().FullName)"
    Write-Host " Exception Message: $($_.Exception.Message)"
}
