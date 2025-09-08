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
   OldPass  = '//*[@id="login-content"]/div/div[2]/div[2]/form/div[1]/div[2]/input'
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
   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
   $auth = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("${User}:${Pass}"))
   $headers = @{
     "Authorization" = "Basic $auth"
   }
   $body = @{"ui_access" = $Enable} | ConvertTo-Json
   $response = Invoke-WebRequest -Uri $APIURL -UseBasicParsing -Method Put -Headers $headers -ContentType "Application/JSON" -Body $body -ErrorAction stop | Out-Null
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
    return $null
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
       try {
           $res = Set-UIAccess -User $UserName -Pass $CurrentPwd -Enable $true
       } catch {
           EndScript 'Failed to set ui_access' 1
       }
       try {
           $ChromeDriver = New-Object OpenQA.Selenium.Chrome.ChromeDriver($ChromeService,$ChromeOptions)
           $ChromeDriver.Url = $BaseURL
           $UsernameField = WaitForElement -Driver $ChromeDriver -XPath $Xpaths.Username -TimeoutSec 20
           If ($UsernameField) { $UsernameField.SendKeys($UserName) } else { EndScript 'Unable to connect to the remote server' 1 }
           $PasswordField = WaitForElement -Driver $ChromeDriver -XPath $Xpaths.Password -TimeoutSec 20
           If ($PasswordField) { $PasswordField.SendKeys($CurrentPwd) } else { EndScript 'Unable to connect to the remote server' 1 }
           $SubmitButton = WaitForElement -Driver $ChromeDriver -XPath $Xpaths.Submit -TimeoutSec 20
           If ($SubmitButton) { $SubmitButton.Click() } else { EndScript 'Unable to connect to the remote server' 1 }
           $Validation = WaitForElement -Driver $ChromeDriver -XPath "//*[@id='$($Xpaths.Designer)']" -TimeoutSec 20
           if (-not $Validation) { EndScript '403 - Forbidden' 1 }
       }
       catch { EndScript '403 - Forbidden' 1 }
       try {
           $res = Set-UIAccess -User $UserName -Pass $CurrentPwd -Enable $false
       } catch {
           EndScript 'Failed to set ui_access' 1
       }
       EndScript '200 - Connect Success'
   }
   "changepass" {
       try {
           $res = Set-UIAccess -User $UserName -Pass $CurrentPwd -Enable $true
       } catch {
           EndScript 'Failed to set ui_access' 1
       }
       try {
           $ChromeDriver = New-Object OpenQA.Selenium.Chrome.ChromeDriver($ChromeService,$ChromeOptions)
           $ChromeDriver.Url = $ChgPassURL
           $PasswordField = WaitForElement -Driver $ChromeDriver -XPath $Xpaths.OldPass -TimeoutSec 20
           If ($PasswordField) { $PasswordField.SendKeys($CurrentPwd) } else { EndScript 'Unable to connect to the remote server' 1 }
           $NewPasswordField = WaitForElement -Driver $ChromeDriver -XPath $Xpaths.NewPass -TimeoutSec 20
           If ($NewPasswordField) { $NewPasswordField.SendKeys($NewPwd) } else { EndScript 'Unable to connect to the remote server' 1 }
           $ConfirmPasswordField = WaitForElement -Driver $ChromeDriver -XPath $Xpaths.Confirm -TimeoutSec 20
           If ($ConfirmPasswordField) { $ConfirmPasswordField.SendKeys($NewPwd) } else { EndScript 'Unable to connect to the remote server' 1 }
           $SubmitButton = WaitForElement -Driver $ChromeDriver -XPath $Xpaths.Submit -TimeoutSec 20
           If ($SubmitButton) { $SubmitButton.Click() } else { EndScript 'Unable to connect to the remote server' 1 }
           $Validation = WaitForElement -Driver $ChromeDriver -XPath "//*[@id='$($Xpaths.Designer)']" -TimeoutSec 20
           if (-not $Validation) { EndScript '403 - Forbidden' 1 }
       }
       catch { EndScript '403 - Forbidden' 1 }
       try {
           $res = Set-UIAccess -User $UserName -Pass $NewPwd -Enable $false
       } catch {
           EndScript 'Failed to set ui_access' 1
       }
       EndScript '200 - Change Password Success'
   }
   default {
       EndScript '404 - Not Found' 1
   }
}
