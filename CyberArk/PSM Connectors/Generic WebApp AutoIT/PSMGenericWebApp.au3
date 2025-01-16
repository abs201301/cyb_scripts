
#AutoIt3Wrapper_UseX64=n
Opt("MustDeclareVars", 1)
AutoItSetOption("WinTitleMatchMode", 3) ; EXACT_MATCH!

;============================================================
;           Generic Web Apps
;           ----------------
; Description : PSM Dispatcher for Websites
; Abhishek Singh
; Developed and compiled in AutoIt 3.3.14.1
;============================================================
; Uses AutoIT Web driver UDF
;============================================================

#include "PSMGenericClientWrapper.au3"
#include <GUIConstantsEx.au3>
#include <wd_Core.au3>
#include <wd_helper.au3>
#include <wd_cdp.au3>
#include <wd_capabilities.au3>
#include <Json.au3>
#include <BinaryCall.au3>
#include <WinHttp.au3>
#include <WinHttpConstants.au3>

;================================
; Consts & Globals
;================================

Global $ERROR_MESSAGE_TITLE 
Global $LOG_MESSAGE_PREFIX 
Global $DISPATCHER_NAME  ;Will be fetched from the PSM Session
Global $TargetUsername   ;Will be fetched from the PSM Session
Global $TargetPassword   ;Will be fetched from the PSM Session
Global $TargetAddress    ;Will be fetched from the PSM Session
Global $TargetDomain	;Will be fetched from the PSM Session
Global $RemoteMachine ;Will be fetched from the PSM Session
Global $DriverPath ; Will be fetched from the PSM Session
Global $BrowserPath ; Will be fetched from the PSM Session
Global $ProxyAddress ; Will be fetched from the PSM Session
Global $ProxyBypassList ; Will be fetched from the PSM Session
Global $ConnectionClientPID = 0
Global $sDesiredCapabilities
Global $sSession
Global $usernameXPath = "//*[@id='username' or @name='j_username']"
Global $passwordXPath = "//*[@id='password' or @name='j_password']"
Global $submitButtonXPath = "//button[@type='submit' or @type='button']"

;=======================================
; Code
;=======================================
Exit Main()

; #FUNCTION# ====================================================================================================================
; Name...........: FetchSessionProperties
; Description ...: Fetches properties required for the session from the PSM
; Parameters ....: None
; Return values .: None
; ===============================================================================================================================
Func FetchSessionProperties()

	If (PSMGenericClient_GetSessionProperty("Username", $TargetUsername) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf

	If (PSMGenericClient_GetSessionProperty("Password", $TargetPassword) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
	if (PSMGenericClient_GetSessionProperty("Address", $TargetAddress) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
	if (PSMGenericClient_GetSessionProperty("PSMRemoteMachine", $RemoteMachine) <> $PSM_ERROR_SUCCESS) Then
		LogWrite("PSMRemoteMachine is not defined")
	EndIf
	
	if (PSMGenericClient_GetSessionProperty("LogonDomain", $TargetDomain) <> $PSM_ERROR_SUCCESS) Then
		LogWrite("LogonDomain parameter is missing")
	EndIf
	
	if (PSMGenericClient_GetSessionProperty("DriverPath", $DriverPath) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
	if (PSMGenericClient_GetSessionProperty("BrowserPath", $BrowserPath) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
	if (PSMGenericClient_GetSessionProperty("DISPATCHER_NAME", $DISPATCHER_NAME) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
	if (PSMGenericClient_GetSessionProperty("ProxyAddress", $ProxyAddress) <> $PSM_ERROR_SUCCESS) Then
		LogWrite("ProxyAddress is not defined")
	EndIf
	
	if (PSMGenericClient_GetSessionProperty("ProxyBypassList", $ProxyBypassList) <> $PSM_ERROR_SUCCESS) Then
		LogWrite("ProxyBypassList is not defined")
	EndIf
	
EndFunc

;*=*=*=*=*=*=*=*=*=*=*=*=*=
; Main script starts here
;*=*=*=*=*=*=*=*=*=*=*=*=*=

;=======================================
; Main
;=======================================
Func Main()
	; Init PSM Dispatcher utils wrapper

	If (PSMGenericClient_Init() <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf

	LogWrite("Successfully initialized Dispatcher Utils Wrapper")
	LogWrite("Mapping local drives")

	If (PSMGenericClient_MapTSDrives() <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf

	; Get the dispatcher parameters
	FetchSessionProperties()
	$ERROR_MESSAGE_TITLE  	= "PSM " & $DISPATCHER_NAME & " Dispatcher error message"
	$LOG_MESSAGE_PREFIX 		= $DISPATCHER_NAME & " Dispatcher - "
	
	MessageUserOn("PSM-" & $DISPATCHER_NAME, "Starting " & $DISPATCHER_NAME & "...")
	LogWrite("Starting client application")
	
	$sSession = SetupEdge()
	_WD_LoadWait($sSession)
	LogWrite("Finished loading msedge")
	
	$ConnectionClientPID = WinGetProcess("[CLASS:Chrome_WidgetWin_1]")
	LogWrite($ConnectionClientPID)
	if ($ConnectionClientPID == 0) Then
		Error(StringFormat("Failed to execute process [%s]", $ConnectionClientPID, @error))
	EndIf

	LogWrite("Entered LoginProcess()")
    _WD_LoadWait($sSession)

   BlockAllInput()
   MessageUserOff()
   ; References to HTML elements in the login process
    Local $i, $j, $k
    For $i = 1 to 10
		LogWrite("Finding username field. Attempt: " & $i)
		Local $oUserName  = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, $usernameXPath)
		If $oUserName <> "" Then
			LogWrite("Username field found sending username ")
			_WD_ElementAction($sSession, $oUserName, 'value', $TargetUsername)
			ExitLoop
		EndIf
	Next
	
	For $j = 1 to 10
		LogWrite("Finding password field. Attempt: " & $j)
		Local $oPassword  = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, $passwordXPath)
		If $oPassword <> "" Then
			LogWrite("Password field found sending password.")
			_WD_ElementAction($sSession, $oPassword, 'value', $TargetPassword)
			ExitLoop
		EndIf
	Next
	
	For $k = 1 to 10
		LogWrite("Finding submit button. Attempt: " & $k)
		Local $SignIn   = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, $submitButtonXPath)
		If $SignIn <> "" Then
			LogWrite("Found submit button clicked submit.")
			_WD_ElementAction($sSession, $SignIn, 'click')
			ExitLoop
		EndIf
	Next
	
	_WD_Shutdown()
	UnblockAllBlockProhibited()
	Local $WinTitle = "[CLASS:Chrome_WidgetWin_1]"
	Local $WinText = ""
	Local $FinalWindow = WinWait($WinTitle, $WinText, 20)
	
	 If $FinalWindow <> 0 Then
		WinActivate($FinalWindow)
		WinSetState($FinalWindow, "", @SW_SHOW)
	EndIf
	LogWrite("Finished LoginProcess() successfully")
	LogWrite("sending PID to PSM")
	
	If (PSMGenericClient_SendPID($ConnectionClientPID) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
    EndIf

	
	LogWrite("Terminating Dispatcher Utils Wrapper")
	PSMGenericClient_Term()

	Return $PSM_ERROR_SUCCESS
EndFunc

;==================================
; Functions
;==================================

; #FUNCTION# ====================================================================================================================
; Name...........: Error
; Description ...: An exception handler - displays an error message and terminates the dispatcher
; Parameters ....: $ErrorMessage - Error message to display
; 				   $Code 		 - [Optional] Exit error code
; ===============================================================================================================================
Func Error($ErrorMessage, $Code = -1)

   ; If the dispatcher utils DLL was already initialized, write an error log message and terminate the wrapper
   If (PSMGenericClient_IsInitialized()) Then
		LogWrite($ErrorMessage, $LOG_LEVEL_ERROR)
		PSMGenericClient_Term()
   EndIf

   ProgressBarOn("ERROR - PROCESS IS SHUTTING DOWN", $ErrorMessage)
	sleep($g_ErrorMessageTime)
	; If the connection component was already invoked, terminate it
	If ($ConnectionClientPID <> 0) Then
		ProcessClose($ConnectionClientPID)
		$ConnectionClientPID = 0
	EndIf
	Exit $Code

EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: LogWrite
; Description ...: Write a PSMWinSCPDispatcher log message to standard PSM log file
; Parameters ....: $sMessage - [IN] The message to write
;                  $LogLevel - [Optional] [IN] Defined If the message should be handled as an error message or as a trace messge
; Return values .: $PSM_ERROR_SUCCESS - Success, otherwise error - Use PSMGenericClient_PSMGetLastErrorString for details.
; ===============================================================================================================================
Func LogWrite($sMessage, $LogLevel = $LOG_LEVEL_TRACE)
	Return PSMGenericClient_LogWrite($LOG_MESSAGE_PREFIX & $sMessage, $LogLevel)
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: AssertErrorLevel
; Description ...: Checks If error level is <> 0. If so, write to log and call error.
; Parameters ....: $error_code - the error code from last function call (@error)
;                  $message - Message to show to user as well as write to log
;				   $code - exit code (default -1)
; Return values .: None
; ===============================================================================================================================
Func AssertErrorLevel($error_code, $message, $code = -1)
   ;Unblock input so user can exit
	If ($error_code <> 0) Then
		LogWrite(StringFormat("AssertErrorLevel - %s :: @error = %d", $message, $error_code), $LOG_LEVEL_ERROR)
		Error($message, $code)
	EndIf
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: MessageUserOn
; Description ...: Writes a message to the user, and keeps it indefinitely (until function call to MessageUserOff)
; ===============================================================================================================================
Func MessageUserOn(Const ByRef $msgTitle, Const ByRef $msgBody)
	SplashOff()
    SplashTextOn ($msgTitle, $msgBody, -1, 54, -1, -1, 0, "Tahoma", 9, -1)
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: MessageUserOff
; Description ...: See SplashOff()
; ===============================================================================================================================
Func MessageUserOff()
    SplashOff()
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: BlockAllInput
; Description ...: Blocks all input (mouse & keyboard). Use when login process runs and visible, so user can't
;                  manipulate the process
; Parameters ....:
; Return values .: none
; ===============================================================================================================================
Func BlockAllInput()
    LogWrite("Blocking Input")
	;Block all input - mouse and keyboard
	If IsDeclared("s_KeyboardKeys_Buffer") <> 0 Then
		_BlockInputEx(1)
		AssertErrorLevel(@error, StringFormat("Could not block all input. Aborting... @error: %d", @error))
	Else
		BlockInput(1)
		AssertErrorLevel(@error, StringFormat("Could not block all input. Aborting... @error: %d", @error))
	EndIf

EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: UnblockAllBlockProhibited
; Description ...: Allows all input from the user, except for prohibited keys (such as F11).
; Parameters ....:
;
; Return values .: none
; ===============================================================================================================================
Func UnblockAllBlockProhibited()
	If IsDeclared("s_KeyboardKeys_Buffer") <> 0 Then
		_BlockInputEx(0)
		_BlockInputEx(3, "", "{F11}|{Ctrl}") ;Ctrl - also +C? +V?...
	Else
		BlockInput(0)
	EndIf
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: SetupEdge
; Description ...: Prepares Webdriver capabilities
; Parameters ....: None
; Return values .: $sDesiredCapabilities
; ===============================================================================================================================
Func SetupEdge()
		
	_WD_Option('Driver', 'msedgedriver.exe')
  _WD_Option('Port', 9515)
	Local $sParams = '--port=9515 --debug --log-path="' & @UserProfileDir & '\msedge.log"'
  Local $sCommand = StringFormat('"%s", %s', $DriverPath, $sParams)
	If $TargetDomain <> "" Then
		LogWrite("Launching Edge Webdriver using RunAs capability")
		RunAs($TargetUsername, $TargetDomain, $TargetPassword, 2, $sCommand, "", @SW_HIDE)
	Else
		LogWrite("Launching Edge Webdriver")
		Run($sCommand, "", @SW_HIDE)
	EndIf
	_WD_Option('driverdetect', true)
	
	Local $sURL
	If $RemoteMachine <> "" Then
		LogWrite("Using RemoteMachine as address")
		$TargetAddress = $RemoteMachine
	Else
		LogWrite("Using TargetAddress as address")
	EndIf
	
	$sURL = "https://" & $TargetAddress
	
	If $ProxyAddress <> "" Then
		$sDesiredCapabilities = '{"capabilities": {"alwaysMatch": {"ms:edgeOptions": {"args": [ "start-maximized" , "--proxy-server=http://' & $ProxyAddress & '" , "--proxy-bypass-list=' & $ProxyBypassList & '" , "--app=' & $sURL & '"], "binary": "' & StringReplace (@ProgramFilesDir, "\", "/") & '/Microsoft/Edge/Application/msedge.exe", "excludeSwitches": [ "enable-automation"]}}}}'
	Else
		$sDesiredCapabilities = '{"capabilities": {"alwaysMatch": {"ms:edgeOptions": {"args": [ "start-maximized" , "--app=' & $sURL & '"], "binary": "' & StringReplace (@ProgramFilesDir, "\", "/") & '/Microsoft/Edge/Application/msedge.exe", "excludeSwitches": [ "enable-automation"]}}}}'
	EndIf
	_WD_Startup()
	$sSession = _WD_CreateSession($sDesiredCapabilities)
	Return $sSession
	
 EndFunc
