import SwiftUI

/// 白卡片容器：圆角 16、轻投影。
/// 统一撑满可用宽度，保证同一页面所有卡片左右边缘对齐（内容收缩不再影响卡片宽度）。
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardBackground())
    }
}

/// 主按钮：主绿填充、白字，按压时轻微变淡。
struct PrimaryButtonStyle: ButtonStyle {
    var filled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(filled ? AnyShapeStyle(Color.white) : AnyShapeStyle(Palette.primary))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(filled ? AnyShapeStyle(Palette.primary) : AnyShapeStyle(Palette.primarySoft))
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.smooth(duration: 0.12), value: configuration.isPressed)
    }
}

/// 次按钮：描边样式。
struct SecondaryButtonStyle: ButtonStyle {
    var tint: Color = Palette.primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(tint.opacity(0.5), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.smooth(duration: 0.12), value: configuration.isPressed)
    }
}

/// 字段错误文案。
struct FieldErrorText: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(Palette.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("输入错误：\(message)")
    }
}

/// 区块小标签（徽标）。
struct BadgeText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .foregroundStyle(Palette.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Palette.primarySoft, in: Capsule())
    }
}
