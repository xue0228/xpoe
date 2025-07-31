#Include lib\TextRender.ahk
#Include lib\JSON.ahk
#Include lib\EasyInput.ahk
#Include lib\FindText\dxgi.ahk
; #Include lib\Debug.ahk

CoordMode "Mouse", "Screen"

POE_EXE := "Path of Exile"

class Rect {
    __New(x1, y1, x2?, y2?, w?, h?) {
        if IsSet(x2) and IsSet(y2) {
            this._w := x2 - x1
            this._h := y2 - y1
        } else if IsSet(w) and IsSet(h) {
            this._w := w
            this._h := h
        } else {
            throw Error("创建Rect时需要指定x2、y2或w、h中的一组")
        }
        if this._w <= 0 or this._h <= 0 {
            throw Error("Rect的宽和高必须大于0")
        }
        this._x := x1
        this._y := y1
    }

    x
    {
        get {
            return Round(this._x)
        }
        set {
            this._x := Value
        }
    }
    y
    {
        get {
            return Round(this._y)
        }
        set {
            this._y := Value
        }
    }

    width
    {
        get {
            return Round(this._w)
        }
        set {
            if Value < 0 {
                throw "宽度w不能为负数"
            } else {
                this._w := Value
            }
        }
    }
    height
    {
        get {
            return Round(this._h)
        }
        set {
            if Value < 0 {
                throw "高度h不能为负数"
            } else {
                this._h := Value
            }
        }
    }
    w
    {
        get => this.width
        set => this.width := Value
    }
    h
    {
        get => this.height
        set => this.height := Value
    }

    topLeft
    {
        get => { x: this.x, y: this.y }
    }
    bottomRight
    {
        get => { x: Round(this._x + this._w), y: Round(this._y + this._h) }
    }
    center
    {
        get => { x: Round(this._w / 2 + this._x), y: Round(this._h / 2 + this._y) }
    }

    SplitByRowAndCol(rows, cols) {
        if (rows <= 0 || cols <= 0) {
            throw "行数和列数必须大于0"
        }

        subWidth := this._w / cols
        subHeight := this._h / rows
        subRects := []

        loop rows {
            row := A_Index - 1
            subRects.Push([])
            loop cols {
                col := A_Index - 1
                x := this._x + col * subWidth
                y := this._y + row * subHeight
                subRects[row + 1].Push(Rect(x, y, , , subWidth, subHeight))
            }
        }

        return subRects
    }

    Map() {
        return { x: this._x, y: this._y, w: this._w, h: this._h }
    }
}

; 文本提示框，默认1s后关闭
TextTooltip(text, time := 1000) {
    TextRender(text, "t:" time " c:#F9E486 y:75vh r:1vmin")
}

; 获取下一次鼠标左键点击的坐标
GetNextLeftClickPos(&x, &y, text?) {
    ; 创建全屏提示窗口
    g := Gui()
    g.Opt("+AlwaysOnTop +ToolWindow -Caption +LastFound +Owner")
    g.BackColor := 0x000000
    WinSetTransColor(" 100", g)
    content := "按下鼠标左键记录位置"
    if IsSet(text) {
        content := content "`n" text
    }
    t := g.Add("Text", "Center X0 Y" A_ScreenHeight / 20 " W" A_ScreenWidth " H" A_ScreenHeight, content)
    t.SetFont("cFFFFFF s" Min(A_ScreenHeight, A_ScreenWidth) / 20)
    ; 显示全屏提示窗口
    g.Show("X0 Y0 W" A_ScreenWidth " H" A_ScreenHeight)

    ; 等待鼠标左键按下后记录鼠标位置
    KeyWait("LButton", "D")
    MouseGetPos(&x, &y)
    ; 等待鼠标左键松开后销毁提示窗口
    KeyWait("LButton")
    g.Destroy()

    return
}

; 获取下一次鼠标左键框选的Rect对象
GetNextLeftClickRect()
{
    ; 创建全屏提示窗口
    g := Gui()
    g.Opt("+AlwaysOnTop +ToolWindow -Caption +LastFound +Owner")
    g.BackColor := 0x000000
    WinSetTransColor(" 100", g)
    t := g.Add("Text", "Center X0 Y" A_ScreenHeight / 20 " W" A_ScreenWidth " H" A_ScreenHeight, "按住鼠标左键框选目标区域")
    t.SetFont("cFFFFFF s" Min(A_ScreenHeight, A_ScreenWidth) / 20)

    ; 创建框选提示窗口
    g2 := Gui()
    g2.Opt("+AlwaysOnTop +ToolWindow -Caption +LastFound +Owner")
    g2.BackColor := 0x439b9e
    WinSetTransColor(" 100", g2)

    ; 显示全屏提示窗口
    g.Show("X0 Y0 W" A_ScreenWidth " H" A_ScreenHeight)

    ; 等待鼠标左键被按下
    KeyWait("LButton", "D")
    ; 记录当前鼠标位置
    MouseGetPos(&x1, &y1)
    ; 显示框选提示窗口
    g2.Show("NA")
    ; 持续监测鼠标左键的按键状态
    while GetKeyState("LButton", "P") {
        MouseGetPos(&x, &y)
        g2.Move(Min(x1, x), Min(y1, y), Abs(x - x1), Abs(y - y1))
        Sleep(10)
    }
    ; 等待鼠标左键松开
    KeyWait("LButton")
    ; 记录当前鼠标位置
    MouseGetPos(&x2, &y2)

    ; 等待一段时间后销毁两个提示窗口
    Sleep(500)
    g2.Destroy()
    g.Destroy()

    try {
        res := Rect(Min(x1, x2), Min(y1, y2), Max(x1, x2), Max(y1, y2))
    }  catch Error as err {
        MsgBox err.Message
        return
    }
    
    return res
}

; 区域选择窗口
class RangeSelectWindow {
    __New(title, callback, tooltip := "", rows := "", cols := "", x := "", y := "", w := "", h := "") {
        g := Gui(, title)
        g.SetFont("s9")
        g.AddGroupBox("x8 y8 w215 h58", "布局")
        g.AddGroupBox("x8 y72 w215 h116", "范围")
        g.AddText("x16 y32 w17 h23", "行:")
        g.AddText("x120 y32 w17 h23", "列:")
        g.AddText("x16 y128 w17 h23", "x:")
        g.AddText("x120 y128 w17 h23", "y:")
        g.AddText("x16 y160 w17 h23", "w:")
        g.AddText("x120 y160 w17 h23", "h:")

        this._t1 := g.AddText("x8 y192 w129 h38", tooltip)

        this._e1 := g.AddEdit("x40 y32 w70 h21", rows)
        this._e2 := g.AddEdit("x144 y32 w70 h21", cols)

        this._b1 := g.AddButton("x16 y96 w200 h23", "选择范围")
        this._e3 := g.AddEdit("x40 y128 w70 h21", x)
        this._e4 := g.AddEdit("x144 y128 w70 h21", y)
        this._e5 := g.AddEdit("x40 y160 w70 h21", w)
        this._e6 := g.AddEdit("x144 y160 w70 h21", h)

        this._b2 := g.AddButton("x144 y198 w80 h23", "确定")

        this._b1.OnEvent("Click", B1OnEvent)
        this._b2.OnEvent("Click", callback)

        this._gui := g

        B1OnEvent(*) {
            this._gui.Hide()
            r := GetNextLeftClickRect()

            if r = "" {
                this._gui.Show()
                return
            }
            
            try {
                RectTooltip(&r, this._e1.Value, this._e2.Value)
            }

            this._e3.Value := r.x
            this._e4.Value := r.y
            this._e5.Value := r.w
            this._e6.Value := r.h
            this._gui.Show()
        }

        ControlFocus(this._b1)
    }

    __Delete() {
        this._gui.Destroy()
    }

    FocusConfirm() {
        ControlFocus(this._b2)
        return
    }

    Show() {
        this._gui.Show("w231 h236")
        return
    }

    Hide() {
        this._gui.Hide()
        return
    }

    r {
        get {
            return Integer(this._e1.Value)
        }
        set {
            this._e1.Value := Value
            return
        }
    }
    c {
        get {
            return Integer(this._e2.Value)
        }
        set {
            this._e2.Value := Value
            return
        }
    }
    x {
        get {
            return Round(Number(this._e3.Value))
        }
        set {
            this._e3.Value := Value
            return
        }
    }
    y {
        get {
            return Round(Number(this._e4.Value))
        }
        set {
            this._e4.Value := Value
            return
        }
    }
    w {
        get {
            return Round(Number(this._e5.Value))
        }
        set {
            this._e5.Value := Value
            return
        }
    }
    h {
        get {
            return Round(Number(this._e6.Value))
        }
        set {
            this._e6.Value := Value
            return
        }
    }
    result {
        get {
            return { r: this.r, c: this.c, x: this.x, y: this.y, w: this.w, h: this.h }
        }
        set {
            this.r := Value.r
            this.c := Value.c
            this.x := Value.x
            this.y := Value.y
            this.w := Value.w
            this.h := Value.h
            this.FocusConfirm()
            return
        }
    }
}

; 目标位置选择窗口
class ItemPositionWindow {
    __New(title, items, callback, tooltip := "") {
        l := items.Length
        g := Gui(, title)
        g.SetFont("s9")
        g.AddGroupBox("x8 y0 w353 h" 40 + 32 * l, "")
        g.AddText("x136 y16 w35 h23", "X坐标")
        g.AddText("x208 y16 w35 h23", "Y坐标")

        this._t1 := g.AddText("x8 y" 41 + 32 * l " w265 h36", tooltip)
        this._b1 := g.AddButton("x280 y" 49 + 32 * l " w80 h23", "确认")
        this._b1.OnEvent("Click", callback)
        this._b2 := []
        this._e1 := []
        this._e2 := []
        for k, v in items {
            y := 40 + 32 * (k - 1)
            g.AddText("center x16 y" y " w100 h23", v ":")
            tem_x := g.AddEdit("x120 y" y " w70 h21")
            tem_y := g.AddEdit("x192 y" y " w70 h21")
            tem_b := g.AddButton("x272 y" y " w80 h23", "选择目标")
            if k = 1 {
                ControlFocus(tem_b)
            }

            tem_b.OnEvent("Click", tem_func)

            this._y := y
            this._e1.Push(tem_x)
            this._e2.Push(tem_y)
            this._b2.Push(tem_b)
        }

        tem_func(obj, *) {
            this.Hide()
            GetNextLeftClickPos(&x0, &y0)
            tem := 0
            for k, v in this._b2 {
                if v = obj {
                    tem := k
                    break
                }
            }
            if tem != 0 {
                this._e1[tem].Text := x0
                this._e2[tem].Text := y0
            }
            if tem = this.Length {
                this.FocusConfirm()
            }
            this.Show()
        }

        this._gui := g
        this._l := l
    }

    Length {
        get => this._l
    }

    __Delete() {
        this._gui.Destroy()
        return
    }

    FocusConfirm() {
        ControlFocus(this._b1)
        return
    }

    Show() {
        this._gui.Show("w368 h" this._y + 72)
        return
    }

    Hide() {
        this._gui.Hide()
        return
    }

    results {
        get {
            res := []
            loop this.Length {
                res.Push({ x: Integer(this._e1[A_Index].Text), y: Integer(this._e2[A_Index].Text) })
            }
            return res
        }
        set {
            for k, v in Value {
                this._e1[k].Text := v.x
                this._e2[k].Text := v.y
            }
            this.FocusConfirm()
            return
        }
    }
}

; 热键注册窗口
; {name: "func1", callback : func1, default: "^1", active: "poe"}
class ShortcutEditWindow {
    __New(title, objs, callback, tooltip := "") {
        l := objs.Length
        g := Gui(, title)
        g.SetFont("s9")
        g.AddGroupBox("x8 y0 w249 h" 17 + 32 * l, "")

        this._t1 := g.AddText("x8 y" 22 + 32 * l " w161 h36", tooltip)
        this._b1 := g.AddButton("x176 y" 28 + 32 * l " w80 h23", "确认")
        this._b1.OnEvent("Click", RegisterHotkey)
        this._h1 := []
        this._last := ""
        for k, v in objs {
            y := 16 + 32 * (k - 1)
            g.AddText("center x16 y" y " w100 h23", v.name ":")
            if v.HasOwnProp("default") {
                tem_h := g.AddHotkey("x128 y" y " w120 h21", v.default)
            } else {
                tem_h := g.AddHotkey("x128 y" y " w120 h21")
            }

            if k = 1 {
                ControlFocus(tem_h)
            }

            this._y := y
            this._h1.Push(tem_h)
        }

        RegisterHotkey(*) {
            seen := {}
            ; hasDuplicates := false
            for k, v in this._h1 {
                if seen.HasOwnProp(v.Value) {
                    MsgBox v.Value "快捷键冲突"
                    return
                }
                seen.DefineProp(v.Value, { Value: true })
            }

            if this._last = "" {
                this._last := []
                for k, v in this._h1 {
                    this._last.Push(v.Value)
                    if v.Value != "" {
                        if objs[k].HasOwnProp("active") and objs[k].active != "" {
                            HotIfWinActive objs[k].active
                        } else {
                            HotIfWinActive
                        }
                        Hotkey(v.Value, objs[k].callback, "On")
                    }
                }
            } else {
                for k, v in this._last {
                    if v != "" {
                        try Hotkey(v, "Off")
                    }
                }
                for k, v in this._h1 {
                    if v.Value != "" {
                        if objs[k].HasOwnProp("active") and objs[k].active != "" {
                            HotIfWinActive objs[k].active
                        } else {
                            HotIfWinActive
                        }
                        Hotkey(v.Value, objs[k].callback, "On")
                    }
                    this._last[k] := v.Value
                }
            }
            this.Hide()
            HotIfWinActive
            callback()
        }

        CloseWindow(*) {
            Suspend this._suspend
        }

        g.OnEvent("Close", CloseWindow)

        this._gui := g
        this._l := l
        this._suspend := A_IsSuspended
    }

    Length {
        get => this._l
    }

    __Delete() {
        this._gui.Destroy()
        return
    }

    FocusConfirm() {
        ControlFocus(this._b1)
        return
    }

    Show() {
        this._suspend := A_IsSuspended
        Suspend 1
        this._gui.Show("w266 h" this._y + 80)
        return
    }

    Hide() {
        Suspend this._suspend
        this._gui.Hide()
        return
    }

    results {
        get {
            res := []
            for index, value in this._h1 {
                res.Push(value.Value)
            }
            return res
        }
        set {
            for k, v in Value {
                this._h1[k].Value := v
            }
            this.FocusConfirm()
            return
        }
    }
}

; 框选范围提示窗口，获取焦点后自动关闭
RectTooltip(&r, rows, cols) {
    g := Gui()
    g.Opt("+AlwaysOnTop +ToolWindow -Caption +LastFound +Owner")
    g.BackColor := 0x000000
    WinSetTransColor(" 150", g)

    subWidth := r.width / cols
    subHeight := r.height / rows
    b := Round(Min(subWidth, subHeight) / 4)
    startX := (subWidth - b) / 2
    startY := (subHeight - b) / 2

    loop rows {
        row := A_Index - 1
        loop cols {
            col := A_Index - 1
            g.Add("Button", "Disabled W" b " H" b " X" Round(startX + col * subWidth) " Y" Round(startY + row * subHeight))
        }
    }

    g.Show("NA X" r.x " Y" r.y " W" r.width " H" r.height)

    WinWaitActive("ahk_id " g.Hwnd)
    g.Destroy()
}

; 保存对象到json文件
SaveJson(obj, file) {
    file := StrReplace(file, "/", "\")
    if FileExist(file) {
        FileDelete(file)
    } else {
        dir := SubStr(file, 1, InStr(file, "\", , -1))
        if (!FileExist(dir) && dir != "") {
            DirCreate dir
        }
    }
    FileAppend(JSON.stringify(obj), file, "UTF-8")
    return
}

; 读取json文件为对象
LoadJson(file) {
    if !FileExist(file) {
        throw "文件" file "不存在"
    }
    content := FileRead(file, "UTF-8")
    return JSON.parse(content, , false)
}

; 读取文件为列表
FileToStrArray(file) {
    lines := FileRead(file, "UTF-8")
    data := StrSplit(lines, "`r`n")
    res := []
    for k, v in data {
        if v != "" {
            res.Push(v)
        }
    }
    return res
}

; 获取物品信息
GetItemInfo() {
    CommandBetweenSleepRandom()
    clipSaved := ClipboardAll()
    A_Clipboard := ""
    TapKeys("lctrl", "c")
    res := A_Clipboard
    A_Clipboard := clipSaved
    return res
}

; 获取物品详细信息
GetItemDetailInfo() {
    CommandBetweenSleepRandom()
    clipSaved := ClipboardAll()
    A_Clipboard := ""
    TapKeys("LCtrl", "LAlt", "c")
    res := A_Clipboard
    A_Clipboard := clipSaved
    return res
}

; 快速移动物品
MoveItemFast() {
    CommandBetweenSleepRandom()
    TapKeys("LCtrl", "LButton")
}

; 物品分组拿取
SplitItems(num := 10) {
    KeyDown("LShift")
    MouseClickRandom()
    KeyUp("LShift")
    KeyBetweenSleepRandom()
    target := String(num)
    loop StrLen(target) {
        TapKeys(SubStr(target, A_Index, 1))
        KeyBetweenSleepRandom()
    }
    TapKeys("Enter")
}

; 查找物品名称
FindItemName(text) {
    RegExMatch(text, "稀 有 度:[^\r\n]*\R\R?([\s\S]+?)\R\s*--------", &match)
    if match = "" {
        return ""
    }
    itemName := Trim(match[1], "★ `t")
    return itemName
}

; 查找物品堆叠数量
FindItemNumber(text) {
    RegExMatch(text, "堆叠数量: ([0-9]+,?[0-9]*) / [0-9]+", &match)
    itemName := Trim(match[1])
    itemName := StrReplace(itemName, ",")
    ; TextTooltip(itemName)
    return Integer(itemName)
}

; 查找物品品质
FindItemQuality(text) {
    RegExMatch(text, "品质: \+([0-9]+)%", &match)
    if match = "" {
        return 0
    } else {
        return Integer(Trim(match[1]))
    }
}

; 查找物品类型
FindItemType(text) {
    RegExMatch(text, "物品类别: (.+)", &match)
    if match = "" {
        return ""
    }
    itemName := Trim(match[1])
    return itemName
}

; 查找物品稀有度
FindItemRarity(text) {
    RegExMatch(text, "稀 有 度: (.+)", &match)
    if match = "" {
        return ""
    } else {
        return Trim(match[1])
    }
}

; 判断物品信息中是否含有指定字符串
HasContainAnyModifiers(text, modifiers*) {
    for k, v in modifiers {
        if InStr(text, v) {
            return true
        }
    }
    return false
}

; 判断数组是否包含目标对象
IsValueInArray(value, array) {
    for k, v in array {
        if v = value {
            return true
        }
    }
    return false
}

; test1(*) {
;     MsgBox 1
; }
; test2(*) {
;     MsgBox 2
; }

; s := ShortcutEditWindow("test", [{ name: "func1", callback: test1, default: "^1", active: "" }, { name: "func2", callback: test2, default: "^2", active: "" }], "sdfsdfsdfsdfdsf`nsdfsdfdsfdsfds`ndsfsdfsdf")
; ; s.results := ["^2", "^3"]
; ; PrintArray s.results
; s.Show()

; ^0::
; {
;     s.Show()
; }

; x := 100
; x := String(x)
; loop StrLen(x) {
;     MsgBox SubStr(x, A_Index, 1)
; }
