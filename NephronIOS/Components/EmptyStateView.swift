import SwiftUI

/// 通用空状态：图标 + 标题 + 文案 + 动作按钮。
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(Palette.primary.opacity(0.7))
                .frame(width: 76, height: 76)
                .background(Palette.primarySoft, in: Circle())
            Text(title)
                .font(.headline)
                .foregroundStyle(Palette.primaryText)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Palette.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
            Button(action: action) {
                Text(actionTitle)
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: 220)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .accessibilityElement(children: .combine)
    }
}
