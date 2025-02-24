#AutoIt3Wrapper_UseX64=n
Opt("MustDeclareVars", 1)
AutoItSetOption("WinTitleMatchMode", 3)

;============================================================
;           Generic Web Portal
;           -------------------
; Description : PSM Dispatcher for Websites
; Created : Aug 30, 2024
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
Global $TargetUsername   ;Will be fetched from the PSM Session
Global $TargetPassword   ;Will be fetched from the PSM Session
Global $TargetAddress    ;Will be fetched from the PSM Session
Global $TargetDomain	;Will be fetched from the PSM Session
Global $RemoteMachine ;Will be fetched from the PSM Session
Global $DriverPath ; Will be fetched from the PSM Session
Global $BrowserPath ; Will be fetched from the PSM Session
Global $AppName  ; Will be fetched from the PSM Session
Global $ConnectionClientPID = 0
Global $sDesiredCapabilities
Global $sSession
Global $Sleep = 500
Global $usernameXPath
Global $passwordXPath
Global $submitButtonXPath

;=======================================
; Code
;=======================================
Exit Main()

Func FetchSessionProperties() ;----------> Retrieves properties required for the session from the PSM

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
	
	if (PSMGenericClient_GetSessionProperty("AppName", $AppName) <> $PSM_ERROR_SUCCESS) Then
		LogWrite("Application Name is not defined")
	EndIf
	
EndFunc

;*=*=*=*=*=*=*=*=*=*=*=*=*=
; Main script starts here
;*=*=*=*=*=*=*=*=*=*=*=*=*=

;=======================================
; Main
;=======================================
Func Main()

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
	Global $DISPATCHER_NAME 			= $AppName
	Global $MESSAGE_TITLE				= "PSM-" & $AppName & "-WebApp"
	$ERROR_MESSAGE_TITLE  	= "PSM " & $DISPATCHER_NAME & " Dispatcher error message"
	$LOG_MESSAGE_PREFIX 		= $DISPATCHER_NAME & " Dispatcher - "
	
	MessageUserOn($MESSAGE_TITLE, "Starting " & $DISPATCHER_NAME & "...")
	LogWrite("Starting client application")
	
	$sSession = SetupEdge()
	LogWrite("Finished loading msedge")
	
	BlockAllInput()

	$ConnectionClientPID = WinGetProcess("[CLASS:Chrome_WidgetWin_1]")

	if ($ConnectionClientPID == 0) Then
		Error(StringFormat("Failed to execute process [%s]", $ConnectionClientPID, @error))
	EndIf
	
	LogWrite("Entered LoginProcess()")
	If $AppName = "Azure" Then
		Local $iPID = AzureLogin()
	Else
		Local $iPID = DefaultLogin()
	EndIf
	
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
	
	MessageUserOff()
	LogWrite("Terminating Dispatcher Utils Wrapper")
	PSMGenericClient_Term()

	Return $PSM_ERROR_SUCCESS
EndFunc

;==================================
; Functions
;==================================

Func Error($ErrorMessage, $Code = -1) ;----------> An exception handler - displays an error message and terminates the dispatcher


   If (PSMGenericClient_IsInitialized()) Then
		LogWrite($ErrorMessage, $LOG_LEVEL_ERROR)
		PSMGenericClient_Term()
   EndIf

   ProgressBarOn("ERROR - PROCESS IS SHUTTING DOWN", $ErrorMessage)
	sleep($g_ErrorMessageTime)

	If ($ConnectionClientPID <> 0) Then
		ProcessClose($ConnectionClientPID)
		$ConnectionClientPID = 0
	EndIf
	Exit $Code

EndFunc

Func LogWrite($sMessage, $LogLevel = $LOG_LEVEL_TRACE) ;---------> Write the dispatcher log message to standard PSM log file
	Return PSMGenericClient_LogWrite($LOG_MESSAGE_PREFIX & $sMessage, $LogLevel)
EndFunc

Func AssertErrorLevel($error_code, $message, $code = -1) ;--------------> Checks If error level is <> 0. If so, write to log and call error.

	If ($error_code <> 0) Then
		LogWrite(StringFormat("AssertErrorLevel - %s :: @error = %d", $message, $error_code), $LOG_LEVEL_ERROR)
		Error($message, $code)
	EndIf
EndFunc

Func MessageUserOn(Const ByRef $msgTitle, Const ByRef $msgBody) ;---------> Writes a message to the user, and keeps it indefinitely (until function call to MessageUserOff)
	SplashOff()
    SplashTextOn ($msgTitle, $msgBody, -1, 54, -1, -1, 0, "Tahoma", 9, -1)
EndFunc

Func MessageUserOff() ;-----------> TurnsOff splash message
    SplashOff()
EndFunc

Func BlockAllInput() ;----------> Blocks all input (mouse & keyboard). Use when login process runs and visible, so user can't
    LogWrite("Blocking Input")

	If IsDeclared("s_KeyboardKeys_Buffer") <> 0 Then
		_BlockInputEx(1)
		AssertErrorLevel(@error, StringFormat("Could not block all input. Aborting... @error: %d", @error))
	Else
		BlockInput(1)
		AssertErrorLevel(@error, StringFormat("Could not block all input. Aborting... @error: %d", @error))
	EndIf

EndFunc

Func UnblockAllBlockProhibited() ;-----------> Allows all input from the user, except for prohibited keys (such as F11).
	If IsDeclared("s_KeyboardKeys_Buffer") <> 0 Then
		_BlockInputEx(0)
		_BlockInputEx(3, "", "{F11}|{Ctrl}")
	Else
		BlockInput(0)
	EndIf
EndFunc


Func SetupEdge() ;-----------> Prepares Webdriver capabilities and creates browser session
		
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
	
	If $AppName = "Azure" Then
		$sURL = "https://myapps.microsoft.com"
	Else
		$sURL = "https://" & $TargetAddress
	EndIf
	
	LogWrite("Launching URL:" & $sURL)
	$sDesiredCapabilities = '{"capabilities": {"alwaysMatch": {"ms:edgeOptions": {"args": [ "start-maximized" , "InPrivate", "--app=' & $sURL & '"], "binary": "' & StringReplace (@ProgramFilesDir, "\", "/") & '/Microsoft/Edge/Application/msedge.exe", "excludeSwitches": [ "enable-automation"]}}}}'
	
	_WD_Startup()
	$sSession = _WD_CreateSession($sDesiredCapabilities)
	Return $sSession
	
 EndFunc
 
 Func AzureLogin()
 
    _WD_LoadWait($sSession)
    LogWrite("Finding elements")

	$usernameXPath = "//*[@id='i0116' or @type='email']"
	$passwordXPath = "//*[@id='i0118' or @type='password']"
	$submitButtonXPath = "//*[@id='idSIButton9' or @type='submit']"
	
	Sleep($Sleep)
	For $i = 1 to 20
		LogWrite("Finding username field. Attempt: " & $i)
		Sleep(250)
		Local $oUsername  = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, $usernameXPath)
		If $oUsername <> "" Then
			LogWrite("Username field found entering username ")
			_WD_ElementAction($sSession, $oUsername, 'value', $TargetUsername & "@<Domain>")
			ExitLoop
		EndIf
	Next
	
	For $i = 1 to 20
		LogWrite("Finding next button. Attempt: " & $i)
		Sleep(250)
		Local $oSubmit   = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, $submitButtonXPath)
		If $oSubmit <> "" Then
			LogWrite("Found submit button clicked submit.")
			_WD_ElementAction($sSession, $oSubmit, 'click')
			ExitLoop
		EndIf
	Next
	
	Sleep($Sleep)
	For $i = 1 to 20
		LogWrite("Finding password field. Attempt: " & $i)
		Sleep(250)
		Local $oPassword  = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, $passwordXPath)
		If $oPassword <> "" Then
			LogWrite("Password field found sending password.")
			_WD_ElementAction($sSession, $oPassword, 'value', $TargetPassword)
			ExitLoop
		EndIf
	Next
	Sleep($Sleep)
	For $i = 1 to 20
		LogWrite("Finding submit button. Attempt: " & $i)
		Sleep(250)
		Local $oSubmit   = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, $submitButtonXPath)
		If $oSubmit <> "" Then
			LogWrite("Found submit button clicked submit.")
			_WD_ElementAction($sSession, $oSubmit, 'click')
			ExitLoop
		EndIf
	Next
	Sleep($Sleep)
	For $i = 1 to 20
		LogWrite("Finding submit button. Attempt: " & $i)
		Sleep(250)
		Local $oSubmit   = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, $submitButtonXPath)
		If $oSubmit <> "" Then
			LogWrite("Found submit button clicked submit.")
			_WD_ElementAction($sSession, $oSubmit, 'click')
			ExitLoop
		EndIf
	Next
	
	Sleep($Sleep)
	LogWrite("Waiting for final landing page")
	_WD_Shutdown()
	UnblockAllBlockProhibited()
	Return $sSession
EndFunc

Func DefaultLogin()
	
    _WD_LoadWait($sSession)
    LogWrite("Finding elements")
	
	$usernameXPath = "//input[@id='j_username' or @name='j_username' or @id='username' or contains(@placeholder, 'Username') or contains(@name, 'user')]"
	$passwordXPath = "//input[@id='j_password' or @name='j_password' or @id='password' or contains(@placeholder, 'Password') or contains(@name, 'pass')]"
	$submitButtonXPath = "//*[@id='login-submission-button' or @type='submit']"
	
	Sleep($Sleep)
	For $i = 1 to 20
		LogWrite("Finding username field. Attempt: " & $i)
		Sleep(250)
		Local $oUsername  = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, $usernameXPath)
		If $oUsername <> "" Then
			LogWrite("Username field found entering username ")
			_WD_ElementAction($sSession, $oUsername, 'value', $TargetUsername)
			ExitLoop
		EndIf
	Next
	
	Sleep($Sleep)
	For $i = 1 to 20
		LogWrite("Finding password field. Attempt: " & $i)
		Sleep(250)
		Local $oPassword  = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, $passwordXPath)
		If $oPassword <> "" Then
			LogWrite("Password field found sending password.")
			_WD_ElementAction($sSession, $oPassword, 'value', $TargetPassword)
			ExitLoop
		EndIf
	Next
	
	Sleep($Sleep)
	For $i = 1 to 20
		LogWrite("Finding submit button. Attempt: " & $i)
		Sleep(250)
		Local $oSubmit   = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, $submitButtonXPath)
		If $oSubmit <> "" Then
			LogWrite("Found submit button clicked submit.")
			_WD_ElementAction($sSession, $oSubmit, 'click')
			ExitLoop
		EndIf
	Next
	
	Sleep($Sleep)
	LogWrite("Waiting for final landing page")
	_WD_Shutdown()
	UnblockAllBlockProhibited()
	Return $sSession

EndFunc
