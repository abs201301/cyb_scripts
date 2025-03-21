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
import getpass
import platform
from seleniumwire import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.edge.options import Options
from selenium.webdriver.edge.service import Service
from webdriver_manager.microsoft import EdgeChromiumDriverManager
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


##############################################################################
# Main Script starts here
# Dependencies --
# pip install selenium seleniumwire blinker==1.7.0 requests webdriver-manager
# Works on Windows as well as Linux
# © Abhishek Singh
# Script will terminate if any errors are encountered
##############################################################################

IDP_URL = "https://launcher.myapps.microsoft.com/api/signin/<EntraID>?tenantId=<TenantID>"
BASE_URL = "https://<PVWA>/PasswordVault/API"
username = os.getlogin()
ACCOUNT_NAME = "<AccountName>"
ssl_verify = True
wait_time = 10
RegEx = re.compile(r'name="SAMLResponse" value="(.*?)"')

def main():

    # Supress un-necessary logs and warnings
    os.environ['WDM_LOG_LEVEL'] = '0'
    sys.stderr = open(os.devnull, 'w')
    current_os = platform.system()
    if current_os == "Windows":
       BASE_LOCATION = f"C:/Users/{username}/<PathtoFolder>"
    else:
       BASE_LOCATION = f"/home/{username}/.config/edge-profile"
    profile_path = f"{BASE_LOCATION}/Edge"
    driver_path = f"{BASE_LOCATION}/msedgedriver.exe"
    # Setup selenium and selenium_wire capabiliies
    edge_options = webdriver.EdgeOptions()
    edge_options.add_argument("--headless")
    edge_options.add_argument("--log-level=3")
    #edge_options.add_argument("InPrivate")
    edge_options.add_experimental_option("excludeSwitches", ["enable-logging"])
    edge_options.add_argument('--start-maximized')
    edge_options.add_argument('useAutomationExtesion=false')
    edge_options.add_argument('ignore-certificate-errors')
    edge_options.add_argument('--user-data-dir='+fr'{profile_path}')
    edge_options.add_argument('--profile-directory=Default')
    edge_options.add_experimental_option("excludeSwitches", ['enable-automation'])
    edge_options.add_argument(f"--app={IDP_URL}")
    # service = Service(driver_path) <Un-comment and comment the one below if you want to load driver from specific path>
    service = Service(EdgeChromiumDriverManager().install())
    swire_options = {
        'disable_encoding': True,
        'suppress_connection_errors': True
        }
    driver = webdriver.Edge(service=service, options=edge_options, seleniumwire_options=swire_options)    
    # Wait for SAMLResponse in network requests
    try:
       driver
       if current_os == "Windows":
          num_element = WebDriverWait(driver, wait_time).until(
                 EC.presence_of_element_located((By.XPATH, "//*[@id='idRichContext_DisplaySign' or contains(text(), 'displaySign')]"))
                 )
          num_text = num_element.text.strip()
          print(f"Enter: {num_text} in Authenticator App")
       else:
          EMAIL = "<YourEmail>"
          PASSWORD = getpass.getpass("Enter your password: ")
          time.sleep(3)
          username_field = WebDriverWait(driver, wait_time).until(
                 EC.presence_of_element_located((By.ID, "i0116"))
                 )
          username_field.send_keys(EMAIL)
          submit_button = WebDriverWait(driver, wait_time).until(
                 EC.presence_of_element_located((By.XPATH, "//*[@type='submit']"))
                 )
          submit_button.click()
          time.sleep(2)
          password_field = WebDriverWait(driver, wait_time).until(
                 EC.presence_of_element_located((By.ID, "i0118"))
                 )
          password_field.send_keys(PASSWORD)
          submit_button = WebDriverWait(driver, wait_time).until(
                 EC.presence_of_element_located((By.XPATH, "//*[@type='submit']"))
                 )
          submit_button.click()    
          num_element = WebDriverWait(driver, wait_time).until(
                 EC.presence_of_element_located((By.XPATH, "//*[@id='idRichContext_DisplaySign' or contains(text(), 'displaySign')]"))
                 )
          num_text = num_element.text.strip()
          print(f"Enter: {num_text} in Authenticator App")
          final_button = WebDriverWait(driver, wait_time).until(
                 EC.presence_of_element_located((By.ID, "idBtn_Back"))
                 )
          final_button.click()
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
    response = requests.post(f"{BASE_URL}/Accounts/{ACCOUNT_ID}/Password/Retrieve/", headers=headers, data=payload, verify=ssl_verify)
    password = response.text.replace('"',"")
    print (f"Password: {password}")

if __name__ == "__main__":
   main()
   
