###################################################################################
## Main script starts here - script will terminate if any errors are encountered ##
#=================================================================================
#         CPM Wrapper for Snaplogic
#        ---------------------------
# Description : Snaplogic Local Accounts
# Created : June 17, 2024
# Updated: Sept 05, 2025 (Refactored for maintainability)
# Abhishek Singh
# Uses Selenium framework and REST web services
#=================================================================================
###################################################################################

##-------------------------------------------
## Load Dependencies
##-------------------------------------------
$ErrorActionPreference = "stop"
$PathToFolder = 'D:\Program Files (x86)\CyberArk\Password Manager\bin'
[System.Reflection.Assembly]::LoadFrom("$PathToFolder\WebDriver.dll") | Out-Null
if ($env:Path -notcontains ";$PathToFolder") { $env:Path += ";$PathToFolder" }
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Web
##-------------------------------------------
## Chrome driver settings
##-------------------------------------------
$ChromeService = [OpenQA.Selenium.Chrome.ChromeDriverService]::CreateDefaultService()
$ChromeService.SuppressInitialDiagnosticInformation = $true
$ChromeService.HideCommandPromptWindow = $true
$ChromeOptions = New-Object OpenQA.Selenium.Chrome.ChromeOptions
$ChromeOptions.AddArgument('start-maximized')
$ChromeOptions.AcceptInsecureCertificates = $true
$ChromeOptions.AddArgument('--ignore-certificate-errors')
$ChromeOptions.AddArgument('--no-sandbox')
$ChromeOptions.AddArgument('--Incognito')
$ChromeOptions.AddArgument('--disable-gpu')
$ChromeOptions.AddArgument('--headless=new') #Comment this for debugging. CPM runs in headless mode!

##-------------------------------------------
## Init Variables
##-------------------------------------------
$ActionName   = $args[0]
$VerifyLogon  = $args[1]
$UserName     = $args[2]
$Address      = $args[3]
$CurrentPwd   = $args[4]
$NewPwd       = $args[5]
$BaseURL       = "https://$Address"
$APIURL        = "$BaseURL/api/1/rest/public/users/$UserName"
$ChgPassURL    = "$BaseURL/sl/login.html?password=update&email=$UserName"
$LogoutURL     = "$BaseURL/sl/login.html?"
##-------------------------------------------
## Config - XPaths
##-------------------------------------------
$Xpaths = @{
   Username = '//*[@id="login-content"]/div/div[2]/div[2]/form/div[1]/div[2]/input'
   Password = '//*[@id="login-content"]/div/div[2]/div[2]/form/div[2]/div[2]/input'
   Submit   = '//*[@id="login-content"]/div/div[2]/div[2]/form/button'
   NewPass  = '//*[@id="login-content"]/div/div[2]/div[2]/form/div[2]/div/div[2]/input'
   Confirm  = '//*[@id="login-content"]/div/div[2]/div[2]/form/div[3]/div/div[2]/input'
   Designer = 'slc-header-tab-Designer'
}

##-------------------------------------------
## Helper Functions
##-------------------------------------------
function Set-UIAccess {
   param(
       [string]$User,
       [string]$Pass,
       [bool]$Enable
   )
   $auth = "${User}:${Pass}"
   $Encoded = [System.Text.Encoding]::UTF8.GetBytes($auth)
   $authorizationInfo = [System.Convert]::ToBase64String($Encoded)
   $headers = @{ "Authorization" = "Basic $authorizationInfo" }
   $body = "{ `"ui_access`": $([System.Convert]::ToString($Enable).ToLower()) }"
   try {
       $res = Invoke-WebRequest -Uri $APIURL -UseBasicParsing -Method Put -Headers $headers -ContentType "application/json" -Body $body -ErrorAction stop | Out-Null
   }
   catch {
       throw "Failed to set UI access ($Enable): $($_.Exception.Message)"
   }
}
function WaitForElement {
   param(
       [object]$Driver,
       [string]$XPath,
       [int]$TimeoutSec = 15
   )
   $wait = New-Object OpenQA.Selenium.Support.UI.WebDriverWait($Driver, [System.TimeSpan]::FromSeconds($TimeoutSec))
   for ($i = 0; $i -lt $TimeoutSec * 4; $i++) {
       Start-Sleep -Milliseconds 250
       try {
		   $element = $Driver.FindElement([OpenQA.Selenium.By]::Xpath($XPath))
           if ($element.Displayed) {
               return $element
           }
        } catch {
            continue
        }
    }
}
function EndScript {
   param(
       $Output,$Logout
   )
   If ($ChromeDriver) {
    try {
        if ($Logout -ne "1") {
            try { $ChromeDriver.Url = $LogoutURL; Start-Sleep -Seconds 1 } catch {}
        }
        $ChromeDriver.Quit()
    } catch {}
   }
   Write-Output $Output
   return 'PowerShell Script Ended'
}
##-------------------------------------------
## Main Logic
##-------------------------------------------
if ($VerifyLogon -eq '1') {
   $ActionName = 'verifypass'
}
switch ($ActionName) {
   "verifypass" {
       try { Set-UIAccess -User $UserName -Pass $CurrentPwd -Enable $true }
       catch { EndScript "Failed to enable UI access: $_" 1 }
       $ChromeDriver = New-Object OpenQA.Selenium.Chrome.ChromeDriver($ChromeService,$ChromeOptions)
       $ChromeDriver.Url = $BaseURL
       try {
           $UsernameField = WaitForElement -Driver $ChromeDriver -XPath $Xpaths.Username -TimeoutSec 20
           If ($UsernameField) { $UsernameField.SendKeys($UserName) }
           $PasswordField = WaitForElement -Driver $ChromeDriver -XPath $Xpaths.Password -TimeoutSec 20
           If ($PasswordField) { $PasswordField.SendKeys($CurrentPwd) }
           $SubmitButton = WaitForElement -Driver $ChromeDriver -XPath $Xpaths.Submit -TimeoutSec 20
           If ($SubmitButton) { $SubmitButton.Click() }
           $Validation = WaitForElement -Driver $ChromeDriver -XPath "//*[@id='$($Xpaths.Designer)']"
       }
       catch { EndScript "403 - Forbidden: $_" 1 }
       Set-UIAccess -User $UserName -Pass $CurrentPwd -Enable $false
       EndScript '200 - Connect Success'
   }
   "changepass" {
       try { Set-UIAccess -User $UserName -Pass $CurrentPwd -Enable $true }
       catch { EndScript "Failed to enable UI access: $_" 1 }
       $ChromeDriver = New-Object OpenQA.Selenium.Chrome.ChromeDriver($ChromeService,$ChromeOptions)
       $ChromeDriver.Url = $ChgPassURL
       try {
           $PasswordField = WaitForElement -Driver $ChromeDriver -XPath $Xpaths.Password -TimeoutSec 20
           If ($PasswordField) { $PasswordField.SendKeys($CurrentPwd) }
           $NewPasswordField = WaitForElement -Driver $ChromeDriver -XPath $Xpaths.NewPass -TimeoutSec 20
           If ($NewPasswordField) { $NewPasswordField.SendKeys($NewPwd) }
           $ConfirmPasswordField = WaitForElement -Driver $ChromeDriver -XPath $Xpaths.Confirm -TimeoutSec 20
           If ($ConfirmPasswordField) { $ConfirmPasswordField.SendKeys($NewPwd) }
           $SubmitButton = WaitForElement -Driver $ChromeDriver -XPath $Xpaths.Submit -TimeoutSec 20
           If ($SubmitButton) { $SubmitButton.Click() }
           $Validation = WaitForElement -Driver $ChromeDriver -XPath "//*[@id='$($Xpaths.Designer)']" -TimeoutSec 20
       }
       catch { EndScript "403 - Forbidden: $_" 1 }
       Set-UIAccess -User $UserName -Pass $NewPwd -Enable $false
       EndScript '200 - Change Password Success'
   }
   default {
       EndScript '404 - Not Found' 1
   }
}
