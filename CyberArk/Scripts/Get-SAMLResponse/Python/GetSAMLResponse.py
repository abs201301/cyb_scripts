import os
import zipfile
import requests
import shutil
import sys
import time
import re
import subprocess
import platform
from seleniumwire import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.edge.options import Options
from selenium.webdriver.edge.service import Service
from webdriver_manager.microsoft import EdgeChromiumDriverManager
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

# Arguments
if len(sys.argv) < 2:
   print("ERROR: No IdP URL provided")
   sys.exit(1)
IDP_URL = sys.argv[1]

try:
   import win32api
except ImportError:
   print("Please install pywin32: pip install pywin32")
   sys.exit(1)

WAIT_TIME = 20
SAML_REGEX = re.compile(r'name="SAMLResponse" value="(.*?)"')
username = os.getlogin()
global driver_path
driver_path = os.path.join(os.getcwd(), "msedgedriver.exe")

# Downloads msedgedriver.exe if not present already
def download_driver(driver_path):
   paths = [
       r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
       r"C:\Program Files\Microsoft\Edge\Application\msedge.exe"
   ]
   version = None
   for path in paths:
       if os.path.exists(path):
           ver_info = win32api.GetFileVersionInfo(path, "\\")
           ms = ver_info['FileVersionMS']
           ls = ver_info['FileVersionLS']
           version = f"{ms >> 16}.{ms & 0xFFFF}.{ls >> 16}.{ls & 0xFFFF}"
           break
   if not version:
       raise Exception("Failed to detect installed Microsoft Edge version")
   print(f"Detected Edge version: {version}")
   arch = "64" if platform.architecture()[0] == "64bit" else "32"
   zip_url = f"https://msedgewebdriverstorage.blob.core.windows.net/edgewebdriver/{version}/edgedriver_win{arch}.zip"
   print(f"Downloading EdgeDriver from: {zip_url}")
   r = requests.get(zip_url, stream=True)
   if r.status_code != 200:
       raise Exception(f"Failed to download Edge driver from {zip_url}")
   with open("driver.zip", "wb") as f:
       for chunk in r.iter_content(1024):
           f.write(chunk)
   with zipfile.ZipFile("driver.zip", "r") as zip_ref:
       zip_ref.extractall()
   if os.path.exists("msedgedriver.exe"):
       shutil.move("msedgedriver.exe", driver_path)
   os.remove("driver.zip")
   print(f"msedgedriver downloaded to {driver_path}")
   
# Initializes MS edge webdriver
def get_driver(edge_options, swire_options, driver_path):
   try:
      if not os.path.exists(driver_path):
         download_driver(driver_path)
      service = Service(driver_path)
      return webdriver.Edge(service=service, options=edge_options, seleniumwire_options=swire_options)
   except Exception as e:
       service = Service(EdgeChromiumDriverManager().install())
       return webdriver.Edge(service=service, options=edge_options, seleniumwire_options=swire_options)

# Wait for SAMLResponse in network requests
def wait_for_saml_response(driver, timeout=WAIT_TIME):
   start_time = time.time()
   while True:
       for request in driver.requests:
           if request.response and request.response.body:
               try:
                   content = request.response.body.decode('utf-8', errors='ignore')
                   match = SAML_REGEX.search(content)
                   if match:
                       raw_saml = match.group(1)
                       saml_response = raw_saml.replace("&#x2b;", "+").replace("&#x3d;", "=")
                       return saml_response
               except Exception:
                   pass
       if time.time() - start_time > timeout:
          print("Timeout reached.")
          return None
def main():
   
   # Configure Edge
   edge_options = webdriver.EdgeOptions()
   edge_options.add_argument("--headless")
   edge_options.add_argument("--log-level=3")
   edge_options.add_experimental_option("excludeSwitches", ["enable-logging"])
   edge_options.add_argument('--start-maximized')
   edge_options.add_argument('useAutomationExtesion=false')
   edge_options.add_argument('ignore-certificate-errors')
   edge_options.add_argument('--profile-directory=Default')
   edge_options.add_experimental_option("excludeSwitches", ['enable-automation'])
   edge_options.add_argument(f"--app={IDP_URL}")
   swire_options = {
       'disable_encoding': True,
       'suppress_connection_errors': True
       }
   driver = get_driver(edge_options, swire_options, driver_path)
   try:
       driver
       num_element = WebDriverWait(driver, WAIT_TIME).until(
           EC.presence_of_element_located((By.XPATH, "//*[@id='idRichContext_DisplaySign' or contains(text(),'displaySign')]"))
       )
       num_text = num_element.text.strip()
       print(f"Enter: {num_text} in Authenticator App", flush=True)
       saml_response = wait_for_saml_response(driver)
       if saml_response:
          print(f"SAML_RESPONSE:{saml_response}", end="", flush=True)
       else:
           print("ERROR:SAML_NOT_FOUND", flush=True)
           sys.exit(1)
   finally:
       driver.quit()
if __name__ == "__main__":
   main()
