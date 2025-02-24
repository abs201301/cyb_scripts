#AutoIt3Wrapper_UseX64=n
Opt("MustDeclareVars", 1)
AutoItSetOption("WinTitleMatchMode", 3) ; EXACT_MATCH!

;============================================================
;           Generic Web Portal
;           ----------------------------------------------------------
; Description : PSM Dispatcher for Websites
; Created : 06.11.2024
; Abhishek Singh
; Developed and compiled in AutoIt 3.3.14.1
;============================================================
; Uses Selenium Framework
;============================================================

#include "PSMGenericClientWrapper.au3"
#include <GUIConstantsEx.au3>
#include <AutoItConstants.au3>
#include <Crypt.au3>
#include <StringConstants.au3>
#Include "Base64.au3"
;================================
; Consts & Globals
;================================

Global $ERROR_MESSAGE_TITLE 
Global $LOG_MESSAGE_PREFIX 
Global $AppName  ; Will be fetched from the PSM Session
Global $PS_EXE   ;Will be fetched from the PSM Session
Global $Script_Path   ;Will be fetched from the PSM Session
Global $Script_Name   ;Will be fetched from the PSM Session
Global $TargetUsername   ;Will be fetched from the PSM Session
Global $TargetPassword   ;Will be fetched from the PSM Session
Global $TargetAddress    ;Will be fetched from the PSM Session
Global $TargetDomain	;Will be fetched from the PSM Session
Global $RemoteMachine ;Will be fetched from the PSM Session
Global $DriverPath ; Will be fetched from the PSM Session
Global $BrowserPath ; Will be fetched from the PSM Session
Global $sScript
Global $sPSCmd
Global $WinTitle
Global $WinText
Global $FinalWindow
Global $ConnectionClientPID = 0
Global $iPID


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
	
	if (PSMGenericClient_GetSessionProperty("AppName", $AppName) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
	if (PSMGenericClient_GetSessionProperty("PS_EXE", $PS_EXE) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
	if (PSMGenericClient_GetSessionProperty("Script_Path", $Script_Path) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
	if (PSMGenericClient_GetSessionProperty("Script_Name", $Script_Name) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
EndFunc

;=======================================
; Main sript starts here
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

	FetchSessionProperties()
	Global $DISPATCHER_NAME 			= $AppName
	$ERROR_MESSAGE_TITLE  	= "PSM " & $DISPATCHER_NAME & " Dispatcher error message"
	$LOG_MESSAGE_PREFIX 		= $DISPATCHER_NAME & " Dispatcher - "
	
	MessageUserOn("PSM-" & $DISPATCHER_NAME & "-WebApp", "Starting " & $DISPATCHER_NAME & "...")
	LogWrite("Starting selenium wrapper")
	
	$ConnectionClientPID  = LaunchEdge()

	LogWrite("Finished LoginProcess() successfully")
	LogWrite("sending PID to PSM")
	
	If (PSMGenericClient_SendPID($ConnectionClientPID) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
    EndIf

	MessageUserOff()
	LogWrite("Terminating Dispatcher Utils Wrapper")
	PSMGenericClient_Term()
	
	While ProcessExists($ConnectionClientPID)
		Sleep(1000)
	WEnd

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
; Description ...: Write a Dispatcher log message to standard PSM log file         
; ===============================================================================================================================
Func LogWrite($sMessage, $LogLevel = $LOG_LEVEL_TRACE)
	Return PSMGenericClient_LogWrite($LOG_MESSAGE_PREFIX & $sMessage, $LogLevel)
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: AssertErrorLevel
; Description ...: Checks If error level is <> 0. If so, write to log and call error.
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
; Name...........: LaunchEdge
; Description ...: Creates browser session using selenium webdriver. Encodes the password in base64 format instead of clear text.
; $iPID = Run($sPSCmd, "", @SW_HIDE)
; ===============================================================================================================================
Func LaunchEdge()

	If $RemoteMachine <> "" Then
		LogWrite("Using RemoteMachine as address")
		$TargetAddress = $RemoteMachine
	Else
		LogWrite("Using TargetAddress as address")
	EndIf
	
	LogWrite("Sending file copy cmd")
	FileCopy($Script_Path & "\" & $Script_Name, @AppDataDir, 1)
	
	$sScript = @AppDataDir & "\" & $Script_Name
	Local $encodedPassword = _Base64Encode(StringToBinary($TargetPassword, 4))
	If $AppName = "Azure" Then
		Local $sUsername = $TargetUsername & "@<Domain>"
		Local $sAddress = "myapps.microsoft.com"
		$sPSCmd = $PS_EXE & " -File "& '"'&$sScript &'" ' & $sAddress & ' ' & $sUsername & ' ' & $AppName & ' ' & $encodedPassword
	Else
		$sPSCmd = $PS_EXE & " -File "& '"'&$sScript &'" ' & $TargetAddress & ' ' & $TargetUsername & ' ' & $AppName & ' ' & $encodedPassword
	EndIf
	LogWrite("Sending connection string")
	
	If $TargetDomain <> "" Then
		$iPID = RunAs($TargetUsername, $TargetDomain, $TargetPassword, 2, @ComSpec & " /c " & $sPSCmd, @AppDataDir, @SW_HIDE, $STDERR_MERGED)
		LogWrite("Creating browser session using RunAs capability")
	Else
		$iPID = Run(@ComSpec & " /k " & $sPSCmd, @AppDataDir, @SW_HIDE, $STDERR_MERGED)
		LogWrite("Creating browser session using Run capability")
	EndIf
	
	If $iPID == 0 Then
		Error("Error running scipt: " & @error & " - " & PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
	$iPID = Login()
	Return $iPID

EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: Login
; Description ...: Determines the final logged in window by class and returns the PID to parent function
; ===============================================================================================================================
Func Login()
	
	$WinTitle = "[CLASS:Chrome_WidgetWin_1]"
	$WinText = ""
	$FinalWindow = WinWait($WinTitle, $WinText, 20)
	
	 If $FinalWindow <> 0 Then
		WinActivate($FinalWindow)
		WinSetState($FinalWindow, "", @SW_SHOW)
	Else
		LogWrite("Couldn't find the browser window")
		CloseSession()
	EndIf
	
	Return WinGetProcess($FinalWindow)

EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: CloseSession
; Description ...: Terminates the session gracefully in case of errors
; ===============================================================================================================================
Func CloseSession()
	
	$WinTitle = "[CLASS:Chrome_WidgetWin_1]"
	$WinText = ""
	Local $hMsg = WinWait($WinTitle, $WinText, 20)
	
	 If $hMsg <>"" Then
		ProcessClose(WinGetProcess($hMsg))
	EndIf
	
	If ProcessExists($iPID) Then
		ProcessClose($iPID)
	EndIf

EndFunc
