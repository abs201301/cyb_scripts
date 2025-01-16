
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Change2CUI=y
#AutoIt3Wrapper_Res_Fileversion=1.4.0.8
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
;
;============================================================
;           Informatica Powercenter Tools
;           -----------------------------
; Description : PSM Dispatcher for Informatica PC Tools
; Abhishek Singh
; Developed and compiled in AutoIt 3.3.14.1
;============================================================
;
;
#include <WinAPIEx.au3>
#include <AutoITConstants.au3>
#include <WindowsConstants.au3>
#include <GUIConstantsEx.au3>
#include <array.au3>
#include <GuiTreeView.au3>
#include <PSMGenericClientWrapper.au3>
#include <BlockInputEx.au3>
#include <EditConstants.au3>

Opt("MustDeclareVars", 1)
AutoItSetOption("WinTitleMatchMode", -1) ; Match from Start case insensitive
AutoItSetOption("SendKeyDelay", 30)
AutoItSetOption("MouseCoordMode", 0) ; Relative to active window

;=======================================
; Consts & Globals
;=======================================
Global Const $DISPATCHER_NAME = "PSM Informatica PC Tools"
Global Const $RepoEXE					= "<Path to your Informatica pmrep.exe>"
Global Const $ERROR_MESSAGE_TITLE = "PSM " & $DISPATCHER_NAME & " Dispatcher error message"
Global Const $LOG_MESSAGE_PREFIX = $DISPATCHER_NAME & " Dispatcher - "
Global Const $_CTL_CHECK = "Check"
Global Const $_CTL_LEFT = "Left"
Global Const $_TXT_PCTOOLS = "Informatica PowerCenter Designer - [Start Page]"
Global Const $MESSAGE_TITLE	= $DISPATCHER_NAME

Global $Debug
Global $TargetUsername
Global $TargetPassword
Global $TargetAddress
Global $InfaDomain
Global $TargetPort
Global $Repository
Global $SecureDomain = "<Secure Domain Name>"
Global $WorkspaceFilePath = "C:\Users" & "\" & @UserName & "\AppData\Local\.."
Global $TargetEXE ; Full path to pmdesign executable with NO surrounding quotes
Global $TargetDomain      ;Will be fetched from the PSM Session
Global $ConnectionClientPID = 0

;=======================================
; Code
;=======================================
Exit Main()

;=======================================
; Main
;=======================================
Func Main()

	; Init PSM Dispatcher utils wrapper

	If (PSMGenericClient_Init() <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf

	LogWrite("successfully initialized Dispatcher Utils Wrapper")

	LogWrite("mapping local drives")
	If (PSMGenericClient_MapTSDrives() <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf

	FetchSessionProperties()
	
	LogWrite("starting client application")
	MessageUserOff()
	MessageUserOn($MESSAGE_TITLE, "Starting " & $DISPATCHER_NAME & @LF & "Please wait...")
	;
	; Prevent user interaction while we're getting logged on
	;
	If Not IsTrue($Debug) Then _BlockInputEx(1)
	
	$ConnectionClientPID = LaunchEXE()
	;
	; Release keyboard and mouse
	;
	_BlockInputEx(0)

	; Send PID to PSM as early as possible so recording/monitoring can begin
	LogWrite("sending PID to PSM")
	If (PSMGenericClient_SendPID($ConnectionClientPID) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	MessageUserOff()
	; Terminate PSM Dispatcher utils wrapper
	LogWrite("Terminating Dispatcher Utils Wrapper")
	PSMGenericClient_Term()
	;
	; Enter the password when prompted within LIVE session
	;
	Sleep(2000)
	Local $WinTitle = "Connect to Repository"
	Local $WinText = "L&ess <<"
	Local $hMsg
    Local $loginSent = False

	While ProcessExists($ConnectionClientPID)
		$hMsg = WinWait($WinTitle, $WinText, 20)
			If (WinActivate($hMsg) And Not $loginSent) Then
				EnterCreds()
				$loginSent = True
			ElseIf ($loginSent and WinActivate($hMsg)) Then
				$loginSent = False
			EndIf
	WEnd
	Return $PSM_ERROR_SUCCESS
EndFunc   ;==>Main

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
		LogWrite($ErrorMessage, True)
		PSMGenericClient_Term()
	EndIf

	Local $MessageFlags = BitOR(0, 16, 262144) ; 0=OK button, 16=Stop-sign icon, 262144=MsgBox has top-most attribute set

	MsgBox($MessageFlags, $ERROR_MESSAGE_TITLE, $ErrorMessage)

	; If the connection component was already invoked, terminate it
	If ($ConnectionClientPID <> 0) Then
		ProcessClose($ConnectionClientPID)
		$ConnectionClientPID = 0
	EndIf

	Exit $Code
EndFunc   ;==>Error

; #FUNCTION# ====================================================================================================================
; Name...........: LogWrite
; Description ...: Write a PSMWinSCPDispatcher log message to standard PSM log file
; Parameters ....: $sMessage - [IN] The message to write
;                  $LogLevel - [Optional] [IN] Defined if the message should be handled as an error message or as a trace messge
; Return values .: $PSM_ERROR_SUCCESS - Success, otherwise error - Use PSMGenericClient_PSMGetLastErrorString for details.
; ===============================================================================================================================
Func LogWrite($sMessage, $LogLevel = $LOG_LEVEL_TRACE)
	Return PSMGenericClient_LogWrite($LOG_MESSAGE_PREFIX & $sMessage, $LogLevel)
EndFunc   ;==>LogWrite

; #FUNCTION# ====================================================================================================================
; Name...........: PSMGenericClient_GetSessionProperty
; Description ...: Fetches properties required for the session
; Parameters ....: None
; Return values .: None
; ===============================================================================================================================
Func FetchSessionProperties()


	If (PSMGenericClient_GetSessionProperty("Username", $TargetUsername) <> $PSM_ERROR_SUCCESS) Then
		Error("Error getting username " & PSMGenericClient_PSMGetLastErrorString())
	EndIf

	If (PSMGenericClient_GetSessionProperty("Password", $TargetPassword) <> $PSM_ERROR_SUCCESS) Then
		Error("Error getting password " & PSMGenericClient_PSMGetLastErrorString())
	EndIf

	If (PSMGenericClient_GetSessionProperty("PSMRemoteMachine", $TargetAddress) <> $PSM_ERROR_SUCCESS) Then
		Error("Error getting address " & PSMGenericClient_PSMGetLastErrorString())
	EndIf

	If (PSMGenericClient_GetSessionProperty("TargetEXE", $TargetEXE) <> $PSM_ERROR_SUCCESS) Then
		Error("Error getting EXE path " & PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
	If (PSMGenericClient_GetSessionProperty("Port", $TargetPort) <> $PSM_ERROR_SUCCESS) Then
		Error("Error getting port number " & PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
	if (PSMGenericClient_GetSessionProperty("LogonDomain", $TargetDomain) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
	If (PSMGenericClient_GetSessionProperty("InfaDomain", $InfaDomain) <> $PSM_ERROR_SUCCESS) Then
		Error("Error getting secure domain " & PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
	If (PSMGenericClient_GetSessionProperty("Repository", $Repository) <> $PSM_ERROR_SUCCESS) Then
		Error("Error getting repository " & PSMGenericClient_PSMGetLastErrorString())
	EndIf

	If (PSMGenericClient_GetSessionProperty("DEBUG", $Debug) <> $PSM_ERROR_SUCCESS) Then
	 LogWrite(PSMGenericClient_PSMGetLastErrorString())
	 $Debug = False
	Else
		If ($Debug == "Yes") Then
			$Debug = True
		Else
			$Debug = False
		EndIf
	EndIf

EndFunc   ;==>FetchSessionProperties

Func LaunchEXE()
	AutoItSetOption("WinTitleMatchMode", -1) ; Match from Start
	
	MessageUserOff()
    MessageUserOn($MESSAGE_TITLE, "Starting " & $DISPATCHER_NAME & @LF & "Please wait... Configuration setup (1/5)")
	If ($Debug) Then
		MessageUserOff()
		ToolTip("pmrep.exe cleanup")
	EndIf
	Local $RunCleanup = $RepoEXE & " cleanup"
	RunWait($RunCleanup,"",@SW_HIDE)
	LogWrite("Cleaning up the stale sessions")
	
	MessageUserOff()
    MessageUserOn($MESSAGE_TITLE, "Starting " & $DISPATCHER_NAME & @LF & "Please wait... Configuration setup (2/5)")
	If ($Debug) Then
		MessageUserOff()
		ToolTip("pmrep.exe connect -r " & $Repository & " -n " & $TargetUsername & " -h " & $TargetAddress & " -o " & $TargetPort & " -s FIL_GenericAccounts")
	EndIf
	Local $RunCfg = $RepoEXE & " connect " & "-r " & $Repository & " -n " & $TargetUsername & " -x " & $TargetPassword & " -h " & $TargetAddress & " -o " & $TargetPort & " -s FIL_GenericAccounts"
	RunWait($RunCfg,"",@SW_HIDE)
	LogWrite("Configuring session: " & $RepoEXE & " connect " & "-r " & $Repository & " -n " & $TargetUsername & " -x  somepassword" & " -h " & $TargetAddress & " -o " & $TargetPort & " -s FIL_GenericAccounts")
	
	MessageUserOff()
    MessageUserOn($MESSAGE_TITLE, "Starting " & $DISPATCHER_NAME & @LF & "Please wait... Configuration setup (3/5)")
	If ($Debug) Then
		MessageUserOff()
		ToolTip("pmrep.exe connect -r" & $Repository & " -d" & $InfaDomain)
	EndIf
	Local $RunDCconnect = $RepoEXE & " connect" & " -r " & $Repository & " -d " & $InfaDomain
	RunWait($RunDCconnect,"",@SW_HIDE)
	LogWrite("Connecting sesison: " & $RepoEXE & " connect" & " -r " & $Repository & " -d " & $InfaDomain)

	MessageUserOff()
    MessageUserOn($MESSAGE_TITLE, "Starting " & $DISPATCHER_NAME & @LF & "Please wait... Configuration setup (4/5)")
	If ($Debug) Then
		MessageUserOff()
		ToolTip("Setting up repository services")
	EndIf
	Local $sKey = "HKEY_CURRENT_USER\Software\Informatica\PowerMart Client Tools\10.5.4\Designer\Options\Tips"
	RegWrite($sKey, "ShowAtStartup", "REG_DWORD", "0")
	
	Local $var = "HKEY_CURRENT_USER\Software\Informatica\PowerMart Client Tools\10.5.4\Cache Repository List" & "\" & $Repository
	RegWrite($var, "Repository Name", "REG_SZ", $Repository)
	RegWrite($var, "Domain Name", "REG_SZ", $InfaDomain)
	LogWrite("Disabling startup tips and setting Repository and Domain")
	
	Local $sWorkspace = "HKEY_CURRENT_USER\Software\Informatica\PowerMart Client Tools\10.5.4\Designer\Options\Global\Workspace"
	RegWrite($sWorkspace, "Workspace File Path", "REG_SZ", $WorkspaceFilePath)
	LogWrite("Setting up repository services")
	
	MessageUserOff()
    MessageUserOn($MESSAGE_TITLE, "Starting " & $DISPATCHER_NAME & @LF & "Please wait... Configuration setup (5/5)")
	If ($Debug) Then
		MessageUserOff()
		ToolTip("Launching pmdesign.exe")
	EndIf
	Local $PID
	$PID = Run($TargetEXE, "", @SW_HIDE)
	Sleep(3000)
	LogWrite("Launching " & """" & $TargetEXE)
	
	If $PID == 0 Then
		Error("Error running executable: " & @error & " - " & PSMGenericClient_PSMGetLastErrorString())
	EndIf
	$PID = PCToolsLogin()
	ToolTip("")
	Return $PID
	
	If ($Debug) Then
		LogWrite("1: " & $RunCleanup)
		LogWrite("2: " & $RunCfg)
		LogWrite("3: " & $RunDCconnect)
		LogWrite("4: " & $sWorkspace)
		LogWrite("5: " & $PID)
	EndIf
	
EndFunc   ;==>LaunchEXE

Func PCToolsLogin()

	MessageUserOff()
	Local $WinTitle, $WinTitle2, $WinText, $WinText1, $WinText2, $hMsg, $hMsg1, $hMsg2, $hCtl, $hWnd, $hTreeView, $hItemFound, $FinalWindow
	
	; Check that the client is open and send keystrokes
	
	$WinTitle = "Informatica PowerCenter Designer - [Start Page]"
	$WinText = ""
	$hMsg = WinWait($WinTitle, $WinText, 30)
	
	If WinActivate($hMsg) Then
	; Select the target repository under SysTreeView32 control	
	
			$hWnd = WinGetHandle($WinTitle)
			$hTreeView = ControlGetHandle($hWnd, "", "[CLASS:SysTreeView32; INSTANCE:1]")
			$hItemFound = _GUICtrlTreeView_FindItem($hTreeView, $Repository, True) 
			WinSetState($WinTitle, "", @SW_SHOW) ; This will remain SW_SHOW
			If $hItemFound <> 0 Then
				_GUICtrlTreeView_SelectItem($hTreeView, $hItemFound)
				_GUICtrlTreeView_ClickItem($hTreeView, $hItemFound)
				_GUICtrlTreeView_ClickItem($hTreeView, $hItemFound)
			Else
				LogWrite("Didn't find " & $hItemFound)
				Return (0)
			EndIf
	EndIf
	
	$WinTitle = "Connect to Repository"
	$WinText = "FIL_GenericAccounts"
	$WinTitle2 = "Designer"
	$WinText2 = "OK"
	$hMsg2 = WinWait($WinTitle2, $WinText2, 3)
	$hMsg = WinWait($WinTitle, $WinText, 3)
	$WinText1 = ""
	$hMsg1 = WinWait($WinTitle, $WinText1, 3)
			
	WinSetState($WinTitle, "", @SW_HIDE)
	If $hMsg2 <> 0 Then
		LogWrite("Found: " & $WinTitle2)
		LogWrite("Failed to connect using pmrep CLI. Connecting manually")
		MessageUserOff()
		MessageUserOn($MESSAGE_TITLE, "Failed to connect using pmrep CLI. Connecting manually" & @LF & "")
		WinActivate($hMsg2)
		Controlclick($hMsg2, "", "Button1", $_CTL_LEFT)
		Sleep(200)
		Controlclick($WinTitle, $WinText1, "Button7", $_CTL_LEFT)
		WinWait("Add Domain", "OK", 5)
		WinActivate("Add Domain", "OK")
		ControlSetText("Add Domain", "OK", "Edit1", $InfaDomain)
		ControlSetText("Add Domain", "OK", "Edit2", $TargetAddress)
		ControlSetText("Add Domain", "OK", "Edit3", $TargetPort)
		Controlclick("Add Domain", "OK", "Button1", $_CTL_LEFT)
	EndIf
	If WinActivate($hMsg) Then
		LogWrite("Found: " & $WinTitle & " and secure domain: " & $WinText)
		LogWrite("Sending credentials")
		$hCtl = ControlGetHandle($hMsg, "", "Button5")
			If $hCtl <> 0 Then
				ControlSend($hMsg, "", "", "!u")
				ControlSend($hMsg, "", "",$TargetUsername, 1)
				Sleep(100)
				ControlSend($hMsg, "", "", "!p")
				Sleep(100)
				ControlSend($hMsg, "", "",$TargetPassword, 1)
				Sleep(100)
				ControlSend($hMsg, "", "", "!c")
			Else
				LogWrite("Didn't find " & $hCtl)
				Return (0)
			EndIf
	ElseIf WinActivate($hMsg1) Then
		LogWrite("Found: " & $WinTitle)
		LogWrite("Sending credentials")
		ControlSend($hMsg1, "", "", "!u")
		ControlSend($hMsg1, "", "",$TargetUsername, 1)
		Sleep(100)
		ControlSend($hMsg1, "", "", "!p")
		Sleep(100)
		ControlSend($hMsg1, "", "",$TargetPassword, 1)
		Sleep(500)
		ControlCommand($hMsg1, "", "ComboBox3", "SelectString", $SecureDomain)
		ControlSend($hMsg1, "", "", "!c")
		WinWaitActive($_TXT_PCTOOLS)
		MessageUserOff()
	Else
		LogWrite("Couldn't determine any of the active windows")
		CloseSession()
	EndIf
	LogWrite("Connection successfully established..")
	LogWrite("Displaying " & $_TXT_PCTOOLS)
	MessageUserOff()
	Local $FinalWindow = WinWaitActive($_TXT_PCTOOLS)
	WinActivate($FinalWindow)
	WinSetState($FinalWindow, "", @SW_SHOWMAXIMIZED)
	Return WinGetProcess($FinalWindow)

EndFunc   ;==>PCToolsLogin()

; Return only the path part of a filename
;
Func FilePath($filename)

	Local $a = StringInStr($filename, "\", 0, -1)

	If $a == 0 Then Return ("")
	Return StringLeft($filename, $a)

EndFunc   ;==>FilePath

;==================================================================================================
; IsTrue($string) - return version message
; Abhishek Singh (FIL)
;
; Return TRUE if $string is True or some case insensitive text form of y/yes/true
; Otherwise return FALSE
;
;==================================================================================================
;
Func IsTrue($exp)
	If StringRegExp($exp, '^(?i)(true|y(es)?)$') Then Return True
	Return (False)
EndFunc   ;==>IsTrue

Func CloseSession()

	Local $WinTitle = $_TXT_PCTOOLS
	Local $WinText = ""
	Local $hMsg = WinWait($WinTitle, $WinText, 10)
	If $hMsg <> "" Then
		ProcessClose(WinGetProcess($hMsg))
	EndIf


EndFunc   ;==>CloseSession

Func EnterCreds()

		ControlSend("Connect to Repository", "L&ess <<", "", "!u")
		ControlSend("Connect to Repository", "L&ess <<", "",$TargetUsername, 1)
		Sleep(100)
		ControlSend("Connect to Repository", "L&ess <<", "", "!p")
		Sleep(100)
		ControlSend("Connect to Repository", "L&ess <<", "",$TargetPassword, 1)
		Sleep(100)

EndFunc   ;==>EnterCreds
; #FUNCTION# ====================================================================================================================
; Name...........: MessageUserOn
; Description ...: Writes a message to the user, and keeps it indefinitely (until function call to MessageUserOff)
; Parameters ....: $msgTitle - Title of the message
;                  $msgBody - Body of the message
; Return values .: none
; ===============================================================================================================================
Func MessageUserOn(Const ByRef $msgTitle, Const ByRef $msgBody)
	SplashOff()
    SplashTextOn ($msgTitle, $msgBody, -1, 54, -1, -1, 0, "Tahoma", 9, -1)
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: MessageUserOff
; Description ...: See SplashOff()
; Parameters ....:
;
; Return values .: none
; ===============================================================================================================================
Func MessageUserOff()
    SplashOff()
EndFunc
