## PSMPSWebApp.au3 ##
A generic all-purpose AutoIT script that retrieves connection parameters using PSM fetch session API and passes the arguments to subsequent application specific Powershell script

The script handles login under local as well as domain based accounts. For address, script uses values passed in 'Address' as well as 'PSMRemoteMachine' parameters. Where the LogonDomain is specified, script will launch the session using 'RunAs' capability else 'Run'. Since, the password is sent as argument for consumption by Powershell script, base64 encoding is used to send the encoded password to Powershell which is then decoded by Powershell script at runtime.

Important paramaters that must be defined against PSM connection component

Global $DISPATCHER_NAME ;Will be fetched from the PSM Session
Global $PS_EXE ;Will be fetched from the PSM Session
Global $Script_Path ;Will be fetched from the PSM Session
Global $Script_Name ;Will be fetched from the PSM Session
Global $TargetUsername ;Will be fetched from the PSM Session
Global $TargetPassword ;Will be fetched from the PSM Session
Global $TargetAddress ;Will be fetched from the PSM Session
Global $TargetDomain ;Will be fetched from the PSM Session
Global $RemoteMachine ;Will be fetched from the PSM Session
Global $DriverPath ; Will be fetched from the PSM Session
Global $BrowserPath ; Will be fetched from the PSM Session

** PSM<"AppName">WebApp.ps1 **
This is meant to be application specific Powershell script. The intention of creating Powershell script is to handle web login for various websites in a particular technology stack
