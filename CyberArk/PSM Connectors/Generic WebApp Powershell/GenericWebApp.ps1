function LogWrite {
   param(
       [string]$Msg
   )
   If ($Msg) {
      Add-Content -Path $logpath -Value ((Get-Date -Format "dd/MM/yyyy HH:mm") + $Msg)
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
	
	LogWrite -Msg " $Output"
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
        LogWrite -Msg " Logging into Github"
        $continueText = WaitForElement -driver $Driver -timeoutInSeconds 20 -locatorValue "//*[text() = 'Continue']"
        If ($continueText) {
            $continueText.Click()   
        }
    } Else {
        LogWrite -Msg " Logging into Azure MyApps Portal"
    } 
    If ($appName -match "EPM") {
        LogWrite -Msg " Logging into BeyondTrust EPM"
        $button = WaitForElement -driver $Driver -timeoutInSeconds 20 -locatorValue "//*[@id='test-login-button']"
        If ($button) {
            $button.Click()   
        }
    }
   try {
        $usernameField = WaitForElement -driver $Driver -timeoutInSeconds 20 -locatorValue "//*[@id = 'i0116']"
        If ($usernameField) {
            LogWrite -Msg " Found the username field"
            $usernameField.SendKeys($strUserName)
            LogWrite -Msg " Filled the username field"
   	    } else {
		    LogWrite -Msg " Username field not found"
	    }

        $submitButton = WaitForElement -driver $Driver -timeoutInSeconds 20 -locatorValue "//*[@type='submit' or @id='idSIButton9']"
        if ($submitButton) {
		    LogWrite -Msg " Found the submit button"
		    $submitButton.Click()
		    LogWrite -Msg " Clicked the submit button"
	    } else {
		    LogWrite -Msg " Submit button not found"
	    }

        $passwordField = WaitForElement -driver $Driver -timeoutInSeconds 20 -locatorValue "//*[@id='i0118' or contains(@placeholder, 'Password')]"
        if ($passwordField) {
		    LogWrite -Msg " Found the password field"
		    $passwordField.SendKeys($strPwd)
		    LogWrite -Msg " Filled the password field"
	    } else {
		    LogWrite -Msg " Password field not found"
	    }
        $submitButton = WaitForElement -driver $Driver -timeoutInSeconds 20 -locatorValue "//*[@type='submit' or @id='idSIButton9']"
        if ($submitButton) {
		    LogWrite -Msg " Found the submit button"
		    $submitButton.Click()
		    LogWrite -Msg " Clicked the submit button"
	    } else {
		    LogWrite -Msg " Submit button not found"
	    }
        $numberCodeElement = WaitForElement -driver $Driver -timeoutInSeconds 10 -locatorValue "//*[@id='idRichContext_DisplaySign']"
        if ($numberCodeElement) {
           $codeText = $numberCodeElement.Text
           $numberMatch = [regex]::Match($codeText, '\d{2,3}')
           if ($numberMatch.Success) {
               $authCode = $numberMatch.Value
               LogWrite -Msg " Found Authenticator code: $authCode"
               [System.Windows.Forms.MessageBox]::Show(
               "Please open Microsoft Authenticator on your phone and enter number: $authCode",
               "Authenticator Prompt",
               [System.Windows.Forms.MessageBoxButtons]::OK,
               [System.Windows.Forms.MessageBoxIcon]::Information
               )
            } else {
               LogWrite -Msg " No number matching prompt detected"
            }
        }
        If (-not $appName -match "EPM") { 
           $submitButton = WaitForElement -driver $Driver -timeoutInSeconds 20 -locatorValue "//*[@type='submit' or @id='idSIButton9']"
            if ($submitButton) {
		        LogWrite -Msg " Found the submit button"
		        $submitButton.Click()
		        LogWrite -Msg " Clicked the submit button"
	        } else {
		        LogWrite -Msg " Submit button not found"
            }
	    }
	Start-Sleep -Seconds 1
    } catch {
	    LogWrite -Msg " An exception has occurred!"
	    LogWrite -Msg " Exception Type: $($_.Exception.GetType().FullName)"
	    LogWrite -Msg " Exception Message: $($_.Exception.Message)"
	    EndScript 'Exception has occurred ' 1 
    } finally {
	    LogWrite -Msg " Script finished"
    }	
        
}

function Login-Default {
    param (
        $UserName,
        $Password,
        $AppName
    )
    LogWrite -Msg " Logging into ${appName}"
    try {
	    # Locate username field by id, name, or placeholder
	    $usernameField = WaitForElement -driver $Driver -timeoutInSeconds 20 -locatorValue $usernameXPath

	    If ($usernameField) {
		    LogWrite -Msg " Found the username field"
		    $usernameField.SendKeys($strUserName)
		    LogWrite -Msg " Filled the username field"
	    } else {
		    LogWrite -Msg " Username field not found"
	    }

	    # Locate password field by id, name, or placeholder
	    $passwordField = WaitForElement -driver $Driver -timeoutInSeconds 20 -locatorValue $passwordXPath

	    if ($passwordField) {
		    LogWrite -Msg " Found the password field"
		    $passwordField.SendKeys($strPwd)
		    LogWrite -Msg " Filled the password field"
	    } else {
		    LogWrite -Msg " Password field not found"
	    }

	    # Locate and click the submit button
	    $submitButton = WaitForElement -driver $Driver -timeoutInSeconds 20 -locatorValue $submitButtonXPath
	    if ($submitButton) {
		    LogWrite -Msg " Found the submit button"
		    $submitButton.Click()
		    LogWrite -Msg " Clicked the submit button"
	    } else {
		    LogWrite -Msg " Submit button not found"
	    }
	Start-Sleep -Seconds 1
    } catch {
	    LogWrite -Msg " An exception has occurred!"
	    LogWrite -Msg " Exception Type: $($_.Exception.GetType().FullName)"
	    LogWrite -Msg " Exception Message: $($_.Exception.Message)"
	    EndScript 'Exception has occurred ' 1 
    } finally {
	    LogWrite -Msg " Script finished"
    }	
}


###################################################################################
## Main script starts here - script will terminate if any errors are encountered ##
#============================================================
#         PSM Wrapper for Selenium webdriver
#          ---------------------------------------------------
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
$usernameXPath = "//*[@id='username' or contains(@id, '-input') or @id='j_username' or @name='j_username' or contains(@placeholder, 'Username')]"
$passwordXPath = "//*[@id='password' or @type='password' or @id='j_password' or contains(@placeholder, 'Password')]"
$submitButtonXPath = "//*[@type='submit' or @id='login-submission-button' or @id='signIn' or @id='signInBtn' or @id='login-button-id']"

##-------------------------------------------
## Script starts here
##-------------------------------------------


#Create log file if needed and start logging
if (!(Test-Path $logpath -Type Leaf)) {New-Item -Path $logpath -Type File}
LogWrite -Msg " Script started"

			
# Start a Edge tab and load URL
  
$EdgeOptions.AddArgument("--app=$FullLoginURL")
$Driver = New-Object OpenQA.Selenium.Edge.EdgeDriver($EdgeOptions)
LogWrite -Msg " Args: ${strUserName}, ${appName}, ${FullLoginURL}"

Start-Sleep -Seconds 1

If ($appName -match "Azure" -or $appName -match "Github" -or $appName -match "EPM" ) {
    $login = Login-Azure -UserName $strUserName -Password $strPwd -AppName $appName  
} Else {
    $login = Login-Default -UserName $strUserName -Password $strPwd -AppName $appName
}

