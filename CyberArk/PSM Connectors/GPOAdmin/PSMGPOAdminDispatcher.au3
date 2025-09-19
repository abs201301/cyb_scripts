#AutoIt3Wrapper_UseX64=n
Opt("MustDeclareVars", 1)
AutoItSetOption("WinTitleMatchMode", 2)

#include <MsgBoxConstants.au3>
#include "PSMGenericClientWrapper.au3"
#include "PSMGenericClientWrapper.au3"
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <ProgressConstants.au3>
#include <ColorConstants.au3>
#include <StaticConstants.au3>
#include <AutoItConstants.au3>
#include <WinAPIFiles.au3>
#include <WinAPISys.au3>
#include <BlockInputEx.au3>
#include <CyberArkPSMAnimation.au3>

;============================================================
;             PSM-GPOAdmin
;             -------------------------
; Created : SEP - 2025
; Created By: Abhishek Singh
; This is intended to work with Quest GPOAdmin (all versions)
;
;============================================================


;=======================================
; Consts & Globals
;=======================================

Global $DISPATCHER_NAME		
Global $TargetUsername, $TargetPassword, $TargetDomain, $AppName
Global $WinTitle, $WinText, $hMsg
Global $iPID = 0, $ConnectionClientPID = 0, $Debug = "N"
Global $LOG_MESSAGE_PREFIX, $ERROR_MESSAGE_TITLE
Global $LogonFlag  = 1

;0 - Interactive logon with no profile.
;1 - Interactive logon with profile.
;2 - Network credentials only.
;4 - Inherit the calling process's environment instead of the user's environment.


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

	FetchSessionProperties() ; -----> Get the dispatcher parameters
	
	If Not IsTrue($Debug) Then Start_Animation("Progress") ; Replace with Start_Animation("CyberArk") for alternate animation
	LogWrite("Starting progress animation")
	
	$ERROR_MESSAGE_TITLE  	= "PSM " & $DISPATCHER_NAME & " Dispatcher error message"
	$LOG_MESSAGE_PREFIX 		= $DISPATCHER_NAME & " Dispatcher - "
	
	LogWrite("Starting LoginProcess()")
	$ConnectionClientPID = LoginProcess()
	
	LogWrite("sending PID to PSM")
	LogWrite("Stoping progess animation")
	
	If Not IsTrue($Debug) Then Stop_Animation()
	
	If (PSMGenericClient_SendPID($ConnectionClientPID) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	LogWrite("Terminating Dispatcher Utils Wrapper")
	Return $PSM_ERROR_SUCCESS
	PSMGenericClient_Term()

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
   GetSessionProperty("PSMRemoteMachine", $AppName)
   GetSessionProperty("LogonDomain", $TargetDomain)
   GetSessionProperty("DISPATCHER_NAME", $DISPATCHER_NAME)
   GetSessionProperty("DEBUG", $Debug, "N")
EndFunc

Func LoginProcess() ; --------------> Uses control commands to login to client
	
	_BlockInputEx(1)
	
	Local $Apps[2][2] = [ _
		["GPMC", '"' & @SystemDir & '\mmc.exe" "C:\Windows\System32\gpmc.msc"'], _
		["GPOADmin", '"' & @SystemDir & '\mmc.exe" "C:\Program Files\Quest\GPOADmin\GPOADmin.msc"'] _
	]
	
	For $i = 0 To UBound($Apps) - 1
		If $Apps[$i][0] = $AppName Then
			LogWrite("Launching selected application: " & $AppName)
			$iPID = RunAs($TargetUsername, $TargetDomain, $TargetPassword, $LogonFlag, $Apps[$i][1], @SystemDir, @SW_MAXIMIZE)
			ExitLoop
		EndIf
	Next

	if ($iPID == 0) Then
		Error(StringFormat("Failed to execute process [%s]", $Apps[$i][1], @error))
	EndIf
	
	$WinTitle = "GPOADmin"
	$WinText = ""
	$hMsg = WinWait($WinTitle, $WinText, 20)

	If WinActivate($hMsg) Then
		LogWrite("Finished LoginProcess() successfully")
		WinSetState($hMsg, "", @SW_MAXIMIZE)
	EndIf
	_BlockInputEx(0)
	Return WinGetProcess($hMsg)

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
