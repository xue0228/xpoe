PrintArray(arr) {
    ; 初始化一个空字符串用于累积数组元素
    output := ""

    ; 遍历数组中的每个元素
    for index, value in arr {
        ; 将元素添加到输出字符串中
        output .= "Index " index ": " value "`n"
    }

    ; 使用 MsgBox 显示结果
    MsgBox(output)
}