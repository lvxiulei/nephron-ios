import SwiftUI

/// 了解 Tab：健康科普内容 + 公式折叠区，不生成个体化医疗建议。
struct KnowledgeView: View {
    @State private var isFormulaExpanded = false

    private let tips: [(icon: String, title: String, detail: String)] = [
        (
            "chart.line.downtrend.xyaxis",
            "比较趋势，比盯单次更有用",
            "连续的 eGFR 结果有助于了解变化，比只看一次估算更有参考价值。[2]"
        ),
        (
            "waveform.path.ecg",
            "肌酐会受很多因素影响",
            "饮食、肌肉量和部分药物等因素，都可能影响血肌酐或估算的准确性。[3]"
        ),
        (
            "doc.text.magnifyingglass",
            "还需要结合尿检与病史",
            "医生还需结合尿白蛋白等检查及既往结果评估肾脏情况。[2, 4]"
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                estimateCard
                tipsCard
                formulaCard
                MedicalReferenceCard()
                bottomNotice
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .contentMargins(.bottom, 96, for: .scrollContent)
        .background(Palette.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("数字之外，还要看什么？")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Palette.primaryText)
            Text("这一页帮助你理解 eGFR 的边界，不提供个体化医疗建议。")
                .font(.subheadline)
                .foregroundStyle(Palette.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }

    private var estimateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("它是“估算值”")
                .font(.headline)
                .foregroundStyle(Palette.primary)
            Text("eGFR 根据年龄、生物学性别和血肌酐估算；不是直接测得的 GFR，也不是一次结果就能给出的诊断。[1–3]")
                .font(.subheadline)
                .foregroundStyle(Palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle()
    }

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(tips, id: \.title) { tip in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: tip.icon)
                        .font(.subheadline)
                        .foregroundStyle(Palette.primary)
                        .frame(width: 28, height: 28)
                        .background(Palette.primarySoft, in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tip.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.primaryText)
                        Text(tip.detail)
                            .font(.footnote)
                            .foregroundStyle(Palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .cardStyle()
    }

    private var formulaCard: some View {
        Button {
            withAnimation(.smooth(duration: 0.22)) {
                isFormulaExpanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("使用的计算公式")
                            .font(.headline)
                            .foregroundStyle(Palette.primaryText)
                        HStack(spacing: 8) {
                            Text("CKD-EPI 2021")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Palette.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Palette.primarySoft, in: Capsule())
                            Text("成人血肌酐公式")
                                .font(.footnote)
                                .foregroundStyle(Palette.secondaryText)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.up")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.secondaryText)
                        .rotationEffect(.degrees(isFormulaExpanded ? 0 : 180))
                }

                if isFormulaExpanded {
                    VStack(alignment: .leading, spacing: 12) {
                        formulaRow(title: "适用范围", body: MedicalReference.applicability)
                        formulaRow(title: "单位换算", body: MedicalReference.conversion)
                        formulaRow(title: "结果可能不同", body: "不同公式可能给出不同结果；本工具未使用胱抑素 C，结果需结合医生评估理解。[2]")

                        VStack(alignment: .leading, spacing: 6) {
                            Text("公式表达式")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Palette.primaryText)
                            Text(MedicalReference.formula)
                                .font(.footnote.monospaced())
                                .foregroundStyle(Palette.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Palette.fieldBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Text(MedicalReference.coefficients)
                                .font(.caption)
                                .foregroundStyle(Palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 2)
                    .transition(.opacity)
                }
            }
            .clipped()
            .cardStyle()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(isFormulaExpanded ? "收起公式详情" : "展开公式详情")
        .accessibilityIdentifier("knowledge.formula.toggle")
    }

    private func formulaRow(title: String, body text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.primary)
            Text(text)
                .font(.footnote)
                .foregroundStyle(Palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var bottomNotice: some View {
        Text("出现明显不适、报告异常，或对结果有担忧时，请及时前往正规医疗机构咨询。本页不构成医疗建议。")
            .font(.footnote)
            .foregroundStyle(Palette.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .fixedSize(horizontal: false, vertical: true)
    }
}
