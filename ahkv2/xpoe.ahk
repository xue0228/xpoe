#Include lib\TextRender.ahk
#Include lib\JSON.ahk

CoordMode "Mouse", "Screen"

POE_EXE := "Path of Exile"

KEY_DELAY_BASE := 100
KEY_DELAY_RANGE := 25
KEY_UP_BASE := 50
KEY_UP_RANGE := 25

MOUSE_ACC := 5
MOUSE_SPEED_BASE := 15
MOUSE_SPEED_RANGE := 5

KeyUpSleep(upBase := KEY_UP_BASE, upRange := KEY_UP_RANGE) {
    Sleep upBase + Random(-upRange, upRange)
}

KeyBetweenSleep(delayBase := KEY_DELAY_BASE, delayRange := KEY_DELAY_RANGE) {
    Sleep delayBase + Random(-delayRange, delayRange)
}

class Rect {
    __New(x1, y1, x2?, y2?, w?, h?) {
        if IsSet(x2) and IsSet(y2) {
            this._w := x2 - x1
            this._h := y2 - y1
        } else if IsSet(w) and IsSet(h) {
            this._w := w
            this._h := h
        } else {
            throw "创建Rect时需要指定x2、y2或w、h中的一组"
        }
        if this._w < 0 or this._h < 0 {
            throw "Rect的宽和高不能为负数"
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

TextTooltip(text, time := 1000) {
    TextRender(text, "t:" time " c:#F9E486 y:75vh r:1vmin")
}

GetNextLeftClickPos(&x, &y) {
    ; 创建全屏提示窗口
    g := Gui()
    g.Opt("+AlwaysOnTop +ToolWindow -Caption +LastFound +Owner")
    g.BackColor := 0x000000
    WinSetTransColor(" 100", g)
    t := g.Add("Text", "Center X0 Y" A_ScreenHeight / 20 " W" A_ScreenWidth " H" A_ScreenHeight, "按下鼠标左键记录位置")
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

    return Rect(Min(x1, x2), Min(y1, y2), Max(x1, x2), Max(y1, y2))
}

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

SaveJson(map, file) {
    file := StrReplace(file, "/", "\")
    if FileExist(file) {
        FileDelete(file)
    } else {
        dir := SubStr(file, 1, InStr(file, "\", , -1))
        if (!FileExist(dir) && dir != "") {
            DirCreate dir
        }
    }
    FileAppend(JSON.stringify(map), file, "UTF-8")
    return
}

LoadJson(file) {
    if !FileExist(file) {
        throw "文件" file "不存在"
    }
    content := FileRead(file, "UTF-8")
    return JSON.parse(content, , false)
}

MoveMouseRandomBezier(x, y, acc := MOUSE_ACC, speedBase := MOUSE_SPEED_BASE, speedRange := MOUSE_SPEED_RANGE) {
    MouseGetPos(&x1, &y1)
    x4 := x + Random(-acc, acc)
    y4 := y + Random(-acc, acc)

    distance := Sqrt((x1 - x4) * (x1 - x4) + (y1 - y4) * (y1 - y4))
    r := Round(0.5 * distance)
    x2 := Random(Max(0, x1 - r), Min(A_ScreenWidth, x1 + r))
    y2 := Random(Max(0, y1 - r), Min(A_ScreenHeight, y1 + r))
    x3 := Random(Max(0, x4 - r), Min(A_ScreenWidth, x4 + r))
    y3 := Random(Max(0, y4 - r), Min(A_ScreenHeight, y4 + r))

    num := Round(distance / 5)
    each := 1 / num
    loop num - 1 {
        t := A_Index * each
        x := Round(x1 * (1 - t) * (1 - t) * (1 - t) + 3 * x2 * t * (1 - t) * (1 - t) + 3 * x3 * t * t * (1 - t) + x4 * t * t * t)
        y := Round(y1 * (1 - t) * (1 - t) * (1 - t) + 3 * y2 * t * (1 - t) * (1 - t) + 3 * y3 * t * t * (1 - t) + y4 * t * t * t)
        loop speedBase + Random(-speedRange, speedRange) {
            MouseMove(x, y)
        }
    }
    MouseMove(x4, y4)
}

LeftClickRandom(delayBase := KEY_DELAY_BASE, delayRange := KEY_DELAY_RANGE, upBase := KEY_UP_BASE, upRange := KEY_UP_RANGE) {
    Sleep delayBase + Random(-delayRange, delayRange)
    Send "{LButton Down}"
    Sleep upBase + Random(-upRange, upRange)
    Send "{LButton Up}"
    return
}

RightClickRandom(delayBase := KEY_DELAY_BASE, delayRange := KEY_DELAY_RANGE, upBase := KEY_UP_BASE, upRange := KEY_UP_RANGE) {
    Sleep delayBase + Random(-delayRange, delayRange)
    Send "{RButton Down}"
    Sleep upBase + Random(-upRange, upRange)
    Send "{RButton Up}"
    return
}

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

GetItemInfo(delayBase := KEY_DELAY_BASE, delayRange := KEY_DELAY_RANGE, upBase := KEY_UP_BASE, upRange := KEY_UP_RANGE) {
    clipSaved := ClipboardAll()
    A_Clipboard := ""

    Sleep delayBase + Random(-delayRange, delayRange)
    Send "{Ctrl Down}"
    Sleep delayBase + Random(-delayRange, delayRange)
    Send "{C Down}"
    Sleep upBase + Random(-upRange, upRange)
    Send "{C Up}"
    Sleep delayBase + Random(-delayRange, delayRange)
    Send "{Ctrl Up}"
    res := A_Clipboard
    A_Clipboard := clipSaved
    return res
}

GetItemDetailInfo(delayBase := KEY_DELAY_BASE, delayRange := KEY_DELAY_RANGE, upBase := KEY_UP_BASE, upRange := KEY_UP_RANGE) {
    clipSaved := ClipboardAll()
    A_Clipboard := ""

    Sleep delayBase + Random(-delayRange, delayRange)
    Send "{Ctrl Down}"
    Sleep upBase + Random(-upRange, upRange)
    Send "{Alt Down}"
    Sleep delayBase + Random(-delayRange, delayRange)
    Send "{C Down}"
    Sleep upBase + Random(-upRange, upRange)
    Send "{C Up}"
    Sleep delayBase + Random(-delayRange, delayRange)
    Send "{Alt Up}"
    Sleep upBase + Random(-upRange, upRange)
    Send "{Ctrl Up}"
    res := A_Clipboard
    A_Clipboard := clipSaved
    return res
}

MoveItemFast(delayBase := KEY_DELAY_BASE, delayRange := KEY_DELAY_RANGE, upBase := KEY_UP_BASE, upRange := KEY_UP_RANGE) {
    Sleep delayBase + Random(-delayRange, delayRange)
    Send "{Ctrl Down}"
    Sleep delayBase + Random(-delayRange, delayRange)
    Send "{LButton Down}"
    Sleep upBase + Random(-upRange, upRange)
    Send "{LButton Up}"
    Sleep delayBase + Random(-delayRange, delayRange)
    Send "{Ctrl Up}"
}

SplitTenItem(delayBase := KEY_DELAY_BASE, delayRange := KEY_DELAY_RANGE, upBase := KEY_UP_BASE, upRange := KEY_UP_RANGE) {
    Sleep delayBase + Random(-delayRange, delayRange)
    Send "{Shift Down}"
    Sleep delayBase + Random(-delayRange, delayRange)
    Send "{LButton Down}"
    Sleep upBase + Random(-upRange, upRange)
    Send "{LButton Up}"
    Sleep delayBase + Random(-delayRange, delayRange)
    Send "{Shift Up}"
    Sleep delayBase + Random(-delayRange, delayRange)
    Send "{Numpad1 Down}"
    Sleep upBase + Random(-upRange, upRange)
    Send "{Numpad1 Up}"
    Sleep delayBase + Random(-delayRange, delayRange)
    Send "{Numpad0 Down}"
    Sleep upBase + Random(-upRange, upRange)
    Send "{Numpad0 Up}"
    Sleep delayBase + Random(-delayRange, delayRange)
    Send "{Enter Down}"
    Sleep upBase + Random(-upRange, upRange)
    Send "{Enter Up}"
    return
}

FindItemName(text) {
    RegExMatch(text, "稀 有 度:[^\r\n]*\R\R?([\s\S]+?)\R\s*--------", &match)
    if match = "" {
        return ""
    }
    itemName := Trim(match[1], "★ `t")
    return itemName
}

FindItemNumber(text) {
    RegExMatch(text, "堆叠数量: ([0-9]+,?[0-9]*) / [0-9]+", &match)
    itemName := Trim(match[1])
    itemName := StrReplace(itemName, ",")
    ; TextTooltip(itemName)
    return Integer(itemName)
}

FindItemQuality(text) {
    RegExMatch(text, "品质: \+([0-9]+)%", &match)
    if match = "" {
        return 0
    } else {
        return Integer(Trim(match[1]))
    }
}

FindItemType(text) {
    RegExMatch(text, "物品类别: (.+)", &match)
    if match = "" {
        return ""
    }
    itemName := Trim(match[1])
    return itemName
}

FindItemRarity(text) {
    RegExMatch(text, "稀 有 度: (.+)", &match)
    if match = "" {
        return ""
    } else {
        return Trim(match[1])
    }
}

HasContainAnyModifiers(text, modifiers*) {
    for k, v in modifiers {
        if InStr(text, v) {
            return true
        }
    }
    return false
}

IsValueInArray(value, array) {
    for k, v in array {
        if v = value {
            return true
        }
    }
    return false
}

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

; ^1::
; {
;     info := GetItemInfo()
;     MsgBox Mod(10, 3)
; }
; ; ^2::
; ; {
; ;     GetNextLeftClickPos(&x, &y)
; ;     MsgBox x " " y
; ; }

; ; 按 ESC 键退出脚本
; Esc:: ExitApp

; FileToStrArray("cheap.txt")
