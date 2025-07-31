#Include xpoe.ahk
#Include lib\FindText\dxgi.ahk
#SingleInstance Force

; 配置文件路径
CONFIG := A_ScriptDir "\config.json"
; 获取配置信息
if FileExist(CONFIG) {
    c := LoadJson(CONFIG)
} else {
    c := ""
}

FUNC0_DATA := A_ScriptDir "\collect.txt"
FUNC3_DATA := A_ScriptDir "\cheap.txt"
FUNC3_LOG := A_ScriptDir "\transform.log"
FUNC4_PREFIX := A_ScriptDir "\prefix.txt"
FUNC4_SUFFIX := A_ScriptDir "\suffix.txt"

; 命令中止标识符
stopFlag := false
stopKey := "Numpad0"

; 拾取配置数据，追求速度，提前初始化相关配置
data0 := FileToStrArray(FUNC0_DATA)
target0 := ""
for k,v in data0 {
    target0 := target0 v
}

; 参数配置窗口
shortcuts := [
    {name: "参数-清空背包", callback : Func1Config, default: "^!Numpad1", active: ""},
    {name: "运行-清空背包", callback : RunFunc1, default: "^Numpad1", active: POE_EXE},
    ; {name: "运行-清空背包2", callback : RunFunc1_2, default: "!Numpad1", active: POE_EXE},

    {name: "参数-10个一组", callback : Func2Config, default: "^!Numpad2", active: ""},
    {name: "运行-10个一组", callback : RunFunc2, default: "^Numpad2", active: POE_EXE},

    {name: "参数-庄园转换", callback : Func3Config, default: "^!Numpad3", active: ""},
    {name: "运行-庄园转换", callback : RunFunc3, default: "^Numpad3", active: POE_EXE},

    {name: "参数-自动改造", callback : Func4Config, default: "^!Numpad4", active: ""},
    {name: "运行-自动改造", callback : RunFunc4, default: "^Numpad4", active: POE_EXE},

    {name: "参数-自动瓦图", callback : Func5Config, default: "^!Numpad5", active: ""},
    {name: "运行-自动瓦图", callback : RunFunc5, default: "^Numpad5", active: POE_EXE},

    {name: "自动拾取", callback : RunFunc0, default: "Space", active: POE_EXE},

    {name: "中止按键", callback : ChangeKey, default: "Numpad0", active: ""},
    {name: "退出程序", callback : Exit, default: "^NumpadSub", active: ""},
]
g0 := ShortcutEditWindow("快捷键设置", shortcuts, Func0Event, "双击托盘图标打开本页面")
if c != "" and c.HasProp("shortcuts") {
    g0.results := c.shortcuts
}
g0.Show()
g1 := RangeSelectWindow("清空背包", Func1Event, "", 5, 11)
if c != "" and c.HasProp("func1") {
    g1.result := c.func1
}
g2 := RangeSelectWindow("10个一组", Func2Event, "", 5, 2)
if c != "" and c.HasProp("func2") {
    g2.result := c.func2
}
g3 := RangeSelectWindow("庄园通货转换", Func3Event, "", 5, 2)
if c != "" and c.HasProp("func3") {
    g3.result := c.func3
}
items := ["知识卷轴", "蜕变石", "改造石", "增幅石", "重铸石", "目标装备"]
g4 := ItemPositionWindow("自动改造", items, Func4Event, "")
if c != "" and c.HasProp("func4") {
    g4.results := c.func4
}

items2 := ["制图钉", "知识卷轴", "重铸石", "点金石", "瓦尔宝珠"]
g5_1 := RangeSelectWindow("自动瓦图", Func5Event1, "", 5, 11)
g5_2 := ItemPositionWindow("自动瓦图", items2, Func5Event2, "")
if c != "" and c.HasProp("func5") {
    g5_1.results := c.func5.c1
    g5_2.results := c.func5.c2
}

A_TrayMenu.Add()  ; 创建分隔线.
A_TrayMenu.Add("快捷键设置", MenuHandler)  ; 创建新菜单项.
A_TrayMenu.Default := "快捷键设置"

MenuHandler(ItemName, ItemPos, MyMenu) {
    g0.Show()
}

ChangeKey(HotkeyName) {
    global stopFlag, stopKey
    stopKey := HotkeyName
    stopFlag := true
    Hotkey(HotkeyName, "off")
    ; TextTooltip "test"
}

WaitStop() {
    global stopFlag, stopKey
    if GetKeyState(stopKey, "P") {
        stopFlag := true
        TextTooltip("已中断")
        SetTimer(, 0)
    }
}

Func0Event(*) {
    global g0, c
    try {
        tem := g0.results
    } catch Error as err {
        MsgBox err.Message
        return
    }

    if c = "" {
        c := { shortcuts: tem }
    } else {
        c.shortcuts := tem
    }

    SaveJson(c, CONFIG)
    return
}

Func1Event(*) {
    global g1, c
    try {
        tem := g1.result
    } catch Error as err {
        MsgBox err.Message
        return
    }

    if tem.r <= 0 or tem.c <= 0 {
        return
    }

    if c = "" {
        c := { func1: tem }
    } else {
        c.func1 := tem
    }

    SaveJson(c, CONFIG)
    g1.Hide()
    return
}

Func2Event(*) {
    global g2, c
    try {
        tem := g2.result
    } catch Error as err {
        MsgBox err.Message
        return
    }

    if Mod(tem.c, 2) = 1 {
        tem.c := tem.c - 1
    }
    if tem.r <= 0 or tem.c <= 0 {
        return
    }

    g2.c := tem.c

    if c = "" {
        c := { func2: tem }
    } else {
        c.func2 := tem
    }

    SaveJson(c, CONFIG)
    g2.Hide()
    return
}

Func3Event(*) {
    global g3, c
    try {
        tem := g3.result
    } catch Error as err {
        MsgBox err.Message
        return
    }

    if tem.r <= 0 or tem.c <= 0 {
        return
    }

    g3.Hide()
    GetNextLeftClickPos(&x1, &y1)
    GetNextLeftClickPos(&x2, &y2)

    tem.x1 := x1
    tem.x2 := x2
    tem.y1 := y1
    tem.y2 := y2

    if c = "" {
        c := { func3: tem }
    } else {
        c.func3 := tem
    }

    SaveJson(c, CONFIG)
    return
}

Func4Event(*) {
    global g4, c
    try {
        tem := g4.results
    } catch Error as err {
        MsgBox err.Message
        return
    }

    g4.Hide()

    if c = "" {
        c := { func4: tem }
    } else {
        c.func4 := tem
    }

    SaveJson(c, CONFIG)
    return
}

Func5Event1(*) {
    global g5_1, g5_2, c
    try {
        tem := g5_1.result
    } catch Error as err {
        MsgBox err.Message
        return
    }

    if tem.r <= 0 or tem.c <= 0 {
        return
    }

    g5_1.Hide()
    g5_2.Show()
    return
}

Func5Event2(*) {
    global g5_1, g5_2, c
    try {
        tem := g5_2.results
    } catch Error as err {
        MsgBox err.Message
        return
    }

    g5_2.Hide()

    if c = "" {
        c := { func5: { c1: g5_1.result, c2: tem } }
    } else {
        c.func5 := {}
        c.func5.c1 := g5_1.result
        c.func5.c2 := tem
    }

    SaveJson(c, CONFIG)
    return
}

; 清空背包
Func1() {
    TimeBeginPeriod()

    global c, stopFlag
    rows := c.func1.r
    cols := c.func1.c
    r := Rect(c.func1.x, c.func1.y, , , c.func1.w, c.func1.h)
    sub := r.SplitByRowAndCol(rows, cols)
    KeyDown("LControl")
    reversed := false
    first := true
    Loop cols {
        j := A_Index
        Loop rows {
            if stopFlag {
                KeyUp("LControl")
                stopFlag := false
                return
            }

            if !reversed {
                i := A_Index
            } else {
                i := rows + 1 - A_Index
            }

            center := sub[i][j].center
            if first {
                MoveMouseRandomBezier(center.x, center.y,,,,false)
                first := false
            } else {
                MoveMouseRandomBezier(center.x, center.y, , 90, 10,false)
            }
            KeyBetweenSleepRandom()
            MouseClickRandom(,false)
        }
        reversed := !reversed
    }
    KeyUp("LControl")

    TimeEndPeriod()
}
; Func1_2() {
;     KeyDown("lshift")
;     Func1()
;     KeyUp("lshift")
; }

; 每组取出10个
Func2() {
    TimeBeginPeriod()

    global c, stopFlag
    rows := c.func2.r
    cols := c.func2.c
    r := Rect(c.func2.x, c.func2.y, , , c.func2.w, c.func2.h)
    sub := r.SplitByRowAndCol(rows, cols)
    targetCols := cols // 2

    loop targetCols {
        j := A_Index
        loop rows {
            if stopFlag {
                stopFlag := false
                return
            }
            i := A_Index
            center := sub[i][j].center
            MoveMouseRandomBezier(center.x, center.y)
            info := GetItemInfo()
            if info != "" {
                try {
                    if FindItemNumber(info) <= 10 {
                        continue
                    }
                } catch {
                    continue
                }
                SplitItems(10)
                center := sub[i][targetCols + j].center
                MoveMouseRandomBezier(center.x, center.y)
                MouseClickRandom()
            }
        }
    }

    TimeEndPeriod()
    return
}

; 转化通货
Func3() {
    TimeBeginPeriod()

    global c, stopFlag
    rows := c.func3.r
    cols := c.func3.c
    r := Rect(c.func3.x, c.func3.y, , , c.func3.w, c.func3.h)
    sub := r.SplitByRowAndCol(rows, cols)

    data := FileToStrArray(FUNC3_DATA)

    loop cols {
        j := A_Index
        loop rows {
            if stopFlag {
                stopFlag := false
                return
            }
            i := A_Index
            center := sub[i][j].center
            MoveMouseRandomBezier(center.x, center.y)
            info := GetItemInfo()
            if info != "" {
                name := FindItemName(info)
                if IsValueInArray(name, data) {
                    MoveItemFast()
                    MoveMouseRandomBezier(c.func3.x2, c.func3.y2)
                    MouseClickRandom()
                    MoveMouseRandomBezier(c.func3.x1, c.func3.y1)
                    tem := GetItemInfo()
                    if tem = "" {
                        return
                    }
                    tem := FindItemName(tem)
                    if tem = name {
                        return
                    }
                    FileAppend(tem "`r`n", FUNC3_LOG, "UTF-8")
                    last := tem
                    while IsValueInArray(tem, data) {
                        if stopFlag {
                            stopFlag := false
                            return
                        }
                        MoveMouseRandomBezier(c.func3.x2, c.func3.y2)
                        MouseClickRandom()
                        MoveMouseRandomBezier(c.func3.x1, c.func3.y1)
                        tem := GetItemInfo()
                        if tem = "" {
                            return
                        }
                        tem := FindItemName(tem)
                        if tem = last {
                            return
                        }
                        FileAppend(tem "`r`n", FUNC3_LOG, "UTF-8")
                        last := tem
                    }
                    MoveItemFast()
                }
            }
        }
    }

    TimeEndPeriod()
}

; 自动改造
Func4() {
    TimeBeginPeriod()

    global c, stopFlag, items
    results := c.func4
    ; 确保通货存在
    numbers := []
    loop 5 {
        if stopFlag {
            stopFlag := false
            return
        }
        MoveMouseRandomBezier(results[A_Index].x, results[A_Index].y)
        item_info := GetItemInfo()
        if item_info = "" {
            TextTooltip("没有找到" items[A_Index])
            return
        }
        numbers.Push(FindItemNumber(item_info))
    }
    ; 确保目标装备存在
    MoveMouseRandomBezier(results[6].x, results[6].y)
    info := GetItemDetailInfo()
    if info = "" {
        TextTooltip("未检测到装备")
        return
    }
    ; 确保装备未腐化
    if HasContainAnyModifiers(info, "已腐化") {
        TextTooltip("目标装备已腐化")
        return
    }
    ; 确保装备已鉴定
    if HasContainAnyModifiers(info, "未鉴定") {
        MoveMouseRandomBezier(results[1].x, results[1].y)
        MouseClickRandom("Right")
        MoveMouseRandomBezier(results[6].x, results[6].y)
        MouseClickRandom()
    }

    ; 从文件中读取目标前后缀
    prefix := FileToStrArray(FUNC4_PREFIX)
    suffix := FileToStrArray(FUNC4_SUFFIX)

    ; 确保装备稀有度为魔法
    loop {
        if stopFlag {
            stopFlag := false
            return
        }

        if HasContainAnyModifiers(info, prefix*) or HasContainAnyModifiers(info, suffix*) {
            return
        }

        rarity := FindItemRarity(info)
        if rarity = "稀有" {
            MoveMouseRandomBezier(results[5].x, results[5].y)
            MouseClickRandom("Right")
            MoveMouseRandomBezier(results[6].x, results[6].y)
            MouseClickRandom()
        } else if rarity = "普通" {
            MoveMouseRandomBezier(results[2].x, results[2].y)
            MouseClickRandom("Right")
            MoveMouseRandomBezier(results[6].x, results[6].y)
            MouseClickRandom()
        } else if rarity = "魔法" {
            break
        } else {
            TextTooltip("不支持的稀有度：" rarity)
        }
        info := GetItemDetailInfo()
        if info = "" {
            TextTooltip("未检测到装备")
            return
        }
    }

    MoveMouseRandomBezier(results[3].x, results[3].y)
    KeyDown("lshift")
    MouseClickRandom("Right")
    MoveMouseRandomBezier(results[6].x, results[6].y)
    while !HasContainAnyModifiers(info, prefix*) and !HasContainAnyModifiers(info, suffix*) {
        if stopFlag {
            KeyUp("lshift")
            stopFlag := false
            return
        }

        if (prefix.Length > 0 and !HasContainAnyModifiers(info, "前缀")) or (suffix.Length > 0 and !HasContainAnyModifiers(info, "后缀")) {
            KeyUp("lshift")
            MouseClickRandom("Right")

            MoveMouseRandomBezier(results[4].x, results[4].y)
            MouseClickRandom("Right")
            MoveMouseRandomBezier(results[6].x, results[6].y)
            if numbers[4] > 0 {
                MouseClickRandom()
                numbers[4] := numbers[4] - 1
            } else {
                TextTooltip(items[4] "已用完")
                return
            }

            MoveMouseRandomBezier(results[3].x, results[3].y)
            KeyDown("lshift")
            MouseClickRandom("Right")
            MoveMouseRandomBezier(results[6].x, results[6].y)
        } else {
            if numbers[3] > 0 {
                MouseClickRandom()
                numbers[3] := numbers[3] - 1
            } else {
                TextTooltip(items[3] "已用完")
                KeyUp("lshift")
                return
            }
        }
        info := GetItemDetailInfo()
        if info = "" {
            TextTooltip("未检测到装备")
            KeyUp("lshift")
            return
        }
    }
    KeyUp("lshift")

    TimeEndPeriod()
    return
}

; 自动瓦图
Func5() {
    TimeBeginPeriod()

    global c, stopFlag

    results := c.func5.c2
    ; 确保通货存在
    numbers := []
    loop results.Length {
        if stopFlag {
            stopFlag := false
            return
        }
        MoveMouseRandomBezier(results[A_Index].x, results[A_Index].y)
        item_info := GetItemInfo()
        if item_info = "" {
            TextTooltip("没有找到" items2[A_Index])
            return
        }
        numbers.Push(FindItemNumber(item_info))
    }

    rows := c.func5.c1.r
    cols := c.func5.c1.c
    r := Rect(c.func5.c1.x, c.func5.c1.y, , , c.func5.c1.w, c.func5.c1.h)
    sub := r.SplitByRowAndCol(rows, cols)

    next2 := []
    next3 := []
    next4 := []
    next5 := []

    ; 使用制图钉
    MoveMouseRandomBezier(results[1].X, results[1].y)
    KeyDown("lshift")
    MouseClickRandom("Right")

    ; reversed := false
outer:
    Loop cols {
        j := A_Index
        Loop rows {
            if stopFlag {
                KeyUp("lshift")
                stopFlag := false
                return
            }
            i := A_Index
            center := sub[i][j].center

            MoveMouseRandomBezier(center.x, center.y)
            info := GetItemInfo()
            if info = "" {
                break outer
            }
            if FindItemType(info) != "异界地图" {
                continue
            }
            if HasContainAnyModifiers(info, "已腐化", "已复制") {
                continue
            }
            quality := FindItemQuality(info)
            times := Ceil((20 - quality) / 5)
            while times > 0 {
                if numbers[1] > 0 {
                    MouseClickRandom()
                    numbers[1] := numbers[1] - 1
                } else {
                    KeyUp("lshift")
                    TextTooltip(items2[1] "已用完")
                    return
                }
                times := times - 1
            }
            pos := { r: i, c: j }
            next5.Push(pos)
            if HasContainAnyModifiers(info, "未鉴定") {
                next2.Push(pos)
            }
            rarity := FindItemRarity(info)
            if rarity != "稀有" and rarity != "普通" {
                next3.Push(pos)
            }
            if rarity != "稀有" {
                next4.Push(pos)
            }
        }
        ; reversed := !reversed
    }
    KeyUp("lshift")

    ; 使用知识卷轴
    if next2.Length = 0 {
        goto step3
    }
    MoveMouseRandomBezier(results[2].x, results[2].y)
    KeyDown("lshift")
    MouseClickRandom("Right")

    for k, v in next2 {
        if stopFlag {
            KeyUp("lshift")
            stopFlag := false
            return
        }
        target := sub[v.r][v.c].center
        MoveMouseRandomBezier(target.x, target.y)
        info := GetItemInfo()
        if info = "" {
            KeyUp("lshift")
            TextTooltip("没有找到地图")
            return
        }
        if HasContainAnyModifiers(info, "未鉴定") {
            if numbers[2] > 0 {
                MouseClickRandom()
                numbers[2] := numbers[2] - 1
            } else {
                KeyUp("lshift")
                TextTooltip(items2[2] "已用完")
                return
            }
        }

    }
    KeyUp("lshift")

    ; 使用重铸石
step3:
    if next3.Length = 0 {
        goto step4
    }
    MoveMouseRandomBezier(results[3].x, results[3].y)
    KeyDown("lshift")
    MouseClickRandom("Right")

    for k, v in next3 {
        if stopFlag {
            KeyUp("lshift")
            stopFlag := false
            return
        }
        target := sub[v.r][v.c].center
        MoveMouseRandomBezier(target.x, target.y)
        info := GetItemInfo()
        if info = "" {
            KeyUp("lshift")
            TextTooltip("没有找到地图")
            return
        }
        if HasContainAnyModifiers(info, "未鉴定") {
            continue
        }
        rarity := FindItemRarity(info)
        if rarity = "" {
            KeyUp("lshift")
            TextTooltip("未知稀有度")
            return
        }
        if rarity != "稀有" and rarity != "普通" {
            if numbers[3] > 0 {
                MouseClickRandom()
                numbers[3] := numbers[3] - 1
            } else {
                KeyUp("lshift")
                TextTooltip(items2[3] "已用完")
                return
            }
        }
    }
    KeyUp("lshift")

    ; 使用点金石
step4:
    if next4.Length = 0 {
        goto step5
    }
    MoveMouseRandomBezier(results[4].x, results[4].y)
    KeyDown("lshift")
    MouseClickRandom("Right")

    for k, v in next4 {
        if stopFlag {
            KeyUp("lshift")
            stopFlag := false
            return
        }
        target := sub[v.r][v.c].center
        MoveMouseRandomBezier(target.x, target.y)
        info := GetItemInfo()
        if info = "" {
            KeyUp("lshift")
            TextTooltip("没有找到地图")
            return
        }
        rarity := FindItemRarity(info)
        if rarity = "" {
            KeyUp("lshift")
            TextTooltip("未知稀有度")
            return
        }
        if rarity = "普通" {
            if numbers[4] > 0 {
                MouseClickRandom()
                numbers[4] := numbers[4] - 1
            } else {
                KeyUp("lshift")
                TextTooltip(items2[4] "已用完")
                return
            }
        }
    }
    KeyUp("lshift")

    ; 使用瓦尔宝珠
step5:
    if next5.Length = 0 {
        return
    }
    MoveMouseRandomBezier(results[5].X, results[5].y)
    KeyDown("lshift")
    MouseClickRandom("Right")

    for k, v in next5 {
        if stopFlag {
            KeyUp("lshift")
            stopFlag := false
            return
        }
        target := sub[v.r][v.c].center
        MoveMouseRandomBezier(target.x, target.y)
        info := GetItemInfo()
        if info = "" {
            KeyUp("lshift")
            TextTooltip("没有找到地图")
            return
        }
        if FindItemQuality(info) < 20 {
            continue
        }
        rarity := FindItemRarity(info)
        if rarity = "" {
            KeyUp("lshift")
            TextTooltip("未知稀有度")
            return
        }
        if rarity = "稀有" {
            if numbers[5] > 0 {
                MouseClickRandom()
                numbers[5] := numbers[5] - 1
            } else {
                KeyUp("lshift")
                TextTooltip(items2[5] "已用完")
                return
            }
        }
    }
    KeyUp("lshift")
    A_Clipboard := "物品数量: \+.{3}%"

    TimeEndPeriod()
}

Func1Config(*) {
    g1.Show()
    return
}

Func2Config(*) {
    g2.Show()
    return
}

Func3Config(*) {
    g3.Show()
    return
}

Func4Config(*) {
    g4.Show()
    return
}

Func5Config(*) {
    g5_1.Show()
    return
}

; ^!Numpad1::
; {
;     g1.Show()
;     return
; }

; ^!Numpad2::
; {
;     g2.Show()
;     return
; }

; ^!Numpad3::
; {
;     g3.Show()
;     return
; }

; ^!Numpad4::
; {
;     g4.Show()
;     return
; }

; ^!Numpad5::
; {
;     g5_1.Show()
;     return
; }

; #HotIf WinActive(POE_EXE)

RunFunc0(*){
    TimeBeginPeriod()

    global target0
    if (ok := FindText(&x, &y, 0, 0, A_ScreenWidth, A_ScreenHeight, 0, 0, target0, 1, 0, , , , 9)) {
        MouseGetPos(&x1, &y1)
        MouseMove(x, y)
        SystemSleep(15)
        Click()
        Click()
        MouseMove(x1, y1)
    } else {
        TextTooltip("无拾取目标")
    }
    SystemSleep(100)

    TimeEndPeriod()
}

WaitBeforeRun := 500

RunFunc1(*){
    global c, stopFlag
    if c = "" or !c.HasProp("func1") {
        g1.Show()
        return
    }
    Sleep WaitBeforeRun
    stopFlag := false
    SetTimer(WaitStop, 100)
    Func1()
    SetTimer(WaitStop, 0)
    SoundBeep()
    SoundBeep()
    return
}

; RunFunc1_2(*){
;     global c, stopFlag
;     if c = "" or !c.HasProp("func1") {
;         g1.Show()
;         return
;     }
;     Sleep WaitBeforeRun
;     stopFlag := false
;     SetTimer(WaitStop, 100)
;     Func1_2()
;     SetTimer(WaitStop, 0)
;     SoundBeep()
;     SoundBeep()
;     return
; }

RunFunc2(*){
    global c, stopFlag
    if c = "" or !c.HasProp("func2") {
        g2.Show()
        return
    }

    Sleep WaitBeforeRun
    stopFlag := false
    SetTimer(WaitStop, 100)
    Func2()
    SetTimer(WaitStop, 0)
    SoundBeep()
    SoundBeep()
    return
}

RunFunc3(*){
    global c, stopFlag
    if c = "" or !c.HasProp("func3") {
        g3.Show()
        return
    }

    Sleep WaitBeforeRun
    stopFlag := false
    SetTimer(WaitStop, 100)
    Func3()
    SetTimer(WaitStop, 0)
    SoundBeep()
    SoundBeep()
    return
}

RunFunc4(*){
    global c, stopFlag
    if c = "" or !c.HasProp("func4") {
        g4.Show()
        return
    }

    Sleep WaitBeforeRun
    stopFlag := false
    SetTimer(WaitStop, 100)
    Func4()
    SetTimer(WaitStop, 0)
    SoundBeep()
    SoundBeep()
    return
}

RunFunc5(*){
    global c, stopFlag
    if c = "" or !c.HasProp("func5") {
        g5_1.Show()
        return
    }

    Sleep WaitBeforeRun
    stopFlag := false
    SetTimer(WaitStop, 100)
    Func5()
    SetTimer(WaitStop, 0)
    SoundBeep()
    SoundBeep()
    return
}

Exit(*){
    ExitApp
    return
}
