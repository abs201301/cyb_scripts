#    Get-SAML_MFAKey

##    Overview
The scripts written in Python and Powershell serve the same purpose, i.e. generating the MFA caching SSH key over REST API and saving it to the location of choice.

##    File Names and their description

**GetMFAKey.ps1** - This is the powershell script that uses Powershell's windows forms in combination with Edge WebView to simulate the browser session to IDP (Microsoft Online). 
As soon as number matching (MFA) is confirmed, the script using "Navigating" handler retrieves the SAMLResponse from DOC HTML parser and closes the browser window. Then REST API call to CyberArk is invoked to download the SSH key. The script also, generates secure passphrase at runtime.

**GetMFAKey.py** - This repository contains a Python script that automates the process of logging into an Identity Provider (IDP) using Selenium, capturing the SAMLResponse from network requests, and utilizing it for subsequent API calls. It’s designed to handle MFA scenarios (including number matching) and includes error handling to ensure reliability.
Features
• Automates login to the IDP using Selenium.
• Waits for and captures the SAMLResponse from network requests using a while loop.
• Handles MFA challenges, including number matching workflows.
• Suppresses Selenium runtime logs for cleaner output.
• Includes clear and customizable logic for making API calls after obtaining the SAMLResponse.

Prerequisites
Before running the script, ensure you have the following installed:
• Python 3.8 or higher
• Selenium (pip install selenium)
• Selenium Wire (pip install selenium-wire)
• WebDriver (for Chrome/Edge/Firefox, depending on your browser)
• A working API endpoint for testing the SAMLResponse.

Usage
1. Open the script file and update the following:
• IDP URL: Replace idp_url with the login page of your Identity Provider.
• API Endpoint: Update the API endpoint URL and headers for your use case.
2. Run the script:
