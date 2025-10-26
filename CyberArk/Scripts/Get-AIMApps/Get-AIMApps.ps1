function LogWrite {
   param(
       [string]$Msg
   )
   If ($Msg) {
      Add-Content -Path $logpath -Value ((Get-Date -Format "dd/MM/yyyy HH:mm") + $Msg)
   }
}

# Function to get various object properties over AAM-CCP
function Get-CCPPassword {
   param(
       [string]$AppID,
       [string]$Safe,
       [string]$Object
   )
   $URI = "$CCP/AIMWebService/api/Accounts"
   $Body = @{
       AppID  = $AppID
       Safe   = $Safe
       Object = $Object
   }
   try {
       $result = Invoke-RestMethod -Method Get -Uri $URI -Certificate $cert -Body $Body
       return $result
   } catch {
       LogWrite -Msg "Get-CCPPassword failed: $($_.Exception.Message)"
   }
}

########################################################
# Main Script starts here
# © Abhishek Singh
# Returns list of AIM applications and their details
# Script will terminate if any errors are encountered
########################################################

# Variables used by AAM-CCP.
$logpath = ".\Get-AIMApps.log"
$CCP = "https://pvwa.acme.corp"
$appID = "AIMAppID"
$safe    = "AIMSafe"
$Object  = "AIMObject"
$cert = 'c:\users\jdoe\cert.cer'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if (!(Test-Path $logpath -Type Leaf)) {New-Item -Path $logpath -Type File}
$response = Get-CCPPassword -AppID $appID -Safe $safe -Object $Object
$baseURL = "$CCP/PasswordVault"
$username = $response.Username
$password = $response.Content


LogWrite -Msg " Script Started"

$body= @{
    "username" = $username
    "password" = $password
    "ConcurrentSession" = $true
   } | ConvertTo-Json

$token = Invoke-RestMethod -Uri "$baseURL/API/auth/LDAP/Logon" -Method Post -body $body -ContentType 'application/json'
$headers = @{"Authorization" = $token}

# =================================
# > Get All Applications
# =================================

LogWrite -Msg " Fetching all applications"
$response = Invoke-RestMethod -Method Get -Uri "$baseURL/WebServices/PIMServices.svc/Applications/" -Headers $headers -ContentType 'application/json'
$applications = $response.application

# =================================
# > Get Applications authentication
# =================================

$results = @()
$totalApplications = $applications.Count
$count = 0
LogWrite -Msg " Total Applications found: $totalApplications"

foreach ($app in $applications) {
   $count++
   $appId = $app.AppID
   LogWrite -Msg " [$count/$totalApplications] Processing AppID: $appID"
   $uri = "$baseURL/WebServices/PIMServices.svc/Applications/$appId/Authentications"
   try {
       $authResponse = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
       $authRecords = $authResponse.authentication
       if ($authRecords) {
           foreach ($auth in $authRecords) {
               $results += [pscustomobject]@{
                   AppID                       = $app.AppID
                   Description                 = $app.Description
                   Location                    = $app.Location
                   Disabled                    = $app.Disabled
                   AccessPermittedFrom         = $app.AccessPermittedFrom
                   AccessPermittedTo           = $app.AccessPermittedTo
                   AllowExtendedAuthRestriction = $app.AllowExtendedAuthenticationRestrictions
                   OwnerName                   = "$($app.BusinessOwnerFName) $($app.BusinessOwnerLName)"
                   OwnerEmail                  = $app.BusinessOwnerEmail
                   OwnerPhone                  = $app.BusinessOwnerPhone
                   ExpirationDate              = $app.ExpirationDate
                   AuthType                    = $auth.AuthType
                   AuthValue                   = $auth.AuthValue
                   AllowInternalScripts        = $auth.AllowInternalScripts
                   Comment                     = $auth.Comment
                   IsFolder                    = $auth.IsFolder
                   AuthID                      = $auth.authID
               }
           }
       }
       else {
           $results += [pscustomobject]@{
               AppID                       = $app.AppID
               Description                 = $app.Description
               Location                    = $app.Location
               Disabled                    = $app.Disabled
               AccessPermittedFrom         = $app.AccessPermittedFrom
               AccessPermittedTo           = $app.AccessPermittedTo
               AllowExtendedAuthRestriction = $app.AllowExtendedAuthenticationRestrictions
               OwnerName                   = "$($app.BusinessOwnerFName) $($app.BusinessOwnerLName)"
               OwnerEmail                  = $app.BusinessOwnerEmail
               OwnerPhone                  = $app.BusinessOwnerPhone
               ExpirationDate              = $app.ExpirationDate
               AuthType                    = "-"
               AuthValue                   = "-"
               AllowInternalScripts        = "-"
               Comment                     = "-"
               IsFolder                    = "-"
               AuthID                      = "-"
           }
       }
   } catch {
       LogWrite -Msg " Failed to fetch authentication methods for AppID $appID - $($_.Exception.Message)"
   }
}

LogWrite -Msg " Total Applications processed: $totalApplications"
$results | Export-CSV ".\apps-auth-methods.csv" -NoTypeInformation -Encoding UTF8
$results | ConvertTo-JSON -Depth 5 | Out-File ".\apps-auth-methods.json"

LogWrite -Msg " Script finished"
