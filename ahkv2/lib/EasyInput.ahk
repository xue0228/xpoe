#Requires AutoHotkey v2.0 64-bit

; IbSendInit("LogitechGHubNew")
; IbSendInit("Logitech")
; IbSendInit("DD", 1, A_LineFile "\..\" (A_PtrSize * 8) "bit\ddhid54908.dll")
; IbSendInit("Razer")

; RAZER_MOUSE_HEIGHT_FACTOR := 1.2

MAX_MOUSE_SPEED := 5000
MOUSE_ACC := 5
MOUSE_SPEED_BASE := 50
MOUSE_SPEED_RANGE := 25

; 在 PC 中休眠持续时间一般向上取整到 15.6 ms, 尝试 TimePeriod=7 来允许
; 稍短一点的休眠, 而尝试 TimePeriod=3 或更小的值来允许最小可能的休眠.
SleepDuration := 1  ; 这里有时可以根据下面的值进行细微调整(例如 2 与 3 的区别).
TimePeriod := 3 ; 尝试 7 或 3. 请参阅下面的注释.

KEY_UP_BASE := 60
KEY_UP_RANGE := 20
KEY_BETWEEN_BASE := 30
KEY_BETWEEN_RANGE := 10
COMMAND_BETWEEN_BASE := 100
COMMAND_BETWEEN_RANGE := 25

; KEY_UP_BASE := 100
; KEY_UP_RANGE := 25
; KEY_BETWEEN_BASE := 100
; KEY_BETWEEN_RANGE := 25
; COMMAND_BETWEEN_BASE := 100
; COMMAND_BETWEEN_RANGE := 25

; 设定系统最小休眠间隔
; https://wyagd001.github.io/v2/docs/lib/Sleep.htm
TimeBeginPeriod(period := TimePeriod) {
    DllCall("Winmm\timeBeginPeriod", "UInt", period)  ; 作用于所有的应用程序, 而不只是脚本的 DllCall("Sleep"...), 但不影响 SetTimer.
}

TimeEndPeriod(period := TimePeriod) {
    DllCall("Winmm\timeEndPeriod", "UInt", period)
}

; 搭配 TimeBeginPeriod 使用的休眠
SystemSleep(duration := SleepDuration) {
    DllCall("Sleep", "UInt", duration)
}

; 计算三次贝塞尔曲线的值
CalBezier(t, x1, x2, x3, x4) {
    return x1 * (1 - t) * (1 - t) * (1 - t) + 3 * x2 * t * (1 - t) * (1 - t) + 3 * x3 * t * t * (1 - t) + x4 * t * t * t
}

; 模拟 500Hz 回报率鼠标的移动，基于贝塞尔曲线
; 鼠标移动速度可设定范围为(0, 100]，100 为最快速度
MoveMouseRandomBezier(x, y, acc := MOUSE_ACC, speedBase := MOUSE_SPEED_BASE, speedRange := MOUSE_SPEED_RANGE, hasDelay := true) {
    ; 速度数值判断
    if speedBase <= 0 or speedBase > 100 {
        throw ValueError("speedBase " speedBase " not in range (0, 100]", -1, speedBase)
    }
    if speedRange >= speedBase {
        throw ValueError("speedBase " speedBase " must larger than speedRange " speedRange, -1, { speedBase: speedBase, speedRange: speedRange })
    }

    if hasDelay {
        CommandBetweenSleepRandom()
    }

    ; 起止点坐标
    MouseGetPos(&x1, &y1)
    x4 := x + Random(-acc, acc)
    y4 := y + Random(-acc, acc)
    ; 起止点距离
    distance := Sqrt((x1 - x4) * (x1 - x4) + (y1 - y4) * (y1 - y4))
    ; 方向点
    r := Round(0.5 * distance)
    x2 := Random(Max(0, x1 - r), Min(A_ScreenWidth, x1 + r))
    y2 := Random(Max(0, y1 - r), Min(A_ScreenHeight, y1 + r))
    x3 := Random(Max(0, x4 - r), Min(A_ScreenWidth, x4 + r))
    y3 := Random(Max(0, y4 - r), Min(A_ScreenHeight, y4 + r))
    ; 鼠标移动速度计算：px/s
    speed := MAX_MOUSE_SPEED / 100 * (speedBase + Random(-speedRange, speedRange))
    ; 默认鼠标回报率500Hz，计算数据点总数
    num := Ceil(distance / speed * 500)

    ;计算 t
    v1 := 100
    v4 := 0
    rV := Random(0.5 * (v1 - v4))
    v2 := Random(v1 - rV, v1 + rV)
    v3 := Random(v4 - rV, v4 + rV)
    v := [v1]
    dv := 1 / (num - 1)
    loop num - 2 {
        v.Push(CalBezier(A_Index * dv, v1, v2, v3, v4))
    }
    v.Push(v4)
    t := [0]
    loop num - 1 {
        t.Push(t[A_Index] + dv * (v[A_Index + 1] + v[A_Index]) / 2)
    }
    t.RemoveAt(1)
    for index, value in t {
        SystemSleep()
        MouseMove(CalBezier(value / t[t.Length], x1, x2, x3, x4), CalBezier(value / t[t.Length], y1, y2, y3, y4))
    }

    return num
}

SleepRandom(base, range) {
    SystemSleep(base + Random(-range, range))
}

KeyUpSleepRandom() {
    SleepRandom(KEY_UP_BASE, KEY_UP_RANGE)
}

KeyBetweenSleepRandom() {
    SleepRandom(KEY_BETWEEN_BASE, KEY_BETWEEN_RANGE)
}

CommandBetweenSleepRandom() {
    SleepRandom(COMMAND_BETWEEN_BASE, COMMAND_BETWEEN_RANGE)
}

KeyDown(key, hasDelay := true) {
    if hasDelay {
        CommandBetweenSleepRandom()
    }
    code := "{" key " Down}"
    SendInput(code)
}

KeyUp(key, hasDelay := true) {
    if hasDelay {
        CommandBetweenSleepRandom()
    }
    code := "{" key " Up}"
    SendInput(code)
}

TapKeys(keys*) {
    CommandBetweenSleepRandom()
    ; res := ""
    loop keys.Length {
        i := A_Index
        KeyDown(keys[i], false)
        ; res := res "-" keys[i] "D"
        if i != keys.Length {
            KeyBetweenSleepRandom()
            ; res := res "-B"
        } else {
            KeyUpSleepRandom()
            ; res := res "-U"
        }
    }
    loop keys.Length {
        i := keys.Length + 1 - A_Index
        KeyUp(keys[i], false)
        ; res := res "-" keys[i] "U"
        if i != 1 {
            KeyBetweenSleepRandom()
            ; res := res "-B"
        }
    }
    ; return res
}

MouseClickRandom(button := "Left", hasDelay := true) {
    if hasDelay {
        CommandBetweenSleepRandom()
    }
    Click("Down " button)
    KeyUpSleepRandom()
    Click("Up " button)
}

; ^1::
; {
;     ; TimeBeginPeriod()
;     x :=MoveMouseRandomBezier(600, 600)
;     ; TimeEndPeriod()
;     ; PrintArray(x)
;     ; MsgBox x[1] " " x[x.Length]
;     ; MsgBox x
;     KeyWait "Ctrl"
;     TapKeys("Ctrl", "v")
; }