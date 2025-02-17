import os
import sys
import datetime
import re
import requests
import json
import urllib.parse
import random
import string
import subprocess
from pathlib import Path
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

# Function to generate 12 chars long passphrase
def generate_passphrase(length=14):
   if length < 4:
       raise ValueError("Passphrase length must be at least 4 to meet the criteria.")
   lowercase = string.ascii_lowercase
   uppercase = string.ascii_uppercase
   digits = string.digits
   passphrase = [
       random.choice(uppercase),
       '@',  # Special character
   ]
   all_chars = lowercase + digits + uppercase
   passphrase += random.choices(all_chars, k=length - len(passphrase))
   random.shuffle(passphrase)
   return ''.join(passphrase)

# Function to generate MFA caching SSH key
def get_ssh_key():

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
   #print(response.json()) <Un-comment for debugging>
   token = response.text.replace('"',"")
   #print(token) <Un-comment for debugging>
   # Generate MFA caching SSH key
   passphrase = generate_passphrase(14)
   print(f"Passphrase: {passphrase}")
   print("Generating MFA caching SSH key...")
   headers = {
       "Authorization": f'{token}',
       "Content-Type": "application/json"
       }
   payload = json.dumps({
       "formats": [f"{KEY_FORMAT}"],
       'keyPassword': passphrase
       })
   response = requests.request("POST", f"{BASE_URL}/Users/Secret/SSHKeys/Cache/", headers=headers, data=payload, verify=ssl_verify)
   json_object = json.loads(response.text)
   
   # Save the SSH key to a file
   try:
       key = json_object['value'][0]['privateKey']
       key = re.sub("\r","",key)
       with open(KEY_PATH, 'w') as f:
           f.write(key)
       print(f"SSH Key downloaded to {KEY_PATH}.")
   except:
       print("Sorry, an error occurred. Please check your settings and try again.")

############################################################
# Main Script starts here
# Dependencies --
# pip install selenium seleniumwire blinker==1.7.0 requests
# © Abhishek Singh
# Script will terminate if any errors are encountered
############################################################

IDP_URL = "https://launcher.myapps.microsoft.com/api/signin/<TenantID>"
BASE_URL = "https://<PVWA>/PasswordVault/API"
username = os.getlogin()
BASE_LOCATION = f"C:/Users/{username}/Connect-SSH"
KEY_PATH = f"{BASE_LOCATION}/CAMFAKey.ppk"
profile_path = f"{BASE_LOCATION}/Edge"
PSMP = "<PSMP>"
DOMAIN = "<DOMAIN>"
NP_ACCOUNT  = "<Account1>"
P_ACCOUNT = "<Account2>"
GW_ACCOUNT = "<Account3>"
ticketing_system = "ServiceNow"
SSH_TIMEOUT = 14400
KEY_FORMAT = "OpenSSH"
ssl_verify = True
wait_time = 20
RegEx = re.compile(r'name="SAMLResponse" value="(.*?)"')

# Prepare list of hosts with their connection string
hosts = [
   { "Name": "<Host1>", "Environment": "<ENV>", "Component": "<HostType>" },
   { "Name": "<Host2>", "Environment": "<ENV>", "Component": "<HostType>" },
   { "Name": "<Host3>", "Environment": "<ENV>", "Component": "<HostType>" },
   { "Name": "<Host4>", "Environment": "<ENV>", "Component": "<HostType>" },
]

# Check if SSH key exists and is not older than 4 hours
if os.path.exists(KEY_PATH):
   last_modified = datetime.datetime.fromtimestamp(os.path.getmtime(KEY_PATH))
   age = datetime.datetime.now() - last_modified
   if age.total_seconds() / 3600 > timeout_hours:
       print("The SSH key is older than 4 hours. Generating a new key...")
       get_ssh_key()
   else:
       print("SSH key is still valid. Proceeding to connection...")
else:
   print("SSH key does not exist. Generating a new key...")
   get_ssh_key()
# Prompt user to select a target host
print("Please choose a host to connect to:")
for i, host in enumerate(hosts, start=1):
   print(f"{i}. {host['Name']}")
selection = input(f"Enter your choice (1-{len(hosts)}): ")
if selection.isdigit() and 1 <= int(selection) <= len(hosts):
   selected_host = hosts[int(selection) - 1]
   hostname = selected_host["Name"]
   print(f"Connecting to {hostname}...")
   if selected_host["Environment"] == "<ENV>":
       ticket_id = input("Enter SNOW ticket number: ")
       if selected_host["Component"] == "<HostType>":
           connection_string = f"+vu+{username}+tu+{P_ACCOUNT}+da+{DOMAIN}+ta+{hostname}+ti+{ticket_id}+ts+{ticketing_system}@{PSMP}"
       else:
           connection_string = f"+vu+{username}+tu+{GW_ACCOUNT}+ta+{hostname}+ti+{ticket_id}+ts+{ticketing_system}@{PSMP}"
   else:
       if selected_host["Component"] == "<HostType>":
           connection_string = f"{username}@{NP_ACCOUNT}#{DOMAIN}@{hostname}@{PSMP}"
       else:
           connection_string = f"{username}@{GW_ACCOUNT}@{hostname}@{PSMP}"
   # Clear terminal screen
   os.system("cls" if os.name == "nt" else "clear")
   # Start SSH session
   ssh_command = [
       "ssh",
       "-q",
       "-o", "StrictHostKeyChecking=no",
       "-o", "UserKnownHostsFile=/dev/null",
       "-o", "BatchMode=no",
       "-i", KEY_PATH,
       connection_string
   ]
   subprocess.run(ssh_command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
else:
   print("Invalid choice. Exiting.")
   exit(1)
