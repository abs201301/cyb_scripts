#include <File.au3>
#include <InetConstants.au3>
#include <Date.au3>
;============================================================
;           Update Webdriver utility
;           -------------------------
; Description : Updates MSEdge and Chrome webdriver
; Created : 25.09.2025
; © Abhishek Singh
; Developed and compiled in AutoIt 3.3.14.1
;============================================================
Global Const $g_sDriverPath = "D:\NewFolder"
Global Const $g_sLogFile = $g_sDriverPath & "\WebDriverUpdater_" & StringFormat("%02d-%02d-%04d", @MDAY, @MON, @YEAR) & ".log"

; ========== Check & Update Webdrivers ============
UpdateWebDriver("GoogleChrome")
UpdateWebDriver("MSEdge")

; ============ MAIN FUNCTION  ============
Func UpdateWebDriver($sBrowser)
   Local $sExe, $sBit, $sVer, $sDriverFile, $sUrl

   If $sBrowser = "GoogleChrome" Then
       $sExe = @ProgramFilesDir & "\Google\Chrome\Application\chrome.exe"
       If Not FileExists($sExe) Then $sExe = @ProgramFilesDir & " (x86)\Google\Chrome\Application\chrome.exe"
   ElseIf $sBrowser = "MSEdge" Then
       $sExe = @ProgramFilesDir & "\Microsoft\Edge\Application\msedge.exe"
       If Not FileExists($sExe) Then $sExe = @ProgramFilesDir & " (x86)\Microsoft\Edge\Application\msedge.exe"
   EndIf
   If Not FileExists($sExe) Then
       LogWrite($sBrowser & " not found", True)
       Return
   EndIf

   $sBit = StringInStr($sExe, "(x86)") ? "32" : "64"

   $sVer = FileGetVersion($sExe)
   If @error Or $sVer = "" Then
       LogWrite("Error. Could not detect " & $sBrowser & " version", True)
       Return
   EndIf
   LogWrite("Detected browser: " & $sBrowser & " with version: " & $sVer)

   $sDriverFile = ($sBrowser = "GoogleChrome") ? $g_sDriverPath & "\chromedriver.exe" : $g_sDriverPath & "\msedgedriver.exe"

   If FileExists($sDriverFile) Then
       Local $sDrvVer = FileGetVersion($sDriverFile)
	   LogWrite("Found " & $sDriverFile & " with version: " & $sDrvVer)
       If $sDrvVer = $sVer Then
           LogWrite($sBrowser & " webdriver already matches exact version: " & $sDrvVer, True)
           Return
       Else
           LogWrite($sBrowser & " webdriver version mismatch (found " & $sDrvVer & ", browser " & $sVer & ")")
       EndIf
   Else
       LogWrite($sBrowser & " driver not found. Downloading new driver")
   EndIf

   If $sBrowser = "GoogleChrome" Then
       Local $sArch = ($sBit = "64") ? "win64" : "win32"
       $sUrl = "https://storage.googleapis.com/chrome-for-testing-public/" & $sVer & "/" & $sArch & "/chromedriver-" & $sArch & ".zip"
   ElseIf $sBrowser = "MSEdge" Then
       $sUrl = "https://msedgewebdriverstorage.blob.core.windows.net/edgewebdriver/" & $sVer & "/edgedriver_win" & $sBit & ".zip"
   EndIf

   Local $sZip = $g_sDriverPath & "\" & $sBrowser & "_driver.zip"
   If Not _DownloadWithRetry($sUrl, $sZip) Then
       LogWrite("Error - Failed to download driver ZIP after multiple attempts: " & $sUrl, True)
       Return
   EndIf

   If FileExists($sDriverFile) Then
	  FileDelete($sDriverFile)
   EndIf
   _ExtractZip($sZip, $g_sDriverPath, $sBrowser)
   FileDelete($sZip)
   LogWrite($sBrowser & " webdriver updated successfully to version: " & $sVer, True)

EndFunc

; =================== Helper: Download with retry ===================
Func _DownloadWithRetry($sUrl, $sDest, $iMaxRetries = 3, $iWaitSec = 5)
   Local $iAttempt = 0
   While $iAttempt < $iMaxRetries
       InetGet($sUrl, $sDest, $INET_FORCERELOAD, $INET_DOWNLOADWAIT)
       If FileExists($sDest) Then Return True
       $iAttempt += 1
       LogWrite("Download failed for " & $sUrl & ". Retry " & $iAttempt & " of " & $iMaxRetries)
       Sleep($iWaitSec * 1000)
   WEnd
   Return False
EndFunc

; =================== Extract Zip using Shell.Application ===================
Func _ExtractZip($sZipFile, $sDestFolder, $sBrowser)
   Local $oShell = ObjCreate("Shell.Application")
   If Not FileExists($sDestFolder) Then DirCreate($sDestFolder)
   Local $oZip = $oShell.NameSpace($sZipFile)
   If IsObj($oZip) Then
       $oShell.NameSpace($sDestFolder).CopyHere($oZip.Items, 4 + 16)
   EndIf

   If $sBrowser = "GoogleChrome" Then
       Local $sSubFolder32 = $sDestFolder & "\chromedriver-win32\chromedriver.exe"
       Local $sSubFolder64 = $sDestFolder & "\chromedriver-win64\chromedriver.exe"
       If FileExists($sSubFolder32) Then
           If FileExists($sDestFolder & "\chromedriver.exe") Then FileDelete($sDestFolder & "\chromedriver.exe")
           FileMove($sSubFolder32, $sDestFolder & "\chromedriver.exe")
           DirRemove($sDestFolder & "\chromedriver-win32", 1)
       ElseIf FileExists($sSubFolder64) Then
           If FileExists($sDestFolder & "\chromedriver.exe") Then FileDelete($sDestFolder & "\chromedriver.exe")
           FileMove($sSubFolder64, $sDestFolder & "\chromedriver.exe")
           DirRemove($sDestFolder & "\chromedriver-win64", 1)
       EndIf
   EndIf
EndFunc

; =================== Write Log messages ===================
Func LogWrite($lMsg, $Separator = False)
   Local $sTime = StringFormat("%02d/%02d/%04d %02d:%02d:%02d", @MDAY, @MON, @YEAR, @HOUR, @MIN, @SEC)
   Local $hFile = FileOpen($g_sLogFile, 1) 
   If $hFile = -1 Then Return
   FileWriteLine($hFile, $sTime & " - " & $lMsg)
   If $Separator Then
		FileWriteLine($hFile, "========================================================================================")
   EndIf
   FileClose($hFile)
EndFunc
