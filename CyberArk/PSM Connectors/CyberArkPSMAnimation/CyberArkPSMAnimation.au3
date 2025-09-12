#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <ProgressConstants.au3>
#include <StaticConstants.au3>
#include <ColorConstants.au3>
#include <WinAPISys.au3>

;============================================================
;            AnimationWrapper
;           -----------------
; Created : SEP - 2025
; Created By: © Abhishek Singh 
; Description : AutoIT wrapper to run animation during login process
; Usage : Start_Animation("Progress") or Start_Animation("CyberArk")
; Just use #include<CyberArkPSMAnimation.au3> in your scripts
;
;============================================================

;====================================
; Globals
;====================================
Global $Loader_hGUI, $Loader_Mode
Global $Loader_hProgress, $Loader_hPercentage, $Loader_ProgressValue = 0
Global $Loader_lblOutline[4], $Loader_lblMain
Global $Loader_dots[8], $Loader_currentFrame = 0
Global $Loader_dotBaseSize = 18, $Loader_dotMaxSize = 24
Global $Loader_dotColors[4] = [0x222222, 0x555555, 0xAAAAAA, 0xFFFFFF]
;====================================
; Show + Start Loader
;====================================
Func Start_Animation($mode = "Progress", $text = "CyberArk")
   $Loader_Mode = StringLower($mode)
   Local $w = @DesktopWidth, $h = @DesktopHeight
   $Loader_hGUI = GUICreate("Loader", $w, $h, 0, 0, $WS_POPUP, $WS_EX_TOPMOST)
   Local $bkLabel = GUICtrlCreateLabel("", 0, 0, $w, $h)
   GUICtrlSetBkColor($bkLabel, 0x000000)
   If $Loader_Mode = "Progress" Then
       ; Text
       Local $lbl = GUICtrlCreateLabel("Please wait while we log you in...", ($w-400)/2, ($h/2)-50, 400, 40, $SS_CENTER)
       GUICtrlSetFont($lbl, 12, 700)
       GUICtrlSetColor($lbl, 0xFFFFFF)
       GUICtrlSetBkColor($lbl, 0x000000)
       ; Progress bar
       $Loader_hProgress = GUICtrlCreateProgress(($w-400)/2, ($h/2), 400, 20, $PBS_SMOOTH)
       $Loader_hPercentage = GUICtrlCreateLabel("0%", ($w-400)/2, ($h/2)-25, 400, 20, $SS_CENTER)
       GUICtrlSetFont($Loader_hPercentage, 12, 700)
       GUICtrlSetColor($Loader_hPercentage, 0xFFFFFF)
       GUICtrlSetBkColor($Loader_hPercentage, $GUI_BKCOLOR_TRANSPARENT)
       ; Start updating
       $Loader_ProgressValue = 0
       AdlibRegister("Loader_UpdateProgress", 100)
   Else
       Local $cx = $w / 2, $cy = ($h / 2) - 100
       Local $fontSize = 36

       $Loader_lblOutline[0] = GUICtrlCreateLabel($text, $cx - 101, $cy - 49, 200, 60, $SS_CENTER)
       $Loader_lblOutline[1] = GUICtrlCreateLabel($text, $cx - 99,  $cy - 49, 200, 60, $SS_CENTER)
       $Loader_lblOutline[2] = GUICtrlCreateLabel($text, $cx - 101, $cy - 51, 200, 60, $SS_CENTER)
       $Loader_lblOutline[3] = GUICtrlCreateLabel($text, $cx - 99,  $cy - 51, 200, 60, $SS_CENTER)
       For $i = 0 To 3
           GUICtrlSetFont($Loader_lblOutline[$i], $fontSize, 800, 0, "Segoe UI Bold")
           GUICtrlSetColor($Loader_lblOutline[$i], 0xFFFFFF)
           GUICtrlSetBkColor($Loader_lblOutline[$i], $GUI_BKCOLOR_TRANSPARENT)
       Next

       $Loader_lblMain = GUICtrlCreateLabel($text, $cx - 100, $cy - 50, 200, 60, $SS_CENTER)
       GUICtrlSetFont($Loader_lblMain, $fontSize, 800, 0, "Segoe UI Bold")
       GUICtrlSetColor($Loader_lblMain, 0x0033A1) ; CyberArk blue
       GUICtrlSetBkColor($Loader_lblMain, $GUI_BKCOLOR_TRANSPARENT)

       Local $r = 50, $dotSize = 20
       For $i = 0 To 7
           Local $angle = ($i * 45) * (3.14159 / 180)
           Local $x = $cx + Cos($angle) * $r - ($dotSize / 2)
           Local $y = ($h / 2) + Sin($angle) * $r - ($dotSize / 2)
           $Loader_dots[$i] = GUICtrlCreateLabel("?", $x, $y, $dotSize, $dotSize, $SS_CENTER)
           GUICtrlSetFont($Loader_dots[$i], $Loader_dotBaseSize, 400, 0, "Segoe UI Symbol")
           GUICtrlSetColor($Loader_dots[$i], 0x444444)
           GUICtrlSetBkColor($Loader_dots[$i], $GUI_BKCOLOR_TRANSPARENT)
       Next
       ; Start animation
       $Loader_currentFrame = 0
       AdlibRegister("Loader_AnimateDots", 120)
   EndIf
   GUISetState(@SW_SHOW, $Loader_hGUI)
   ; Transparency (70%)
   Local $hWnd = WinGetHandle("Loader", "")
   If $hWnd Then
       Local $oldStyle = _WinAPI_GetWindowLong($hWnd, $GWL_EXSTYLE)
       _WinAPI_SetWindowLong($hWnd, $GWL_EXSTYLE, BitOR($oldStyle, $WS_EX_LAYERED, $WS_EX_TRANSPARENT))
       DllCall("user32.dll", "bool", "SetLayeredWindowAttributes", "hwnd", $hWnd, "dword", 0, "byte", 178, "dword", 0x02)
       WinSetState($hWnd, "", @SW_SHOW)
   EndIf
EndFunc
;====================================
; Progress update
;====================================
Func Loader_UpdateProgress()
   $Loader_ProgressValue += 2
   If $Loader_ProgressValue > 100 Then $Loader_ProgressValue = 0
   GUICtrlSetData($Loader_hProgress, $Loader_ProgressValue)
   GUICtrlSetData($Loader_hPercentage, $Loader_ProgressValue & "%")
   GUIGetMsg()
EndFunc

Func Loader_AnimateDots()
   For $i = 0 To 7
       Local $offset = Mod(($i - $Loader_currentFrame) + 8, 8)
       If $offset = 0 Then
           GUICtrlSetColor($Loader_dots[$i], $Loader_dotColors[3])
           GUICtrlSetFont($Loader_dots[$i], $Loader_dotMaxSize, 700, 0, "Segoe UI Symbol")
       ElseIf $offset = 1 Or $offset = 7 Then
           GUICtrlSetColor($Loader_dots[$i], $Loader_dotColors[2])
           GUICtrlSetFont($Loader_dots[$i], $Loader_dotBaseSize + 3, 600, 0, "Segoe UI Symbol")
       ElseIf $offset = 2 Or $offset = 6 Then
           GUICtrlSetColor($Loader_dots[$i], $Loader_dotColors[1])
           GUICtrlSetFont($Loader_dots[$i], $Loader_dotBaseSize, 500, 0, "Segoe UI Symbol")
       Else
           GUICtrlSetColor($Loader_dots[$i], $Loader_dotColors[0])
           GUICtrlSetFont($Loader_dots[$i], $Loader_dotBaseSize, 400, 0, "Segoe UI Symbol")
       EndIf
   Next
   $Loader_currentFrame = Mod($Loader_currentFrame + 1, 8)
EndFunc
;====================================
; Stop + Hide Loader
;====================================
Func Stop_Animation()
   If $Loader_Mode = "Progress" Then
       AdlibUnRegister("Loader_UpdateProgress")
   Else
       AdlibUnRegister("Loader_AnimateDots")
   EndIf

   Local $hWnd = WinGetHandle("Loader", "")
   If $hWnd Then
       For $i = 178 To 0 Step -15
           DllCall("user32.dll", "bool", "SetLayeredWindowAttributes", "hwnd", $hWnd, "dword", 0, "byte", $i, "dword", 0x02)
           Sleep(15)
       Next
   EndIf
   GUIDelete($Loader_hGUI)
EndFunc
