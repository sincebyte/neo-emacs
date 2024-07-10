#k::
   WinTitle := "ahk_exe emacs.exe"
   WinGet WinState, MinMax, %WinTitle%  ; retrieve minimized/maximized state
      if (WinState = -1)                ; minimized
         WinRestore, %WinTitle%
      else                              ; not minimized
         WinMinimize, %WinTitle%
Return

!k::
   WinTitle := "ahk_exe emacs.exe"
   WinGet WinState, MinMax, %WinTitle%  ; retrieve minimized/maximized state
      if (WinState = -1)                ; minimized
         WinRestore, %WinTitle%
      else                              ; not minimized
         WinMinimize, %WinTitle%
Return

#r::
   WinTitle := "ahk_class Chrome_WidgetWin_1"
   WinGet WinState, MinMax, %WinTitle%  ; retrieve minimized/maximized state
      if (WinState = -1)                ; minimized
         WinRestore, %WinTitle%
      else                              ; not minimized
         WinMinimize, %WinTitle%
Return

!r::
   WinTitle := "ahk_class Chrome_WidgetWin_1"
   WinGet WinState, MinMax, %WinTitle%  ; retrieve minimized/maximized state
      if (WinState = -1)                ; minimized
         WinRestore, %WinTitle%
      else                              ; not minimized
         WinMinimize, %WinTitle%
Return


#;::
   WinTitle := "ahk_exe WXWork.exe"
   WinGet WinState, MinMax, %WinTitle%  ; retrieve minimized/maximized state
      if (WinState = -1)                ; minimized
         WinRestore, %WinTitle%
      else                              ; not minimized
         WinMinimize, %WinTitle%
Return


#c::
send ^c
Return

#v::
send ^v
Return

#x::
send ^x
Return

#z::
send ^z
Return

#y::
send ^y
Return


!c::
send ^c
Return

!v::
send ^v
Return

!x::
send ^x
Return

!z::
send ^z
Return

!y::
send ^y
Return

!d::
send #d
Return


F7::
Suspend, Off
Pause, Off, 1
If (toggle := !toggle) 
 Suspend, On
 Pause, On, 1
Return




g_LastCtrlKeyDownTime := 0
g_AbortSendEsc := false
g_ControlRepeatDetected := false

*CapsLock::
    if (g_ControlRepeatDetected)
    {
        return
    }

    send,{Ctrl down}
    g_LastCtrlKeyDownTime := A_TickCount
    g_AbortSendEsc := false
    g_ControlRepeatDetected := true

    return

*CapsLock Up::
    send,{Ctrl up}
    g_ControlRepeatDetected := false
    if (g_AbortSendEsc)
    {
        return
    }
    current_time := A_TickCount
    time_elapsed := current_time - g_LastCtrlKeyDownTime
    if (time_elapsed <= 250)
    {
        SendInput {Esc}
    }
    return


