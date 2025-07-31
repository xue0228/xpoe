Average(arr) {
    sum := 0
    for index, value in arr {
        sum += value
    }
    return sum / arr.Length
}