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
## MSEdge driver settings
##-------------------------------------------
$EdgeService = [OpenQA.Selenium.Edge.EdgeDriverService]::CreateDefaultService()
#$EdgeService.LogPath = ".\edgedriver.log"
$EdgeService.UseVerboseLogging = $true
$EdgeOptions = New-Object OpenQA.Selenium.Edge.EdgeOptions
$EdgeOptions.AddArgument('start-maximized')
$EdgeOptions.AddArgument('--ignore-certificate-errors')
$EdgeOptions.AddArgument('--no-sandbox')
$EdgeOptions.AddArgument('--disable-extensions')
$EdgeOptions.AddArgument('--disable-gpu')
$EdgeOptions.AddArgument('--InPrivate')
$EdgeOptions.AddArgument('--headless')
$EdgeOptions.AddExcludedArgument('enable-automation')

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

function EndScript {
   param(
       $Output,$Logout
   )
   If ($EdgeDriver) {
    try {
        if ($Logout -ne "1") {
            try { $EdgeDriver.Url = $LogoutURL; Start-Sleep -Seconds 1 } catch {}
        }
        $EdgeDriver.Quit()
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
           $EdgeOptions.AddArgument("--app=$BaseURL")
           $EdgeDriver = New-Object OpenQA.Selenium.Edge.EdgeDriver($EdgeService,$EdgeOptions)
           $timeout = 20
           $sw = [System.Diagnostics.Stopwatch]::StartNew()
           do {
              Start-Sleep -Milliseconds 500
              $readyState = $EdgeDriver.ExecuteScript("return document.readyState;")
           } while ($readyState -ne 'complete' -and $sw.Elapsed.TotalSeconds -lt $timeout)
           if ($readyState -ne 'complete') {
              EndScript 'Unable to connect to the remote server' 1
           }
           $wrapper = WaitForElement -Driver $EdgeDriver -XPath '//*[@id="login-content"]' -TimeoutSec 20
           if (-not $wrapper) { EndScript 'Unable to connect to the remote server' 1 }
           $UsernameField = WaitForElement -Driver $EdgeDriver -XPath $Xpaths.Username -TimeoutSec 20
           If ($UsernameField) { $UsernameField.SendKeys($UserName) } else { EndScript 'Unable to connect to the remote server' 1 }
           $PasswordField = WaitForElement -Driver $EdgeDriver -XPath $Xpaths.Password -TimeoutSec 20
           If ($PasswordField) { $PasswordField.SendKeys($CurrentPwd) } else { EndScript 'Unable to connect to the remote server' 1 }
           $SubmitButton = WaitForElement -Driver $EdgeDriver -XPath $Xpaths.Submit -TimeoutSec 20
           If ($SubmitButton) { $SubmitButton.Click() } else { EndScript 'Unable to connect to the remote server' 1 }
           $Validation = WaitForElement -Driver $EdgeDriver -XPath "//*[@id='$($Xpaths.Designer)']" -TimeoutSec 20
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
           $null = Set-UIAccess -User $UserName -Pass $CurrentPwd -Enable $true
           if (-not (Wait-ForUIAccess -User $UserName -Pass $CurrentPwd -Expected $true -TimeoutSec 20)) {
              EndScript 'Failed to set ui_access' 1
           }
       } catch {
           EndScript 'Failed to set ui_access' 1
       }
       try {
           $EdgeOptions.AddArgument("--app=$ChgPassURL")
           $EdgeDriver = New-Object OpenQA.Selenium.Edge.EdgeDriver($EdgeService,$EdgeOptions)
           $timeout = 20
           $sw = [System.Diagnostics.Stopwatch]::StartNew()
           do {
              Start-Sleep -Milliseconds 500
              $readyState = $EdgeDriver.ExecuteScript("return document.readyState;")
           } while ($readyState -ne 'complete' -and $sw.Elapsed.TotalSeconds -lt $timeout)
           if ($readyState -ne 'complete') {
              EndScript 'Unable to connect to the remote server' 1
           }
           $wrapper = WaitForElement -Driver $EdgeDriver -XPath '//*[@id="login-content"]' -TimeoutSec 20
           if (-not $wrapper) { EndScript 'Unable to connect to the remote server' 1 }
           $PasswordField = WaitForElement -Driver $EdgeDriver -XPath $Xpaths.OldPass -TimeoutSec 20
           If ($PasswordField) { $PasswordField.SendKeys($CurrentPwd) } else { EndScript 'Unable to connect to the remote server' 1 }
           $NewPasswordField = WaitForElement -Driver $EdgeDriver -XPath $Xpaths.NewPass -TimeoutSec 20
           If ($NewPasswordField) { $NewPasswordField.SendKeys($NewPwd) } else { EndScript 'Unable to connect to the remote server' 1 }
           $ConfirmPasswordField = WaitForElement -Driver $EdgeDriver -XPath $Xpaths.Confirm -TimeoutSec 20
           If ($ConfirmPasswordField) { $ConfirmPasswordField.SendKeys($NewPwd) } else { EndScript 'Unable to connect to the remote server' 1 }
           $SubmitButton = WaitForElement -Driver $EdgeDriver -XPath $Xpaths.Submit -TimeoutSec 20
           If ($SubmitButton) { $SubmitButton.Click() } else { EndScript 'Unable to connect to the remote server' 1 }
           $Validation = WaitForElement -Driver $EdgeDriver -XPath "//*[@id='$($Xpaths.Designer)']" -TimeoutSec 20
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
