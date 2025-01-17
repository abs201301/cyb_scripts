
#AutoIt3Wrapper_UseX64=n
Opt("MustDeclareVars", 1)
AutoItSetOption("WinTitleMatchMode", -1) ; Match from Start case insensitive
AutoItSetOption("SendKeyDelay", 30) ; Match from Start case insensitive

;============================================================
;           SQL Server Management Studio 20
;           --------------------------------
; Description : PSM Dispatcher for SSMS 20
; Abhishek Singh
; Developed and compiled in AutoIt 3.3.14.1
;============================================================

#include "PSMGenericClientWrapper.au3"
#include <WindowsConstants.au3>
#include <AutoItConstants.au3>
#include <File.au3>

;=======================================
; Consts & Globals
;=======================================
Global Const $DISPATCHER_NAME = "SQL Server Management Studio"
Global Const $ERROR_MESSAGE_TITLE = "PSM " & $DISPATCHER_NAME & " Dispatcher error message"
Global Const $LOG_MESSAGE_PREFIX = $DISPATCHER_NAME & " Dispatcher - "
Global $CLIENT_EXECUTABLE ; Full path to ssms executable with NO surrounding quotes
Global $TargetUsername   ;Will be fetched from the PSM Session
Global $TargetPassword   ;Will be fetched from the PSM Session
Global $TargetAddress    ;Will be fetched from the PSM Session
Global $TargetPort       ;Will be fetched from the PSM Session
Global $TargetDomain      ;Will be fetched from the PSM Session
Global $Sleep = 200
Global $Longsleep = 2000
Global $ConnectionClientPID = 0

;=======================================
; Code
;=======================================

Exit Main()

;=======================================
; Main script starts here
;=======================================

Func Main()

	Global $WinTitle, $WinText, $hMsg, $hCtl
	LogWrite("Initialising variables")

   if (PSMGenericClient_Init() <> $PSM_ERROR_SUCCESS) Then
    Error(PSMGenericClient_PSMGetLastErrorString())
   EndIf

   LogWrite("successfully initialized Dispatcher Utils Wrapper")

   FetchSessionProperties()
   MessageUserOn("PSM-" & $DISPATCHER_NAME, "Starting " & $DISPATCHER_NAME & "...")
   LogWrite("mapping local drives")

   if (PSMGenericClient_MapTSDrives() <> $PSM_ERROR_SUCCESS) Then
	Error(PSMGenericClient_PSMGetLastErrorString())
   EndIf
   
	DirRemove (_PathFull("SQL Server Management Studio", @AppDataDir & "\Microsoft"), 1)
	LogWrite("Starting client application")
   
	$ConnectionClientPID = RunAs($TargetUsername, $TargetDomain,$TargetPassword,2, $CLIENT_EXECUTABLE  ,"",@SW_MAXIMIZE)

	if ($ConnectionClientPID == 0) Then
		Error(StringFormat("Failed to execute process [%s]", $CLIENT_EXECUTABLE, @error))
	EndIf

	$WinTitle = "Import User Settings"
	$WinText = "Do &not import"
	$hMsg = WinWait($WinTitle, $WinText, 5)
	
	If $hMsg <> 0 Then
		LogWrite("Found window: " & $WinTitle)
		WinActivate($WinTitle, $WinText)
		ControlClick($WinTitle, $WinText, "WindowsForms10.BUTTON.app.0.1b098ad_r40_ad12", "Left")
	EndIf
	
	Local $certTextPos, $pixelColor
	
	$WinTitle = "Connect to Server"
	$WinText = "&Connect"
	$hMsg = WinWait($WinTitle, $WinText, 0)
	
	If $hMsg <> 0 Then
		WinActivate($hMsg)
		LogWrite("Found window: " & $WinTitle & ": Sending connection string: " & $TargetAddress)
		Sleep($Sleep)
		ControlSetText ($hMsg, "", "[CLASS:Edit; INSTANCE:1]", $TargetAddress)
		Sleep($Sleep)
		$hCtl = ControlGetHandle($hMsg, "", "[NAME:trustServerCertCheckbox]")
		If $hCtl <> 0 Then	
			LogWrite($WinTitle & ": Selected Trust Server Certificate")
			ControlCommand($hMsg, "", $hCtl, "Check", "")
		EndIf
		LogWrite($WinTitle & ": Clicked connect button")
		ControlClick($hMsg, "", "[NAME:connect]")
	Else
		LogWrite("Window: " & $WinTitle & " not found")
	EndIf
	
	$WinTitle = "Microsoft SQL Server Management Studio"
	$WinText = ""
	$hMsg = WinWait($WinTitle, $WinText, 0)
	LogWrite("Waiting for window: " & $WinTitle)
	
	If $hMsg <> 0 Then
		WinActivate($WinTitle, $WinText)
		LogWrite("Found window: " & $WinTitle)
		WinSetState($hMsg,"",@SW_SHOW)
		LogWrite("Activating window: " & $WinTitle)
	Else
		LogWrite("Window: " & $WinTitle & " not found")
	EndIf

	LogWrite("sending PID to PSM")

	if (PSMGenericClient_SendPID($ConnectionClientPID) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	MessageUserOff()
   LogWrite("Terminating Dispatcher Utils Wrapper")
   PSMGenericClient_Term()

   Return $PSM_ERROR_SUCCESS
   EndFunc
   
;=======================================
; Main script ends here
;======================================= 

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
; Description ...: Write a log message to standard PSM log file
; Parameters ....: $sMessage - [IN] The message to write
; $LogLevel - [Optional] [IN] Defined if the message should be handled as an error message or as a trace messge
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

	if (PSMGenericClient_GetSessionProperty("LogonDomain", $TargetDomain) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf

    if (PSMGenericClient_GetSessionProperty("PSMRemoteMachine", $TargetAddress) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
	If (PSMGenericClient_GetSessionProperty("CLIENT_EXECUTABLE", $CLIENT_EXECUTABLE) <> $PSM_ERROR_SUCCESS) Then
		Error("Error getting EXE path " & PSMGenericClient_PSMGetLastErrorString())
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
