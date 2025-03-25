# Function to hide browser window
function Hide-Window {
   $hwnd = (Get-Process msedge).MainWindowHandle
   if ($hwnd -ne 0) {
       # Hide window (0 = SW_HIDE)
       [Win32]::ShowWindow($hwnd, 0)
   } else {
       Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Unable to hide window. Handle not found.")
   }
}
# Function to show browser window
function Show-Window {
   $hwnd = (Get-Process msedge).MainWindowHandle
   if ($hwnd -ne 0) {
       # Show window (5 = SW_SHOW)
       [Win32]::ShowWindow($hwnd, 5)
       [Win32]::SetForegroundWindow($hwnd)
   } else {
       Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Unable to show window. Handle not found.")
   }
}

# Function to wait until an element is visible
function WaitForElement {
    param (
        $driver,
        $timeoutInSeconds,
        $locatorValue
    )

    $wait = New-Object OpenQA.Selenium.Support.UI.WebDriverWait($Driver, [TimeSpan]::FromSeconds($timeoutInSeconds))

    # Custom loop for waiting until element is found
    for ($i = 0; $i -lt $timeoutInSeconds * 4; $i++) {
        Start-Sleep -Milliseconds 250
        try {
			$element = $Driver.FindElement([OpenQA.Selenium.By]::Xpath($locatorValue))
            if ($element.Displayed) {
                return $element
            }
        } catch {
            continue
        }
    }

}

function EndScript
{
    Param ($Output)
	
	$Driver.close()
	$Driver.quit()
	
	Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " $Output")
    return 'PowerShell Script Ended'
}

# Application-specific login functions
function Login-Azure {
    param (
        $UserName,
        $Password,
        $AppName
    )
    If ($appName -match "Github") {
        Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Logging into Github")
        $continueText = WaitForElement -driver $Driver -timeoutInSeconds 20 -locatorValue "//*[text() = 'Continue']"
        If ($continueText) {
            $continueText.Click()   
        }
    } Else {
        Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Logging into Azure MyApps Portal")
    } 
      
   try {
        $usernameField = WaitForElement -driver $Driver -timeoutInSeconds 20 -locatorValue "//*[@id = 'i0116']"
        If ($usernameField) {
            Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Found the username field")
            $usernameField.SendKeys($strUserName)
            Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Filled the username field")
   	    } else {
		    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Username field not found")
	    }

        $submitButton = WaitForElement -driver $Driver -timeoutInSeconds 20 -locatorValue "//*[@type='submit' or @id='idSIButton9']"
        if ($submitButton) {
		    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Found the submit button")
		    $submitButton.Click()
		    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Clicked the submit button")
	    } else {
		    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Submit button not found")
	    }

        $passwordField = WaitForElement -driver $Driver -timeoutInSeconds 20 -locatorValue "//*[@id='i0118' or contains(@placeholder, 'Password')]"
        if ($passwordField) {
		    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Found the password field")
		    $passwordField.SendKeys($strPwd)
		    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Filled the password field")
	    } else {
		    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Password field not found")
	    }

        $submitButton = WaitForElement -driver $Driver -timeoutInSeconds 20 -locatorValue "//*[@type='submit' or @id='idSIButton9']"
        if ($submitButton) {
		    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Found the submit button")
		    $submitButton.Click()
		    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Clicked the submit button")
	    } else {
		    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Submit button not found")
	    }

        $submitButton = WaitForElement -driver $Driver -timeoutInSeconds 20 -locatorValue "//*[@type='submit' or @id='idSIButton9']"
        if ($submitButton) {
		    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Found the submit button")
		    $submitButton.Click()
		    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Clicked the submit button")
	    } else {
		    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Submit button not found")
	    }
	Start-Sleep -Seconds 1
    } catch {
	    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " An exception has occurred!")
	    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Exception Type: $($_.Exception.GetType().FullName)")
	    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Exception Message: $($_.Exception.Message)")
	    EndScript 'Exception has occurred ' 1 
    } finally {
	    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Script finished")
    }	
        
}

function Login-Default {
    param (
        $UserName,
        $Password,
        $AppName
    )
    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Logging into ${appName}")
    try {
	    # Locate username field by id, name, or placeholder
	    $usernameField = WaitForElement -driver $Driver -timeoutInSeconds 20 -locatorValue $usernameXPath

	    If ($usernameField) {
		    Write-Host "Found the username field."
		    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Found the username field")
		    $usernameField.SendKeys($strUserName)
		    Write-Host "Filled the username field."
		    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Filled the username field")
	    } else {
		    Write-Host "Username field not found."
		    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Username field not found")
	    }

	    # Locate password field by id, name, or placeholder
	    $passwordField = WaitForElement -driver $Driver -timeoutInSeconds 20 -locatorValue $passwordXPath

	    if ($passwordField) {
		    Write-Host "Found the password field."
		    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Found the password field")
		    $passwordField.SendKeys($strPwd)
		    Write-Host "Filled the password field."
		    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Filled the password field")
	    } else {
		    Write-Host "Password field not found."
		    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Password field not found")
	    }

	    # Locate and click the submit button
	    $submitButton = WaitForElement -driver $Driver -timeoutInSeconds 20 -locatorValue $submitButtonXPath
	    if ($submitButton) {
		    Write-Host "Found the submit button."
		    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Found the submit button")
		    $submitButton.Click()
		    Write-Host "Clicked the submit button."
		    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Clicked the submit button")
	    } else {
		    Write-Host "Submit button not found."
		    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Submit button not found")
	    }
	Start-Sleep -Seconds 1
    } catch {
	    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " An exception has occurred!")
	    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Exception Type: $($_.Exception.GetType().FullName)")
	    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Exception Message: $($_.Exception.Message)")
	    EndScript 'Exception has occurred ' 1 
    } finally {
	    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Script finished")
    }	
}


###################################################################################
## Main script starts here - script will terminate if any errors are encountered ##
#============================================================
#         PSM Wrapper for Selenium webdriver
#         -----------------------------------
# Description : PSM Web Applications
# Created : Nov 06, 2024
# Abhishek Singh
# Uses Selenium framework
#============================================================
###################################################################################

##-------------------------------------------
## Load Dependencies
##-------------------------------------------
$logpath = '.\PSM-WebApp.log'
$PathToFolder = 'D:\Program Files (x86)\CyberArk\PSM\Components'
[System.Reflection.Assembly]::LoadFrom($PathToFolder + "\WebDriver.dll" -f $PathToFolder) | Out-Null
if ($env:Path -notcontains ";$PathToFolder" ) {
    $env:Path += ";$PathToFolder"
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Web
# Load required Win32 APIs
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
   [DllImport("user32.dll")]
   public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
   [DllImport("user32.dll")]
   public static extern bool SetForegroundWindow(IntPtr hWnd);
}
"@

##-------------------------------------------
## MSEdge driver settings
##-------------------------------------------
$EdgeOptions = New-Object OpenQA.Selenium.Edge.EdgeOptions
$EdgeOptions.AddArgument('start-maximized')
$EdgeOptions.AddArgument('--ignore-certificate-errors')
$EdgeOptions.AddArgument('--no-sandbox')
$EdgeOptions.AddArgument('--disable-extensions')
$EdgeOptions.AddArgument('--disable-gpu')
$EdgeOptions.AddArgument('--InPrivate')
$EdgeOptions.AddExcludedArgument('enable-automation')

##-------------------------------------------
## Init Variables
##-------------------------------------------
$strURL = 'https://'
$strAddress = $args[0]
$strUserName = $args[1]
$appName = $args[2]
$encodedPwd = $args[3]


##--------------------------------------------
## Handle base64 encoded password
##--------------------------------------------
$DecodedPasswordBytes = [System.Convert]::FromBase64String($encodedPwd)
$DecodedPassword = [System.Text.Encoding]::UTF8.GetString($DecodedPasswordBytes)
$securePassword = ConvertTo-SecureString -String $DecodedPassword -AsPlainText -Force
$strPwd = [System.RunTime.InteropServices.Marshal]::PtrToStringAuto([System.RunTime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
$FullLoginURL = "$strURL$strAddress"

# Define the XPath expression to search by id, name, or placeholder
$usernameXPath = "//*[@id='username' or contains(@id, '-input') or @id='j_username' or contains(@placeholder, 'Username')]"
$passwordXPath = "//*[@id='password' or @type='password' or @id='j_password' or contains(@placeholder, 'Password')]"
$submitButtonXPath = "//*[@type='submit' or @id='login-submission-button' or @id='signIn' or @id='signInBtn']"

##-------------------------------------------
## Script starts here
##-------------------------------------------


#Create log file if needed and start logging
if (!(Test-Path $logpath -Type Leaf)) {New-Item -Path $logpath -Type File}
Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Script started")

			
# Start a Edge tab and load URL
    
$EdgeOptions.AddArgument("--app=$FullLoginURL")
$Driver = New-Object OpenQA.Selenium.Edge.EdgeDriver($EdgeOptions)
Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Args: ${strUserName}, ${appName}, ${FullLoginURL}")

Start-Sleep -Seconds 1
Hide-Window

If ($appName -match "Azure" -or $appName -match "Github" ) {
    $login = Login-Azure -UserName $strUserName -Password $strPwd -AppName $appName  
} Else {
    $login = Login-Default -UserName $strUserName -Password $strPwd -AppName $appName
}
Show-Window
