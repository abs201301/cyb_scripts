#AutoIt3Wrapper_UseX64=n
Opt("MustDeclareVars", 1)
AutoItSetOption("WinTitleMatchMode", 3) ; EXACT_MATCH!

;============================================================
;           Generic Web Portal
;           -------------------
; Description : PSM Dispatcher for Websites
; Created : 26.03.2025
; Abhishek Singh
; Developed and compiled in AutoIt 3.3.14.1
;============================================================
; Uses Selenium Framework
;============================================================

#include "PSMGenericClientWrapper.au3"
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <ProgressConstants.au3>
#include <ColorConstants.au3>
#include <StaticConstants.au3>
#include <AutoItConstants.au3>
#include <Crypt.au3>
#include <StringConstants.au3>
#include <WinAPIFiles.au3>
#include <WinAPISys.au3>
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
Global $Debug = "N"


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
	
	If (PSMGenericClient_GetSessionProperty("DEBUG", $Debug) <> $PSM_ERROR_SUCCESS) Then
		$Debug = "N"
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
	$ERROR_MESSAGE_TITLE  	= "PSM " & $AppName & " Dispatcher error message"
	$LOG_MESSAGE_PREFIX 		= $AppName & " Dispatcher - "
	
	If Not Is($Debug) Then
		HideWindow()
	EndIf

	LogWrite("Starting selenium wrapper")
	
	$ConnectionClientPID  = LaunchEdge()
	LogWrite("Finished LoginProcess() successfully")
	LogWrite("sending PID to PSM")

	If Not Is($Debug) Then
		ShowWindow()
	EndIf
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

Func Is($var)
   $var = StringLower($var)
   If $var == "yes" Or $var == "y" Or $var == "true" Then
       Return True
   EndIf
   If $var == "no" Or $var == "n" Or $var == "false" Then
       Return False
   EndIf
   Return False
EndFunc

Func HideWindow()

	Global $hGUI, $screenWidth, $screenHeight, $sMessage, $labelWidth, $labelHeight, $labelX, $labelY, $hLabel, $progressWidth, $progressHeight, $progressX, $progressY, $hProgress, $hPercentage
	$screenWidth = @DesktopWidth
	$screenHeight = @DesktopHeight
	$hGUI = GUICreate($LOG_MESSAGE_PREFIX, $screenWidth, $screenHeight, 0, 0, $WS_POPUP, $WS_EX_TOPMOST)
	GUICtrlCreateLabel("", 0, 0, $screenWidth, $screenHeight)
	GUICtrlSetBkColor(-1, 0x000000)
	$sMessage = "Please wait while we log you in..."
	$labelWidth = 400
	$labelHeight = 40
	$labelX = ($screenWidth - $labelWidth) / 2
	$labelY = ($screenHeight - $labelHeight) / 2 - 50
	$hLabel = GUICtrlCreateLabel($sMessage, $labelX, $labelY, $labelWidth, $labelHeight, $SS_CENTER)
	GUICtrlSetFont($hLabel, 12, 700)
	GUICtrlSetColor($hLabel, 0xFFFFFF)
	GUICtrlSetBkColor($hLabel, 0x000000)
	$progressWidth = 400
	$progressHeight = 20
	$progressX = ($screenWidth - $progressWidth) / 2
	$progressY = $labelY + 50
	$hProgress = GUICtrlCreateProgress($progressX, $progressY, $progressWidth, $progressHeight, $PBS_SMOOTH)
	GUICtrlSetColor($hProgress, 0xFFFFFF)
	$hPercentage = GUICtrlCreateLabel("0%", $progressX, $progressY - 25, $progressWidth, 20, $SS_CENTER)
	GUICtrlSetFont($hPercentage, 12, 700)
	GUICtrlSetColor($hPercentage, 0xFFFFFF)
	GUICtrlSetBkColor($hPercentage, $GUI_BKCOLOR_TRANSPARENT)
	GUISetState(@SW_SHOW)
	
EndFunc

Func ShowWindow()
	GUIDelete($hGUI)
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
	ElseIf $AppName = "Github" Then
		Local $sUsername = $TargetUsername & "@<Domain>"
		$sPSCmd = $PS_EXE & " -File "& '"'&$sScript &'" ' & $TargetAddress & ' ' & $sUsername & ' ' & $AppName & ' ' & $encodedPassword
	Else
		$sPSCmd = $PS_EXE & " -File "& '"'&$sScript &'" ' & $TargetAddress & ' ' & $TargetUsername & ' ' & $AppName & ' ' & $encodedPassword
	EndIf
	LogWrite("Sending connection string")
	
	If $TargetDomain <> "" Then
		$iPID = RunAs($TargetUsername, $TargetDomain, $TargetPassword, 2, @ComSpec & " /c " & $sPSCmd, @AppDataDir, @SW_HIDE, $STDERR_MERGED)
		LogWrite("Creating browser session using RunAs capability")
	Else
		$iPID = Run(@ComSpec & " /c " & $sPSCmd, @AppDataDir, @SW_HIDE, $STDERR_MERGED)
		LogWrite("Creating browser session using Run capability")
	EndIf
	
	If $iPID == 0 Then
		Error("Error running scipt: " & @error & " - " & PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
	If Not Is($Debug) Then
		Local $progressDone = False
		For $i = 1 To 100
			If ProcessExists($iPID) Then
				GUICtrlSetData($hProgress, $i / 2)
				GUICtrlSetData($hPercentage, int($i / 2) & "%")
				Sleep(75)
			Else
				$progressDone = True
				ExitLoop
			EndIf
		Next
	
		If $progressDone = False Then
			GUICtrlSetData($hProgress, 100)
			GUICtrlSetData($hPercentage, "100%")
		EndIf
	EndIf

	While ProcessExists($iPID)
		Sleep(500)
	WEnd
	
	Local $CleanEnv = CleanEnv()
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

Func CleanEnv() ;----------------------------------------->> Deletes any Powershell transcript generated during the login process

	Local $iDelete = FileDelete($sScript)
	Local $sDate = @YEAR & @MON & @MDAY
	Local $sTranscriptFolder = @UserProfileDir & "\Documents\" & $sDate & "\"
	
	If FileExists($sTranscriptFolder) Then
		Local $sFile = FileFindFirstFile($sTranscriptFolder & "PowerShell_Transcript*.txt")
		If $sFile = -1 Then
			LogWrite("Info: No PowerShell transcript files found for today.")
		Else
        While 1
            Local $sFileName = FileFindNextFile($sFile)
            If @error Then ExitLoop
				Local $sFullPath = $sTranscriptFolder & $sFileName
				If FileDelete($sFullPath) Then
					LogWrite("Success: Deleted transcript: " & $sFullPath)
				Else
					LogWrite("Error: Failed to delete: " & $sFullPath)
				EndIf
        WEnd
        FileClose($sFile)
		EndIf
	Else
		LogWrite("Info: Transcript folder not found: " & $sTranscriptFolder)
	EndIf 
	
EndFunc
