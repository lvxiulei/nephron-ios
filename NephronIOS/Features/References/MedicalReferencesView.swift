import SwiftUI

/// 公式说明与引用随 App 离线提供；只有主动点击来源才交由系统打开网页。
struct MedicalReferencesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    formulaCard
                    sourcesCard
                    limitsCard
                    rangesCard
                    Text("本工具仅供个人记录与参考，不提供诊断、处方或治疗建议。如有不适或对结果有疑问，请咨询专业医生。")
                        .font(.footnote)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
            }
            .background(Palette.background)
            .navigationTitle("公式与参考来源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .accessibilityIdentifier("medical.references.done")
                }
            }
            .tint(Palette.primary)
        }
    }

    private var formulaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("CKD-EPI 2021")
            paragraph(MedicalReference.applicability)
            Text(MedicalReference.formula)
                .font(.footnote.monospaced())
                .foregroundStyle(Palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.fieldBackground, in: RoundedRectangle(cornerRadius: 10))
            paragraph(MedicalReference.coefficients)
            paragraph(MedicalReference.conversion)
            paragraph("min 取两者较小值，max 取两者较大值；公式使用经标准化的实验室血肌酐，不包含种族系数。[1, 2]")
        }
        .cardStyle()
    }

    private var limitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("如何理解估算值")
            paragraph("趋势通常比单次估算更有帮助；医生还需结合尿白蛋白等检查评估肾脏情况。[2]")
            paragraph("饮食、肌肉量、妊娠和部分药物等因素会影响血肌酐或估算的准确性，特殊情况下需由医生选择合适的评估方法。[3]")
            paragraph("不同公式可能给出不同结果；本工具未使用胱抑素 C。不要依据本结果自行调整药物或治疗。[2]")
        }
        .cardStyle()
    }

    private var rangesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("结果区间的依据")
            paragraph("App 的区间按 ≥90、60–89、45–59、30–44、15–29、＜15 划分，参考 NKF 的 GFR 分类；单位为 mL/min/1.73 m²。[4]")
            paragraph("这里仅显示数值区间，不据此判定疾病分期。在没有肾损伤证据时，G1 或 G2 区间本身不满足 CKD 诊断条件。[4]")
        }
        .cardStyle()
    }

    private var sourcesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading("参考来源")
            Text("以下为英文原文。点击链接将使用系统浏览器打开。")
                .font(.footnote)
                .foregroundStyle(Palette.secondaryText)
            ForEach(MedicalReference.all) { source in
                VStack(alignment: .leading, spacing: 6) {
                    Text("[\(source.id)] \(source.organization)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.primaryText)
                    Text(source.originalTitle)
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(source.scope)
                        .font(.footnote)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Link(destination: source.url) {
                        Text("\(source.title) · 查看原文 ↗")
                            .font(.subheadline.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("medical.reference.\(source.id)")
                }
                if source.id != MedicalReference.all.last?.id {
                    Divider().overlay(Palette.hairline)
                }
            }
            Text("来源核对日期：2026 年 10 月 15 日")
                .font(.caption)
                .foregroundStyle(Palette.secondaryText)
        }
        .cardStyle()
    }

    private func heading(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(Palette.primaryText)
            .accessibilityAddTraits(.isHeader)
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Palette.primaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}
