#AutoIt3Wrapper_UseX64=n
Opt("MustDeclareVars", 1)
AutoItSetOption("WinTitleMatchMode", 2)

#include <MsgBoxConstants.au3>
#include "PSMGenericClientWrapper.au3"
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <AutoItConstants.au3>
#include <BlockInputEx.au3>
#include <CyberArkPSMAnimation.au3>

;============================================================
;             PSM-GPOAdmin
;             -------------
; Created : SEP - 2025
; Created By: Abhishek Singh
; This is intended to work with Quest GPOAdmin (all versions)
;
;============================================================


;=======================================
; Consts & Globals
;=======================================
Global $Selection_Title, $Default_Selection, $App_Selections, $hGUI, $idComboBox, $g_pApp
Global $Width = 400
Global $DISPATCHER_NAME		
Global $TargetUsername, $TargetPassword, $TargetDomain
Global $WinTitle, $WinText, $hMsg
Global $iPID = 0, $ConnectionClientPID = 0, $Debug = "N"
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

	FetchSessionProperties() ; -----> Get the dispatcher parameters
	SelectApplication() ; ------> Select application to access through GUI combobox
	
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
   GetSessionProperty("Selection_Title", $Selection_Title)
   GetSessionProperty("Default_Selection", $Default_Selection)
   GetSessionProperty("App_Selections", $App_Selections)
   GetSessionProperty("LogonDomain", $TargetDomain)
   GetSessionProperty("DISPATCHER_NAME", $DISPATCHER_NAME)
   GetSessionProperty("DEBUG", $Debug, "N")
EndFunc

Func SelectApplication() ; --------------> Creates AutoIT GUI combox

	$hGUI = GUICreate($Selection_Title, $Width, 90)
	$idComboBox = GUICtrlCreateCombo($Default_Selection, 10, 10, $Width-25, 25)
	GUICtrlSetData($idComboBox, $App_Selections & "|Exit")
	Local $idOK = GUICtrlCreateButton("OK", ($Width / 2) - 30, 50, 60, 25)
	GUISetState(@SW_SHOW, $hGUI)
	$g_pApp = ""
    While 1
		Local $nMsg = GUIGetMsg()
        Switch $nMsg
			Case $GUI_EVENT_CLOSE
				ExitScript("User closed the window")
            Case $idOK
				$g_pApp = GUICtrlRead($idComboBox)
				If $g_pApp = "" Or $g_pApp = $Default_Selection Then
					MsgBox($MB_ICONWARNING, "Selection Required", "Please choose an option before continuing.")
					ContinueLoop
				EndIf
				If $g_pApp = "Exit" Then
					ExitScript("User selected Exit")
				EndIf
			ExitLoop
		EndSwitch
    WEnd
    GUIDelete($hGUI)

EndFunc

Func LoginProcess() ; --------------> Uses control commands to login to client
	
	_BlockInputEx(1)
	#cs
	About AutoIT logon flags:- We will use 1 for GPMC and 2 for GPOAdmin
	0 - Interactive logon with no profile.
	1 - Interactive logon with profile.
	2 - Network credentials only.
	4 - Inherit the calling process's environment instead of the user's environment.
	Why 1 for GPMC - The LogonFlag=1 essentially tells the connector that you need to log on with 
	a regular user with a profile, rather than the transparent PSM Shadow User process. This is so that you can launch GPMC in the context of that user. 
	Since this is all happening on the PSM machine itself, we need to 'allow log on locally' for those users, as they will be inside a managed PSM session, 
	running GPMC on the PSM server to execute tasks. Basically, when GPMC tries to log in as the target user, it is a local logon.
	#ce
	
	Local $Apps[2][4] = [ _
		["GPMC", '"' & @SystemDir & '\mmc.exe" "C:\Windows\System32\gpmc.msc"', 1, "[CLASS:MMCMainFrame]"], _
		["GPOADmin", '"' & @SystemDir & '\mmc.exe" "C:\Program Files\Quest\GPOADmin\GPOADmin.msc"', 2, "GPOADmin"] _
	]
	
	Local $bLaunched = False
	$WinTitle = ""
	$WinText = ""
	
	For $i = 0 To UBound($Apps) - 1
		If $Apps[$i][0] = $g_pApp Then
			LogWrite("Launching selected application: " & $g_pApp & " with LogonFlag = " & $Apps[$i][2])
			$iPID = RunAs($TargetUsername, $TargetDomain, $TargetPassword, $Apps[$i][2], $Apps[$i][1], @SystemDir, @SW_MAXIMIZE)
			$WinTitle = $Apps[$i][3]
			$bLaunched = True
			ExitLoop
		EndIf
	Next

	If Not $bLaunched Or $iPID = 0 Then
		Error(StringFormat("Failed to execute process [%s] for AppName [%s] - @error=%d", _
           $Apps[$i][1], $AppName, @error))
	EndIf
	LogWrite("Waiting for window with title: " & $WinTitle)
	$hMsg = WinWait($WinTitle, $WinText, 20)

	If $hMsg <> 0 Then
		WinActivate($hMsg)
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

Func ExitScript($reason)
   LogWrite("Dispatcher terminated: " & $reason)
   If (PSMGenericClient_IsInitialized()) Then
       PSMGenericClient_Term()
   EndIf
   Exit
EndFunc
