#AutoIt3Wrapper_UseX64=n
Opt("MustDeclareVars", 1)
AutoItSetOption("WinTitleMatchMode", 3)

;============================================================
;           Azure MyApps Portal
;           --------------------
; Description : PSM Dispatcher for Websites
; Created :Feb 19, 2025
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

Global Const $DISPATCHER_NAME 			= "Azure MyApps"
Global Const $MESSAGE_TITLE	= "PSM-Azure-MyApps"
Global Const $ERROR_MESSAGE_TITLE  	= "PSM " & $DISPATCHER_NAME & " Dispatcher error message"
Global Const $LOG_MESSAGE_PREFIX 		= $DISPATCHER_NAME & " Dispatcher - "

Global $TargetUsername   ;Will be fetched from the PSM Session
Global $TargetPassword   ;Will be fetched from the PSM Session
Global $TargetAddress    ;Will be fetched from the PSM Session
Global $DriverPath ; Will be fetched from the PSM Session
Global $BrowserPath ; Will be fetched from the PSM Session
Global $PROGRESS_BAR ; Full path to progressbar exe with NO surrounding quotes
Global $ConnectionClientPID = 0
Global $sDesiredCapabilities
Global $sSession
global $Sleep = 1000
Global $usernameXPath = "//input[@id='i0116' or @type='email']"
Global $passwordXPath = "//input[@id='i0118' or @type='password']"
Global $submitButtonXPath = "//*[@id='idSIButton9' or @type='submit']"

;=======================================
; Code
;=======================================
Exit Main()

Func FetchSessionProperties() ;----------> Retrieves properties required for the session from the PSM

	If (PSMGenericClient_GetSessionProperty("Email", $TargetUsername) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf

	If (PSMGenericClient_GetSessionProperty("Password", $TargetPassword) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
	if (PSMGenericClient_GetSessionProperty("Address", $TargetAddress) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
	if (PSMGenericClient_GetSessionProperty("DriverPath", $DriverPath) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
	if (PSMGenericClient_GetSessionProperty("BrowserPath", $BrowserPath) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
	If (PSMGenericClient_GetSessionProperty("PROGRESS_BAR", $PROGRESS_BAR) <> $PSM_ERROR_SUCCESS) Then
		Error("Error launching progress bar " & PSMGenericClient_PSMGetLastErrorString())
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
	
	ProgressBarOn()
	LogWrite("Starting client application")
	
	$sSession = SetupEdge()
	
	_WD_LoadWait($sSession, 1000)
	LogWrite("Finished loading msedge")

	$ConnectionClientPID = WinGetProcess("[CLASS:Chrome_WidgetWin_1]")
	LogWrite($ConnectionClientPID)
	if ($ConnectionClientPID == 0) Then
		Error(StringFormat("Failed to execute process [%s]", $ConnectionClientPID, @error))
	EndIf

	LogWrite("Entered LoginProcess()")

    _WD_LoadWait($sSession, 2000)

   BlockAllInput()
   ProgressBarOff()
	
    Local $i, $j, $k, $l, $m
	    For $i = 1 to 10
		LogWrite("Finding username field. Attempt: " & $i)
		Local $oUserName  = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, $usernameXPath)
		If $oUserName <> "" Then
			LogWrite("Username field found sending username ")
			_WD_ElementAction($sSession, $oUserName, 'value', $TargetUsername)
			ExitLoop
		EndIf
	Next
	Sleep($Sleep)
	For $j = 1 to 10
		LogWrite("Finding submit button. Attempt: " & $j)
		Local $SignIn   = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, $submitButtonXPath)
		If $SignIn <> "" Then
			LogWrite("Found submit button clicked submit.")
			_WD_ElementAction($sSession, $SignIn, 'click')
			ExitLoop
		EndIf
	Next
	Sleep($Sleep)
	For $k = 1 to 10
		LogWrite("Finding password field. Attempt: " & $k)
		Local $oPassword  = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, $passwordXPath)
		If $oPassword <> "" Then
			LogWrite("Password field found sending password.")
			_WD_ElementAction($sSession, $oPassword, 'value', $TargetPassword)
			ExitLoop
		EndIf
	Next
	Sleep($Sleep)
	For $l = 1 to 10
		LogWrite("Finding submit button. Attempt: " & $l)
		Local $SignIn   = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, $submitButtonXPath)
		If $SignIn <> "" Then
			LogWrite("Found submit button clicked submit.")
			_WD_ElementAction($sSession, $SignIn, 'click')
			ExitLoop
		EndIf
	Next
	Sleep($Sleep)
	For $m = 1 to 10
		LogWrite("Finding submit button. Attempt: " & $m)
		Local $SignIn   = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, $submitButtonXPath)
		If $SignIn <> "" Then
			LogWrite("Found submit button clicked submit.")
			_WD_ElementAction($sSession, $SignIn, 'click')
			ExitLoop
		EndIf
	Next
	Send ("{ENTER}")
	
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

Func ProgressBarOn() ;-----------> Launches CyberArk Progresss bar
			LogWrite("Launching progress bar: " & $PROGRESS_BAR)
			Global $iPID = Run($PROGRESS_BAR)
				$iPID = ProcessWait("CyberArk.ProgressBar.exe")
			Return $iPID
EndFunc


Func ProgressBarOff() ;-----------> Closes CyberArk Progresss bar
		LogWrite("Closing progress bar: " & $PROGRESS_BAR)
        ProcessClose($iPID)
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
		
        _WD_Option('Driver', 'chromedriver.exe')
        _WD_Option('Port', 9515)
	Local $sParams = '--port=9515 --debug --log-path="' & @UserProfileDir & '\chrome.log"'
        Local $sCommand = StringFormat('"%s", %s', $DriverPath, $sParams)

	LogWrite("Launching Edge Webdriver")
	Run($sCommand, "", @SW_HIDE)
	_WD_Option('driverdetect', true)

	LogWrite("Launching: https://myapps.microsoft.com/")
	
	Local $sURL = "https://myapps.microsoft.com/"
	$sDesiredCapabilities = '{"capabilities": {"alwaysMatch": {"goog:chromeOptions": {"args": [ "start-maximized", "allow-running-insecure-content", "InCognito" , "--app=' & $sURL & '"], "binary": "' & StringReplace (@ProgramFilesDir, "\", "/") & '/Google/Chrome/Application/chrome.exe", "excludeSwitches": [ "enable-automation"]}}}}'
	
	_WD_Startup()
	$sSession = _WD_CreateSession($sDesiredCapabilities)
	Return $sSession
	
 EndFunc
