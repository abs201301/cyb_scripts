# Sync-ADPPA
PowerShell automation to synchronize Active Directory (AD) Privileged Access (PPA) accounts with CyberArk, backed by an SQL database and ServiceNow integration for incident tracking.
This script is designed to keep CyberArk safes and accounts aligned with AD and organizational policies while ensuring failures are logged, emailed, and tracked in ServiceNow.

The script uses following Powershell modules obtained from Powershell Gallery. 

[SqlServer 22.2.0](https://www.powershellgallery.com/packages/SqlServer/22.2.0)

[psPAS 5.2.54](https://www.powershellgallery.com/packages/psPAS/5.2.54)

[dbatools 2.0.4](https://www.powershellgallery.com/packages/dbatools/2.0.4) (Optional)


## 📋 Features
- AD to CyberArk Sync
- Identifies eligible AD personal privileged accounts (SA, WA, NA, AA, RA) in defined OUs.
- Creates missing safes and accounts in CyberArk.
- Removes decommissioned/disabled accounts from CyberArk.
- SQL Integration
- Imports AD and CyberArk EVD data into SQL tables (CAFiles, CASafes, ADPPA) for reporting and reconciliation.
- Falls back to CSV (EVD exports) if SQL is unavailable.
- CyberArk API Integration
- Creates safes with appropriate members and permissions.
- Adds and reconciles accounts using psPAS.
- Removes obsolete accounts and API users.
- ServiceNow Integration
- Uses OAuth Client ID/Secret (retrieved from CyberArk CP).
- Automatically creates incidents for script failures with detailed exception information.
- Notifications
- Logs all actions to Sync-ADPPA.log.
- Sends email alerts for errors with ServiceNow ticket references.

## ⚙️ Prerequisites
1. Powershell 5.1+
2. Quest ARS Powershell module
3. SQL Server accessible instance with required tables and stored procedures (usp_GetSafesToCreate, usp_GetAccountsToAdd, usp_GetAccountsToRemove)
4. SQL Server Management Studio 20.1 (For UI experience)
5. psPAS Powershell module (To invoke CyberArk REST API commands)
6. SqlServer Powershell module (To invoke sqlcmd powershell cmdlets)
7. DBATools Powershell module (A powerful alternative to SqlServer module)
8. Remote Server Administration tools (To invoke Active Directory powershell cmdlets)
9. CyberArk EVD (To export Vault data and import into various MSSQL tables)
10. Sqlcmd tools (A mandatory program to get SqlServer module to work)
11. Out-DataTable.ps1 wrapper (To write the output of Get-ADUser cmdlet in sql table)
12. Client ID and Secret stored in CyberArk.
13. Caller/Opened_by sys_id available.

## 🔑 Configuration
Update variables in the script before use
## 🚀 Execution
Run the script on the automation server: .\SyncADPPA.ps1

- Logs are written to: .\Sync-ADPPA.log
- Successful runs end with Synchronization finished.
- Failures:
-- Logged in the log file.
-- Email alert sent to PAM team.
-- ServiceNow ticket created.

## 🧩 Script Flow
1. Initialization
  - Connects to CyberArk (API session).
  - Connects to Quest ARS.
  - Retrieves credentials from CyberArk CP.
2. Data Load
  - Truncates SQL tables and imports fresh AD/EVD data.
  - Falls back to CSV export if SQL unavailable.
3. Reconciliation
  - Creates missing safes.
  - Adds missing accounts to CyberArk.
  - Removes obsolete/disabled accounts.
  - Removes API user from safes if required.
4. Error Handling
  - Exceptions logged with full stack trace.
  - ServiceNow ticket raised.
  - Email alert sent to PAM team.
5. Cleanup
  - Closes API sessions and disconnects ARS.
  - Writes completion entry to log.

## 📌 Notes
- Regex Rules
  - AD accounts: ^(?i)(sa|aa|na|ra|wa)\d{8}$
  - Safes: ^A\d{8}-Admins$
  - CyberArk accounts: ^acme-[ANRSW]A\d{8}$
- ServiceNow Fields
  - caller_id and opened_by must be valid sys_ids.
  - cmdb_ci must map to a CI in ServiceNow.
- Security
  - No credentials are hardcoded — all secrets are retrieved dynamically from CyberArk CP.

## 🛠️ Troubleshooting
- SQL Connection Failure
  - Falls back to CSV mode, check EVD exports.
- ServiceNow Ticket Not Created
  - Verify OAuth client in CyberArk CP.
  - Check $sys_id values.
- CyberArk API Errors
  - Ensure psPAS module is installed and PVWA accessible.
  - Confirm API user permissions.

