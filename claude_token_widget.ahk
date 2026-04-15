#Requires AutoHotkey v2.0
#SingleInstance Force

DATA_FILE  := A_Temp "\claude_tokens.json"
WATCHER_JS := A_ScriptDir "\watcher.js"
REFRESH_MS := 900
TRACK_MS   := 1000

WIDGET_W := 280,  WIDGET_H := 80
MINI_W   := 140,  MINI_H   := 28

global wGui, lblTitle, lblPct, lblCount, pBar, lblBar
global btnRefresh, btnMin, btnClose
global gTokens    := 0
global gMax       := 200000
global gLastMod   := ""
global gVisible    := false
global gMinimized  := false
global gBuilt      := false
global gUserClosed := false

A_TrayMenu.Delete()
A_TrayMenu.Add("Show / Hide",  ToggleWidget)
A_TrayMenu.Add("Refresh",      RefreshNow)
A_TrayMenu.Add("Reset",        ResetCounter)
A_TrayMenu.Add()
A_TrayMenu.Add("Exit",         (*) => ExitApp())

SetTimer(TrackClaude, TRACK_MS)
SetTimer(Poll,        REFRESH_MS)
return

; -----------------------------------------------------------
; BUILD WIDGET
; -----------------------------------------------------------
BuildWidget(wx, wy) {
    global wGui, lblTitle, lblPct, lblCount, pBar
    global btnRefresh, btnMin, btnClose
    global WIDGET_W, WIDGET_H, gBuilt, gVisible

    wGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    wGui.BackColor := "0C0C0A"
    wGui.MarginX := 0
    wGui.MarginY := 0

    ; Top accent bar (2px blue line)
    accentBar := wGui.Add("Progress", "x0 y0 w280 h2 Smooth", 100)
    try DllCall("uxtheme\SetWindowTheme", "Ptr", accentBar.Hwnd, "Str", " ", "Str", " ")
    SendMessage(0x0409, 0, 0x1A56FF, accentBar)
    SendMessage(0x2001, 0, 0x0C0C0A, accentBar)

    ; Title label
    wGui.SetFont("s6 c525250 Bold", "Segoe UI")
    lblTitle := wGui.Add("Text", "x14 y10 w190 h12 BackgroundTrans", "CLAUDE  .  CONTEXT WINDOW")

    ; Control buttons (Text controls - transparent background, no white box)
    wGui.SetFont("s8 c656563 Bold", "Segoe UI")
    btnClose   := wGui.Add("Text", "x258 y5 w16 h16 BackgroundTrans Center", "x")
    btnMin     := wGui.Add("Text", "x238 y5 w16 h16 BackgroundTrans Center", "-")
    btnRefresh := wGui.Add("Text", "x218 y5 w16 h16 BackgroundTrans Center", "R")

    btnClose.OnEvent("Click",   CloseWidget)
    btnMin.OnEvent("Click",     ToggleMinimize)
    btnRefresh.OnEvent("Click", RefreshNow)

    ; Big percentage
    wGui.SetFont("s26 cF2F1ED Bold", "Segoe UI")
    lblPct := wGui.Add("Text", "x12 y22 w130 h38 BackgroundTrans", "0%")

    ; Token count - right side, two rows
    wGui.SetFont("s6 c555553", "Segoe UI")
    lblCount := wGui.Add("Text", "x142 y38 w126 h14 BackgroundTrans Right", "0 / 200,000")

    ; Progress bar - bottom strip
    pBar := wGui.Add("Progress", "x0 y72 w280 h8 Smooth", 0)
    try DllCall("uxtheme\SetWindowTheme", "Ptr", pBar.Hwnd, "Str", " ", "Str", " ")
    SendMessage(0x0409, 0, 0x4EC429, pBar)
    SendMessage(0x2001, 0, 0x161614, pBar)

    try {
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", wGui.Hwnd, "UInt", 33, "Int*", 2, "Int", 4)
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", wGui.Hwnd, "UInt", 2,  "Int*", 1, "Int", 4)
    }

    WinSetTransparent(235, wGui)
    wGui.OnEvent("Close", CloseWidget)
    OnMessage(0x0201, OnLBDown)

    wGui.Show("x" wx " y" wy " w" WIDGET_W " h" WIDGET_H " NoActivate")
    gBuilt   := true
    gVisible := true
}

; -----------------------------------------------------------
; TRACK CLAUDE
; -----------------------------------------------------------
TrackClaude(*) {
    global wGui, gVisible, gBuilt, gMinimized
    global WIDGET_W, WIDGET_H, MINI_W, MINI_H

    claudeHwnd := FindClaudeWindow()

    if !claudeHwnd {
        if gVisible && gBuilt {
            wGui.Hide()
            gVisible := false
        }
        return
    }

    if WinGetMinMax("ahk_id " claudeHwnd) = -1 {
        if gVisible && gBuilt {
            wGui.Hide()
            gVisible := false
        }
        return
    }

    WinGetPos(&cx, &cy, &cw, &ch, "ahk_id " claudeHwnd)
    ww := gMinimized ? MINI_W : WIDGET_W
    wh := gMinimized ? MINI_H : WIDGET_H
    wx := cx + cw - ww - 14
    wy := cy + ch - wh - 14

    if !gBuilt {
        BuildWidget(wx, wy)
        RefreshNow()
        return
    }

    if !gVisible && !gUserClosed {
        wGui.Show("NoActivate")
        gVisible := true
    }

    if !gVisible
        return

    try {
        WinGetPos(&curX, &curY, , , "ahk_id " wGui.Hwnd)
        if (Abs(curX - wx) > 2 || Abs(curY - wy) > 2)
            wGui.Move(wx, wy)
    }
}

; -----------------------------------------------------------
; CHECK if hwnd is a real non-minimized Claude/Antigravity window
; -----------------------------------------------------------
IsClaudeHwnd(h) {
    if !h
        return false
    try {
        if !WinExist("ahk_id " h)
            return false
        if WinGetMinMax("ahk_id " h) = -1
            return false
        pid := WinGetPID("ahk_id " h)
        exe := ProcessGetName(pid)
        if (exe = "claude.exe")
            return WinGetTitle("ahk_id " h) = "Claude"
        if (exe = "Antigravity.exe") {
            title := WinGetTitle("ahk_id " h)
            if title = ""
                return false
            WinGetPos(,, &tw, &th, "ahk_id " h)
            return (tw > 100 && th > 100)
        }
        title := WinGetTitle("ahk_id " h)
        return InStr(title, "Claude Code") > 0
    } catch {
        return false
    }
}

; -----------------------------------------------------------
; FIND which Claude window to follow
; -----------------------------------------------------------
FindClaudeWindow() {
    ; 1. Active window if it is Claude/Antigravity
    try {
        active := WinGetID("A")
        if IsClaudeHwnd(active)
            return active
    }

    ; 2. Any non-minimized Antigravity window
    for hwnd in WinGetList("ahk_exe Antigravity.exe") {
        try {
            if IsClaudeHwnd(hwnd)
                return hwnd
        }
    }

    ; 3. Claude Desktop non-minimized
    hwnd := WinExist("Claude ahk_exe claude.exe")
    if hwnd && WinGetMinMax("ahk_id " hwnd) != -1
        return hwnd

    ; 4. VS Code / Cursor with Claude Code
    for pattern in ["- Claude Code", "Claude Code -"] {
        hwnd := WinExist(pattern)
        if hwnd
            return hwnd
    }

    return 0
}

; -----------------------------------------------------------
; POLL + RENDER
; -----------------------------------------------------------
Poll(*) {
    global DATA_FILE, gLastMod, gTokens, gMax, gBuilt
    if !gBuilt
        return
    try {
        mod := FileGetTime(DATA_FILE, "M")
        if (mod != gLastMod) {
            gLastMod := mod
            content  := FileRead(DATA_FILE, "UTF-8")
            if RegExMatch(content, '"tokens"\s*:\s*(\d+)', &m1)
                gTokens := Integer(m1[1])
            if RegExMatch(content, '"max"\s*:\s*(\d+)', &m2)
                gMax := Integer(m2[1])
            Render()
        }
    }
}

Render(*) {
    global lblPct, lblCount, pBar, gTokens, gMax, gMinimized, gBuilt
    if !gBuilt
        return
    pct := (gMax > 0) ? Min(100, Round(gTokens / gMax * 100, 1)) : 0
    lblPct.Value   := gMinimized ? Round(pct) "%" : pct "%"
    lblCount.Value := FmtNum(gTokens) " / " FmtNum(gMax)
    pBar.Value     := Round(pct)
    ; Green -> Orange -> Red
    clr := (pct < 60) ? 0x4EC429 : (pct < 82) ? 0xFF8C00 : 0xE53530
    SendMessage(0x0409, 0, clr, pBar)
}

FmtNum(n) {
    s := String(Integer(n)), r := ""
    while StrLen(s) > 3 {
        r := "," SubStr(s, StrLen(s)-2) r
        s := SubStr(s, 1, StrLen(s)-3)
    }
    return s r
}

; -----------------------------------------------------------
; MINIMIZE / EXPAND
; -----------------------------------------------------------
ToggleMinimize(*) {
    global wGui, gMinimized
    global lblTitle, lblPct, lblCount, pBar, btnRefresh, btnMin, btnClose
    global WIDGET_W, WIDGET_H, MINI_W, MINI_H

    WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " wGui.Hwnd)
    rightEdge  := wx + ww
    bottomEdge := wy + wh

    if !gMinimized {
        lblTitle.Visible := false
        lblCount.Visible := false
        pBar.Visible     := false
        lblPct.Move(6, 6, 72, 16)
        lblPct.SetFont("s13 Bold cF2F1ED", "Segoe UI")
        btnRefresh.Move(84, 7)
        btnMin.Move(104, 7)
        btnClose.Move(122, 7)
        ControlSetText("-", btnMin)
        wGui.Move(rightEdge - MINI_W, bottomEdge - MINI_H, MINI_W, MINI_H)
        gMinimized := true
    } else {
        wGui.Move(rightEdge - WIDGET_W, bottomEdge - WIDGET_H, WIDGET_W, WIDGET_H)
        lblPct.Move(12, 22, 130, 38)
        lblPct.SetFont("s26 Bold cF2F1ED", "Segoe UI")
        btnRefresh.Move(218, 5)
        btnMin.Move(238, 5)
        btnClose.Move(258, 5)
        ControlSetText("-", btnMin)
        lblTitle.Visible := true
        lblCount.Visible := true
        pBar.Visible     := true
        gMinimized := false
    }
}

; -----------------------------------------------------------
; REFRESH / CLOSE / TOGGLE / RESET
; -----------------------------------------------------------
RefreshNow(*) {
    global WATCHER_JS
    if !FileExist(WATCHER_JS)
        return
    Run('node "' WATCHER_JS '" --once', , "Hide")
}

CloseWidget(*) {
    global wGui, gVisible, gUserClosed
    wGui.Hide()
    gVisible    := false
    gUserClosed := true
}

ToggleWidget(*) {
    global wGui, gVisible, gBuilt, gUserClosed
    if !gBuilt
        return
    if gVisible {
        wGui.Hide()
        gVisible    := false
        gUserClosed := true
    } else {
        gUserClosed := false
        wGui.Show("NoActivate")
        gVisible := true
    }
}

ResetCounter(*) {
    global gTokens, gMax, gLastMod, gBuilt
    gTokens := 0, gMax := 200000, gLastMod := ""
    try FileDelete(A_Temp "\claude_tokens.json")
    if gBuilt
        Render()
}

; -----------------------------------------------------------
; DRAG
; -----------------------------------------------------------
OnLBDown(wParam, lParam, msg, hwnd) {
    global wGui
    if IsObject(wGui) && hwnd = wGui.Hwnd
        PostMessage(0xA1, 2, 0, , "ahk_id " hwnd)
}
