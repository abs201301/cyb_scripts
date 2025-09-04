#AutoIt3Wrapper_UseX64=n
Opt("MustDeclareVars", 1)
AutoItSetOption("WinTitleMatchMode", 3)

;============================================================
;           Vermillion Web Portal
;           ---------------------
; Description : PSM Dispatcher for Web applications
; Created : 30.08.2024
; Updated : 03.09.2025
; Abhishek Singh
; Developed and compiled in AutoIt 3.3.14.1
;============================================================
; Uses AutoIT Web driver UDF
;============================================================

#include "PSMGenericClientWrapper.au3"
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <ProgressConstants.au3>
#include <ColorConstants.au3>
#include <StaticConstants.au3>
#include <AutoItConstants.au3>
#include <wd_Core.au3>
#include <wd_helper.au3>
#include <wd_cdp.au3>
#include <wd_capabilities.au3>
#include <Json.au3>
#include <BinaryCall.au3>
#include <WinHttp.au3>
#include <WinHttpConstants.au3>
#include <WinAPIFiles.au3>
#include <WinAPISys.au3>

;================================
; Consts & Globals
;================================

Global $TargetUsername, $TargetPassword, $TargetAddress, $TargetDomain, $RemoteMachine, $DriverPath, $BrowserPath, $TargetPort, $AppName
Global $usernameXPath, $passwordXPath, $submitButtonXPath
Global $ConnectionClientPID = 0, $sDesiredCapabilities, $sSession, $Sleep = 500, $Debug = "N"
Global $WinTitle, $WinText, $FinalWindow, $iPID = 0, $hGUI, $hProgress, $hPercentage
Global $ProgressValue = 0, $ProgressRunning = False
Global $LOG_MESSAGE_PREFIX, $ERROR_MESSAGE_TITLE

;=======================================
; Code
;=======================================
Main()
Exit

;=======================================
; Main
;=======================================
Func Main()

	If (PSMGenericClient_Init() <> $PSM_ERROR_SUCCESS) Then Error(PSMGenericClient_PSMGetLastErrorString())
	LogWrite("Successfully initialized Dispatcher Utils Wrapper")
	LogWrite("Mapping local drives")
	If (PSMGenericClient_MapTSDrives() <> $PSM_ERROR_SUCCESS) Then Error(PSMGenericClient_PSMGetLastErrorString())

	; Get the dispatcher parameters
	FetchSessionProperties()
	If Not IsTrue($Debug) Then HideWindow()
	LogWrite("Starting progress animation")
	StartProgressAnimation()
	
	Global $DISPATCHER_NAME 			= $AppName
	$ERROR_MESSAGE_TITLE  	= "PSM " & $DISPATCHER_NAME & " Dispatcher error message"
	$LOG_MESSAGE_PREFIX 		= $DISPATCHER_NAME & " Dispatcher - "
	
	LogWrite("Starting LoginProcess()")
	
	$ConnectionClientPID = SetupEdge()
	LogWrite("Finished LoginProcess() successfully")
	LogWrite("sending PID to PSM")

	LogWrite("Stoping progess animation")
	StopProgressAnimation()
	
	If Not IsTrue($Debug) Then ShowWindow()

	If (PSMGenericClient_SendPID($ConnectionClientPID) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
    EndIf
	LogWrite("Terminating Dispatcher Utils Wrapper")
	PSMGenericClient_Term()

	Return $PSM_ERROR_SUCCESS
EndFunc
	
;==============================
; Session Property Helper function
;==============================
Func GetSessionProperty($key, ByRef $outVar, $default = "")
   If (PSMGenericClient_GetSessionProperty($key, $outVar) <> $PSM_ERROR_SUCCESS) Then
       If $default <> "" Then
           $outVar = $default
       Else
           LogWrite($key & " is not defined")
       EndIf
   EndIf
EndFunc

Func FetchSessionProperties()
   GetSessionProperty("Username", $TargetUsername)
   GetSessionProperty("Password", $TargetPassword)
   GetSessionProperty("Address", $TargetAddress)
   GetSessionProperty("LogonDomain", $TargetDomain)
   GetSessionProperty("PSMRemoteMachine", $RemoteMachine)
   GetSessionProperty("DriverPath", $DriverPath)
   GetSessionProperty("BrowserPath", $BrowserPath)
   GetSessionProperty("Port", $TargetPort, "443")
   GetSessionProperty("DEBUG", $Debug, "N")
EndFunc

;==============================
; Progress Bar GUI + Animation
;==============================
Func HideWindow()
   Local $w = @DesktopWidth, $h = @DesktopHeight
   $hGUI = GUICreate($LOG_MESSAGE_PREFIX, $w, $h, 0, 0, $WS_POPUP, $WS_EX_TOPMOST)
   GUICtrlCreateLabel("", 0, 0, $w, $h)
   GUICtrlSetBkColor(-1, 0x000000)
   Local $lbl = GUICtrlCreateLabel("Please wait while we log you in...", ($w-400)/2, ($h/2)-50, 400, 40, $SS_CENTER)
   GUICtrlSetFont($lbl, 12, 700)
   GUICtrlSetColor($lbl, 0xFFFFFF)
   GUICtrlSetBkColor($lbl, 0x000000)
   $hProgress = GUICtrlCreateProgress(($w-400)/2, ($h/2), 400, 20, $PBS_SMOOTH)
   $hPercentage = GUICtrlCreateLabel("0%", ($w-400)/2, ($h/2)-25, 400, 20, $SS_CENTER)
   GUICtrlSetFont($hPercentage, 12, 700)
   GUICtrlSetColor($hPercentage, 0xFFFFFF)
   GUICtrlSetBkColor($hPercentage, $GUI_BKCOLOR_TRANSPARENT)
   GUISetState(@SW_SHOW)
EndFunc

Func UpdateProgress()
   If Not $ProgressRunning Then Return
   $ProgressValue += 2
   If $ProgressValue > 100 Then $ProgressValue = 0 ; Loop animation
   GUICtrlSetData($hProgress, $ProgressValue)
   GUICtrlSetData($hPercentage, $ProgressValue & "%")
   GUIGetMsg()
EndFunc

Func StartProgressAnimation()
   $ProgressRunning = True
   $ProgressValue = 0
   AdlibRegister("UpdateProgress", 100) ; Call every 100ms
EndFunc

Func StopProgressAnimation()
   $ProgressRunning = False
   AdlibUnRegister("UpdateProgress")
   GUICtrlSetData($hProgress, 100)
   GUICtrlSetData($hPercentage, "100%")
EndFunc

Func ShowWindow()
   GUIDelete($hGUI)
EndFunc

;==============================
; Webdriver Setup & Login
;==============================
Func SetupEdge() ;-----------> Prepares Webdriver capabilities and creates browser session
		
	_WD_Option('Driver', 'msedgedriver.exe')
    _WD_Option('Port', 9515)
	Local $sParams = '--port=9515 --debug --log-path="' & @UserProfileDir & '\msedge.log"'
    Local $sCommand = StringFormat('"%s", %s', $DriverPath, $sParams)
	If $TargetDomain <> "" Then
		LogWrite("Launching Edge Webdriver using RunAs capability")
		$iPID = RunAs($TargetUsername, $TargetDomain, $TargetPassword, 2, $sCommand, "", @SW_HIDE)
	Else
		LogWrite("Launching Edge Webdriver")
		$iPID = Run($sCommand, "", @SW_HIDE)
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
	$sDesiredCapabilities = '{"capabilities":{"alwaysMatch":{"ms:edgeOptions":{"args":["start-maximized","InPrivate","--app=' & $sURL & '"],"excludeSwitches":["enable-automation"]}}}}'	
	_WD_Startup()
	$sSession = _WD_CreateSession($sDesiredCapabilities)
	If Not $AppName = "Azure" Then
		DefaultLogin()
	Else
		AzureLogin()
	EndIf
	$FinalWindow = WinWait("[CLASS:Chrome_WidgetWin_1]", "", 20)
	If $FinalWindow Then
		WinActivate($FinalWindow)
		Return WinGetProcess($FinalWindow)
	Else
		LogWrite("Browser window not found")
		ShowWindow()
		CloseSession()
	EndIf
EndFunc
	
Func WaitForElement($session, $xpath, $action, $value = "")
   Local $stepName = ""
   If $xpath = $usernameXPath Then $stepName = "Username Field"
   If $xpath = $passwordXPath Then $stepName = "Password Field"
   If $xpath = $submitButtonXPath Then $stepName = "Submit Button"
   
   If $stepName <> "" Then LogWrite("Looking for " & $stepName)
   
   For $i = 1 To 20
       Local $elem = _WD_FindElement($session, $_WD_LOCATOR_ByXPath, $xpath)
       If $elem <> "" Then
			If $action = "click" Then
				LogWrite("Clicking " & $stepName)
				_WD_ElementAction($session, $elem, "click")
			ElseIf $action = "value" Then
				 LogWrite("Sending value to " & $stepName)
				 _WD_ElementAction($session, $elem, "value", $value)
			EndIf
            Return True
       EndIf
       Sleep(250)
   Next
   LogWrite("Element not found: " & $xpath)
   Return False
EndFunc
 
 Func AzureLogin()
 
    _WD_LoadWait($sSession)
    LogWrite("Finding elements")
	$usernameXPath = "//*[@id='i0116' or @type='email']"
	$passwordXPath = "//*[@id='i0118' or @type='password']"
	$submitButtonXPath = "//*[@id='idSIButton9' or @type='submit']"
	WaitForElement($sSession, $usernameXPath, "value", $TargetUsername & "@fil.com")
	WaitForElement($sSession, $submitButtonXPath, "click")
	WaitForElement($sSession, $passwordXPath, "value", $TargetPassword)
	WaitForElement($sSession, $submitButtonXPath, "click")
	WaitForElement($sSession, $submitButtonXPath, "click")
EndFunc

Func DefaultLogin()
	
	_WD_LoadWait($sSession)
    LogWrite("Finding elements")
	$usernameXPath = "//input[@id='j_username' or @name='j_username' or @id='username' or contains(@placeholder, 'Username') or contains(@name, 'user')]"
	$passwordXPath = "//input[@id='j_password' or @name='j_password' or @id='password' or contains(@placeholder, 'Password') or contains(@name, 'pass')]"
	$submitButtonXPath = "//*[@id='login-submission-button' or @id='login-button-id' or @type='submit']"
	WaitForElement($sSession, $usernameXPath, "value", $TargetUsername)
	WaitForElement($sSession, $passwordXPath, "value", $TargetPassword)
	WaitForElement($sSession, $submitButtonXPath, "click")
EndFunc

Func CloseSession()
   If $sSession <> "" Then _WD_DeleteSession($sSession)
   _WD_Shutdown()
   If ProcessExists($iPID) Then ProcessClose($iPID)
EndFunc

;==============================
; Internal PSM utilities
;==============================
Func Error($ErrorMessage, $Code = -1) ;----------> An exception handler - displays the error message and terminates the dispatcher


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

Func IsTrue($var)
   $var = StringLower($var)
   If $var == "yes" Or $var == "y" Or $var == "true" Then
       Return True
   EndIf
   If $var == "no" Or $var == "n" Or $var == "false" Then
       Return False
   EndIf
   Return False
EndFunc
