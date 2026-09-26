import SwiftUI
import UIKit

/// 全局配色：浅色以 #F7F8F4 为底、#0F5B50 为主绿、#17312C 为正文色；
/// 深色模式提供同色相暗色变体，保持克制、安静的医疗工具感。
enum Palette {
    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? uiColor(dark) : uiColor(light)
        })
    }

    private static func uiColor(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    /// 页面底色 #F7F8F4
    static let background = dynamic(light: 0xF7F8F4, dark: 0x0E1311)
    /// 白卡片
    static let card = dynamic(light: 0xFFFFFF, dark: 0x1B2622)
    /// 浅绿色卡片
    static let mintCard = dynamic(light: 0xEAF3EE, dark: 0x1D2E29)
    /// 主绿 #0F5B50；深色下提亮以保证对比度
    static let primary = dynamic(light: 0x0F5B50, dark: 0x5BC0AC)
    /// 主绿的浅底（用于徽标、标签）
    static let primarySoft = dynamic(light: 0xDCEBE3, dark: 0x24443C)
    /// 深文字 #17312C
    static let primaryText = dynamic(light: 0x17312C, dark: 0xE4EEE9)
    /// 次要文字
    static let secondaryText = dynamic(light: 0x5C726B, dark: 0x9DB3AB)
    /// 分隔线
    static let hairline = dynamic(light: 0xE3E8E0, dark: 0x2A3631)
    /// 输入框底色
    static let fieldBackground = dynamic(light: 0xF1F4EE, dark: 0x232F2B)
    /// 结果卡片（主绿深底）
    static let resultCard = dynamic(light: 0x0F5B50, dark: 0x14332D)
    /// 结果卡片上的强调数值（浅绿）
    static let resultAccent = dynamic(light: 0x9FE0CB, dark: 0x6FCCB6)
    static let danger = Color.red

    // MARK: 可选指标区（1:1 复刻小程序配色，深色为同色系变体）
    /// 折叠头文字与 +/− 符号
    static let optToggle = dynamic(light: 0x277766, dark: 0x6FBFA8)
    /// +/− 圆圈描边
    static let optCircle = dynamic(light: 0xA7D2C4, dark: 0x2E5147)
    /// 展开内容面板底色
    static let optPanel = dynamic(light: 0xF4FAF6, dark: 0x16211E)
    /// 面板描边
    static let optPanelBorder = dynamic(light: 0xCAE5DA, dark: 0x243931)
    /// 指标块底色（含输入框底色）
    static let optTile = dynamic(light: 0xFCFDF9, dark: 0x1B2622)
    /// 指标块描边
    static let optTileBorder = dynamic(light: 0xE1E7E4, dark: 0x2A3835)
    /// 输入框描边
    static let optInputBorder = dynamic(light: 0xDCE2DF, dark: 0x2E3B37)
    /// 血压 "/" 分隔符
    static let optDivider = dynamic(light: 0x91A099, dark: 0x7E938C)
    /// 尿蛋白区底色
    static let optUrineBand = dynamic(light: 0xEDF5F0, dark: 0x1A2823)
    /// 「尿蛋白」小节标题
    static let optUrineTitle = dynamic(light: 0x668078, dark: 0x8FA69D)
    /// 指标名称
    static let optLabel = dynamic(light: 0x28413C, dark: 0xD8E4DF)
    /// 单位与说明小字
    static let optUnit = dynamic(light: 0x829089, dark: 0x93A79F)
    /// 「已填写 N 项」
    static let optCount = dynamic(light: 0x526D65, dark: 0xA9BEB6)
    /// 「补充至…」提示
    static let optTarget = dynamic(light: 0x899991, dark: 0x8FA099)
    /// 保存按钮
    static let optButton = dynamic(light: 0x176A59, dark: 0x37B495)
    static let optButtonDoneBg = dynamic(light: 0xDCEFE7, dark: 0x1F3B33)
    static let optButtonDoneText = dynamic(light: 0x176A59, dark: 0x7BD0B5)
    static let optButtonDisabledBg = dynamic(light: 0xDFE8E4, dark: 0x2A3835)
    static let optButtonDisabledText = dynamic(light: 0x94A29D, dark: 0x84928D)
}
