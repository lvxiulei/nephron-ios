import SwiftUI

/// 读取 Bundle 的真实版本信息（单一来源，不在多处硬编码）。
enum AppInfo {
    static var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleInfoVersion") as? String ?? "0"
    }

    static var versionText: String {
        "版本 \(shortVersion)（\(buildNumber)）"
    }
}

/// 我的 Tab：隐私与边界、意见反馈、版本信息。
/// 本地 App 不提供备份导入导出：数据只保存在本机，删除 App 即删除全部数据。
struct SettingsView: View {
    @Environment(RecordStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                storageCard
                privacyCard
                versionFooter
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .contentMargins(.bottom, 96, for: .scrollContent)
        .background(Palette.background)
    }

    // MARK: 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("数据在你手里。")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Palette.primaryText)
            Text("不登录、不上传；你保存的每一条记录默认只存在本机。")
                .font(.subheadline)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: 本机存储

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("本机存储")
                        .font(.headline)
                        .foregroundStyle(Palette.primaryText)
                    Text("当前共有 \(store.recordCount) 条记录，仅保存在这台设备上")
                        .font(.footnote)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "iphone.gen3")
                    .foregroundStyle(Palette.primary)
            }

            VStack(alignment: .leading, spacing: 10) {
                bullet("删除 App 会同时删除全部本机记录，且无法找回")
                bullet("更换新设备后，旧设备上的记录不会自动转移")
            }
        }
        .cardStyle()
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(Palette.secondaryText.opacity(0.5))
                .frame(width: 4, height: 4)
                .padding(.top, 5)
            Text(text)
                .font(.footnote)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: 隐私与边界

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("隐私与边界")
                .font(.headline)
                .foregroundStyle(Palette.primaryText)

            privacyRow(icon: "person.slash", title: "不需要登录", detail: "不收集手机号、姓名或身份证信息。")
            privacyRow(icon: "icloud.slash", title: "不上传检验数据", detail: "输入数据只在本机计算与保存，不会上传到互联网。")
            privacyRow(icon: "stethoscope", title: "不替代医疗服务", detail: "不提供在线问诊、处方、购药或个体化饮食方案。")
        }
        .cardStyle()
    }

    private func privacyRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Palette.primary)
                .frame(width: 28, height: 28)
                .background(Palette.primarySoft, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.primaryText)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }


    // MARK: 版本

    private var versionFooter: some View {
        Text(AppInfo.versionText)
            .font(.footnote)
            .foregroundStyle(Palette.secondaryText)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("settings.version")
    }
}
