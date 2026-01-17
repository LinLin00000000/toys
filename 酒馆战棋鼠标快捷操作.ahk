#SingleInstance force
#Warn

; See AHK hotkeys documentation: https://wyagd001.github.io/v2/docs/Hotkeys.htm

+^r:: Reload

WINTITLE := "ahk_exe Hearthstone.exe"

#HotIf WinActive(WINTITLE)

DELAY := 30

CoordMode "Mouse", "Client"

; 获取窗口的宽度和高度，并缓存以提高性能
; 但是每次窗口大小变化时，需要重启脚本
GetWidthAndHeight(&width, &height) {
    static StaticWidth := unset
    static StaticHeight := unset
    if !IsSet(StaticWidth) {
        WinGetClientPos , , &StaticWidth, &StaticHeight, WINTITLE
    }
    width := StaticWidth
    height := StaticHeight
}

MoveAndClickWithRestore(xRatio, yRatio, xpos?, ypos?) {
    if !IsSet(xpos) {
        MouseGetPos &xpos, &ypos
    }
    GetWidthAndHeight &width, &height
    MouseMove width * xRatio, height * yRatio, 0
    Sleep DELAY
    SendInput "{LButton}"
    Sleep DELAY
    MouseMove xpos, ypos, 0
}

ClickAndDrag(xRatio, yRatio) {
    GetWidthAndHeight &width, &height
    SendInput "{LButton down}"
    Sleep DELAY
    MouseMove width * xRatio, height * yRatio, 0
    Sleep DELAY
    SendInput "{LButton up}"
}

ClickAndDragWithRestore(xRatio, yRatio, xpos?, ypos?) {
    if !IsSet(xpos) {
        MouseGetPos &xpos, &ypos
    }
    GetWidthAndHeight &width, &height
    SendInput "{LButton down}"
    Sleep DELAY
    MouseMove width * xRatio, height * yRatio, 0
    Sleep DELAY
    SendInput "{LButton up}"
    Sleep DELAY
    MouseMove xpos, ypos, 0
}

; 发现 1
; a::MoveAndClickWithRestore(0.349, 0.4875)

; 发现 2
; s::MoveAndClickWithRestore(0.5534, 0.4875)

; 发现 3
; d::MoveAndClickWithRestore(0.6479, 0.4875)

; 刷新酒馆
; f::RefreshTavern()

; 冻结酒馆
; Space::MoveAndClickWithRestore(0.6458, 0.1634)

; 鼠标右键重映射为鼠标中键
; 原右键在战棋中仅有双打中标记的功能, 因此改为其他更常用的操作
MButton::RButton

; 根据区域执行不同的操作，智能选择鼠标的落点
RButton:: SmartDrag()

; 根据区域执行不同的操作，执行完成后鼠标返回原位置
XButton1:: SmartDragWithRestore()

; 上侧键为刷新酒馆
XButton2:: RefreshTavern()

RefreshTavern() {
    MoveAndClickWithRestore(0.5885, 0.1921)
}

; 酒馆卡牌区域判断
IsInTavernCardArea(xpos, ypos) {
    static
    GetWidthAndHeight(&width, &height)
    x1 := 0.2565 * width
    y1 := 0.3102 * height
    x2 := 0.7474 * width
    y2 := 0.4444 * height
    return (xpos >= x1 && xpos <= x2 && ypos >= y1 && ypos <= y2)
}

; 场上随从区域判断
IsInMinionsArea(xpos, ypos) {
    static
    GetWidthAndHeight(&width, &height)
    x1 := 0.2565 * width
    y1 := 0.4815 * height
    x2 := 0.7474 * width
    y2 := 0.6157 * height
    return (xpos >= x1 && xpos <= x2 && ypos >= y1 && ypos <= y2)
}

; 手牌区域判断
IsInHandArea(xpos, ypos) {
    static
    GetWidthAndHeight(&width, &height)
    x1 := 0.3164 * width
    y1 := 0.8727 * height
    x2 := 0.6419 * width
    y2 := 0.9977 * height
    return (xpos >= x1 && xpos <= x2 && ypos >= y1 && ypos <= y2)
}

SmartDrag() {
    ; 获取当前鼠标位置
    MouseGetPos &xpos, &ypos
    GetWidthAndHeight(&width, &height)

    ; 判断鼠标所在位置并执行对应的操作
    if (IsInTavernCardArea(xpos, ypos)) {
        ; 从酒馆卡牌区拖动卡牌到手牌区
        ClickAndDrag(0.5885, 0.937)
    } else if (IsInMinionsArea(xpos, ypos)) {
        ; 从场上随从区拖动卡牌到鲍勃脸上出售随从
        ClickAndDrag(0.5, 0.2778)
        ; 从场上区卖怪后, 鼠标会自动移动到手牌区
        Sleep DELAY
        MouseMove width * 0.5885, height * 0.937, 0
    } else if (IsInHandArea(xpos, ypos)) {
        ; 从手牌区拖动卡牌到场上随从区
        ClickAndDrag(0.7, 0.5431)
    } else {
    }
}

SmartDragWithRestore() {
    ; 获取当前鼠标位置
    MouseGetPos &xpos, &ypos

    ; 判断鼠标所在位置并执行对应的操作
    if (IsInTavernCardArea(xpos, ypos)) {
        ClickAndDragWithRestore(0.5885, 0.937, xpos, ypos)
    } else if (IsInMinionsArea(xpos, ypos)) {
        ClickAndDragWithRestore(0.5, 0.2778, xpos, ypos)
    } else if (IsInHandArea(xpos, ypos)) {
        ClickAndDragWithRestore(0.7, 0.5431, xpos, ypos)
    } else {
    }
}

#HotIf