import SwiftUI

/// 了解 Tab：健康科普内容 + 公式折叠区，不生成个体化医疗建议。
struct KnowledgeView: View {
    @State private var isFormulaExpanded = false

    private let tips: [(icon: String, title: String, detail: String)] = [
        (
            "chart.line.downtrend.xyaxis",
            "比较趋势，比盯单次更有用",
            "肾功能的变化方向，比某一次的数值更值得留意。"
        ),
        (
            "waveform.path.ecg",
            "肌酐会受很多因素影响",
            "饮食、运动、药物甚至脱水，都可能让同一天的肌酐出现波动。"
        ),
        (
            "doc.text.magnifyingglass",
            "还需要结合尿检与病史",
            "尿蛋白、尿红细胞等检查与既往病史，是医生判断的重要信息。"
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                estimateCard
                tipsCard
                formulaCard
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
            Text("eGFR 根据年龄、生物学性别和血肌酐估算；不是直接测得的 GFR，也不是一次结果就能给出的诊断。")
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
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.smooth(duration: 0.22)) {
                    isFormulaExpanded.toggle()
                }
            } label: {
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
            }
            .buttonStyle(.plain)
            .accessibilityHint(isFormulaExpanded ? "收起公式详情" : "展开公式详情")
            .accessibilityIdentifier("knowledge.formula.toggle")

            if isFormulaExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    formulaRow(title: "适用范围", body: "18 岁及以上成人的稳定状态估算；不适用于急性肾损伤、孕妇、截肢或极端肌肉量人群。")
                    formulaRow(title: "单位换算", body: "若检验单使用 μmol/L，计算前会除以 88.4 换算为 mg/dL；血肌酐合理范围为换算后 10–2000 μmol/L。")
                    formulaRow(title: "结果可能不同", body: "不同医院可能使用 2009 版 CKD-EPI、MDRD 或包含胱抑素 C 的公式，数值存在差异属于正常现象。")

                    VStack(alignment: .leading, spacing: 6) {
                        Text("公式表达式")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.primaryText)
                        Text("eGFR = 142 × min(Scr/κ, 1)^α × max(Scr/κ, 1)^-1.200 × 0.9938^年龄 × 性别系数")
                            .font(.footnote.monospaced())
                            .foregroundStyle(Palette.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.fieldBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        Text("女性：κ = 0.7，α = -0.241，性别系数 = 1.012\n男性：κ = 0.9，α = -0.302，性别系数 = 1")
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
