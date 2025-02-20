
#    Connect-SSH

##    Overview
The scripts written in Python and Powershell serve the same purpose, i.e. generating the MFA caching SSH key over REST API and saving it to the location of choice + connecting to Linux host via PSMP

##    File Names and their description

**ConnectSSH.ps1** - This is the powershell script that uses Powershell's windows forms in combination with Edge WebView to simulate the browser session to IDP (Microsoft Online). 
As soon as number matching (MFA) is confirmed, the script using "Navigating" handler retrieves the SAMLResponse from DOC HTML parser and closes the browser window. Then REST API call to CyberArk is invoked to download the SSH key. The script also, generates secure passphrase at runtime and stores in env variable to support SSH connections via PSMP.

**ConnectSSH.py** - This repository contains a Python script that automates the process of logging into an Identity Provider (IDP) using Selenium, capturing the SAMLResponse from network requests, and utilizing it for subsequent API calls. It’s designed to handle MFA scenarios (including number matching) and includes error handling to ensure reliability. The script also, generates secure passphrase at runtime and stores in env variable to support SSH connections via PSMP.

***Features***
1. Automates login to the IDP using Selenium.
2. Waits for and captures the SAMLResponse from network requests using a while loop.
3. Handles MFA challenges, including number matching workflows.
4. Suppresses Selenium runtime logs for cleaner output.
5. Includes clear and customizable logic for making API calls after obtaining the SAMLResponse.
6. Fully flexible logic to support various SSH connections via PSMP using the SSH key over MFA caching.
7. The scripts rely on list of target Linux hosts defined in array.

***Prerequisites***
Before running the script, ensure you have the following installed:
1. Python 3.8 or higher
2. Selenium (pip install selenium)
3. Others (pip install selenium-wire pyautogui subprocess requests)
4. WebDriver (for Chrome/Edge/Firefox, depending on your browser)
5. A working API endpoint for testing the SAMLResponse.

***Usage***
1. Open the script file and update the following:
• IDP URL: Replace IDP_URL, PVWA_URL and MFA_KEY_URL with the login page of your Identity Provider, and PVWA hostname/ fqdn.
2. Run the script:
