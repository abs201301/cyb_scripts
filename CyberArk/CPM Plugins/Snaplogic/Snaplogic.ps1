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
$PathToFolder = 'D:\Program Files (x86)\CyberArk\Password Manager\bin'
[System.Reflection.Assembly]::LoadFrom("$PathToFolder\WebDriver.dll") | Out-Null
if ($env:Path -notcontains ";$PathToFolder") { $env:Path += ";$PathToFolder" }
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Web
##-------------------------------------------
## Chrome driver settings
##-------------------------------------------
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
   $body = @{ ui_access = $Enable } | ConvertTo-Json -Compress
   try {
       Invoke-WebRequest -Uri $APIURL -UseBasicParsing `
           -Method Put `
           -Headers $headers `
           -ContentType "application/json" `
           -Body $body | Out-Null
       Log "UI access set to $Enable for $User"
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
       [string]$Output,
       [switch]$NoLogout
   )
   if (-not $NoLogout) {
       try {
           $ChromeDriver.Url = $LogoutURL
           Start-Sleep -Seconds 1
       } catch {}
   }
   try {
       $ChromeDriver.Close()
       $ChromeDriver.Quit()
   } catch {}
   Log $Output
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
       catch { EndScript "Failed to enable UI access: $_" -NoLogout; return }
       $ChromeDriver = New-Object OpenQA.Selenium.Chrome.ChromeDriver($ChromeOptions)
       $ChromeDriver.Url = $BaseURL
       try {
           $UsernameField = WaitForElement -driver $ChromeDriver -TimeoutSec 20 -XPath $Xpaths.Username
           If ($UsernameField) { $UsernameField.SendKeys($UserName) }
           $PasswordField = WaitForElement -driver $ChromeDriver -TimeoutSec 20 -XPath $Xpaths.Password
           If ($PasswordField) { $PasswordField.SendKeys($CurrentPwd) }
           $SubmitButton = WaitForElement -driver $ChromeDriver -TimeoutSec 20 -XPath $Xpaths.Submit
           If ($SubmitButton) { $SubmitButton.Click() }
           Wait-ForElement -Driver $ChromeDriver -XPath "//*[@id='$($Xpaths.Designer)']"
       }
       catch { EndScript "403 - Forbidden: $_" -NoLogout; return }
       Set-UIAccess -User $UserName -Pass $CurrentPwd -Enable $false
       EndScript '200 - Connect Success'
   }
   "changepass" {
       try { Set-UIAccess -User $UserName -Pass $CurrentPwd -Enable $true }
       catch { EndScript "Failed to enable UI access: $_" -NoLogout; return }
       $ChromeDriver = New-Object OpenQA.Selenium.Chrome.ChromeDriver($ChromeOptions)
       $ChromeDriver.Url = $ChgPassURL
       try {
           $PasswordField = WaitForElement -driver $ChromeDriver -TimeoutSec 20 -XPath $Xpaths.Password
           If ($PasswordField) { $PasswordField.SendKeys($CurrentPwd) }
           $NewPasswordField = WaitForElement -driver $ChromeDriver -TimeoutSec 20 -XPath $Xpaths.NewPass
           If ($NewPasswordField) { $NewPasswordField.SendKeys($NewPwd) }
           $ConfirmPasswordField = WaitForElement -driver $ChromeDriver -TimeoutSec 20 -XPath $Xpaths.Confirm
           If ($ConfirmPasswordField) { $ConfirmPasswordField.SendKeys($NewPwd) }
           $SubmitButton = WaitForElement -driver $ChromeDriver -TimeoutSec 20 -XPath $Xpaths.Submit
           If ($SubmitButton) { $SubmitButton.Click() }
           Wait-ForElement -Driver $ChromeDriver -XPath "//*[@id='$($Xpaths.Designer)']" -TimeoutSec 20
       }
       catch { EndScript "403 - Forbidden: $_" -NoLogout; return }
       Set-UIAccess -User $UserName -Pass $NewPwd -Enable $false
       EndScript '200 - Change Password Success'
   }
   default {
       EndScript '404 - Not Found' -NoLogout
   }
}
