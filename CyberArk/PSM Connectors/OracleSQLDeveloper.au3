;=========================================================================================
;             SQL Developer Dispatcher
;             ------------------------
; Description : PSM Dispatcher for Oracle SQL Developer
; Vendor : Oracle
; Product : SQL Developer
; Version : 23.1.1
; Developed by: Abhishek Singh
; IMP NOTE: This connector creates 'connections.json' file using 'ConnectionsTemplate.json'
;=========================================================================================
#AutoIt3Wrapper_UseX64=n
Opt("MustDeclareVars", 1)
AutoItSetOption("WinTitleMatchMode", 1) ; Start of title is matched
#include <PSMGenericClientWrapper.au3>
#include <BlockInputEx.au3>
#include <AutoItConstants.au3>
#include <EditConstants.au3>
#include <WindowsConstants.au3>
#include <FileConstants.au3>
#include <WinAPIFiles.au3>
#include <File.au3>
;=======================================
; Consts & Globals
;=======================================
Global Const $DISPATCHER_NAME					= "Oracle SQL Developer"
Global Const $ERROR_MESSAGE_TITLE  				= "PSM " & $DISPATCHER_NAME & " Dispatcher error message"
Global Const $LOG_MESSAGE_PREFIX 				= $DISPATCHER_NAME & " Dispatcher - "
Global Const $MESSAGE_TITLE	= $DISPATCHER_NAME

Global $TargetUsername
Global $TargetPassword
Global $TargetAddress
Global $TargetPort
Global $TargetDatabase
Global $TargetRole
Global $CLIENT_EXECUTABLE ; Full path to sqldeveloper executable with NO surrounding quotes
Global $TEMPLATE_FILE ; Full path to template file with NO surrounding quotes
Global $PROGRESS_BAR ; Full path to progressbar exe with NO surrounding quotes
Global $PREFERENCES_SOURCE ; Full path to product preferences source file with NO surrounding quotes
Global $CONNECTIONS_PATH ; Full path to connections file with NO surrounding quotes
Global $PREFERENCES_TARGET ; Full path to product preferences source file with NO surrounding quotes
Global $CONNECTIONS_FILE  ; connections.json file name with NO surrounding quotes
Global $CONNECTIONS_PATH ; Full path to connections.json file with NO surrounding quotes
Global $TITLE ; Oracle SQL Developer title window
Global $WELCOME_TITLE ; Oracle SQL Developer Welcome  page title
Global $DTCACHE_SOURCE ; dtcache.xml file source path
Global $DTCACHE_TARGET ; dtcache.xml file target path
Global $Sleep = 500
Global $Longsleep = 2000
Global $hWnd
Global $ConnectionClientPID	= 0

;=======================================
; Code
;=======================================
Exit Main()

;=======================================
; Main
;=======================================
Func Main()


   if (PSMGenericClient_Init() <> $PSM_ERROR_SUCCESS) Then
   Error(PSMGenericClient_PSMGetLastErrorString())
   EndIf

   LogWrite("Successfully initialized Dispatcher Utils Wrapper")

	FetchSessionProperties() ; Get the dispatcher parameters
	ProgressBarOn()
	LogWrite("mapping local drives")

	if (PSMGenericClient_MapTSDrives() <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf

	SetupConfigurationFile() ; Substitutes variables in template file and saves as .json in roaming profile
	
	FileCopy($PREFERENCES_SOURCE, @AppDataDir & "\" & $PREFERENCES_TARGET , 1 + 8)
	LogWrite("Copying " & """" & $PREFERENCES_SOURCE & "  to  " & $PREFERENCES_TARGET)
	
	FileCopy($DTCACHE_SOURCE, @AppDataDir & "\" & $DTCACHE_TARGET , 1 + 8)
	LogWrite("Copying " & """" & $DTCACHE_SOURCE & "  to  " & $DTCACHE_TARGET)
	
	LogWrite("starting client application")
    $ConnectionClientPID = LaunchEXE()

   ; Send PID to PSM as early as possible so recording/monitoring can begin
    LogWrite("sending PID to PSM")
    if (PSMGenericClient_SendPID($ConnectionClientPID) <> $PSM_ERROR_SUCCESS) Then
	  Error(PSMGenericClient_PSMGetLastErrorString())
    EndIf
	ProgressBarOff()
   ; Terminate PSM Dispatcher utils wrapper
    LogWrite("Terminating Dispatcher Utils Wrapper")
    PSMGenericClient_Term()
	
	; =====Send Password to re-connect the disconnected session=====
	
	Sleep($Sleep)
	Local $WinTitle = "Connection Information"
	Local $WinText = ""
	Local $hMsg
    Local $loginSent = False

	While ProcessExists($ConnectionClientPID)
		$hMsg = WinWait($WinTitle, $WinText, 20)
			If (WinActivate($hMsg) And Not $loginSent) Then
				ControlSend($hMsg, "", "", $TargetPassword, 1)
				Sleep(100)
				ControlSend($hMsg,"","","{ENTER}")
				$loginSent = True
			ElseIf ($loginSent and WinActivate($hMsg)) Then
				$loginSent = False
			EndIf
	WEnd
	;=====Re-connected the database session=====
	
    Return $PSM_ERROR_SUCCESS
 EndFunc

 ;==================================
; Functions
;==================================

Func SetupConfigurationFile()   ; ==> Configures the initial login template and substiutes various object parameters used by connections.json
	
	LogWrite("Entered SetupConfigurationFile()")

	  ; Open template file from sqldeveloper directory
   Local $BaseTemplate = FileOpen($TEMPLATE_FILE, 0)
   If ($BaseTemplate == -1) Then
	  LogWrite(StringFormat("Failed to read and open Base Template File: " & $TEMPLATE_FILE, @error))
   EndIf

   ; Read template file from sqldeveloper directory
   Local $BaseText = FileRead($BaseTemplate)
   if (@error <> 0) Then
	  LogWrite(StringFormat("Failed to read file: " &$TEMPLATE_FILE, @error))
   EndIf

   ; Close template file from sqldeveloper directory
   if (FileClose($BaseTemplate) == 0) Then
	   LogWrite(StringFormat("Failed to close file: " & $TEMPLATE_FILE, @error))
	EndIf

	  $BaseText = SubstitueVariables($BaseText)

   ; open config file
   Local $sConnectionsFile = $CONNECTIONS_PATH & $CONNECTIONS_FILE
   Local $OutputFile = FileOpen(@AppDataDir & "\" & $sConnectionsFile, 2 + 8)
   If($OutputFile == -1) Then
	  LogWrite("Failed to open Output file: " & $sConnectionsFile, @error))
   EndIf

   ; write data from template to config file
   if (FileWrite($OutputFile, $BaseText) <> 1) Then
	  LogWrite(StringFormat("Failed to write data to: " & $sConnectionsFile, @error))
   EndIf

   ; close config file
   if (FileClose($OutputFile) == 0) Then
	  LogWrite(StringFormat("Failed to close file: " & $sConnectionsFile, @error))
   EndIf

EndFunc ;==> SetupConfigurationFile

Func SubstitueVariables($RawInput)

   Local $ToReturn = StringReplace($RawInput, "%USERNAME%", $TargetUsername)
   $ToReturn = StringReplace($ToReturn, "%ADDRESS%", $TargetAddress)
   $ToReturn = StringReplace($ToReturn, "%PORT%", $TargetPort)
   $ToReturn = StringReplace($ToReturn, "%DATABASE%", $TargetDatabase)
   $ToReturn = StringReplace($ToReturn, "%ROLE%", $TargetRole)
   Return $ToReturn
EndFunc

Func LaunchEXE() ;==> Launches sqldeveloper executable

	LogWrite("Launching app via CLI = " & $CLIENT_EXECUTABLE)

	Local $PID
	$PID = Run($CLIENT_EXECUTABLE, "", @SW_MAXIMIZE)
	Sleep(5000)
	If $PID == 0 Then
		Error("Error running executable: " & @error & " - " & PSMGenericClient_PSMGetLastErrorString())
	EndIf
	$PID = LoginProcess()
	ToolTip("")
	Return $PID

EndFunc   ;==>LaunchEXE

; #FUNCTION# ====================================================================================================================
; Name...........: LoginProcess
; Description ...: Checks for two pop up windows. Closing each window if found. Sends alt + F10 to open Connection Window. It will try to send ALT+F10 every 3 seconds for 20 intervals. If it does not succeed it will close the session.
; Control Sends the password raw and will overwrite if a connection is already in progress.
; Parameters ....: None
; Return values .: None
; ===============================================================================================================================
Func LoginProcess()

	LogWrite("Entered LoginProcess()")
   $hWnd = WinWaitActive("[REGEXPTITLE:(Confirm Import Preferences|" & $TITLE & ".*)]", "", 60)
  
   If WinActive("Confirm Import Preferences") Then
		LogWrite("Window Found: " & WinGetTitle($hWnd))
		LogWrite("Closing window: " & WinGetTitle($hWnd))
		Send("!n")
		Sleep($Sleep)
   EndIf

   LogWrite("Surpressed all popups, waiting for title window:  "& $TITLE)

   $hWnd = WinWaitActive($TITLE)
   LogWrite("Window has been activated, sending Alt+F10 to open connection")
   sleep($Longsleep)

   Local $tmphWnd
   For $i = 1 To 20
	  $tmphWnd = WinWaitActive("Select Connection","",3)
	  If($tmphWnd == 0) Then
		 LogWrite("Select Connection window not displayed after 3 seconds, resending Alt+F10")
		 ControlSend($hWnd,"","","!{F10}")
	  Else
		 LogWrite("Select Connection window found, sending Enter")
		 ExitLoop
	  EndIf
   Next
   If($tmphWnd == 0) Then
	  Error("Unable to open newly created connection. Select Connection window not appearing after sending Alt+F10")
   Else
	  $hWnd = $tmphWnd
   EndIf

   sleep($Sleep)
   ControlSend($hWnd,"","","{ENTER}")
   $hWnd = WinWaitActive("Connection Information", "", 30)
   Sleep($Sleep)
   ClipPut($TargetPassword)
   sleep($Longsleep)
   ControlSend("Connection Information", "", "", "^v")
   Sleep($Sleep)
   ClipPut(" ")
   ControlSend($hWnd,"","","{ENTER}")
   Sleep($Sleep)
   If WinActive("Connection Name in use") Then
	  ControlSend("Connection Name in use","","","!y")
   EndIf

   ToolTip("Checking if Login Information popup is displayed...")
   Sleep($Sleep)
	Local $WinTitle, $WinText, $hMsg
	$WinTitle = "Login Messages"
	$WinText = ""
	$hMsg = WinWait($WinTitle, $WinText, 5)
	
	If WinActivate($hMsg) Then
		LogWrite("Login Messages window found, sending Enter")
		ControlSend($hMsg,"","","{ENTER}")
		LogWrite("Waiting for title window to become active")
		WinWaitActive($TITLE, "", 10)
	Else
		LogWrite("Waiting for title window to become active")
		WinWaitActive($TITLE, "", 10)
	EndIf
	
   Local $FinalWindow = WinWaitActive($TITLE, "", 10)
   LogWrite("Activating title window")
   WinActivate($FinalWindow)
   Return WinGetProcess($FinalWindow)

EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: Error
; Description ...: An exception handler - displays an error message and terminates the dispatcher
; Parameters ....: $ErrorMessage - Error message to display
; 				   $Code 		 - [Optional] Exit error code
; ===============================================================================================================================
Func Error($ErrorMessage, $Code = -1)

	; If the dispatcher utils DLL was already initialized, write an error log message and terminate the wrapper
	if (PSMGenericClient_IsInitialized()) Then
		LogWrite($ErrorMessage, True)
		PSMGenericClient_Term()
	EndIf

	Local $MessageFlags = BitOr(0, 16, 262144) ; 0=OK button, 16=Stop-sign icon, 262144=MsgBox has top-most attribute set

	MsgBox($MessageFlags, $ERROR_MESSAGE_TITLE, $ErrorMessage)

	; If the connection component was already invoked, terminate it
	if ($ConnectionClientPID <> 0) Then
		ProcessClose($ConnectionClientPID)
		$ConnectionClientPID = 0
	EndIf

	Exit $Code
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: LogWrite
; Description ...: Write a PSMWinSCPDispatcher log message to standard PSM log file
; Parameters ....: $sMessage - [IN] The message to write
;                  $LogLevel - [Optional] [IN] Defined if the message should be handled as an error message or as a trace messge
; Return values .: $PSM_ERROR_SUCCESS - Success, otherwise error - Use PSMGenericClient_PSMGetLastErrorString for details.
; ===============================================================================================================================
Func LogWrite($sMessage, $LogLevel = $LOG_LEVEL_TRACE)
	Return PSMGenericClient_LogWrite($LOG_MESSAGE_PREFIX & $sMessage, $LogLevel)
 EndFunc


; #FUNCTION# ====================================================================================================================
; Name...........: PSMGenericClient_GetSessionProperty
; Description ...: Fetches properties required for the session
; Parameters ....: None
; Return values .: None
; ===============================================================================================================================
Func FetchSessionProperties()

	  if (PSMGenericClient_GetSessionProperty("Username", $TargetUsername) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	  EndIf
	  if (PSMGenericClient_GetSessionProperty("Password", $TargetPassword) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	  EndIf
	  if (PSMGenericClient_GetSessionProperty("Address", $TargetAddress) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	  EndIf
	  if (PSMGenericClient_GetSessionProperty("Port", $TargetPort) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	  EndIf
	  if (PSMGenericClient_GetSessionProperty("Database", $TargetDatabase) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	  EndIf
	  if (PSMGenericClient_GetSessionProperty("ConnectAs", $TargetRole) <> $PSM_ERROR_SUCCESS) Then
		LogWrite("Account property Role not assigned")
	  EndIf
	  If (PSMGenericClient_GetSessionProperty("CLIENT_EXECUTABLE", $CLIENT_EXECUTABLE) <> $PSM_ERROR_SUCCESS) Then
		Error("Error getting EXE path " & PSMGenericClient_PSMGetLastErrorString())
	  EndIf
	  If (PSMGenericClient_GetSessionProperty("TEMPLATE_FILE", $TEMPLATE_FILE) <> $PSM_ERROR_SUCCESS) Then
		Error("Error opening template file " & PSMGenericClient_PSMGetLastErrorString())
	  EndIf
	  If (PSMGenericClient_GetSessionProperty("PROGRESS_BAR", $PROGRESS_BAR) <> $PSM_ERROR_SUCCESS) Then
		Error("Error opening template file " & PSMGenericClient_PSMGetLastErrorString())
	  EndIf
	  If (PSMGenericClient_GetSessionProperty("PREFERENCES_SOURCE", $PREFERENCES_SOURCE) <> $PSM_ERROR_SUCCESS) Then
		Error("Error getting source file location " & PSMGenericClient_PSMGetLastErrorString())
	  EndIf
	  If (PSMGenericClient_GetSessionProperty("PREFERENCES_TARGET", $PREFERENCES_TARGET) <> $PSM_ERROR_SUCCESS) Then
		Error("Error getitng target file location " & PSMGenericClient_PSMGetLastErrorString())
	  EndIf
	  If (PSMGenericClient_GetSessionProperty("TITLE", $TITLE) <> $PSM_ERROR_SUCCESS) Then
		Error("Error getting title " & PSMGenericClient_PSMGetLastErrorString())
	  EndIf
	  If (PSMGenericClient_GetSessionProperty("WELCOME_TITLE", $WELCOME_TITLE) <> $PSM_ERROR_SUCCESS) Then
		Error("Error getting welcome title " & PSMGenericClient_PSMGetLastErrorString())
	  EndIf
	  If (PSMGenericClient_GetSessionProperty("CONNECTIONS_FILE", $CONNECTIONS_FILE) <> $PSM_ERROR_SUCCESS) Then
		Error("Error getting connections file name " & PSMGenericClient_PSMGetLastErrorString())
	  EndIf
	  If (PSMGenericClient_GetSessionProperty("CONNECTIONS_PATH", $CONNECTIONS_PATH) <> $PSM_ERROR_SUCCESS) Then
		Error("Error getting connections file path " & PSMGenericClient_PSMGetLastErrorString())
	  EndIf
	  If (PSMGenericClient_GetSessionProperty("DTCACHE_SOURCE", $DTCACHE_SOURCE) <> $PSM_ERROR_SUCCESS) Then
		Error("Error getting dtcache.xml file path " & PSMGenericClient_PSMGetLastErrorString())
	  EndIf
	  If (PSMGenericClient_GetSessionProperty("DTCACHE_TARGET", $DTCACHE_TARGET) <> $PSM_ERROR_SUCCESS) Then
		Error("Error getting dtcache.xml file path " & PSMGenericClient_PSMGetLastErrorString())
	  EndIf
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: ProgressBarOn
; Description ...: Opens CyberArk Progress Bar
; Return values .: none
; ===============================================================================================================================
Func ProgressBarOn()
			LogWrite("Launching progress bar: " & $PROGRESS_BAR)
			Global $iPID = Run($PROGRESS_BAR)
				$iPID = ProcessWait("CyberArk.ProgressBar.exe")
			Return $iPID
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: ProgressBarOff
; Description ...: Closes CyberArk Progress Bar process
; Return values .: none
; ===============================================================================================================================
Func ProgressBarOff()
		LogWrite("Closing progress bar: " & $PROGRESS_BAR)
        ProcessClose($iPID)
EndFunc
