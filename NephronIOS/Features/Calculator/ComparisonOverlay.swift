import SwiftUI

/// 居中“记录对照”确认卡：发现同日期记录时由保存动作触发，
/// 通过 CenterCardPresenter 以真实呈现层居中展示（浅遮罩、无底部滑入）。
/// 本视图只承载卡片内容，遮罩与点击关闭由呈现器负责。
struct ComparisonOverlay: View {
    let existing: RecordModel
    let dateText: String
    let onUpdate: () -> Void
    let onKeepNew: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            BadgeText(text: "发现同日期记录")

            Text("\(dateText) 已保存过")
                .font(.headline)
                .foregroundStyle(Palette.primaryText)
                .multilineTextAlignment(.center)

            // 预览区域：已有 eGFR / 数值 / 保存于 HH:mm
            VStack(alignment: .leading, spacing: 8) {
                Text("已有 eGFR")
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(EGFRCalculator.formattedNumber(existing.egfr))
                        .font(.title.weight(.semibold))
                        .foregroundStyle(Palette.primary)
                    Text("eGFR")
                        .font(.footnote)
                        .foregroundStyle(Palette.secondaryText)
                }
                Text("保存于 \(DayDate.timeFormatter.string(from: existing.createdAt))")
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Palette.mintCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityElement(children: .combine)

            Button(action: onUpdate) {
                Text("用本次结果更新")
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("comparison.update.button")

            HStack(spacing: 10) {
                Rectangle()
                    .fill(Palette.hairline)
                    .frame(height: 1)
                Text("或")
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
                Rectangle()
                    .fill(Palette.hairline)
                    .frame(height: 1)
            }

            Button(action: onKeepNew) {
                Text("保留为新记录")
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityIdentifier("comparison.keep-new.button")
        }
        .padding(20)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 22, y: 8)
        .accessibilityElement(children: .contain)
    }
}
