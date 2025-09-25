#include <File.au3>
#include <InetConstants.au3>
#include <Date.au3>

;============================================================
;           Update Webdriver utility
;           -------------------------
; Description : Updates MSEdge and Chrome webdriver
; Created : 25.09.2025
; © Abhishek Singh (FIL)
; Developed and compiled in AutoIt 3.3.14.1
;============================================================

Global Const $g_sDriverPath = "D:\CyberArk\PSM\"
Global Const $g_sLogFile = $g_sDriverPath & "\WebDriverUpdater_" & @MDAY & "-" & @MON & "-" & @YEAR & ".log"

; ========== Check & Update Webdrivers ============

UpdateWebDriver("GoogleChrome")
UpdateWebDriver("MSEdge")

; ============ MAIN FUNCTION  ============

Func UpdateWebDriver($sBrowser)
   Local $sExe, $sBit, $sVer, $sMajorVer, $sUrl, $sDriverFile

   If $sBrowser = "GoogleChrome" Then
       $sExe = @ProgramFilesDir & "\Google\Chrome\Application\chrome.exe"
       If Not FileExists($sExe) Then $sExe = @ProgramFilesDir & " (x86)\Google\Chrome\Application\chrome.exe"
   ElseIf $sBrowser = "MSEdge" Then
       $sExe = @ProgramFilesDir & "\Microsoft\Edge\Application\msedge.exe"
       If Not FileExists($sExe) Then $sExe = @ProgramFilesDir & " (x86)\Microsoft\Edge\Application\msedge.exe"
   EndIf
   If Not FileExists($sExe) Then
       LogWrite($sBrowser & " not found")
       Return
   EndIf

   If StringInStr($sExe, "(x86)") Then
       $sBit = "32"
   Else
       $sBit = "64"
   EndIf

   $sVer = FileGetVersion($sExe)
   If @error Or $sVer = "" Then
       LogWrite($MB_ICONERROR & "Error. Could not detect " & $sBrowser & " version")
       Return
   EndIf
   $sMajorVer = StringRegExpReplace($sVer, "^(\d+)\..*", "\1")

   If $sBrowser = "GoogleCrome" Then
       $sDriverFile = $g_sDriverPath & "chromedriver.exe"
   Else
       $sDriverFile = $g_sDriverPath & "msedgedriver.exe"
   EndIf

   If FileExists($sDriverFile) Then
       Local $sDrvVer = FileGetVersion($sDriverFile)
       If $sDrvVer = $sVer Then
           LogWrite($sBrowser & " webdriver already matches major version " & $sDrvVer)
           Return
	   Else
		   LogWrite($sBrowser & " webdriver version mismatch (found " & $sDrvVer & ", browser " & $sVer & ")")
       EndIf
	Else
	   LogWrite($sBrowser & " driver not found. Downloading new driver")
   EndIf

   Local $sDriverVer, $sApi, $sVerFile
   If $sBrowser = "GoogleChrome" Then
       $sApi = "https://chromedriver.storage.googleapis.com/LATEST_RELEASE_" & $sVer
       $sVerFile = $g_sDriverPath & "\chrome_latest.txt"
       InetGet($sApi, $sVerFile, $INET_FORCERELOAD, $INET_DOWNLOADWAIT)
       $sDriverVer = StringStripWS(FileRead($sVerFile), 3)
       FileDelete($sVerFile)
       If $sDriverVer = "" Then
           LogWrite("Error- Could not fetch ChromeDriver version")
           Return
       EndIf

       $sUrl = "https://chromedriver.storage.googleapis.com/" & $sDriverVer & "/chromedriver_win32.zip"
   ElseIf $sBrowser = "MSEdge" Then
       $sApi = "https://msedgedriver.azureedge.net/LATEST_RELEASE_" & $sVer
       $sVerFile = $g_sDriverPath & "\edge_latest.txt"
       InetGet($sApi, $sVerFile, $INET_FORCERELOAD, $INET_DOWNLOADWAIT)
       $sDriverVer = StringStripWS(FileRead($sVerFile), 3)
       FileDelete($sVerFile)
       If $sDriverVer = "" Then
           LogWrite("Error - Could not fetch EdgeDriver version")
           Return
       EndIf
       If $sBit = "64" Then
           $sUrl = "https://msedgedriver.azureedge.net/" & $sDriverVer & "/edgedriver_win64.zip"
       Else
           $sUrl = "https://msedgedriver.azureedge.net/" & $sDriverVer & "/edgedriver_win32.zip"
       EndIf
   EndIf

   Local $sZip = $g_sDriverPath & $sBrowser & "_driver.zip"
   InetGet($sUrl, $sZip, $INET_FORCERELOAD, $INET_DOWNLOADWAIT)
   If Not FileExists($sZip) Then
       LogWrite("Error- Failed to download " & $sBrowser & " driver")
       Return
   EndIf

   If FileExists($sDriverFile) Then FileDelete($sDriverFile)
   _ExtractZip($sZip, $g_sDriverPath)
   FileDelete($sZip)
   LogWrite($sBrowser & " webdriver updated successfully to version " & $sDriverVer)
EndFunc

; =================== Extract Zip using Shell.Application ===================
Func _ExtractZip($sZipFile, $sDestFolder)
   Local $oShell = ObjCreate("Shell.Application")
   If Not FileExists($sDestFolder) Then DirCreate($sDestFolder)
   Local $oZip = $oShell.NameSpace($sZipFile)
   If IsObj($oZip) Then
       $oShell.NameSpace($sDestFolder).CopyHere($oZip.Items, 4 + 16)
   EndIf
EndFunc

; =================== Write Log messages ===================
Func LogWrite($lMsg)
   Local $sTime = _NowCalcDate() & " " & @HOUR & ":" & @MIN & ":" & @SEC
   Local $sTime = StringFormat("%02d-%02d-%04d %02d:%02d:%02d", @MDAY, @MON, @YEAR, @HOUR, @MIN, @SEC)
   Local $hFile = FileOpen($g_sLogFile, 1)
   If $hFile = -1 Then Return
   FileWriteLine($hFile, $sTime & " - " & $lMsg)
   FileClose($hFile)
EndFunc
