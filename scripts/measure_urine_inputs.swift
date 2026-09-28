import Foundation
import CoreGraphics
import ImageIO

// 测量尿蛋白两行输入框（浅色下为 ~0xDCE2DF 描边、内填 ~0xFCFDF9）的左右边缘与宽度
let path = CommandLine.arguments[1]
let url = URL(fileURLWithPath: path) as CFURL
guard let src = CGImageSourceCreateWithURL(url, nil),
      let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { fatalError("读图失败") }
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

// 找输入框：在带状区域内逐行找水平连续 ≥40px 的“描边色”行段（输入框上下边）
// 描边 0xDCE2DF ≈ (0.863,0.886,0.875)，带底 0xEDF5F0 ≈ (0.929,0.961,0.941)
func isBorder(_ c: (r: Double, g: Double, b: Double)) -> Bool {
    abs(c.r - 0.863) < 0.05 && abs(c.g - 0.886) < 0.05 && abs(c.b - 0.875) < 0.05
        && c.r < 0.905
}
// 扫描找所有含 ≥80px 连续描边的行
var hits: [(y: Int, xRange: ClosedRange<Int>)] = []
for y in 0..<h {
    var run = 0, start = -1
    for x in 0..<w {
        if isBorder(px(x, y)) { if run == 0 { start = x }; run += 1 }
        else {
            if run >= 80 { hits.append((y, start...x - 1)) }
            run = 0
        }
    }
    if run >= 80 { hits.append((y, start...w - 1)) }
}
// 聚类成框：相邻行且 x 范围接近的归为一个矩形
var boxes: [(yRange: ClosedRange<Int>, xRange: ClosedRange<Int>)] = []
for hit in hits {
    if var last = boxes.last, hit.y - last.yRange.upperBound <= 2,
       abs(hit.xRange.lowerBound - last.xRange.lowerBound) < 20 {
        last.yRange = last.yRange.lowerBound...hit.y
        last.xRange = min(last.xRange.lowerBound, hit.xRange.lowerBound)...max(last.xRange.upperBound, hit.xRange.upperBound)
        boxes[boxes.count - 1] = last
    } else {
        boxes.append((hit.y...hit.y, hit.xRange))
    }
}
print("检测到 \(boxes.count) 个描边矩形")
for (i, b) in boxes.enumerated() {
    let bw = b.xRange.upperBound - b.xRange.lowerBound + 1
    let bh = b.yRange.upperBound - b.yRange.lowerBound + 1
    print(String(format: "框%d：x [%d, %d] 宽 %dpx（%.0fpt） y [%d, %d] 高 %dpx",
                 i + 1, b.xRange.lowerBound, b.xRange.upperBound, bw, Double(bw) / 3, b.yRange.lowerBound, b.yRange.upperBound, bh))
}
