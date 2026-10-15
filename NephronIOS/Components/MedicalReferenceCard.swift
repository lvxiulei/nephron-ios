import SwiftUI

/// 计算页和了解页共用的常驻来源入口，不依赖计算结果或折叠状态。
struct MedicalReferenceCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsReferences = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("计算依据", systemImage: "book.closed")
                .font(.headline)
                .foregroundStyle(Palette.primaryText)
            Text("CKD-EPI 2021 成人血肌酐公式 · 18 岁及以上。[1, 2]")
                .font(.footnote)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text("结果为估算值，不构成诊断或治疗建议。")
                .font(.footnote)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                showsReferences = true
            } label: {
                Text("查看公式与参考来源")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.primary)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("medical.references.open")
        }
        .cardStyle()
        .sheet(isPresented: $showsReferences) {
            MedicalReferencesView()
                .dynamicTypeSize(dynamicTypeSize)
        }
    }
}
