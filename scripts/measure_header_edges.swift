import Foundation
import CoreGraphics
import ImageIO

// 像素级验收：页头两行文字的最左像素 vs 摘要卡片左边缘，检查文字是否顶到屏幕边缘被切
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
func lum(_ c: (r: Double, g: Double, b: Double)) -> Double { 0.299 * c.r + 0.587 * c.g + 0.114 * c.b }

// CG 坐标 y=0 在底部：截图顶部 = y 接近 h。扫描顶部 30% 区域。
let scale = Double(w) / 393.0
var lines: [(yTop: Int, yBot: Int, minX: Int)] = []
var inLine = false
var y = Int(Double(h) * 0.70)
let yEnd = Int(Double(h) * 0.985)
var curMinX = Int.max, curStart = 0
while y < yEnd {
    var minX = Int.max
    var dark = 0
    for x in 0..<(w / 3) {
        if lum(px(x, y)) < 0.45 { dark += 1; if x < minX { minX = x } }
    }
    if dark >= 3 {
        if !inLine { inLine = true; curStart = y; curMinX = minX } else { curMinX = min(curMinX, minX) }
    } else if inLine {
        lines.append((yTop: curStart, yBot: y, minX: curMinX))
        inLine = false
    }
    y += 2
}
if inLine { lines.append((yTop: curStart, yBot: y, minX: curMinX)) }

print("图像 \(w)x\(h) scale≈\(String(format: "%.0f", scale))x（CG y 向上，0=底）")
for (i, l) in lines.enumerated() {
    // 转成从顶部数的坐标方便对照
    let fromTop = h - l.yBot
    print("文字行\(i)：CGy[\(l.yTop)..\(l.yBot)] 距顶\(fromTop)px  最左x=\(l.minX)px ≈ \(String(format: "%.1f", Double(l.minX)/scale))pt")
}

// 卡片左边缘：在摘要卡区域找一行水平扫描的颜色跳变
outer: for y in stride(from: Int(Double(h) * 0.60), to: Int(Double(h) * 0.70), by: 4) {
    var prev = px(0, y)
    for x in 1..<160 {
        let c = px(x, y)
        if abs(c.r - prev.r) + abs(c.g - prev.g) + abs(c.b - prev.b) > 0.10 {
            print("y=\(y) 颜色分界 x=\(x)px ≈ \(String(format: "%.1f", Double(x)/scale))pt（卡片左边缘）")
            break outer
        }
        prev = c
    }
}
