import Foundation
import CoreGraphics
import ImageIO

// 像素级验收：记录行 eGFR 数字是否垂直居中（与左侧两行文字块中线对比）
let path = CommandLine.arguments[1]
let url = URL(fileURLWithPath: path) as CFURL
guard let src = CGImageSourceCreateWithURL(url, nil),
      let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    fatalError("无法读取截图")
}
let w = img.width, h = img.height
let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
let data = ctx.data!.bindMemory(to: UInt8.self, capacity: w * h * 4)

func px(_ x: Int, _ y: Int) -> (r: Double, g: Double, b: Double) {
    let i = (y * w + x) * 4
    return (Double(data[i]) / 255, Double(data[i + 1]) / 255, Double(data[i + 2]) / 255)
}

// 记录行在列表下半部分：扫描 y ∈ [0.45h, 0.85h]，找主题绿色数字像素（App 主色墨绿）
// 同时收集该行左侧主文字（深灰近黑）像素范围，比较两者垂直中线
var rows: [(yRange: ClosedRange<Int>, greenMid: Double, textMid: Double)] = []
var y = Int(Double(h) * 0.45)
var currentGreen: [Int] = []
var currentText: [Int] = []
func flush() {
    guard !currentGreen.isEmpty, !currentText.isEmpty else { currentGreen = []; currentText = []; return }
    let gm = Double(currentGreen.reduce(0, +)) / Double(currentGreen.count)
    let tm = Double(currentText.reduce(0, +)) / Double(currentText.count)
    rows.append((yRange: currentText.min()!...currentText.max()!, greenMid: gm, textMid: tm))
    currentGreen = []; currentText = []
}
while y < Int(Double(h) * 0.85) {
    var hasGreen = false, hasText = false
    for x in (w / 4)..<(w * 3 / 4) {
        let c = px(x, y)
        // 墨绿主色 0x0F5B50 ≈ (0.06, 0.36, 0.31)：绿远高于红、略高于蓝
        if c.g > 0.25, c.g - c.r > 0.15, c.g - c.b > 0.01 { hasGreen = true }
        // 墨色正文 0x17312C ≈ (0.09, 0.19, 0.17)：整体暗且绿≥红
        if c.r < 0.40, c.g < 0.40, c.b < 0.40, c.g >= c.r { hasText = true }
    }
    if hasGreen { currentGreen.append(y) }
    if hasText {
        if currentText.isEmpty || y - currentText.max()! <= 6 { currentText.append(y) }
    } else if !currentText.isEmpty && !currentGreen.isEmpty && y - currentText.max()! > 6 {
        flush()
    }
    if !hasGreen && !currentGreen.isEmpty && y - currentGreen.max()! > 10 { flush() }
    y += 1
}
flush()

print("尺寸 \(w)×\(h)，检测到 \(rows.count) 个记录行区域")
for (i, row) in rows.enumerated() {
    let diff = row.greenMid - row.textMid
    let blockH = Double(row.yRange.upperBound - row.yRange.lowerBound)
    print(String(format: "行%d：数字中线=%.0f 文字块中线=%.0f 偏差=%.1fpx（文字块高%.0f）",
                 i + 1, row.greenMid, row.textMid, diff, blockH))
}
