# eGFR 肾康随记（nephron-ios）

一款纯本机运行的 eGFR 计算与健康科普 iOS App。基于 CKD-EPI 2021 成人血肌酐公式估算 eGFR，支持趋势记录、可选检验指标与本地备份。**不登录、不上传、不追踪**，所有数据仅保存在设备沙盒内。

参考产品为微信小程序版 `nephron`（只读），本仓库为其原生 iOS 实现。

## 技术栈

- Swift 6（SwiftUI、SwiftData、Swift Charts、CryptoKit、Swift Testing）
- 最低部署目标 iOS 17.0，iPhone 竖屏优先
- 零第三方依赖；无网络请求代码

## 构建

```bash
xcodebuild -project NephronIOS.xcodeproj -scheme NephronIOS \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

测试（37 个 Swift Testing 单元测试 + 5 个 XCTest UI 测试）：

```bash
xcodebuild -project NephronIOS.xcodeproj -scheme NephronIOS \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

用 Xcode 打开 `NephronIOS.xcodeproj`，选任一 iPhone 模拟器 ⌘R 即可运行。模拟器构建无需开发者账号。

## 功能

- **计算**：性别 / 年龄 / 血肌酐（μmol/L 或 mg/dL）/ 检验日期 → eGFR 估算（CKD-EPI 2021，保留一位小数），含区间文案与免责声明
- **同日期对照**：保存时发现同日期记录弹出“记录对照”卡，可选择「用本次结果更新」或「保留为新记录」
- **可选指标**：血压、尿酸、红细胞、钾、磷、尿蛋白肌酐比值、尿蛋白定量（均不参与 eGFR 计算，随检验日期保存，可后续补充）
- **记录**：双摘要 + Swift Charts 趋势（单点不伪造趋势、拖动吸附最近点、选中卡展示已填指标）+ 三列记录列表（删除需确认）
- **了解**：eGFR 科普与公式折叠说明
- **我的**：本机存储说明（记录数与数据留存提示）、隐私边界、反馈模板、版本号。纯本机应用，不提供备份导入导出

## 目录结构

```
NephronIOS/
  App/          入口、主题、根 Tab、UI 测试钩子
  Domain/       eGFR 公式、输入校验、日期策略、可选指标值类型
  Models/       SwiftData 模型
  Storage/      RecordStore（CRUD/同日期/合并）、种子数据
  Features/     Calculator / History / Knowledge / Settings
  Components/   趋势图、卡片样式、可选指标网格、空状态
NephronIOSTests/       37 个单元测试（Swift Testing）
NephronIOSUITests/     5 个 UI 测试（XCTest）
PRIVACY.md / PROGRESS.md / AGENTS.md
```

## 未来上架前仍需完成（由开发者操作）

当前仓库只完成可运行 MVP，**不提交上架**。App Store 发布前需要：

1. **签名与团队**：在 Xcode 配置真实 Apple Developer Team；Bundle Identifier `com.lvxiulei.nephronios` 如被占用需更换；真机运行需开启 Automatically manage signing。
2. **App 图标**：提供正式 App Icon（当前未内置图标资源）。
3. **App Store Connect**：
   - 填写隐私问卷（当前无数据收集，可声明“不收集数据”）；
   - 准备公开可访问的**隐私政策页面**（可基于 `PRIVACY.md` 内容发布）；
   - 选择正确的健康/医疗相关分类与年龄分级；
   - 截图与描述（注意不得宣称诊断、治疗功能）。
4. **审核合规**：eGFR 内容属健康估算工具，审核可能要求补充免责声明一致性检查；本 App 已在界面内多处声明“不构成医疗建议”。
5. **边界声明**：若未来接入广告、分析、登录、云同步或在线服务，必须重新评估隐私、网络安全（ATS）与审核风险，**不能直接复用当前“纯本机、不上传”的声明**。
