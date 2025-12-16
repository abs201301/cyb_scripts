import os
import sys
import time
import re
from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeoutError

def handle_response(response):
   try:
      if response.request.method == "POST":
         body = response.text()
         match = SAML_REGEX.search(body)
         if match:
            raw = match.group(1)
            saml = raw.replace("&#x2b;", "+").replace("&#x3d;", "=")
            return saml
   except Exception:
      pass
         
# Arguments
if len(sys.argv) < 2:
   print("ERROR: No IdP URL provided")
   sys.exit(1)
IDP_URL = sys.argv[1]
WAIT_TIME = 20
SAML_REGEX = re.compile(r'name="SAMLResponse" value="(.*?)"')
username = os.getlogin()

def main():
   saml_response = {"value": None}
   with sync_playwright() as p:
       browser = p.chromium.launch(
           headless=True,
           channel="msedge"
       )
       context = browser.new_context(ignore_https_errors=True)
       # Browser -> Python bridge
       context.expose_binding(
           "reportSaml",
           lambda source, value: saml_response.update({"value": value})
       )
       # JS capture logic
       context.add_init_script("""
           (() => {
               const origSubmit = HTMLFormElement.prototype.submit;
               HTMLFormElement.prototype.submit = function () {
                   try {
                       const input = this.querySelector("input[name='SAMLResponse']");
                       if (input) {
                           window.reportSaml(input.value);
                       }
                   } catch (e) {}
                   return origSubmit.apply(this, arguments);
               };
               document.addEventListener("submit", function (e) {
                   try {
                       const input = e.target.querySelector("input[name='SAMLResponse']");
                       if (input) {
                           window.reportSaml(input.value);
                       }
                   } catch (e) {}
               }, true);
           })();
       """)
       page = context.new_page()
       page.goto(IDP_URL)
       # MFA prompt
       try:
           num_element = page.wait_for_selector(
               "//*[@id='idRichContext_DisplaySign' or contains(text(),'displaySign')]",
               timeout=WAIT_TIME * 1000
           )
           print(f"Enter: {num_element.inner_text().strip()} in Authenticator App", flush=True)
       except TimeoutError:
           print("ERROR: MFA prompt not found", flush=True)
           browser.close()
           sys.exit(1)
       # Wait for browser -> Python callback
       for _ in range(WAIT_TIME * 10):
           if saml_response["value"]:
               print(f"SAML_RESPONSE:{saml_response['value']}", end="", flush=True)
               browser.close()
               return
           page.wait_for_timeout(100)
       print("ERROR:SAML_NOT_FOUND", flush=True)
       browser.close()
       sys.exit(1)
if __name__ == "__main__":
   main()
