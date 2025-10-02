# PSM RDP Launcher (PSM For Windows)

- Author: Abhishek Singh
- Platform: Windows PowerShell 5.1
- Description:

  This PowerShell GUI tool allows secure launching of RDP sessions via CyberArk PSM (Privileged Session Manager) without having to login to PVWA (CyberArk Web UI). It supports storing credentials in DPAPI-secured blobs and generating .rdp files with embedded passwords. 		  Designed for ease of use, automation, and security.

⸻

Features

	•	GUI-based host selection: Tree view of categories, components, and hosts with checkboxes.
	•	Secure credential storage: Uses ConvertFrom-SecureString to store credentials in creds.json.
	•	RDP files: Generates .rdp files with embedded DPAPI password blobs for hosts.
	•	Automatic cleanup: .rdp files are deleted asynchronously after launch.
	•	Configurable components: Supports multiple connection components per host.
	•	Cross-host launch: Select multiple hosts and launch RDP sessions in one click.

⸻

Prerequisites

	•	Windows: PowerShell 5.1
	•	Modules: None required beyond built-in .NET assemblies (System.Windows.Forms, System.Drawing, Microsoft.VisualBasic)
	•	Files:
	        - servers.json – defines hosts, categories, components, and PSM connection details.
	        - creds.json – stores encrypted credentials (created automatically when adding credentials).

⸻

Installation

	1.	Place PSMRDPLauncher.ps1 in a folder.
	2.	Place servers.json in the same folder.
	3.	Optionally, pre-create creds.json or let the script create it when first adding credentials.
	4.	Run the script in Windows PowerShell 5.1: .\PSMRDPLauncher.ps1

 
Usage

	1.	Select Connection Component: Use the dropdown to choose the component.
	2.	Select Credential: Choose a stored credential or add a new one.
	3.	Select Hosts: Use the tree view to check hosts to launch.
	4.	Launch Sessions: Click OK - Launch Selected. RDP sessions will open via Launch-PSMSession function.

⸻

Adding/Removing Credentials

	•	Add Credential: Click Add Cred, enter a friendly name, username, and password.
	•	Remove Credential: Select from dropdown, click Remove.

All credentials are stored securely in creds.json using DPAPI encryption. Passwords are never stored in plaintext.

⸻

File Cleanup

	•	Generated .rdp files are automatically deleted after a short delay to prevent leftover credentials on disk.
	•	Cleanup runs asynchronously and does not block the GUI.

⸻

Configuration (servers.json)

A sample servers.json structure:Usage
```
{
 "Config": {
   "PSMAddress": "psmlb.your.domain.com",
   "PSMPort": 3389,
   "LANID": "YourLANID",
   "ConnectionComponents": "PSM-RDP", "PSM-SSH",
   "DefaultComponent": "PSM-RDP",
   "DefaultWidth": 1280,
   "DefaultHeight": 720,
   "ScreenModeFull": false,
   "EnableCredSSP": false,
   "RdpStoreFolder": null
 },
 "Servers": [
   { "category": "DEV", "component": "PSM", "name": "Host1", "target": "Host1", "targetAccount": "<AccountName>" },
   { "category": "UAT", "component": "CPM", "name": "Host2", "target": "Host2", "targetAccount": "<AccountName>" },
 ]
}
```

	•	category: Grouping for tree view.
	•	component: Friendly component/ technology server.
	•	name: HostName as displayed in GUI.
	•	target: HostName as onboarded in CyberArk.
	•	targetAccount: Remote account to use.


⸻

Security Notes

	•	Passwords are stored as DPAPI blobs (Windows encryption).
	•	.rdp files with embedded passwords are temporary and deleted automatically.
	•	Avoid running in untrusted environments.

 
