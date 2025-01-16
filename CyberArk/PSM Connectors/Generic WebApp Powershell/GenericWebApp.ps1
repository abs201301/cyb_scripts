# Function to wait until an element is visible
function WaitForElement {
    param (
        $driver,
        $timeoutInSeconds,
        $locatorValue
    )

    $wait = New-Object OpenQA.Selenium.Support.UI.WebDriverWait($Driver, [TimeSpan]::FromSeconds($timeoutInSeconds))

    # Custom loop for waiting until element is found
    for ($i = 0; $i -lt $timeoutInSeconds; $i++) {
        Start-Sleep -Milliseconds 250  # Half-second polling interval
        try {
			$element = $Driver.FindElement([OpenQA.Selenium.By]::Xpath($locatorValue))
            if ($element.Displayed) {
                return $element
            }
        } catch {
            # Continue to wait if the element is not found yet
            continue
        }
    }
    throw "Element not found within timeout."
}

function EndScript
{
    Param ($Output)
	
	$Driver.close()
	$Driver.quit()
	
	Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " $Output")
    return 'PowerShell Script Ended'
}

###################################################################################
## Main script starts here - script will terminate if any errors are encountered ##
#============================================================
#         PSM Wrapper for Selenium webdriver
#          ---------------------------------------------------
# Description : PSM Web Applications
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
$EdgeOptions.AcceptInsecureCertificates = $True
$EdgeOptions.AddArgument('--no-sandbox')
$EdgeOptions.AddArgument("useAutomationExtesion=false")
$EdgeOptions.AddExcludedArgument('enable-automation')

##-------------------------------------------
## Init Variables
##-------------------------------------------
$strURL = 'https://'
$strAddress = $args[0]
$strUserName = $args[1]
$encodedPwd = $args[2]

##--------------------------------------------
## Handle base64 encoded password
##--------------------------------------------
$DecodedPasswordBytes = [System.Convert]::FromBase64String($encodedPwd)
$DecodedPassword = [System.Text.Encoding]::UTF8.GetString($DecodedPasswordBytes)
$securePassword = ConvertTo-SecureString -String $DecodedPassword -AsPlainText -Force
$strPwd = [System.RunTime.InteropServices.Marshal]::PtrToStringAuto([System.RunTime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
$FullLoginURL = "$strURL$strAddress"

# Define the XPath expression to search by id, name, or placeholder
$usernameXPath = "//input[@id='username' or @id='j_username' or contains(@placeholder, 'Username')]"
$passwordXPath = "//input[@id='password' or @id='j_password' or contains(@placeholder, 'Password')]"
$submitButtonXPath = "//*[@type='submit' or @id='login-submission-button' or @id='signIn']"

##-------------------------------------------
## Main script starts here
##-------------------------------------------


#Create log file if needed and start logging
if (!(Test-Path $logpath -Type Leaf)) {New-Item -Path $logpath -Type File}
Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Script started")

if ($args.Count -lt 3) {
	Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Missing arguments. <Address> <UserName> <Password>")
	EndScript
}
			
# Start a Edge tab and load URL

$EdgeOptions.AddArgument("--app=$FullLoginURL")
$Driver = New-Object OpenQA.Selenium.Edge.EdgeDriver($EdgeOptions)


Start-Sleep -Seconds 1
$attributesToCheck = @("id", "name", "placeholder")

try {
	# Locate username field by id, name, or placeholder
	$usernameField = WaitForElement -driver $Driver -timeoutInSeconds 10 -locatorValue $usernameXPath

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
	$passwordField = WaitForElement -driver $Driver -timeoutInSeconds 10 -locatorValue $passwordXPath

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
	$submitButton = WaitForElement -driver $Driver -timeoutInSeconds 10 -locatorValue $submitButtonXPath
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
}

catch {
	Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " An exception has occurred!")
	Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Exception Type: $($_.Exception.GetType().FullName)")
	Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Exception Message: $($_.Exception.Message)")
	EndScript 'Exception has occurred ' 1 
}

finally {
	Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Script finished")
}	