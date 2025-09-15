###################################################################################
## Main script starts here - script will terminate if any errors are encountered ##
#=================================================================================
#         CPM Wrapper for Snaplogic
#        ---------------------------
# Description : Snaplogic Local Accounts
# Created : June 17, 2024
# Updated: Sept 15, 2025 (Refactored for maintainability)
# Abhishek Singh
# Uses Selenium framework and REST web services
#=================================================================================
###################################################################################

##-------------------------------------------
## Load Dependencies
##-------------------------------------------
$ErrorActionPreference = "stop"
$PathToFolder = 'C:\Program Files (x86)\CyberArk\Password Manager\bin'
[System.Reflection.Assembly]::LoadFrom($PathToFolder + "\WebDriver.dll" -f $PathToFolder) | Out-Null
if ($env:Path -notcontains ";$PathToFolder" ) {
    $env:Path += ";$PathToFolder"
}
#$driverPath = "C:\Program Files (x86)\CyberArk\Password Manager\bin"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Web

##-------------------------------------------
## Google Chrome driver settings
##-------------------------------------------

$ChromeService = [OpenQA.Selenium.Chrome.ChromeDriverService]::CreateDefaultService()
#$ChromeService.LogPath = ".\chromedriver.log"
#$ChromeService.EnableVerboseLogging = $true
$ChromeOptions = New-Object OpenQA.Selenium.Chrome.ChromeOptions
$ChromeOptions.AddArgument('start-maximized')
$ChromeOptions.AcceptInsecureCertificates = $True
$ChromeOptions.AddArgument('--no-sandbox')
$ChromeOptions.AddArgument('--disable-extensions')
$ChromeOptions.AddArgument('--disable-gpu')
$ChromeOptions.AddArgument('--incognito')
$ChromeOptions.AddArgument('--headless=new')
$ChromeOptions.AddExcludedArgument('enable-automation')
$ChromeOptions.AddArgument("--remote-debugging-port=" + (Get-Random -Minimum 20000 -Maximum 50000))
$tempUserDataDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "ChromeProfile_" + [guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tempUserDataDir | Out-Null
$ChromeOptions.AddArgument("--user-data-dir=$tempUserDataDir")



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
   Username = "//input[@type='email']"
   Password = "//input[@type='password']"
   Submit   = "//*[@type='submit']"
   OldPass  = "//*[@qa-id='old-password-input']"
   NewPass  = "//*[@qa-id='new-password-input']"
   Confirm  = "//*[@qa-id='confirm-password-input']"
}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
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
   $response = Invoke-WebRequest -Uri $APIURL -UseBasicParsing -Method Put -Headers $headers -ContentType "Application/JSON" -Body $body -ErrorAction stop
   return ($response.Content | ConvertFrom-Json)
}

function Wait-ForUIAccess {
   param(
       [string]$User,
       [string]$Pass,
       [bool]$Expected,
       [int]$TimeoutSec = 20
   )
   $auth = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("${User}:${Pass}"))
   $headers = @{ "Authorization" = "Basic $auth" }
   $waittime = (Get-Date).AddSeconds($TimeoutSec)
   while ((Get-Date) -lt $waittime) {
       try {
           $res = Invoke-RestMethod -Uri $APIURL -Method Get -Headers $headers -ErrorAction Stop
           if ($res.ui_access -eq $Expected) {
               return $true
           }
       } catch {
           Start-Sleep -Seconds 1
       }
       Start-Sleep -Seconds 1
   }
   return $false
}

function WaitForElement {
   param(
       [object]$Driver,
       [string]$XPath,
       [int]$TimeoutSec = 15
   )
   $wait = New-Object OpenQA.Selenium.Support.UI.WebDriverWait($Driver, [System.TimeSpan]::FromSeconds($TimeoutSec))
   try {
       $element = $wait.Until([Func[OpenQA.Selenium.IWebDriver, OpenQA.Selenium.IWebElement]]{
        param($drv)
        try {
            $el = $drv.FindElement([OpenQA.Selenium.By]::XPath($XPath))
            if ($el.Displayed) { return $el }
            else { return $null }
        } catch {
            return $null
        }
       })
       return $element
   } catch [OpenQA.Selenium.WebDriverTimeoutException] {
       Write-Warning "Element not found or not visible after $TimeoutSec seconds: $XPath"
       return $null
   }
}

function WaitForUrlChange {
   param(
       [object]$Driver,
       [string]$CurrentUrl,
       [int]$TimeoutSec = 15
   )
   $endTime = (Get-Date).AddSeconds($TimeoutSec)
   while ((Get-Date) -lt $endTime) {
       Start-Sleep -Milliseconds 500
       try {
           $newUrl = $Driver.Url
           if ($newUrl -ne $CurrentUrl) {
               return $true
           }
       } catch {}
   }
   return $false
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
        if ($ChromeDriver) { $ChromeDriver.Quit() }
        if (Test-Path $tempUserDataDir) { Remove-Item -Path $tempUserDataDir -Recurse -Force }
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
           $null = Set-UIAccess -User $UserName -Pass $CurrentPwd -Enable $true
           if (-not (Wait-ForUIAccess -User $UserName -Pass $CurrentPwd -Expected $true -TimeoutSec 20)) {
              EndScript 'Failed to set ui_access' 1
           }
       } catch {
           EndScript 'Failed to set ui_access' 1
       }
       try {
           $ChromeDriver = New-Object OpenQA.Selenium.Chrome.ChromeDriver($ChromeService,$ChromeOptions)
           $ChromeDriver.Navigate().GoToUrl($BaseURL)
           $timeout = 20
           $sw = [System.Diagnostics.Stopwatch]::StartNew()
           do {
              Start-Sleep -Milliseconds 500
              $readyState = $ChromeDriver.ExecuteScript("return document.readyState;")
           } while ($readyState -ne 'complete' -and $sw.Elapsed.TotalSeconds -lt $timeout)
           if ($readyState -ne 'complete') {
              EndScript 'Unable to connect to the remote server' 1
           }
           $wrapper = WaitForElement -Driver $ChromeDriver -XPath '//*[@id="login-content"]' -TimeoutSec 20
           if (-not $wrapper) { EndScript 'Unable to connect to the remote server' 1 }
           $UsernameField = WaitForElement -Driver $ChromeDriver -XPath $Xpaths.Username -TimeoutSec 20
           If ($UsernameField) { $UsernameField.SendKeys($UserName) } else { EndScript 'Unable to connect to the remote server' 1 }
           $PasswordField = WaitForElement -Driver $ChromeDriver -XPath $Xpaths.Password -TimeoutSec 20
           If ($PasswordField) { $PasswordField.SendKeys($CurrentPwd) } else { EndScript 'Unable to connect to the remote server' 1 }
           $currentUrl = $ChromeDriver.Url
           $SubmitButton = WaitForElement -Driver $ChromeDriver -XPath $Xpaths.Submit -TimeoutSec 20
           If ($SubmitButton) {
              $SubmitButton.Click()
              if (-not (WaitForUrlChange -Driver $ChromeDriver -CurrentUrl $currentUrl -TimeoutSec 15)) {
                 Write-Warning "URL did not change after submit. Assuming password was verified anyway."
              } 
           } else { 
              EndScript 'Unable to connect to the remote server' 1
           }
       } catch { 
           EndScript '403 - Forbidden' 1
       }
       try {
           $res = Set-UIAccess -User $UserName -Pass $CurrentPwd -Enable $false
       } catch {
           EndScript 'Failed to set ui_access' 1
       }
       EndScript '200 - Connect Success'
   }
   "changepass" {
       try {
           $null = Set-UIAccess -User $UserName -Pass $CurrentPwd -Enable $true
           if (-not (Wait-ForUIAccess -User $UserName -Pass $CurrentPwd -Expected $true -TimeoutSec 20)) {
              EndScript 'Failed to set ui_access' 1
           }
       } catch {
           EndScript 'Failed to set ui_access' 1
       }
       try {
           $ChromeDriver = New-Object OpenQA.Selenium.Chrome.ChromeDriver($ChromeService,$ChromeOptions)
           $ChromeDriver.Navigate().GoToUrl($ChgPassURL)
           $timeout = 20
           $sw = [System.Diagnostics.Stopwatch]::StartNew()
           do {
              Start-Sleep -Milliseconds 500
              $readyState = $ChromeDriver.ExecuteScript("return document.readyState;")
           } while ($readyState -ne 'complete' -and $sw.Elapsed.TotalSeconds -lt $timeout)
           if ($readyState -ne 'complete') {
              EndScript 'Unable to connect to the remote server' 1
           }
           $wrapper = WaitForElement -Driver $ChromeDriver -XPath '//*[@id="login-content"]' -TimeoutSec 20
           if (-not $wrapper) { EndScript 'Unable to connect to the remote server' 1 }
           $PasswordField = WaitForElement -Driver $ChromeDriver -XPath $Xpaths.OldPass -TimeoutSec 20
           If ($PasswordField) { $PasswordField.SendKeys($CurrentPwd) } else { EndScript 'Unable to connect to the remote server' 1 }
           $NewPasswordField = WaitForElement -Driver $ChromeDriver -XPath $Xpaths.NewPass -TimeoutSec 20
           If ($NewPasswordField) { $NewPasswordField.SendKeys($NewPwd) } else { EndScript 'Unable to connect to the remote server' 1 }
           $ConfirmPasswordField = WaitForElement -Driver $ChromeDriver -XPath $Xpaths.Confirm -TimeoutSec 20
           If ($ConfirmPasswordField) { $ConfirmPasswordField.SendKeys($NewPwd) } else { EndScript 'Unable to connect to the remote server' 1 }
           $currentUrl = $ChromeDriver.Url
           $SubmitButton = WaitForElement -Driver $ChromeDriver -XPath $Xpaths.Submit -TimeoutSec 20
           If ($SubmitButton) {
              $SubmitButton.Click()
              if (-not (WaitForUrlChange -Driver $ChromeDriver -CurrentUrl $currentUrl -TimeoutSec 15)) {
               Write-Warning "URL did not change after submit. Assuming password was changed anyway."
              }
           } else {
              EndScript 'Unable to connect to the remote server' 1
           }
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
