########################################################
# Main Script starts here
# © Abhishek Singh
# Retrieves password using RADIUS authentication
# Script will terminate if any errors are encountered
########################################################

$baseURL = "https://<PVWA>/PasswordVault/API"
$Object = "" #Specify Name property of your account here
$username = (whoami) -split '\\' | Select-Object -Last 1
$sPassword = Read-Host "Enter password" -AsSecureString
$password = [System.RunTime.InteropServices.Marshal]::PtrToStringAuto([System.RunTime.InteropServices.Marshal]::SecureStringToBSTR($sPassword))

try {
    $body= @{
    "username" = $username
    "password" = $password
    "ConcurrentSession" = $true
    } | ConvertTo-Json

    $token = Invoke-RestMethod -Uri "$baseURL/auth/RADIUS/Logon" -Method Post -body $body -ContentType 'application/json'
    $headers = @{"Authorization" = $token}
    $response = Invoke-RestMethod -Uri "$baseURL/Accounts?search=$search" -Method Get -Headers $headers -ContentType 'application/json'
    $accountID = $response.value[0].id

    $body = @{
    reason = "BAU"
    } | ConvertTo-Json

    $pass = Invoke-RestMethod -Uri "$baseURL/Accounts/$accountID/Password/Retrieve/" -Method Post -Headers $headers -Body $body -ContentType 'application/json'
    Write-Host "Password: $pass"

} Catch {
    Write-Host " Exception Type: $($_.Exception.GetType().FullName)"
    Write-Host " Exception Message: $($_.Exception.Message)"
}
