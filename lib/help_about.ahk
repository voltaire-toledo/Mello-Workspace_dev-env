#Requires Autohotkey v2.0
; ╭════════════════════════════════════════════════════════════════════════════════════════════════════════════════─╮
; ║  _HELP_ABOUT.AHK                                                                                                ║
; ╰═════════════════════════════════════════════════════════════════════════════════════════════════════════════════╯

; ╭────────────────────────╮
; │ GLOBAL SCOPE VARIABLES │
; ╰────────────────────────╯
global aboutDlg := ""
global dlgWidth := 800
global dlgHeight := 560
global guiFont := "Segoe UI Variable"
global cpuText := ""

class ThisPC {
  static CPUInfo := Map()
  static RAM := ""
  static OS := Map()
  static Motherboard := Map()
  static Network := []
  static ExternalIP := ""
  static Battery := Map()
  static Uptime := ""

  static CollectInfo() {
    ThisPC.CPUInfo := ThisPC.CPUInfoClass()
    ThisPC.RAM := ThisPC.GetRAMInfo()
    ThisPC.OS := ThisPC.GetOSInfo()
    ThisPC.Motherboard := ThisPC.GetMotherboardInfo()
    ThisPC.Network := ThisPC.GetNetworkInfo()
    ThisPC.ExternalIP := ThisPC.GetExternalIP()
    ThisPC.Battery := ThisPC.GetBatteryInfo()
    ThisPC.Uptime := ThisPC.GetUptime()
  }

  class CPUInfoClass {
    Name := ""
    Manufacturer := ""
    Description := ""
    NumberOfCores := ""
    NumberOfLogicalProcessors := ""
    MaxClockSpeed := ""
    Architecture := ""
    ProcessorId := ""

    __New() {
      for cpu in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Processor") {
        this.Name := cpu.Name
        this.Manufacturer := cpu.Manufacturer
        this.Description := cpu.Description
        this.NumberOfCores := cpu.NumberOfCores
        this.NumberOfLogicalProcessors := cpu.NumberOfLogicalProcessors
        this.MaxClockSpeed := cpu.MaxClockSpeed
        this.Architecture := cpu.Architecture
        this.ProcessorId := cpu.ProcessorId
        break
      }
    }
  }

  static GetRAMInfo() {
    total := 0
    for mem in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_PhysicalMemory")
      total += mem.Capacity
    return Round(total / (1024 ** 3), 2) ; GiB
  }

  static GetOSInfo() {
    for os in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_OperatingSystem") {
      installDate := os.InstallDate
      if installDate
        installDate := SubStr(installDate, 1, 4) "-" SubStr(installDate, 5, 2) "-" SubStr(installDate, 7, 2) " " SubStr(installDate, 9, 2) ":" SubStr(installDate, 11, 2)
      return Map(
        "Name", os.Caption,
        "Version", os.Version,
        "BuildNumber", os.BuildNumber,
        "Architecture", os.OSArchitecture,
        "InstallDate", installDate
      )
    }
    return Map()
  }

  static GetMotherboardInfo() {
    for board in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_BaseBoard") {
      return Map(
        "Manufacturer", board.Manufacturer,
        "Product", board.Product,
        "SerialNumber", board.SerialNumber
      )
    }
    return Map()
  }

  static GetNetworkInfo() {
    info := []
    for nic in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_NetworkAdapterConfiguration WHERE IPEnabled=TRUE") {
      info.Push(Map(
        "Description", nic.Description,
        "MACAddress", nic.MACAddress,
        "IPAddress", nic.IPAddress ? nic.IPAddress[0] : "",
        "Gateway", nic.DefaultIPGateway ? nic.DefaultIPGateway[0] : ""
      ))
    }
    return info
  }

  static GetExternalIP() {
    try {
      whr := ComObject("WinHttp.WinHttpRequest.5.1")
      whr.SetTimeouts(2000, 2000, 2000, 2000)
      whr.Open("GET", "https://api.ipify.org/", true)
      whr.Send()
      whr.WaitForResponse(2)
      return whr.ResponseText
    } catch {
      return "Unavailable"
    }
  }

  static GetBatteryInfo() {
    for bat in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Battery") {
      return Map(
        "Status", bat.BatteryStatus,
        "EstimatedChargeRemaining", bat.EstimatedChargeRemaining,
        "EstimatedRunTime", bat.EstimatedRunTime
      )
    }
    return Map()
  }

  static GetUptime() {
    for os in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_OperatingSystem") {
      lastBoot := os.LastBootUpTime
      if lastBoot {
        yyyy := SubStr(lastBoot, 1, 4)
        MM := SubStr(lastBoot, 5, 2)
        dd := SubStr(lastBoot, 7, 2)
        hh := SubStr(lastBoot, 9, 2)
        mi := SubStr(lastBoot, 11, 2)
        ss := SubStr(lastBoot, 13, 2)
        lastBootTime := yyyy . MM . dd . hh . mi . ss
        uptimeSec := DateDiff(A_Now, lastBootTime, "Seconds")
        days := Floor(uptimeSec / 86400)
        hours := Floor(Mod(uptimeSec, 86400) / 3600)
        mins := Floor(Mod(uptimeSec, 3600) / 60)
        return days "d " hours "h " mins "m"
      }
    }
    return "Unavailable"
  }
}

ShowHelpAbout(*) {
  global aboutDlg
  try {
    aboutDlg.Restore()
    aboutDlg.Show()
    return
  } catch Any {
    aboutDlg := ConstructAboutDialog()
    DllCall("dwmapi\DwmSetWindowAttribute"
      , "ptr", aboutDlg.Hwnd, "int", 20, "int*", 1, "UInt", 4)
    aboutDlg.Show()
  }

  aboutDlg.OnEvent("Escape", (*) => aboutDlg.Destroy())
  aboutDlg.OnEvent("Close", (*) => aboutDlg.Destroy())
  aboutDlg.OnEvent("Size", (*) => aboutDlg.Show("w" dlgWidth " h" dlgHeight))
}

ConstructAboutDialog(*) {
  pid := DllCall("GetCurrentProcessId")
  hProcess := DllCall("OpenProcess", "UInt", 0x1000, "Int", false, "UInt", pid, "Ptr")
  if hProcess {
    structSize := (A_PtrSize = 8) ? 72 : 40
    PROCESS_MEMORY_COUNTERS := Buffer(structSize, 0)
    NumPut("UInt", structSize, PROCESS_MEMORY_COUNTERS, 0)
    if DllCall("psapi\GetProcessMemoryInfo", "Ptr", hProcess, "Ptr", PROCESS_MEMORY_COUNTERS.Ptr, "UInt", structSize) {
      wsOffset := (A_PtrSize = 8) ? 16 : 12
      wsType   := (A_PtrSize = 8) ? "UInt64" : "UInt"
      workingSetSize := NumGet(PROCESS_MEMORY_COUNTERS, wsOffset, wsType)
      memMB := Round(workingSetSize / (1024 * 1024), 1)
    } else {
      memMB := "??"
    }
    DllCall("CloseHandle", "Ptr", hProcess)
  } else {
    memMB := "?"
  }

  __Uptime := A_TickCount - __StartTime
  __days := Floor(__Uptime / 86400000)
  __hours := Floor(Mod(__Uptime, 86400000) / 3600000)
  __minutes := Floor(Mod(__Uptime, 3600000) / 60000)
  __seconds := Floor(Mod(__Uptime, 60000) / 1000)
  UptimeString := __days " D " __hours " h " __minutes " m " __seconds " s"

  aboutDlg := Gui()
  aboutDlg.SetFont("q5 s11", guiFont)
  aboutDlg.Opt("-MinimizeBox -MaximizeBox")

  aboutDlg.Add("Link", "x9 y12 w780 h23",
    "All items below are frequently used features. Visit the <a href=`"https://github.com/voltaire-toledo/Mello-Workspace/tree/main/docs`">Official Documentation</a> for a more comprehensive list."
  )

  aboutDlg.Add("StatusBar", "x0 y530 w800 h30 vStatusBar", "  Hit the [Esc] key to close this window.")

  aboutDlg.SetFont("q5 s10", guiFont)
  mainTab := aboutDlg.Add("Tab3", "x8 y42 w784 h510",
    ["About",
      "Hotkeys  ",
      "Hotstrings  ",
      "Window Management  ",
      "Chords  ",
      "System Info"])

  ; ╭───────────────────────────────────────────────────────────────────────────────────────╮
  ; │ Tab 1 - About                                                                         │
  ; ╰───────────────────────────────────────────────────────────────────────────────────────╯
  mainTab.UseTab(1)
  aboutDlg.Add("Picture", "x16 y76 w92 h92", A_ScriptDir "\assets\images\mello-keycap.png")
  aboutDlg.SetFont("c039314 Bold s21", guiFont)
  aboutDlg.Add("Text", "x120 y74 w450", "Mello-Workspace")

  aboutDlg.SetFont("Bold s14", guiFont)
  aboutDlg.Add("Text", "xp y+4 w400 h23", "Chill. Flow. Repeat.")

  aboutDlg.SetFont("c353881 q5 s10", guiFont)
  aboutDlg.Add("Text", "xp yp+25 w260", "Version: " thisapp_version)
  aboutDlg.Add("Text", "yp w260", "Working Set (RAM): " memMB " MB")
  aboutDlg.Add("Text", "xp-268 yp+20 w260", "Licensed under the GPLv2 License")
  aboutDlg.Add("Text", "yp w260", "Uptime: " UptimeString)
  
  aboutDlg.SetFont("c0066cc Bold q5 s9", guiFont)
  aboutDlg.Add("Text", "xp-268 yp+25 w620", "✓ Tray menu fixed: Now uses Menu().Show() instead of Gui+MenuBar (correct AutoHotkey v2 pattern)")

  aboutDlg.SetFont("c039314 Bold q5 s11", guiFont)
  aboutDlg.Add("Text", "x72 y370 w600 h23", "Credits and Resources")
  aboutDlg.SetFont("c000000 Norm q5 s10", guiFont)
  aboutDlg.Add("Picture", "x72 y+0 w16 h16", A_AhkPath)
  aboutDlg.Add("Link", "yp w400 h23",
    "AutoHotkey (version " A_AhkVersion ") is available at <a href=`"https://www.autohotkey.com`">autohotkey.com</a>")

  aboutDlg.Add("Picture", "x70 yp+20 w20 h20", A_ScriptDir "\assets\icons\icons8.ico")
  aboutDlg.Add("Link", "yp w600 h23", "Icons by <a href=`"https://icons8.com`">icons8.com</a>")

  aboutDlg.Add("Picture", "x70 yp+20 w20 h20", A_ScriptDir "\assets\icons\icons8-github-windows-10-16.png")
  aboutDlg.Add("Link", "yp w300 h23",
    "<a href=`"https://github.com/FuPeiJiang/VD.ahk/tree/v2_port`">VD.ahk library</a> by <a href=`"https://github.com/FuPeiJiang`">FuPeiJiang</a>")

  ; ╭───────────────────────────────────────────────────────────────────────────────────────╮
  ; │ Tab 2 - Hotkeys                                                                       │
  ; ╰───────────────────────────────────────────────────────────────────────────────────────╯
  mainTab.UseTab(2)
  aboutDlg.SetFont("Bold s11", guiFont)
  aboutDlg.Add("Text", "x16 y74 w768 h23", "Hotkeys = keyboard shortcuts. Go ahead and try them out!")

  aboutDlg.SetFont("Norm q5 s10", guiFont)
  lv_corehkeys := aboutDlg.Add("ListView", "x16 y100 w768 r19", ["Action", "Hotkey", "Description"])
  lv_corehkeys.Opt("+Report")
  lv_corehkeys.Opt("-Redraw")
  lv_corehkeys.Add(, "Reload and Restart " thisapp_name, "[Ctrl][Alt][Win]R ", "Reload and restart " thisapp_name)
  lv_corehkeys.Add(, "AutoHotkey Help", "[Ctrl] [Alt][Win]F2", "Open the AutoHotkey help docs")
  lv_corehkeys.Add(, "Sleep", "[Ctrl] [Alt][Win]F12", "Put this system to sleep")
  lv_corehkeys.Add(, thisapp_name " Help", "[Ctrl] [Alt][Win]F1", "Display this dialog")
  lv_corehkeys.Add(, "Open the user's folder", "⊞ F", "Open the user's Documents folder in File Explorer")
  lv_corehkeys.Add(, "Edit this script", "[Ctrl] [Alt][Win]E", "Open the main " thisapp_name " script (default editor)")
  lv_corehkeys.Add(, "Windows Terminal", "[Ctrl] [Alt] T", "Open or focus the Windows Terminal window")
  lv_corehkeys.Add(, "Windows Terminal (Elevated)", "[Ctrl] [Shift] [Alt] T", "Open an elevated Windows Terminal instance")
  lv_corehkeys.Add(, "QuickNote MD", "[Win] [Ctrl] M / [Win] [Alt] M", "Summon or dismiss floating Markdown scratchpad")
  lv_corehkeys.Add(, "QuickNote MD (Edit/Preview)", "[Alt] V", "Toggle between Edit mode and rendered Preview mode")
  lv_corehkeys.Add(, "QuickNote MD (Hide)", "Escape", "Hide the scratchpad (preserves note content)")
  lv_corehkeys.Add(, "QuickNote MD (Opacity)", "[Alt] Scroll", "Adjust scratchpad transparency (hover or active)")
  lv_corehkeys.Add(, "Open Calculator", "2 × [Right_Alt/⌥]", "Open or focus the Calculator app")
  lv_corehkeys.Add(, "Increase Mouse Pointer Size", "[Ctrl] [Alt] [Win]]", "Increase the mouse cursor size (Settings > Accessibility)")
  lv_corehkeys.Add(, "Decrease Mouse Pointer Size", "[Ctrl] [Alt] [Win][", "Decrease the mouse cursor size (Settings > Accessibility)")
  lv_corehkeys.Add(, "Home", "[RCtrl] ←", "[Right_Alt/⌥] supported inside an RDP connection.")
  lv_corehkeys.Add(, "End", "[RCtrl] →", "[Right_Alt/⌥] supported inside an RDP connection.")
  lv_corehkeys.Add(, "PgUp", "[RCtrl] ↑", "[Right_Alt/⌥] supported inside an RDP connection.")
  lv_corehkeys.Add(, "PgDn", "[RCtrl] ↓", "[Right_Alt/⌥] supported inside an RDP connection.")
  lv_corehkeys.ModifyCol()
  lv_corehkeys.ModifyCol(2)
  lv_corehkeys.ModifyCol(3)
  lv_corehkeys.Opt("+Redraw")
  lv_corehkeys.Visible := True

  ; ╭───────────────────────────────────────────────────────────────────────────────────────╮
  ; │ Tab 3 - Hotstrings                                                                    │
  ; ╰───────────────────────────────────────────────────────────────────────────────────────╯
  mainTab.UseTab(3)
  aboutDlg.SetFont("c000000 Bold q5 s11", guiFont)
  aboutDlg.Add("Text", "x16 y74 w768 h24", "Hotstrings = string replacements.")
  aboutDlg.SetFont("c000000 Norm q5 s11", guiFont)

  aboutDlg.SetFont("Bold s10", guiFont)
  aboutDlg.Add("GroupBox", "x16 y98 w768 h50", "Hotstring Groups")

  aboutDlg.SetFont("Norm s10", guiFont)
  hs_rb_ansi := aboutDlg.Add("Radio", "x32 y116 w80 h23 vhs_rb_ansi", "ANSI / Keys")
  hs_rb_kaomoji := aboutDlg.Add("Radio", "x130 y116 w80 h23 vhs_rb_kaomoji", "Kaomoji")
  hs_rb_emoji := aboutDlg.Add("Radio", "x220 y116 w80 h23 vhs_rb_emoji", "Emojis")
  hs_rb_boxes := aboutDlg.Add("Radio", "x310 y116 w140 h23 vhs_rb_boxes", "ASCII P-Graphics")
  hs_rb_custom := aboutDlg.Add("Radio", "x470 y116 w80 h23 vhs_rb_custom", "Custom")

  hs_rb_ansi.Value := true
  aboutDlg.SetFont("c000000 Norm q5 s10", guiFont)
  aboutDlg.Add("Text", "x16 y152 w768 h24 vhs_rb_text", "ANSI and key symbol hotstrings replace typed codes with special Unicode glyphs.")

  ; ANSI / Key Symbols ListView
  aboutDlg.SetFont("Norm q5 s10", guiFont)
  hs_lv_ansi := aboutDlg.Add("ListView", "x16 y178 w768 r16 vhs_lv_ansi", ["Hotstring", "Replacement", "Comments"])
  hs_lv_ansi.Opt("+Report")
  hs_lv_ansi.Opt("-Redraw")
  hs_lv_ansi.Add(, "`:arrowdown", "↓", "Down Arrow")
  hs_lv_ansi.Add(, "`:arrowleft", "←", "Left Arrow")
  hs_lv_ansi.Add(, "`:arrowright", "→", "Right Arrow")
  hs_lv_ansi.Add(, "`:arrowup", "↑", "Up Arrow")
  hs_lv_ansi.Add(, "`:bullet", "•", "Bullet (ANSI 7)")
  hs_lv_ansi.Add(, "`:copyright", "©", "Copyright (ANSI 0169)")
  hs_lv_ansi.Add(, "`:divide", "÷", "Division (ANSI 0247)")
  hs_lv_ansi.Add(, "`:multiply", "×", "Multiplication (ANSI 0215)")
  hs_lv_ansi.Add(, "`:registered", "®", "Registered Trademark (ANSI 0174)")
  hs_lv_ansi.Add(, "`:trademark", "™", "Trademark (ANSI 0153)")
  hs_lv_ansi.Add(, "`:kbdhold", "⭳", "Keyboard Hold")
  hs_lv_ansi.Add(, "`:kbdtap", "⭿", "Keyboard Tap")
  hs_lv_ansi.Add(, "`:kbdrelease", "⭱", "Keyboard Release")
  hs_lv_ansi.Add(, "`:keyalt", "⌥", "Alt / Option key")
  hs_lv_ansi.Add(, "`:keybackspace", "⌫", "Backspace key")
  hs_lv_ansi.Add(, "`:keycaps", "⇪", "Caps Lock key")
  hs_lv_ansi.Add(, "`:keycmd", "⌘", "Command key")
  hs_lv_ansi.Add(, "`:keyctrl", "∧", "Control key")
  hs_lv_ansi.Add(, "`:keydel", "⌦", "Delete key")
  hs_lv_ansi.Add(, "`:keyenter", "↵", "Enter key")
  hs_lv_ansi.Add(, "`:keyescape", "⎋", "Escape key")
  hs_lv_ansi.Add(, "`:keyins", "⎀", "Insert key")
  hs_lv_ansi.Add(, "`:keymeta", "✦", "Meta key")
  hs_lv_ansi.Add(, "`:keyshift", "⇧", "Shift key")
  hs_lv_ansi.Add(, "`:keyspace", "␣", "Space key")
  hs_lv_ansi.Add(, "`:keytab", "⇥", "Tab key")
  hs_lv_ansi.Add(, "`:keywin", "⊞", "Windows key")
  hs_lv_ansi.Add(, "`:hdots", "⋯", "Horizontal ellipsis")
  hs_lv_ansi.Add(, "`:vdots", "⋮", "Vertical ellipsis")
  hs_lv_ansi.Add(, "`:ddots", "⋱", "Diagonal dots (down-right)")
  hs_lv_ansi.Add(, "`:udots", "⋰", "Diagonal dots (up-right)")
  hs_lv_ansi.Add(, "`:yyyy", FormatTime(A_Now, "yyyy"), "Current 4-digit Year")
  hs_lv_ansi.Add(, "`:yy", FormatTime(A_Now, "yy"), "Current 2-digit Year")
  hs_lv_ansi.Add(, "`:mm", FormatTime(A_Now, "MM"), "Current 2-digit Month")
  hs_lv_ansi.Add(, "`:dd", FormatTime(A_Now, "dd"), "Current 2-digit Day")
  hs_lv_ansi.Add(, "[[rnr", "Review and revise...", "AI Prompt Shortcut")
  hs_lv_ansi.ModifyCol(1, 140)
  hs_lv_ansi.ModifyCol(2, 160)
  hs_lv_ansi.ModifyCol(3)
  hs_lv_ansi.Opt("+Redraw")

  ; Kaomoji ListView
  hs_lv_kaomoji := aboutDlg.Add("ListView", "x16 y178 w768 r16 vhs_lv_kaomoji", ["Hotstring", "Replacement", "Comments"])
  hs_lv_kaomoji.Opt("+Report")
  hs_lv_kaomoji.Opt("-Redraw")
  hs_lv_kaomoji.Add(, "`:fuckoff", "୧༼ಠ益ಠ╭∩╮༽", "Rage Kaomoji")
  hs_lv_kaomoji.Add(, "`:fuckyou", "┌П┐(ಠ_ಠ)", "Offensive Kaomoji")
  hs_lv_kaomoji.Add(, "`:idk", "¯\(°_o)/¯", "I Don't Know")
  hs_lv_kaomoji.Add(, "`:ohshit", "( º﹃º )", "Shocked Kaomoji")
  hs_lv_kaomoji.Add(, "`:shrug", "¯\_(ツ)_/¯", "Shrug")
  hs_lv_kaomoji.Add(, "`:tableflip", "(ノಠ益ಠ)ノ彡┻━┻", "Table Flip")
  hs_lv_kaomoji.ModifyCol(1, 140)
  hs_lv_kaomoji.ModifyCol(2, 220)
  hs_lv_kaomoji.ModifyCol(3)
  hs_lv_kaomoji.Opt("+Redraw")
  hs_lv_kaomoji.Visible := false

  ; Emojis ListView
  hs_lv_emoji := aboutDlg.Add("ListView", "x16 y178 w768 r16 vhs_lv_emoji", ["Hotstring", "Replacement", "Comments"])
  hs_lv_emoji.Opt("+Report")
  hs_lv_emoji.Opt("-Redraw")
  hs_lv_emoji.Add(, "`:blackcircle", "⚫", "Black Circle")
  hs_lv_emoji.Add(, "`:bluecircle", "🔵", "Blue Circle")
  hs_lv_emoji.Add(, "`:bug", "🕷", "Spider / Bug")
  hs_lv_emoji.Add(, "`:check", "✔", "Checkmark")
  hs_lv_emoji.Add(, "`:checkmark", "✅", "Green Checkmark")
  hs_lv_emoji.Add(, "`:clock", "⏰", "Alarm Clock")
  hs_lv_emoji.Add(, "`:crossmark", "❎", "Cross Mark Button")
  hs_lv_emoji.Add(, "`:error", "❗", "Exclamation")
  hs_lv_emoji.Add(, "`:file", "📄", "Document File")
  hs_lv_emoji.Add(, "`:fire", "🔥", "Fire")
  hs_lv_emoji.Add(, "`:folder", "📁", "Folder")
  hs_lv_emoji.Add(, "`:folderopen", "📂", "Open Folder")
  hs_lv_emoji.Add(, "`:ghost", "👻", "Ghost")
  hs_lv_emoji.Add(, "`:greencircle", "🟢", "Green Circle")
  hs_lv_emoji.Add(, "`:heart", "❤", "Red Heart")
  hs_lv_emoji.Add(, "`:home", "🏠", "Home")
  hs_lv_emoji.Add(, "`:info", "ℹ", "Information")
  hs_lv_emoji.Add(, "`:lightbulb", "💡", "Light Bulb")
  hs_lv_emoji.Add(, "`:link", "🔗", "Link")
  hs_lv_emoji.Add(, "`:lookup", "🔍", "Magnifying Glass Left")
  hs_lv_emoji.Add(, "`:noob", "🔰", "Beginner / Noob")
  hs_lv_emoji.Add(, "`:ok", "👌", "OK Hand")
  hs_lv_emoji.Add(, "`:purplecircle", "🟣", "Purple Circle")
  hs_lv_emoji.Add(, "`:question", "❓", "Question Mark")
  hs_lv_emoji.Add(, "`:sarcsmile", "🙃", "Upside-Down Face")
  hs_lv_emoji.Add(, "`:search", "🔎", "Search Right")
  hs_lv_emoji.Add(, "`:smile", "😀", "Grinning Face")
  hs_lv_emoji.Add(, "`:sprout", "🌱", "Sprout Seedling")
  hs_lv_emoji.Add(, "`:star", "⭐", "Star")
  hs_lv_emoji.Add(, "`:thumbsdown", "👎", "Thumbs Down")
  hs_lv_emoji.Add(, "`:thumbsup", "👍", "Thumbs Up")
  hs_lv_emoji.Add(, "`:wait", "⏳", "Hourglass")
  hs_lv_emoji.Add(, "`:warning", "⚠", "Warning Sign")
  hs_lv_emoji.Add(, "`:x", "❌", "Cross Mark")
  hs_lv_emoji.Add(, "`:yellowcircle", "🟡", "Yellow Circle")
  hs_lv_emoji.Add(, "`:zap", "⚡", "High Voltage Zap")
  hs_lv_emoji.ModifyCol(1, 140)
  hs_lv_emoji.ModifyCol(2, 100)
  hs_lv_emoji.ModifyCol(3)
  hs_lv_emoji.Opt("+Redraw")
  hs_lv_emoji.Visible := false

  ; ASCII Art / Boxes ListView
  hs_lv_boxes := aboutDlg.Add("ListView", "x16 y178 w768 r16 vhs_lv_boxes", ["Hotstring", "Description / Output", "Comments"])
  hs_lv_boxes.Opt("+Report")
  hs_lv_boxes.Opt("-Redraw")
  hs_lv_boxes.Add(, "##sbox##", "Simple ASCII box (+--+)", "Multi-line Box")
  hs_lv_boxes.Add(, "##stable##", "Simple ASCII table (+--+--+)", "Multi-line Table")
  hs_lv_boxes.Add(, "`:rbox", "Round-cornered box (╭──╮)", "Multi-line Box")
  hs_lv_boxes.Add(, "`:rtable", "Round-cornered table (╭──┬──╮)", "Multi-line Table")
  hs_lv_boxes.Add(, "`:box", "Box with light corners (┌──┐)", "Multi-line Box")
  hs_lv_boxes.Add(, "##tbox-thick##", "Thick-bordered box (╔══╗)", "Multi-line Box")
  hs_lv_boxes.Add(, "`:insert-row", "Insert divider row above current line", "Auto-sizing Divider")
  hs_lv_boxes.Add(, ":|", "┃", "Heavy vertical line")
  hs_lv_boxes.Add(, ":-", "━", "Heavy horizontal line")
  hs_lv_boxes.Add(, ":|-", "┣", "Branch right")
  hs_lv_boxes.Add(, ":|--", "┣━━", "Branch + horizontal run")
  hs_lv_boxes.Add(, ":|_", "┗", "End corner bottom-left")
  hs_lv_boxes.Add(, ":|__", "┗━━", "End corner + run")
  hs_lv_boxes.Add(, ":+", "╋", "Heavy cross intersection")
  hs_lv_boxes.Add(, ":-v-", "┳", "Heavy T down")
  hs_lv_boxes.Add(, ":-^-", "┻", "Heavy T up")
  hs_lv_boxes.Add(, ":-|", "┫", "Branch left")
  hs_lv_boxes.Add(, ":r", "┏", "Heavy corner top-left")
  hs_lv_boxes.Add(, ":7", "┓", "Heavy corner top-right")
  hs_lv_boxes.Add(, ":L", "┗", "Heavy corner bottom-left")
  hs_lv_boxes.Add(, ":J", "┛", "Heavy corner bottom-right")
  hs_lv_boxes.Add(, ":|-d", "┣━━📁", "Directory tree branch")
  hs_lv_boxes.Add(, ":|-f", "┣━━📄", "File tree branch")
  hs_lv_boxes.Add(, ":Ld", "┗━━📁", "Directory tree end")
  hs_lv_boxes.Add(, ":Lf", "┗━━📄", "File tree end")
  hs_lv_boxes.ModifyCol(1, 140)
  hs_lv_boxes.ModifyCol(2, 220)
  hs_lv_boxes.ModifyCol(3)
  hs_lv_boxes.Opt("+Redraw")
  hs_lv_boxes.Visible := false

  ; Custom Hotstrings
  customHsPath := ""
  customHsCandidates := [
      A_ScriptDir "\custom\.mslrc.ahk",
      A_ScriptDir "\.mslrc.ahk",
      A_AppData "\.mslrc.ahk"
  ]
  for p in customHsCandidates {
      if FileExist(p) {
          customHsPath := p
          break
      }
  }

  hs_lv_custom := aboutDlg.Add("ListView", "x16 y178 w768 r16 vhs_lv_custom", ["Hotstring", "Replacement"])
  hs_lv_custom.Opt("+Report")
  hs_lv_custom.Opt("-Redraw")
  if customHsPath {
      content := FileRead(customHsPath)
      pos := 1
      while pos := RegExMatch(content, "m)^:(?:[^:]*):([^:`n]+)::(.*)$", &m, pos) {
          trigger := Trim(m[1])
          replacement := Trim(m[2])
          if trigger != "" && !RegExMatch(replacement, "^\s*\{")
              hs_lv_custom.Add(, trigger, replacement)
          pos += Max(1, m.Len)
      }
      if hs_lv_custom.GetCount() = 0
          hs_lv_custom.Add(, "(no hotstrings found in file)", "")
  } else {
      hs_lv_custom.Add(, "(file not found)", "Expected: " customHsCandidates[1])
  }
  hs_lv_custom.ModifyCol(1, 150)
  hs_lv_custom.ModifyCol(2)
  hs_lv_custom.Opt("+Redraw")
  hs_lv_custom.Visible := false

  hs_switchListView(*) {
    hs_lv_ansi.Visible := hs_rb_ansi.Value
    hs_lv_kaomoji.Visible := hs_rb_kaomoji.Value
    hs_lv_boxes.Visible := hs_rb_boxes.Value
    hs_lv_emoji.Visible := hs_rb_emoji.Value
    hs_lv_custom.Visible := hs_rb_custom.Value
    if (hs_rb_ansi.Value)
      aboutDlg["hs_rb_text"].Value := "ANSI and key symbol hotstrings replace typed codes with special Unicode glyphs."
    else if (hs_rb_custom.Value)
      aboutDlg["hs_rb_text"].Value := customHsPath ? "Custom hotstrings loaded from: " customHsPath : "Custom file not found. Create it at: " customHsCandidates[1]
    else if (hs_rb_kaomoji.Value)
      aboutDlg["hs_rb_text"].Value := "Kaomojis are Japanese emoticons that can be used in text."
    else if (hs_rb_boxes.Value)
      aboutDlg["hs_rb_text"].Value := "ASCII pseudographics (line/box-drawing) create boxes, tables, and dirtrees in monospace fonts."
    else if (hs_rb_emoji.Value)
      aboutDlg["hs_rb_text"].Value := "Emojis provide quick visual glyphs and icons for markdown and notes."
  }
  hs_rb_ansi.OnEvent("Click", hs_switchListView)
  hs_rb_kaomoji.OnEvent("Click", hs_switchListView)
  hs_rb_boxes.OnEvent("Click", hs_switchListView)
  hs_rb_emoji.OnEvent("Click", hs_switchListView)
  hs_rb_custom.OnEvent("Click", hs_switchListView)

  ; ╭───────────────────────────────────────────────────────────────────────────────────────╮
  ; │ Tab 4 - Window Management                                                             │
  ; ╰───────────────────────────────────────────────────────────────────────────────────────╯
  mainTab.UseTab(4)
  aboutDlg.SetFont("c000000 Bold q5 s11", guiFont)
  aboutDlg.Add("Text", "x16 y74 w768 h24", "Control the size and location of active windows with keyboard and mouse shortcuts.")

  aboutDlg.SetFont("Norm q5 s10", guiFont)
  wm_lv_keeb := aboutDlg.Add("ListView", "x16 y100 w768 r19 vwm_lv_keeb", ["Action", "Hotkey", "Description"])
  wm_lv_keeb.Opt("+Report")
  wm_lv_keeb.Opt("-Redraw")
  wm_lv_keeb.Add(, "Resize Window to 70%", "[Ctrl] [Alt][Win]/", "Resize the window to 70% of the monitor.")
  wm_lv_keeb.Add(, "Shrink current window", "[Ctrl] [Alt][Win]<", "5% smaller")
  wm_lv_keeb.Add(, "Expand current window", "[Ctrl] [Alt][Win]>", "5% larger")
  wm_lv_keeb.Add(, "Extend top border", "[Ctrl] [Alt] I", "Extend window to the top of the screen")
  wm_lv_keeb.Add(, "Extend bottom border", "[Ctrl] [Alt] K", "Extend window to the bottom of the screen")
  wm_lv_keeb.Add(, "Extend left border", "[Ctrl] [Alt] J", "Extend window to the left of the screen")
  wm_lv_keeb.Add(, "Extend right border", "[Ctrl] [Alt] L", "Extend window to the right of the screen")
  wm_lv_keeb.Add(, "Resize with mouse", "[Ctrl] [Alt][Win] Right🖱️ drag", "Resize active window from right edge")
  wm_lv_keeb.Add(, "Move window up", "[Ctrl] [Alt][Win] I", "Move window up by 10%")
  wm_lv_keeb.Add(, "Move window down", "[Ctrl] [Alt][Win] K", "Move window down by 10%")
  wm_lv_keeb.Add(, "Move window left", "[Ctrl] [Alt][Win] J", "Move window left by 10%")
  wm_lv_keeb.Add(, "Move window right", "[Ctrl] [Alt][Win] L", "Move window right by 10%")
  wm_lv_keeb.Add(, "Move with mouse", "[Ctrl] [Alt][Win] Left🖱️ drag", "Move window with mouse drag")
  wm_lv_keeb.Add(, "Expand Window Vertically", "[Ctrl] [Alt] [Shift/⇧] I", "Expand the window vertically.")
  wm_lv_keeb.Add(, "Shrink Window Vertically", "[Ctrl] [Alt] [Shift/⇧] J", "Shrink the window vertically.")
  wm_lv_keeb.Add(, "Expand Window Horizontally", "[Ctrl] [Alt] [Shift/⇧] K", "Expand the window horizontally.")
  wm_lv_keeb.Add(, "Shrink Window Horizontally", "[Ctrl] [Alt] [Shift/⇧] L", "Shrink the window horizontally.")
  wm_lv_keeb.ModifyCol(1)
  wm_lv_keeb.ModifyCol(2)
  wm_lv_keeb.ModifyCol(3)
  wm_lv_keeb.Opt("+Redraw")

  ; ╭───────────────────────────────────────────────────────────────────────────────────────╮
  ; │ Tab 5 - Chords (Prefixed Shortcuts)                                                   │
  ; ╰───────────────────────────────────────────────────────────────────────────────────────╯
  mainTab.UseTab(5)
  aboutDlg.SetFont("c000000 Norm q5 s11", guiFont)
  aboutDlg.Add("Text", "x16 y74 w768 h44", "A Chord (or Prefixed Shortcut) is a sequence of keys. Press the leader hotkey (⊞ Win + Alt + O), release, then press a single follow-up key to trigger an action.")

  aboutDlg.SetFont("c000000 Norm q5 s10", guiFont)
  aboutDlg.Add("GroupBox", "x16 y120 w768 h50", "Leader:  ⊞ Win + Alt + O,  then press…")

  a_rb_apps := aboutDlg.Add("Radio", "x32 y138 w120 h23", "Applications")
  a_rb_clip := aboutDlg.Add("Radio", "x172 y138 w120 h23", "Selected Text")
  a_rb_nav := aboutDlg.Add("Radio", "x312 y138 w120 h23", "Navigation")

  a_rb_apps.Value := true

  a_lv_apps := aboutDlg.Add("ListView", "x16 y178 w768 r16 va_lvapps", ["Key", "Application", "Notes"])
  a_lv_apps.Opt("+Report")
  a_lv_apps.Opt("-Redraw")
  a_lv_apps.Add(, "a", "Antigravity", "")
  a_lv_apps.Add(, "b", "Beyond Compare 4", "")
  a_lv_apps.Add(, "c", "Visual Studio Code", "")
  a_lv_apps.Add(, "C", "VS Code Insiders", "")
  a_lv_apps.Add(, "d", "Claude", "")
  a_lv_apps.Add(, "e", "Epic Pen", "")
  a_lv_apps.Add(, "k", "KeyViz", "")
  a_lv_apps.Add(, "l", "Copilot", "")
  a_lv_apps.Add(, "n", "Notion", "")
  a_lv_apps.Add(, "N", "Notepad", "")
  a_lv_apps.Add(, "o", "OpenAI Codex", "")
  a_lv_apps.Add(, "p", "Perplexity Comet", "")
  a_lv_apps.Add(, "t", "Windows Terminal", "")
  a_lv_apps.Add(, "T", "Windows Terminal", "Elevated")
  a_lv_apps.Add(, "v", "Windows Terminal Preview", "")
  a_lv_apps.Add(, "w", "Warp Terminal", "")
  a_lv_apps.Add(, "z", "Zed", "")
  a_lv_apps.ModifyCol(1, 50)
  a_lv_apps.ModifyCol(2, 220)
  a_lv_apps.ModifyCol(3)
  a_lv_apps.Opt("+Redraw")

  a_lv_clip := aboutDlg.Add("ListView", "x16 y178 w768 r16 va_lv_clip", ["Key", "Action", "Description"])
  a_lv_clip.Add(, "—", "No entries yet", "")
  a_lv_clip.Visible := false

  a_lv_nav := aboutDlg.Add("ListView", "x16 y178 w768 r16 va_lv_nav", ["Key", "Action", "Description"])
  a_lv_nav.Add(, "—", "No entries yet", "")
  a_lv_nav.Visible := false

  a_switchListView(*) {
    a_lv_apps.Visible := a_rb_apps.Value
    a_lv_clip.Visible := a_rb_clip.Value
    a_lv_nav.Visible := a_rb_nav.Value
  }
  a_rb_apps.OnEvent("Click", a_switchListView)
  a_rb_clip.OnEvent("Click", a_switchListView)
  a_rb_nav.OnEvent("Click", a_switchListView)

  ; ╭───────────────────────────────────────────────────────────────────────────────────────╮
  ; │ Tab 6 - System Info                                                                   │
  ; ╰───────────────────────────────────────────────────────────────────────────────────────╯
  mainTab.UseTab(6)
  aboutDlg.SetFont("c039314 Bold s11", guiFont)
  aboutDlg.Add("Text", "x16 y70 w300 h22", "System Info")

  aboutDlg.SetFont("c0066cc Bold s10", guiFont)
  btnLoad := aboutDlg.Add("Button", "x555 y66 w225 h28 vbtnLoad", "⚡ Load System Info")
  btnLoad.OnEvent("Click", PopulateTelemetry)

  ; Group 1: System & OS (Left Top)
  aboutDlg.SetFont("Bold s10", guiFont)
  aboutDlg.Add("GroupBox", "x16 y98 w372 h190", "System & OS")

  yPos := 122
  spacing := 28
  aboutDlg.SetFont("c0066cc Norm s10", guiFont)
  aboutDlg.Add("Text", "x28 y" yPos " w90", "Host Name:")
  aboutDlg.SetFont("c000000 Norm s10", guiFont)
  aboutDlg.Add("Text", "x122 y" yPos " w230 vtxtHost", A_ComputerName)
  btnCopyHost := aboutDlg.Add("Picture", "x358 y" (yPos+2) " w14 h14", A_ScriptDir "\assets\icons\icons8-copy-16.png")
  btnCopyHost.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtHost"].Text))

  yPos += spacing
  aboutDlg.SetFont("c0066cc Norm s10", guiFont)
  aboutDlg.Add("Text", "x28 y" yPos " w90", "Current User:")
  aboutDlg.SetFont("c000000 Norm s10", guiFont)
  aboutDlg.Add("Text", "x122 y" yPos " w230 vtxtUser", A_UserName . (A_IsAdmin ? " (Admin)" : ""))
  btnCopyUser := aboutDlg.Add("Picture", "x358 y" (yPos+2) " w14 h14", A_ScriptDir "\assets\icons\icons8-copy-16.png")
  btnCopyUser.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtUser"].Text))

  yPos += spacing
  aboutDlg.SetFont("c0066cc Norm s10", guiFont)
  aboutDlg.Add("Text", "x28 y" yPos " w90", "OS Version:")
  aboutDlg.SetFont("c000000 Norm s10", guiFont)
  aboutDlg.Add("Text", "x122 y" yPos " w230 vtxtOS", A_OSVersion)
  btnCopyOS := aboutDlg.Add("Picture", "x358 y" (yPos+2) " w14 h14", A_ScriptDir "\assets\icons\icons8-copy-16.png")
  btnCopyOS.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtOS"].Text))

  yPos += spacing
  aboutDlg.SetFont("c0066cc Norm s10", guiFont)
  aboutDlg.Add("Text", "x28 y" yPos " w90", "Architecture:")
  aboutDlg.SetFont("c000000 Norm s10", guiFont)
  aboutDlg.Add("Text", "x122 y" yPos " w230 vtxtArch", A_Is64bitOS ? "64-bit" : "32-bit")
  btnCopyArch := aboutDlg.Add("Picture", "x358 y" (yPos+2) " w14 h14", A_ScriptDir "\assets\icons\icons8-copy-16.png")
  btnCopyArch.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtArch"].Text))

  yPos += spacing
  aboutDlg.SetFont("c0066cc Norm s10", guiFont)
  aboutDlg.Add("Text", "x28 y" yPos " w90", "Uptime:")
  aboutDlg.SetFont("c000000 Norm s10", guiFont)
  txtUptime := aboutDlg.Add("Text", "x122 y" yPos " w230 vtxtUptime", "Click 'Load System Info'")
  txtUptime.OnEvent("Click", PopulateTelemetry)
  btnCopyUptime := aboutDlg.Add("Picture", "x358 y" (yPos+2) " w14 h14 vbtnCopyUptime Hidden", A_ScriptDir "\assets\icons\icons8-copy-16.png")
  btnCopyUptime.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtUptime"].Text))

  ; Group 2: Hardware (Left Bottom)
  aboutDlg.SetFont("Bold s10", guiFont)
  aboutDlg.Add("GroupBox", "x16 y294 w372 h230", "Hardware")

  yPos := 318
  aboutDlg.SetFont("c0066cc Norm s10", guiFont)
  aboutDlg.Add("Text", "x28 y" yPos " w90", "CPU:")
  aboutDlg.SetFont("c000000 Norm s10", guiFont)
  txtCPU := aboutDlg.Add("Text", "x122 y" yPos " w230 r2 vtxtCPU", "Click 'Load System Info'")
  txtCPU.OnEvent("Click", PopulateTelemetry)
  btnCopyCPU := aboutDlg.Add("Picture", "x358 y" (yPos+2) " w14 h14 vbtnCopyCPU Hidden", A_ScriptDir "\assets\icons\icons8-copy-16.png")
  btnCopyCPU.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtCPU"].Text))

  yPos += 40
  aboutDlg.SetFont("c0066cc Norm s10", guiFont)
  aboutDlg.Add("Text", "x28 y" yPos " w90", "Motherboard:")
  aboutDlg.SetFont("c000000 Norm s10", guiFont)
  txtMB := aboutDlg.Add("Text", "x122 y" yPos " w230 r2 vtxtMB", "Click 'Load System Info'")
  txtMB.OnEvent("Click", PopulateTelemetry)
  btnCopyMB := aboutDlg.Add("Picture", "x358 y" (yPos+2) " w14 h14 vbtnCopyMB Hidden", A_ScriptDir "\assets\icons\icons8-copy-16.png")
  btnCopyMB.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtMB"].Text))

  yPos += 40
  aboutDlg.SetFont("c0066cc Norm s10", guiFont)
  aboutDlg.Add("Text", "x28 y" yPos " w90", "RAM:")
  aboutDlg.SetFont("c000000 Norm s10", guiFont)
  txtRAM := aboutDlg.Add("Text", "x122 y" yPos " w230 vtxtRAM", "Click 'Load System Info'")
  txtRAM.OnEvent("Click", PopulateTelemetry)
  btnCopyRAM := aboutDlg.Add("Picture", "x358 y" (yPos+2) " w14 h14 vbtnCopyRAM Hidden", A_ScriptDir "\assets\icons\icons8-copy-16.png")
  btnCopyRAM.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtRAM"].Text))

  yPos += spacing
  aboutDlg.SetFont("c0066cc Norm s10", guiFont)
  aboutDlg.Add("Text", "x28 y" yPos " w90", "Battery/Power:")
  aboutDlg.SetFont("c000000 Norm s10", guiFont)
  txtBat := aboutDlg.Add("Text", "x122 y" yPos " w230 vtxtBat", "Click 'Load System Info'")
  txtBat.OnEvent("Click", PopulateTelemetry)
  btnCopyBat := aboutDlg.Add("Picture", "x358 y" (yPos+2) " w14 h14 vbtnCopyBat Hidden", A_ScriptDir "\assets\icons\icons8-copy-16.png")
  btnCopyBat.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtBat"].Text))

  ; Group 3: Network & Adapters (Right)
  aboutDlg.SetFont("Bold s10", guiFont)
  aboutDlg.Add("GroupBox", "x396 y98 w388 h426", "Network & Telemetry")

  yPos := 122
  aboutDlg.SetFont("c0066cc Norm s10", guiFont)
  aboutDlg.Add("Text", "x408 y" yPos " w95", "External IP:")
  aboutDlg.SetFont("c000000 Norm s10", guiFont)
  txtExtIP := aboutDlg.Add("Text", "x508 y" yPos " w245 vtxtExtIP", "Click 'Load System Info'")
  txtExtIP.OnEvent("Click", PopulateTelemetry)
  btnCopyExtIP := aboutDlg.Add("Picture", "x758 y" (yPos+2) " w14 h14 vbtnCopyExtIP Hidden", A_ScriptDir "\assets\icons\icons8-copy-16.png")
  btnCopyExtIP.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtExtIP"].Text))

  yPos += spacing
  aboutDlg.SetFont("c0066cc Norm s10", guiFont)
  aboutDlg.Add("Text", "x408 y" yPos " w95", "Primary NIC:")
  aboutDlg.SetFont("c000000 Norm s10", guiFont)
  txtNIC1Desc := aboutDlg.Add("Text", "x508 y" yPos " w260 r2 vtxtNIC1Desc", "Click 'Load System Info'")
  txtNIC1Desc.OnEvent("Click", PopulateTelemetry)

  yPos += 36
  aboutDlg.SetFont("c0066cc Norm s10", guiFont)
  aboutDlg.Add("Text", "x408 y" yPos " w95", "Primary IP:")
  aboutDlg.SetFont("c000000 Norm s10", guiFont)
  txtNIC1IP := aboutDlg.Add("Text", "x508 y" yPos " w245 vtxtNIC1IP", "Click 'Load System Info'")
  txtNIC1IP.OnEvent("Click", PopulateTelemetry)
  btnCopyNIC1IP := aboutDlg.Add("Picture", "x758 y" (yPos+2) " w14 h14 vbtnCopyNIC1IP Hidden", A_ScriptDir "\assets\icons\icons8-copy-16.png")
  btnCopyNIC1IP.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtNIC1IP"].Text))

  yPos += spacing
  aboutDlg.SetFont("c0066cc Norm s10", guiFont)
  aboutDlg.Add("Text", "x408 y" yPos " w95", "Primary GW:")
  aboutDlg.SetFont("c000000 Norm s10", guiFont)
  txtNIC1GW := aboutDlg.Add("Text", "x508 y" yPos " w245 vtxtNIC1GW", "Click 'Load System Info'")
  txtNIC1GW.OnEvent("Click", PopulateTelemetry)
  btnCopyNIC1GW := aboutDlg.Add("Picture", "x758 y" (yPos+2) " w14 h14 vbtnCopyNIC1GW Hidden", A_ScriptDir "\assets\icons\icons8-copy-16.png")
  btnCopyNIC1GW.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtNIC1GW"].Text))

  yPos += spacing
  aboutDlg.SetFont("c0066cc Norm s10", guiFont)
  aboutDlg.Add("Text", "x408 y" yPos " w95", "Primary MAC:")
  aboutDlg.SetFont("c000000 Norm s10", guiFont)
  txtNIC1MAC := aboutDlg.Add("Text", "x508 y" yPos " w245 vtxtNIC1MAC", "Click 'Load System Info'")
  txtNIC1MAC.OnEvent("Click", PopulateTelemetry)
  btnCopyNIC1MAC := aboutDlg.Add("Picture", "x758 y" (yPos+2) " w14 h14 vbtnCopyNIC1MAC Hidden", A_ScriptDir "\assets\icons\icons8-copy-16.png")
  btnCopyNIC1MAC.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtNIC1MAC"].Text))

  yPos += 36
  aboutDlg.SetFont("c0066cc Norm s10", guiFont)
  aboutDlg.Add("Text", "x408 y" yPos " w95", "Secondary NIC:")
  aboutDlg.SetFont("c000000 Norm s10", guiFont)
  txtNIC2Desc := aboutDlg.Add("Text", "x508 y" yPos " w260 r2 vtxtNIC2Desc", "-")

  yPos += 36
  aboutDlg.SetFont("c0066cc Norm s10", guiFont)
  aboutDlg.Add("Text", "x408 y" yPos " w95", "Secondary IP:")
  aboutDlg.SetFont("c000000 Norm s10", guiFont)
  txtNIC2IP := aboutDlg.Add("Text", "x508 y" yPos " w245 vtxtNIC2IP", "-")
  btnCopyNIC2IP := aboutDlg.Add("Picture", "x758 y" (yPos+2) " w14 h14 vbtnCopyNIC2IP Hidden", A_ScriptDir "\assets\icons\icons8-copy-16.png")
  btnCopyNIC2IP.OnEvent("Click", (c, *) => CopyToClipboard(c.Gui["txtNIC2IP"].Text))

  aboutDlg.Title := "Mello-Workspace - About"
  return aboutDlg
}

PopulateTelemetry(_GuiControlObj, *) {
  dlgGui := _GuiControlObj.Gui
  try {
    dlgGui["btnLoad"].Text := "Loading..."
    dlgGui["btnLoad"].Enabled := false
  }

  ThisPC.CollectInfo()

  ; System & OS
  dlgGui["txtUptime"].Text := ThisPC.Uptime
  dlgGui["btnCopyUptime"].Visible := true

  ; Hardware
  cpuStr := ThisPC.CPUInfo.Name . " (" . ThisPC.CPUInfo.NumberOfCores . "/" . ThisPC.CPUInfo.NumberOfLogicalProcessors . ") @ " . Round(ThisPC.CPUInfo.MaxClockSpeed / 1000, 1) . "GHz"
  dlgGui["txtCPU"].Text := cpuStr
  dlgGui["btnCopyCPU"].Visible := true

  mbStr := (ThisPC.Motherboard.Has("Manufacturer") ? ThisPC.Motherboard["Manufacturer"] : "") . " " . (ThisPC.Motherboard.Has("Product") ? ThisPC.Motherboard["Product"] : "")
  dlgGui["txtMB"].Text := mbStr
  dlgGui["btnCopyMB"].Visible := true

  dlgGui["txtRAM"].Text := ThisPC.RAM . " GiB"
  dlgGui["btnCopyRAM"].Visible := true

  batText := (ThisPC.Battery.Count > 0 && ThisPC.Battery.Has("EstimatedChargeRemaining"))
    ? (ThisPC.Battery["EstimatedChargeRemaining"] . "%")
    : "N/A (Desktop / AC Only)"
  dlgGui["txtBat"].Text := batText
  dlgGui["btnCopyBat"].Visible := true

  ; Network
  dlgGui["txtExtIP"].Text := ThisPC.ExternalIP
  dlgGui["btnCopyExtIP"].Visible := true

  if ThisPC.Network.Length > 0 {
    nic1 := ThisPC.Network[1]
    dlgGui["txtNIC1Desc"].Text := nic1["Description"]
    dlgGui["txtNIC1IP"].Text := nic1["IPAddress"]
    dlgGui["btnCopyNIC1IP"].Visible := true
    dlgGui["txtNIC1GW"].Text := (nic1["Gateway"] != "") ? nic1["Gateway"] : "N/A"
    dlgGui["btnCopyNIC1GW"].Visible := (nic1["Gateway"] != "")
    dlgGui["txtNIC1MAC"].Text := (nic1["MACAddress"] != "") ? nic1["MACAddress"] : "N/A"
    dlgGui["btnCopyNIC1MAC"].Visible := (nic1["MACAddress"] != "")
  }

  if ThisPC.Network.Length > 1 {
    nic2 := ThisPC.Network[2]
    dlgGui["txtNIC2Desc"].Text := nic2["Description"]
    dlgGui["txtNIC2IP"].Text := nic2["IPAddress"]
    dlgGui["btnCopyNIC2IP"].Visible := true
  }

  try {
    dlgGui["btnLoad"].Text := "⚡ Refresh System Info"
    dlgGui["btnLoad"].Enabled := true
  }
}

GetPCInfo(_GuiControlObj, *) {
  PopulateTelemetry(_GuiControlObj)
}

CopyToClipboard(text, *) {
  A_Clipboard := text
  ToolTip("Copied to clipboard!", , , 1)
  SetTimer () => ToolTip(, , , 1), -1000
  return
}