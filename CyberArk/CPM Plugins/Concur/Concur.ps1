##-------------------------------------------
## Helper Functions
##-------------------------------------------

function Init-Driver {
    try {
        $driver = New-Object OpenQA.Selenium.Chrome.ChromeDriver($ChromeService, $ChromeOptions)
        return $driver
    } catch {
        return $null
    }
}

function Perform-Login {
    param([object]$Driver, [string]$Username, [string]$Password, [string]$MFASecret)

    try {
        $Driver.Navigate().GoToUrl($BaseURL)
        if (-not (WaitForPageLoad -Driver $Driver -TimeoutSec 20)) { return @{ Success=$false; Reason="ConnectionFailed" } }

        # cookie consent if present
        $consentButton = WaitForElement -Driver $Driver -Locator $Elements.CookieConsent -TimeoutSec 8
        if ($consentButton) { ClickElementSafely -Driver $Driver -Element $consentButton | Out-Null }

        # username
        $usernameField = WaitForElement -Driver $Driver -Locator $Elements.UsernameInput -LocatorType "ID" -TimeoutSec 15
        if (-not $usernameField) { return @{ Success=$false; Reason="ConnectionFailed" } }
        if (-not (SendUsername -Driver $Driver -Element $usernameField -Text $Username)) {
            return @{ Success=$false; Reason="ConnectionFailed" }
        }
        
        # initial submit
        $submitButton = WaitForElement -Driver $Driver -Locator $Elements.Submit -TimeoutSec 12
        if ($submitButton) { ClickElementSafely -Driver $Driver -Element $submitButton | Out-Null; Start-Sleep -Milliseconds 300 }
        Start-Sleep -Milliseconds 500

        # login button
        $loginButton = WaitForElement -Driver $Driver -Locator $Elements.SAPConcurPassword -TimeoutSec 15
        if ($loginButton) { ClickElementSafely -Driver $Driver -Element $loginButton | Out-Null; Start-Sleep -Seconds 1 }

        # If consent appears again
        $consentButton = WaitForElement -Driver $Driver -Locator $Elements.CookieConsent -TimeoutSec 5
        if ($consentButton) { ClickElementSafely -Driver $Driver -Element $consentButton | Out-Null; Start-Sleep -Milliseconds 300 }

        # password
        $passwordField = WaitForElement -Driver $Driver -Locator $Elements.PasswordField -LocatorType "ID" -TimeoutSec 15
        if (-not $passwordField) { return @{ Success=$false; Reason="ConnectionFailed" } }
        if (-not (SendKeys -Driver $Driver -Element $passwordField -Text $Password -SendSlow $true)) {
            return @{ Success=$false; Reason="ConnectionFailed" }
        }

        # submit password
        $passwordSubmit = WaitForElement -Driver $Driver -Locator $Elements.Submit -TimeoutSec 12
        if ($passwordSubmit) { ClickElementSafely -Driver $Driver -Element $passwordSubmit | Out-Null; Start-Sleep -Milliseconds 500 }

        # handle MFA
        if ($MFASecret) {
            $mfaCode = Generate-TOTPCode -Secret $MFASecret -Digits 6 -Period 30
            if (-not $mfaCode) { return @{ Success=$false; Reason="InvalidCredential" } }
            WaitForPageLoad -Driver $Driver -TimeoutSec 15 | Out-Null
            Start-Sleep -Milliseconds 800
            $authCodeField = WaitForElement -Driver $Driver -Locator $Elements.AuthCodeField -LocatorType "ID" -TimeoutSec 20
            if (-not $authCodeField) {
                $snap = Save-DebugSnapshot -Driver $Driver -prefix "mfa_not_found"
                try {
                    $dbg = @{
                        timestamp = (Get-Date).ToString("o")
                        attempts = $attempt
                        screenshot = $snap.screenshot
                        page = $snap.page
                        url = $Driver.Url
                    } | ConvertTo-Json -Depth 5
                    $dbgFile = Join-Path $DebugSnapshot ("mfa_debug_" + (Get-Date).ToString("yyyyMMdd_HHmmss") + ".json")
                    $dbg | Out-File -FilePath $dbgFile -Encoding UTF8
                } catch {}
                return @{ Success=$false; Reason="InvalidCredential" }
            }
            SendKeys -Driver $Driver -Element $authCodeField -Text $mfaCode -SendSlow $true
            Start-Sleep -Seconds 1
            $mfaSubmit = WaitForElement -Driver $Driver -Locator $Elements.Submit -TimeoutSec 18
            if (-not $mfaSubmit) { return @{ Success=$false; Reason="InvalidCredential" } }
            $cur = $Driver.Url
            ClickElementSafely -Driver $Driver -Element $mfaSubmit | Out-Null
            Start-Sleep -Seconds 1
            # allow URL change or page load to happen
            WaitForUrlChange -Driver $Driver -CurrentUrl $cur -TimeoutSec 8 | Out-Null
        }

        # final check for branding/home to confirm successful login
        if (Validate-LoginSuccess -Driver $Driver -TimeoutSeconds 12) {
            return @{ Success=$true }
        } else {
            # try UAT banner as fallback indicator of successful auth
            $uatBanner = WaitForElement -Driver $Driver -Locator $Elements.UATBanner -TimeoutSec 4
            if ($uatBanner) { return @{ Success=$true } }
        }

        return @{ Success=$false; Reason="InvalidCredential" }
    } catch {
        return @{ Success=$false; Reason="ConnectionFailed" }
    }
}

function Action-Verify {
    param([string]$Username, [string]$Password, [string]$MFASecret)
    $ChromeDriver = Init-Driver
    if (-not $ChromeDriver) { EndScript -Token "ConnectionFailed" -ExitCode 1 -LogoutURL $null -Driver $null -TempProfile $tempUserDataDir }

    $loginResult = Perform-Login -Driver $ChromeDriver -Username $Username -Password $Password -MFASecret $MFASecret
    if (-not $loginResult.Success) {
        $reason = $loginResult.Reason
        EndScript -Token $reason -ExitCode 2 -LogoutURL $null -Driver $ChromeDriver -TempProfile $tempUserDataDir
    }

    # success
    EndScript -Token "VerifyPasswordSuccess" -ExitCode 0 -LogoutURL $LogoutURL -Driver $ChromeDriver -TempProfile $tempUserDataDir
}

function Action-Change {
    param([string]$Username, [string]$OldPassword, [string]$NewPassword, [string]$MFASecret)
    $ChromeDriver = Init-Driver
    if (-not $ChromeDriver) { EndScript -Token "ConnectionFailed" -ExitCode 1 -LogoutURL $null -Driver $null -TempProfile $tempUserDataDir }

    # login using old password
    $loginResult = Perform-Login -Driver $ChromeDriver -Username $Username -Password $OldPassword -MFASecret $MFASecret
    if (-not $loginResult.Success) {
        EndScript -Token $loginResult.Reason -ExitCode 2 -LogoutURL $null -Driver $ChromeDriver -TempProfile $tempUserDataDir
    }

    # navigate to change password page
    try {
        $ChromeDriver.Navigate().GoToUrl($ChangePassURL)
        if (-not (WaitForPageLoad -Driver $ChromeDriver -TimeoutSec 12)) { EndScript -Token "ConnectionFailed" -ExitCode 1 -LogoutURL $LogoutURL -Driver $ChromeDriver -TempProfile $tempUserDataDir }
    } catch {
        EndScript -Token "ConnectionFailed" -ExitCode 1 -LogoutURL $LogoutURL -Driver $ChromeDriver -TempProfile $tempUserDataDir
    }

    # old password field
    $oldPasswordField = WaitForElement -Driver $ChromeDriver -Locator $Elements.OldPasswordField -LocatorType "ID" -TimeoutSec 12
    if (-not $oldPasswordField) { EndScript -Token "ConnectionFailed" -ExitCode 1 -LogoutURL $LogoutURL -Driver $ChromeDriver -TempProfile $tempUserDataDir }
    if (-not (SendKeys -Driver $ChromeDriver -Element $oldPasswordField -Text $OldPassword)) { EndScript -Token "ConnectionFailed" -ExitCode 1 -LogoutURL $LogoutURL -Driver $ChromeDriver -TempProfile $tempUserDataDir }

    # new password fields
    $newPasswordField1 = WaitForElement -Driver $ChromeDriver -Locator $Elements.NewPasswordField1 -LocatorType "ID" -TimeoutSec 12
    if (-not $newPasswordField1) { EndScript -Token "ConnectionFailed" -ExitCode 1 -LogoutURL $LogoutURL -Driver $ChromeDriver -TempProfile $tempUserDataDir }
    if (-not (SendKeys -Driver $ChromeDriver -Element $newPasswordField1 -Text $NewPassword)) { EndScript -Token "ConnectionFailed" -ExitCode 1 -LogoutURL $LogoutURL -Driver $ChromeDriver -TempProfile $tempUserDataDir }

    $newPasswordField2 = WaitForElement -Driver $ChromeDriver -Locator $Elements.NewPasswordField2 -LocatorType "ID" -TimeoutSec 12
    if (-not $newPasswordField2) { EndScript -Token "ConnectionFailed" -ExitCode 1 -LogoutURL $LogoutURL -Driver $ChromeDriver -TempProfile $tempUserDataDir }
    if (-not (SendKeys -Driver $ChromeDriver -Element $newPasswordField2 -Text $NewPassword)) { EndScript -Token "ConnectionFailed" -ExitCode 1 -LogoutURL $LogoutURL -Driver $ChromeDriver -TempProfile $tempUserDataDir }

    # submit change
    $changeSubmitButton = WaitForElement -Driver $ChromeDriver -Locator $Elements.ChangeSubmitButton -TimeoutSec 12
    if (-not $changeSubmitButton) { EndScript -Token "ConnectionFailed" -ExitCode 1 -LogoutURL $LogoutURL -Driver $ChromeDriver -TempProfile $tempUserDataDir }
    ClickElementSafely -Driver $ChromeDriver -Element $changeSubmitButton | Out-Null
    Start-Sleep -Seconds 2

    # expect popup dialog confirmation
    $popupDialog = WaitForElement -Driver $ChromeDriver -Locator $Elements.PopupDialog -TimeoutSec 10
    if ($popupDialog) {
        $popupOkButton = WaitForElement -Driver $ChromeDriver -Locator $Elements.PopupOkButton -TimeoutSec 8
        if ($popupOkButton) {
            ClickElementSafely -Driver $ChromeDriver -Element $popupOkButton | Out-Null
            Start-Sleep -Seconds 1
            EndScript -Token "ChangePasswordSuccess" -ExitCode 0 -LogoutURL $LogoutURL -Driver $ChromeDriver -TempProfile $tempUserDataDir
        } else {
            EndScript -Token "ConnectionFailed" -ExitCode 1 -LogoutURL $LogoutURL -Driver $ChromeDriver -TempProfile $tempUserDataDir
        }
    } else {
        # if no popup found — assume failure
        EndScript -Token "ConnectionFailed" -ExitCode 1 -LogoutURL $LogoutURL -Driver $ChromeDriver -TempProfile $tempUserDataDir
    }
}

function WaitForElement {
   param(
       [object]$Driver,
       [string]$Locator,
       [string]$LocatorType = "XPath",
       [int]$TimeoutSec = 15,
       [bool]$RequireDisplayed = $true
   )
   $wait = New-Object OpenQA.Selenium.Support.UI.WebDriverWait($Driver, [System.TimeSpan]::FromSeconds($TimeoutSec))
   try {
       $element = $wait.Until([Func[OpenQA.Selenium.IWebDriver, OpenQA.Selenium.IWebElement]]{
           param($drv)
           try {
               if ($LocatorType -ieq "ID") {
                   $els = $drv.FindElements([OpenQA.Selenium.By]::Id($Locator))
               } else {
                   $els = $drv.FindElements([OpenQA.Selenium.By]::XPath($Locator))
               }
               if ($els.Count -gt 0) {
                   foreach ($e in $els) {
                       if ($RequireDisplayed) {
                           if ($e.Displayed) { return $e }
                       } else {
                           # return first element even if not displayed yet
                           return $e
                       }
                   }
               }
               return $null
           } catch {
               return $null
           }
       })
       return $element
   } catch [OpenQA.Selenium.WebDriverTimeoutException] {
       return $null
   }
}

function Generate-TOTPCode {
   param(
       [Parameter(Mandatory)]
       [string]$Secret,
       [int]$Digits = 6,
       [int]$Period = 30
   )
   $base32 = $Secret.Trim().Replace(' ', '').ToUpper()
   while ($base32.Length % 8 -ne 0) { $base32 += '=' }
   $base32letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
   $bytes = New-Object System.Collections.Generic.List[byte]
   $buffer = 0
   $bitsLeft = 0
   foreach ($char in $base32.ToCharArray()) {
       if ($char -eq '=') { break }
       $val = $base32letters.IndexOf($char)
       if ($val -lt 0) { return $null }
       $buffer = ($buffer -shl 5) -bor $val
       $bitsLeft += 5
       if ($bitsLeft -ge 8) {
           $bitsLeft -= 8
           $bytes.Add([byte](($buffer -shr $bitsLeft) -band 0xFF))
       }
   }
   $keyBytes = $bytes.ToArray()
   $unixTime = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
   $timeStep = [int64]([Math]::Floor($unixTime / $Period))
   $data = New-Object byte[] 8
   for ($i = 7; $i -ge 0; $i--) {
       $data[$i] = [byte]($timeStep -band 0xFF)
       $timeStep = $timeStep -shr 8
   }
   $hmac = New-Object System.Security.Cryptography.HMACSHA1
   $hmac.Key = $keyBytes
   $hash = $hmac.ComputeHash($data)
   $hmac.Dispose()
   $offset = $hash[19] -band 0x0F
   $binaryCode =
       (($hash[$offset] -band 0x7F) -shl 24) -bor
       (($hash[$offset+1] -band 0xFF) -shl 16) -bor
       (($hash[$offset+2] -band 0xFF) -shl 8)  -bor
       ($hash[$offset+3] -band 0xFF)
   $hmac.Dispose()
   return ($binaryCode % 1000000).ToString("D$digits")
}

function Save-DebugSnapshot {
  param([object]$Driver, [string]$prefix = "debug")
  try {
      if (!(Test-Path $DebugSnapshot)) {
          New-Item -Path $DebugSnapshot -ItemType Directory | Out-Null
      }
      $ts = (Get-Date).ToString("yyyyMMdd_HHmmssfff")
      $png = Join-Path $DebugSnapshot ("${prefix}_screenshot_$ts.png")
      $html = Join-Path $DebugSnapshot ("${prefix}_page_$ts.html")
      try {
          $ss = $Driver.GetScreenshot()
          $ss.SaveAsFile($png, [OpenQA.Selenium.ScreenshotImageFormat]::Png)
      } catch {
          "[Debug] Screenshot failure: $($_.Exception.Message)" | Out-File "$DebugSnapshot\debug.log" -Append
          $png = $null
      }
      try {
          $dom = $Driver.ExecuteScript("return document.documentElement.outerHTML;")
          if (-not $dom) { $dom = $Driver.PageSource }
          $dom | Out-File -FilePath $html -Encoding UTF8
      } catch {
          "[Debug] PageSource failure: $($_.Exception.Message)" | Out-File "$DebugSnapshot\debug.log" -Append
          $html = $null
      }
      return @{ screenshot = $png; page = $html }
  } catch {
      "[Debug] Fatal Save-DebugSnapshot error: $($_.Exception.Message)" |
          Out-File "$DebugSnapshot\debug.log" -Append
      return @{ screenshot = $null; page = $null }
  }
}

##-------------------------------------------
## Safely clicks a web element with fallback mechanisms for reliability
## Attempts regular click first, then JavaScript click if needed
## Returns true on success, false on failure with warning logged
##-------------------------------------------
function ClickElementSafely {
    param([object]$Driver, [object]$Element)
    try {
        $Element.Click(); return $true
    } catch {
        try {
            $Driver.ExecuteScript("arguments[0].click();", $Element); return $true
        } catch {
            return $false
        }
    }
}

##-------------------------------------------
## Safely sends text to web elements
## Supports slow character-by-character input for special characters and complex passwords
##-------------------------------------------
function SendKeys {
    param(
        [object]$Driver,
        [object]$Element,
        [string]$Text,
        [bool]$SendSlow = $false
    )
    try {
        $Element.Clear()
        if ($SendSlow) {
            foreach ($char in $Text.ToCharArray()) {
                $Element.SendKeys($char)
                Start-Sleep -Milliseconds 30
            }
        } else {
            $Element.SendKeys($Text)
        }
        return $true
    } catch {
        return $false
    }
}

function SendUsername {
    param(
        [object]$Driver,
        [object]$Element,
        [string]$Text
    )
    try {
        $Element.Clear()
        $script = @"
            var input = document.querySelector('#username-input');
            var lastValue = input.value;
            input.value = arguments[0];
            var event = new Event('input', { bubbles: true });
            event.simulated = true;
            var tracker = input._valueTracker;
            if (tracker) {
                tracker.setValue(lastValue);
            }
            input.dispatchEvent(event);
"@
        $Driver.ExecuteScript($script, $Text)
        return $true
    } catch {
        return $false
    }
}

function WaitForPageLoad {
    param([object]$Driver, [int]$TimeoutSec = 20)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    do {
        Start-Sleep -Milliseconds 500
        try { $readyState = $Driver.ExecuteScript("return document.readyState;") } catch { $readyState = $null }
    } while ($readyState -ne 'complete' -and $sw.Elapsed.TotalSeconds -lt $TimeoutSec)
    return ($readyState -eq 'complete')
}

function WaitForUrlChange {
   param([object]$Driver, [string]$CurrentUrl, [int]$TimeoutSec = 15)
   $endTime = (Get-Date).AddSeconds($TimeoutSec)
   while ((Get-Date) -lt $endTime) {
       Start-Sleep -Milliseconds 500
       try {
           $newUrl = $Driver.Url
           if ($newUrl -ne $CurrentUrl) { return $true }
       } catch {}
   }
   return $false
}

function Validate-LoginSuccess {
   [CmdletBinding()]
   param(
       [Parameter(Mandatory)]
       [object]$Driver,
       [int]$TimeoutSeconds = 20
   )
   $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
   while ((Get-Date) -lt $deadline) {
       Start-Sleep -Milliseconds 500
       try {
           $url = $Driver.Url
       }
       catch {
           continue
       }
       if ($url -like "https://*.concursolutions.com/home*") {
           return $true
       }
   }
   return $false
}

function EndScript {
    param([string]$Token = "ConnectionFailed", [int]$ExitCode = 1, [string]$LogoutURL = $null, [object]$Driver = $null, [string]$TempProfile = $null)
    try {
        if ($Driver -and $LogoutURL) {
            try { $Driver.Url = $LogoutURL; Start-Sleep -Seconds 1 } catch {}
        }
        if ($Driver) {
            try { $Driver.Quit() } catch {}
        }
        if ($TempProfile) {
            try { if (Test-Path $TempProfile) { Remove-Item -Path $TempProfile -Recurse -Force } } catch {}
        }
    } catch {}
    Write-Output $Token
    exit $ExitCode
}

###################################################################################
## SAP Concur CPM Automation Script - Web-based Password Management with MFA
#=================================================================================
# Description: CPM wrapper for SAP Concur local accounts with TOTP MFA support
# Purpose: Automates password verification and change using Selenium WebDriver
# Created: November 13, 2025
# Updated: November 17, 2025 (Refactored to use shared TOTP module architecture for MFA code generation)
# Author: Abhishek Singh
# Uses Selenium framework with Chrome headless mode and shared TOTP module for MFA
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
$driverPath = "C:\Program Files (x86)\CyberArk\Password Manager\bin"
$DebugSnapshot = "$driverPath\FIL-Concur\Debug"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Web

##-------------------------------------------
## Google Chrome driver settings
##-------------------------------------------
$ChromeService = [OpenQA.Selenium.Chrome.ChromeDriverService]::CreateDefaultService()
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
$ChromeOptions.AddArgument("--disable-popup-blocking")
$ChromeOptions.AddArgument("--disable-features=Autofill")
$ChromeOptions.AddArgument("--disable-features=AutofillServerCommunication")
$ChromeOptions.AddArgument("--disable-features=AutofillPredictionImprovements")
$ChromeOptions.AddUserProfilePreference("profile.password_manager_enabled", $false)
$ChromeOptions.AddUserProfilePreference("credentials_enable_service", $false)
$ChromeOptions.AddUserProfilePreference("autofill.enabled", $false)

##-------------------------------------------
## Init Variables
##-------------------------------------------
$ActionName    = $args[0]
$VerifyLogon   = $args[1]
$UserName      = $args[2]
$UserName = [System.Web.HttpUtility]::UrlDecode($UserName)
if ($UserName -match "^(.*?)(@.*)?$") {
   $base = $Matches[1]
   $base = $base -replace "domain\.com$", ""
   $UserName = "$base@domain.com"
}
$Address       = $args[3]
$CurrentPwd    = $args[4]
$NewPwd        = $args[5]
$MFASecret     = $args[6]

if (-not $ActionName) { EndScript -Token "InvalidAction" -ExitCode 3 }

$BaseURL       = "https://$Address/nui/signin"
$ChangePassURL = "https://region.concursolutions.com/profile/ProfileUserChangePassword.asp"
$LogoutURL     = "https://region.concursolutions.com/home/nui-auth/api/signout?signedout=manual"


##-------------------------------------------
## Config - XPaths and Element IDs
##-------------------------------------------
$Elements = @{
    CookieConsent      = "//*[@id='truste-consent-button']"
    UsernameInput      = "username-input"
    Submit             = "//*[@id='btnSubmit']"
    SAPConcurPassword  = "//button//*[contains(text(),'SAP Concur Password')]"
    PasswordField      = "password"
    AuthCodeField      = "authcode"
    BrandingLogo       = "brandinglogo"
    UATBanner          = "//*[@id='cnqrBody']/div[1]/div[1]/div[2]/span[1]"
    OldPasswordField   = "txtOldPassword"
    NewPasswordField1  = "txtNewPassword1"
    NewPasswordField2  = "txtNewPassword2"
    ChangeSubmitButton = "//*[@id='bSumbit']"
    PopupDialog        = "//*[@id='otPopupDialogdiv']"
    PopupOkButton      = "//*[@id='popupdialogBtn_0']"
}

##-------------------------------------------
## Main logic
##-------------------------------------------
if ($VerifyLogon -eq '1') {
   $ActionName = 'verifypass'
}
try {
    switch ($ActionName.ToLower()) {
        "verifypass" {
            Action-Verify -Username $UserName -Password $CurrentPwd -MFASecret $MFASecret
            break
        }
        "changepass" {
            Action-Change -Username $UserName -OldPassword $CurrentPwd -NewPassword $NewPwd -MFASecret $MFASecret
            break
        }
        default {
            EndScript -Token "InvalidAction" -ExitCode 3 -LogoutURL $null -Driver $null -TempProfile $tempUserDataDir
        }
    }
} catch {
    EndScript -Token "ConnectionFailed" -ExitCode 1 -LogoutURL $null -Driver $null -TempProfile $tempUserDataDir
}
