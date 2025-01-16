#AutoIt3Wrapper_UseX64=n
Opt("MustDeclareVars", 1)
AutoItSetOption("WinTitleMatchMode", -1)
AutoItSetOption("SendKeyDelay", 30)


;============================================================
;             PSM-IBM-iSeries-ACS
;             -------------------
; PSM Connector to emulate IBM i ACS connections via CyberArk
; Abhishek Singh
;============================================================
#include <WinAPIEx.au3>
#include <AutoITConstants.au3>
#include <WindowsConstants.au3>
#include <GUIConstantsEx.au3>
#include <array.au3>
#include <PSMGenericClientWrapper.au3>
#include <BlockInputEx.au3>
#include <EditConstants.au3>
#include <clipboard.au3>
#include <ProgressConstants.au3>
#include <ColorConstants.au3>
;=======================================
; Consts & Globals
;=======================================
Global Const $DISPATCHER_NAME		= "IBM i ACS"
Global Const $ERROR_MESSAGE_TITLE  	= "PSM " & $DISPATCHER_NAME & " Dispatcher error message"
Global Const $LOG_MESSAGE_PREFIX 	= $DISPATCHER_NAME & " Dispatcher - "
Global Const $MESSAGE_TITLE	= $DISPATCHER_NAME

Global $CLIENT_EXECUTABLE
Global $JavaPath
Global $TargetLogonKeyWordList
Global $TargetLogonKeyWords
Global $TargetUsername
Global $TargetPassword
Global $TargetAddress
Global $PROGRESS_BAR 
Global $TraceMode
Global $TargetWSID
Global $Sleep = 200
Global $MedSleep = 500
Global $LongSleep = 3000
Global $ConnectionClientPID = 0


;=======================================
; Code
;=======================================
Exit Main()

;=======================================
; Main script starts here
;=======================================
Func Main()


	if (PSMGenericClient_Init() <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	LogWrite("successfully initialized Dispatcher Utils Wrapper")

	FetchSessionProperties()
	ProgressBarOn()

	if (PSMGenericClient_MapTSDrives() <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
	LogWrite("starting client application")
	_BlockInputEx(2)

	If ($TraceMode) Then
		ToolTip(" /plugin=cfg /SYSTEM="&$TargetAddress&" /userid="&$TargetUsername&" /ssl /r")
	EndIf
	Local $RunCfg = $CLIENT_EXECUTABLE & " -vm " & $JavaPath & " /PLUGIN=CFG /SYSTEM=" & $TargetAddress & " /USERID=" & $TargetUsername & " /ssl=1 /r" ; CONFIG TARGET
	RunWait($RunCfg,"",@SW_HIDE)
	LogWrite("Running command to configure this session")

	If ($TraceMode) Then
		ToolTip(" /PLUGIN=logon /SYSTEM="&$TargetAddress&" /C")
	EndIf
	Local $ClearCachedUidPwd = $CLIENT_EXECUTABLE  & " -vm " & $JavaPath & " /PLUGIN=logon /SYSTEM=" & $TargetAddress & " /C" ; CLEARS CACHE
	RunWait($ClearCachedUidPwd,"",@SW_HIDE)
	LogWrite("Running command to clear credential")

	If ($TraceMode) Then
		ToolTip(" /PLUGIN=logon /SYSTEM="&$TargetAddress&" /userid="&$TargetUsername&" /AUTH /GUI=1")
	EndIf
	Local $SignOnCommand = $CLIENT_EXECUTABLE & " -vm " & $JavaPath & " /PLUGIN=logon /SYSTEM=" & $TargetAddress & " /USERID=" & $TargetUsername & " /AUTH /GUI=1" ; CONFIG CRED
	Run($SignOnCommand)
	LogWrite("Running command to set credential")
	
	If ($TraceMode) Then
		LogWrite("1: " & $RunCfg)
		LogWrite("2: " & $ClearCachedUidPwd)
		LogWrite("3: " & $SignOnCommand)
	EndIf
	
	Local $cntwhile = 0
    Local $loginSent = 0
    Local $loginOK = 0
    While $loginOK == 0 And $cntwhile < 60
		Local $hMsg, $iMsg, $WinTitle, $WinText, $iTitle, $iText, $cTitle
		$WinTitle = "[TITLE:Signon to IBM i;CLASS:SunAwtDialog]"
		$WinText = ""
		$hMsg = 0
		$iTitle = "Informational Message"
		$iText = ""
		$iMsg = 0
		$cTitle = "Inquiry Message"
	
			If $loginSent == 0 Then
				$hMsg = WinWait($WinTitle, $WinText, 20)
				WinSetState($WinTitle, "", @SW_HIDE)
				If ($hMsg <> 0) Then
					WinActivate($hMsg)
					Sleep($Sleep)
					Send($TargetPassword,1)
					Sleep($Sleep)
					WinActivate($hMsg)
					Send("!o")
					$loginSent = True
				EndIf
			EndIf
			
			If ($loginSent And WinExists($cTitle)) Then
				ControlSend($cTitle, "", "", "{ENTER}")
				ControlSend($cTitle, "", "", "{ENTER}")
			EndIf
			
			If ($loginSent) Then
				$iMsg = WinWait($iTitle, $iText, 4)
				If ($iMsg <> 0) Then
					WinActivate($iMsg)
					ControlSend($iMsg, "", "", "!o")
					$loginOK = True
					LogWrite("End while cycle due to successful login")
					ExitLoop
				ElseIf WinExists("Error Message","") Then
					ProgressBarOff()
					Error("Failed to log in with stored credentials")
					ExitLoop
				EndIf
			EndIf
	  $cntwhile+=1
	  LogWrite("Checking GUIs While 1 - Sleep "&$cntwhile)
    WEnd
	If ($loginOK) Then
		LogWrite("Launching: " & $CLIENT_EXECUTABLE)
		If WinExists("Error Message","") Then
			Sleep($MedSleep)
			Error("Error during login")
			CloseSession()
		EndIf
		If $TargetWSID <> "" Then
			$ConnectionClientPID = Run($CLIENT_EXECUTABLE & " /PLUGIN=5250 /SYSTEM=" & $TargetAddress & " /name=" & "PSM-" & $TargetUsername & "-" & $TargetAddress & " /wsid=" & $TargetWSID & " /wide=1 /sso=0 /ssl=1 /nosave=1")
		Else
			$ConnectionClientPID = Run($CLIENT_EXECUTABLE & " /PLUGIN=5250 /SYSTEM=" & $TargetAddress & " /name=" & "PSM-" & $TargetUsername & "-" & $TargetAddress & " /wide=1 /sso=0 /ssl=1 /nosave=1")
		EndIf
	EndIf
		If($ConnectionClientPID == 0) Then
			Error(StringFormat("Failed to execute process [%s]", $ConnectionClientPID, @error))
		EndIf
	If ($loginOK) Then
			If WinExists("Error Message","") Then
				Error("Failed to log in with stored credentials")
				CloseSession()
			EndIf
			
			Local $Title, $Text, $hMsg, $i, $j, $keywordsFound
			
			$Title = "[REGEXPTITLE:.*"&$TargetAddress&".*;CLASS:SunAwtFrame]"
			$Text = "128"
			$hMsg = WinWait($Title, $Text, 30)

			If $hMsg <> 0 Then
				WinActivate($hMsg)
				$keywordsFound = True
				For $i = 1 To 10
					WinActivate($hMsg)
					Sleep($LongSleep)
					Send("^a")
					WinActivate($hMsg)
					Send("^c")
					Local $Clip = _ClipBoard_GetData($CF_TEXT)
					For $j = 1 To $TargetLogonKeyWords[0]
						If StringInStr($Clip, $TargetLogonKeyWords[$j], 0) = 0 Then
							$keywordsFound = False
						Else
							$keywordsFound = True
							ExitLoop
						EndIf
					Next
					If $keywordsFound Then
						ExitLoop
					Else
						LogWrite("Attempt " & ($i + 1) & ": Waiting for logon screen")
						Sleep($MedSleep)
					EndIf
				Next
				If $keywordsFound Then
					ToolTip("Logging on..")
					LogWrite("Found logon keyswords. Attempting login")
					WinActivate($hMsg)
					Sleep($Sleep)
					Send("{HOME}{ENTER}{END}") ; Making sure the cursor is in the username field
					Sleep($Sleep)
					Send($TargetUsername, $SEND_RAW)
					If StringLen($TargetUsername) < 10 Then
						LogWrite("Username: " & $TargetUsername & " is less than 10 chars. Sending tab")
						Send("{TAB}")
					EndIf
					Send($TargetPassword, $SEND_RAW)
					If StringLen($TargetPassword) < 10 Then
						LogWrite("Password is less than 10 chars. Sending tab")
						Send("{TAB}")
					EndIf
					Send("{ENTER}")
					Sleep($MedSleep)
				Else
					LogWrite("Login screen not detected after " & ($i + 1) & " attempts.")
				EndIf
			Else
				LogWrite("Never saw the Session Window - aborting")
				CloseSession()
				Return 0
			EndIf
			_ClipBoard_SetData("")
			WinActivate($hMsg)
			WinSetState($Title, "", @SW_SHOW)
			_BlockInputEx(1)
	Else
		LogWrite("Login was never sent - aborting")
		CloseSession()
	EndIf

	; Send PID to PSM so recording/monitoring can begin
	; Notice that until we send the PID, PSM blocks all user input.
	LogWrite("Sending PID to PSM")

	if (PSMGenericClient_SendPID($ConnectionClientPID) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	ProgressBarOff()
	; Terminate PSM Dispatcher utils wrapper
	LogWrite("Terminating Dispatcher Utils Wrapper")
	Return $PSM_ERROR_SUCCESS
	PSMGenericClient_Term()

EndFunc


;==================================
; Functions
;==================================

; #FUNCTION# ====================================================================================================================

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

Func CloseSession()

	Local $WinTitle = "[REGEXPTITLE:.*"&$TargetAddress&".*;CLASS:SunAwtFrame]"
	Local $WinText = "128"
	Local $hMsg = WinWait($WinTitle, $WinText, 10)
	If $hMsg <> "" Then
		ProcessClose($iPID)
		ProcessClose(WinGetProcess($hMsg))
	EndIf

EndFunc   ;==>CloseSession

; #FUNCTION# ====================================================================================================================
; Name...........: LogWrite
; Description ...: Write a PSMWinSCPDispatcher log message to standard PSM log file
; Parameters ....: $sMessage - [IN] The message to write
;                  $LogLevel - [Optional] [IN] Defined if the message should be handled as an error message or as a trace messge
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
Func FetchSessionProperties() ; CHANGE_ME

	if (PSMGenericClient_GetSessionProperty("Username", $TargetUsername) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
	if (PSMGenericClient_GetSessionProperty("Password", $TargetPassword) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf

	if (PSMGenericClient_GetSessionProperty("Address", $TargetAddress) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
	if (PSMGenericClient_GetSessionProperty("CLIENT_EXECUTABLE", $CLIENT_EXECUTABLE) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
	if (PSMGenericClient_GetSessionProperty("JavaPath", $JavaPath) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
	If (PSMGenericClient_GetSessionProperty("LogonKeywords", $TargetLogonKeyWordList) <> $PSM_ERROR_SUCCESS) Then
		$TargetLogonKeyWordList = "user,password,sign,on"
	EndIf
	$TargetLogonKeyWords = StringSplit($TargetLogonKeyWordList, ",")
	
	If (PSMGenericClient_GetSessionProperty("WSID", $TargetWSID) <> $PSM_ERROR_SUCCESS) Then
		$TargetWSID = ""
	EndIf
	
	if (PSMGenericClient_GetSessionProperty("TraceMode", $TraceMode) <> $PSM_ERROR_SUCCESS) Then
	 LogWrite(PSMGenericClient_PSMGetLastErrorString())
	 $TraceMode = False
	Else
		If ($TraceMode == "Yes") Then
			$TraceMode = True
		Else
			$TraceMode = False
		EndIf
	EndIf
	If (PSMGenericClient_GetSessionProperty("PROGRESS_BAR", $PROGRESS_BAR) <> $PSM_ERROR_SUCCESS) Then
		Error("Error opening template file " & PSMGenericClient_PSMGetLastErrorString())
	 EndIf
	  
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: ProgressBarOn
; Description ...: Opens CyberArk Progress Bar
; Return values .: none
; ===============================================================================================================================
Func ProgressBarOn()
			LogWrite("Launching progress bar.")
			Global $iPID = Run($PROGRESS_BAR)
			ProcessWait($iPID)
			Return $iPID
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: ProgressBarOff
; Description ...: Closes CyberArk Progress Bar process
; Return values .: none
; ===============================================================================================================================
Func ProgressBarOff()
		LogWrite("Closing progress bar.")
        ProcessClose($iPID)
EndFunc
