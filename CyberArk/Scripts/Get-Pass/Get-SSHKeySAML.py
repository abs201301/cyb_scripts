import os
import sys
import time
import base64
import re
import requests
import json
import urllib.parse
import random
import string
from seleniumwire import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.edge.options import Options
from selenium.webdriver.edge.service import Service
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC


# Function to wait for SAMLResponse in network requests
def wait_for_saml_response(driver, timeout=20):
   start_time = time.time()
   while True:
      for request in driver.requests:
         if request.response and request.response.body:
            try:
               content = request.response.body.decode('utf-8', errors='ignore')
               match = RegEx.search(content)
               if match:
                  raw_saml_response = match.group(1)
                  saml_response = raw_saml_response.replace("&#x2b;", "+").replace("&#x3d;", "=")
                  return saml_response
            except Exception:
               pass
      if time.time() - start_time > timeout:
         print("Timeout reached.")
         return None


############################################################
# Main Script starts here
# Dependencies --
# pip install selenium seleniumwire blinker==1.7.0 requests
# © Abhishek Singh
# Retrieves SSH key from CyberArk
# Script will terminate if any errors are encountered
############################################################

IDP_URL = "https://launcher.myapps.microsoft.com/api/signin/<>?tenantId=<>"
BASE_URL = "https://<PVWAHOST>/PasswordVault/API"
profile_path = "C:/Users/<Path>/Edge"
ACCOUNT_NAME = "<AccountName>"
KEY_FORMAT = "PPK"
KEY_PATH = "C:/Users/<Path>"
ssl_verify = True
wait_time = 20
RegEx = re.compile(r'name="SAMLResponse" value="(.*?)"')

def main():

    # Supress un-necessary logs and warnings
    os.environ['WDM_LOG_LEVEL'] = '0'
    sys.stderr = open(os.devnull, 'w')

    # Setup selenium and selenium_wire capabiliies
    edge_options = webdriver.EdgeOptions()
    edge_options.add_argument("--headless")
    edge_options.add_argument("--log-level=3")
    edge_options.add_experimental_option("excludeSwitches", ["enable-logging"])
    edge_options.add_argument('--start-maximized')
    edge_options.add_argument('useAutomationExtesion=false')
    edge_options.add_argument('ignore-certificate-errors')
    edge_options.add_argument('--user-data-dir='+fr'{profile_path}')
    edge_options.add_argument('--profile-directory=Default')
    edge_options.add_experimental_option("excludeSwitches", ['enable-automation'])
    edge_options.add_argument(f"--app={IDP_URL}")
    swire_options = {
        'disable_encoding': True,
        'suppress_connection_errors': True
        }
    driver = webdriver.Edge(options=edge_options, seleniumwire_options=swire_options)

    # Wait for SAMLResponse in network requests
    try:
        driver
        num_element = WebDriverWait(driver, wait_time).until(
               EC.presence_of_element_located((By.XPATH, "//*[@id='idRichContext_DisplaySign' or contains(text(), 'displaySign')]"))
               )
        num_text = num_element.text.strip()
        print(f"Enter: {num_text} in Authenticator App")
        saml_response = wait_for_saml_response(driver)
        if saml_response:
            #print(saml_response) <Un-comment for debugging>
            print("SAMLResponse found.")
        else:
            print("SAMLResponse not found.")
    finally:
       driver.quit()
       
    # Get login token from SAML Response
    print("Authenticating with CyberArk...")
    headers = {
        "Content-Type": "application/x-www-form-urlencoded"
        }
    payload = {
        "concurrentSession": "true",
        "apiUse": "true",
        "SAMLResponse": saml_response
        }
    response = requests.post(f"{BASE_URL}/auth/SAML/Logon", headers=headers, data=payload, verify=ssl_verify)
    token = response.text.replace('"',"")

    # Retrieve Account ID for Account name
    print("Retrieving account ID...")
    headers = {
        "Authorization": f'{token}',
        "Content-Type": "application/json"
        }
    params = {"search": ACCOUNT_NAME}
    response = requests.get(f"{BASE_URL}/Accounts", headers=headers, params=params, verify=ssl_verify)
    accounts = response.json()["value"]
    
    # Retrieve the password
    ACCOUNT_ID = accounts[0]["id"]
    print(f"Account ID: {ACCOUNT_ID}")
    headers = {
       "Authorization": f'{token}',
       "Content-Type": "application/json"
       }
    payload = json.dumps({
       "reason": "BAU"
       })
    response = requests.post(f"{BASE_URL}/Accounts/{ACCOUNT_ID}/Secret/Retrieve/", headers=headers, data=payload, verify=ssl_verify)
    key = response.text.replace('"',"")
    print (f"Key: {key}")
    # Save the SSH key to a file
    try:
        file = f"{KEY_PATH}/MySSHkey.{KEY_FORMAT.lower()}"
        with open(file, 'w') as f:
            f.write(key)
        print(f"SSH Key downloaded to {KEY_PATH}/MySSHkey.{KEY_FORMAT.lower()}.")
    except:
        print("Sorry, an error occurred. Please check your settings and try again.")

if __name__ == "__main__":
   main()
    
