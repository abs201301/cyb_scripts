function Enable-UI {
		$auth = $strUserName + ':' + $strPwd
		$Encoded = [System.Text.Encoding]::UTF8.GetBytes($auth)
		$authorizationInfo = [System.Convert]::ToBase64String($Encoded)
		$headers = @{"Authorization"="Basic $($authorizationInfo)"}
		$res = Invoke-WebRequest -Uri $APIURL -UseBasicParsing `
			-Method Put `
			-Credential $credential `
			-Headers $headers `
			-ContentType "application/json" `
			-Body "{`"ui_access`": true}"
}
function Disable-UI {
		$auth = $strUserName + ':' + $strPwd
		$Encoded = [System.Text.Encoding]::UTF8.GetBytes($auth)
		$authorizationInfo = [System.Convert]::ToBase64String($Encoded)
		$headers = @{"Authorization"="Basic $($authorizationInfo)"}
		$res = Invoke-WebRequest -Uri $APIURL -UseBasicParsing `
			-Method Put `
			-Credential $credential `
			-Headers $headers `
			-ContentType "application/json" `
			-Body "{`"ui_access`": false}"
}
function DisableUI-POSTChange {
		$auth = $strUserName + ':' + $strNewPwd
		$Encoded = [System.Text.Encoding]::UTF8.GetBytes($auth)
		$authorizationInfo = [System.Convert]::ToBase64String($Encoded)
		$headers = @{"Authorization"="Basic $($authorizationInfo)"}
		$res = Invoke-WebRequest -Uri $APIURL -UseBasicParsing `
			-Method Put `
			-Credential $credential `
			-Headers $headers `
			-ContentType "application/json" `
			-Body "{`"ui_access`": false}"
}

###################################################################################
## Main script starts here - script will terminate if any errors are encountered ##
#============================================================
;#         CPM Wrapper for Snaplogic
#          --------------------------
# Description : Snaplogic Local Accounts
# Created : June 17, 2024
# Updated: July 16, 2024 (Defined Try and catch block)
# Abhishek Singh
# Uses Selenium framework and REST web services
#============================================================
###################################################################################

##-------------------------------------------
## Load Dependencies
##-------------------------------------------
$PathToFolder = 'D:\Program Files (x86)\CyberArk\Password Manager\bin'
[System.Reflection.Assembly]::LoadFrom($PathToFolder + "\WebDriver.dll" -f $PathToFolder) | Out-Null
if ($env:Path -notcontains ";$PathToFolder" ) {
    $env:Path += ";$PathToFolder"
}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Web

##-------------------------------------------
## Chrome driver settings
##-------------------------------------------
$ChromeOptions = New-Object OpenQA.Selenium.Chrome.ChromeOptions
$ChromeOptions.AddArgument('start-maximized')
$ChromeOptions.AcceptInsecureCertificates = $True
$ChromeOptions.AddArgument('--incognito')
$ChromeOptions.AddArgument('--no-sandbox')
#$ChromeOptions.AddArgument('--headless=new') #Comment this for debugging. CPM runs in headless mode!

##-------------------------------------------
## Init Variables
##-------------------------------------------
$strURL = 'https://'
$strAPI = '/api/1/rest/public/users/'
$strChgPass = '/sl/login.html?password=update&email='
$strActionName = $args[0]
$verifyLogon = $args[1]
$strUserName = $args[2]
$strAddress = $args[3]
$strPwd = $args[4]
$strNewPwd = $args[5]
$strLogonUserName = $args[6]
$strLogonPwd = $args[7]

$logoutURL = '/sl/login.html?'  # If logout requires more then a redirect, please edit EndScript per your requirement
$APIURL = "$strURL$strAddress$strAPI$strUserName"
$FullLoginURL = "$strURL$strAddress"
$ChgPassURL = "$strURL$strAddress$strChgPass$strUserName"
$FullLogoutURL = "$strURL$strAddress$logoutURL"

##-------------------------------------------
## Functions
##-------------------------------------------

function EndScript
{
    # Function params
    Param (
    $Output, $Logout
    )


	if ($Logout -ne "1")
	{
		#If logout required
		$ChromeDriver.Url = $FullLogoutURL
		Sleep(1)
	}
	## Make sure this is run before sending the request
	
	$ChromeDriver.close()
	$ChromeDriver.quit()

	write-host $Output

    # Return result
    return 'PowerShell Script Ended'
}

##-------------------------------------------
## Script starts here
##-------------------------------------------

# Check if verifyLogon = 1
if ($verifyLogon -eq '1')
{
	$strActionName = 'verifypass'
}


switch($strActionName)
{
    # Verify password action
    "verifypass"
    {
		try {
			Enable-UI
		}
		catch {
			EndScript 'Failed to enable UI access' 1
		}
	
        # Start a chrome tab and load URL
		$ChromeDriver = New-Object OpenQA.Selenium.Chrome.ChromeDriver($ChromeOptions)
		$ChromeDriver.Url = $FullLoginURL
        
        # Start login action
		try
		{
            # Verify by seaching username element, can directly sendkeys 
			$ChromeDriver.FindElement([OpenQA.Selenium.By]::XPath('//*[@id="login-content"]/div/div[2]/div[2]/form/div[1]/div[2]/input')).SendKeys($strUserName)
		}
		catch
		{
            # No action required, if failed at try section will execute end function.
            # EndScript with second parameter '1' means no logout required.
			EndScript 'Unable to connect to the remote server' 1 
		}
		
        # Continue to find and enter password.
		$ChromeDriver.FindElement([OpenQA.Selenium.By]::XPath('//*[@id="login-content"]/div/div[2]/div[2]/form/div[2]/div[2]/input')).SendKeys($strPwd)
		$ChromeDriver.FindElement([OpenQA.Selenium.By]::XPath('//*[@id="login-content"]/div/div[2]/div[2]/form/button')).Click()
       	Sleep(5)
		try
		{
            # After login, find element to verify login
			$ChromeDriver.FindElement([OpenQA.Selenium.By]::Id("slc-header-tab-Designer"))
		}
		catch
		{
			EndScript '403 - Forbidden' 1
		}
		Disable-UI
		EndScript '200 - Connect Success'	
    }

    # change password action
	"changepass"
	{
		try {
			Enable-UI
		}
		catch {
			EndScript 'Failed to enable UI access' 1
		}
			
        # Start a chrome tab and load Chg password URL
		$ChromeDriver = New-Object OpenQA.Selenium.Chrome.ChromeDriver($ChromeOptions)
		$ChromeDriver.Url = $ChgPassURL
		
		### Continue by find and enter password.
       try
        {
			$ChromeDriver.FindElement([OpenQA.Selenium.By]::Xpath('//*[@id="login-content"]/div/div[2]/div[2]/form/div[1]/div[2]/input')).SendKeys($strPwd)
			$ChromeDriver.FindElement([OpenQA.Selenium.By]::Xpath('//*[@id="login-content"]/div/div[2]/div[2]/form/div[2]/div/div[2]/input')).SendKeys($strNewPwd)
			$ChromeDriver.FindElement([OpenQA.Selenium.By]::Xpath('//*[@id="login-content"]/div/div[2]/div[2]/form/div[3]/div/div[2]/input')).SendKeys($strNewPwd)
        }
        catch 
        {
			EndScript 'Unable to connect to the remote server' 1 
        }

        $ChromeDriver.FindElement([OpenQA.Selenium.By]::XPath('//*[@id="login-content"]/div/div[2]/div[2]/form/button')).Click()
        Sleep(10)
		try
		{
            # After login, find element to verify login
			$ChromeDriver.FindElement([OpenQA.Selenium.By]::Id("slc-header-tab-Designer"))
			DisableUI-POSTChange
		}
		catch
		{
			EndScript '403 - Forbidden' 1
		}
		EndScript '200 - Change Password Success'
	}

	default
	{
		EndScript '404 - Not Found' 1
	}
}
