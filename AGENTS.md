# AGENTS.md

本仓库是「eGFR计算随记」原生 iOS App（肾功能 eGFR 计算与趋势记录，前身名「eGFR 肾康随记」已弃用——「肾康」为成药注册商标）。所有参与本仓库的代理（人或 AI）必须遵守：

- 全部用户可见文字使用简体中文。
- 不自动 Git commit，不推送远程。
- 不得接入后端、网络传输、登录、广告、分析或追踪 SDK；不请求网络权限。
- 健康数据只保存在本机沙盒，不上传任何检验数据。
- UI 完成必须以模拟器截图验收，检查宽度、间距、文字换行、空状态、长数字、深浅色模式与动态字体。
- 原生 `Button`、`TextField` 不承担复杂布局；用外围 SwiftUI 容器负责布局，控件只负责交互。
- 不得把 eGFR 计算结果表述为诊断、治疗建议或处方。
- 技术栈限定：Swift 6、SwiftUI、SwiftData、Swift Charts、CryptoKit、Swift Testing；不引入第三方依赖。
- 日期语义只有“天”：存储用设备时区 startOfDay，备份用 ISO 日字符串（yyyy-MM-dd），展示用 zh_CN 格式。
- 日志用 `Logger`，禁止 `print` 输出健康数据。
- 遇到构建错误：保留原始错误输出，只改与错误直接相关的最小范围，重新验证；不得用关闭类型检查、删测试、降级依赖的方式“假修复”。

## 项目现状（截至 2026-10-14；逐次变更明细见 PROGRESS.md，上架权威清单见 APPSTORE.md）

### 已交付功能

- **四个 Tab**：计算 / 记录 / 了解 / 我的。MVP 于 2026-09-25 完成，此后历经约 30 轮用户反馈迭代（明细见 PROGRESS.md 更新记录）。
- **计算 Tab**：性别/年龄/血肌酐（μmol/L|mg/dL 胶囊切换）/检验日期输入；手动点「计算 eGFR」出结果（CKD-EPI 2021），结果大号数值+区间+免责声明+保存；可选指标折叠区 7 项（血压/尿酸/红细胞/钾/磷/尿蛋白肌酐比值/尿蛋白定量，1:1 复刻小程序，配色取自其 wxss）；同日期保存弹「记录对照」居中卡（更新/保留新记录）。
- **记录 Tab**：页头（变化要连起来看）+ 双摘要卡（已记录次数/最近 eGFR）+ 趋势卡（图表 210pt 固定、X 轴仅首尾日期 chartOverlay 自绘、长按吸附选中、52pt 固定指标条）+ 记录列表（含表头「检验信息|eGFR」、自绘左滑删除带确认弹框）+ 空状态。
- **了解 Tab**：估算值说明、三条提示、CKD-EPI 公式折叠区（整块卡片可展开/收起）、就医提示。
- **我的 Tab**：本机存储说明（备份功能已按用户决定移除）、隐私边界、版本号。
- **上架收尾**：App 图标（Assets.xcassets 单尺寸 1024）、显示名「eGFR计算随记」、分类 healthcare-fitness、出口合规声明（Info.plist `ITSAppUsesNonExemptEncryption=NO`）均已接入工程。

### 既定交互/设计决策（勿回退）

- 备份/导出导入的**界面与流程已整体移除**（2026-09-25 用户决定）；但存储层原语**刻意保留供未来导入功能复用，勿当死代码清除**：`RecordStore.replaceAll` + `StorageError.replaceFailed`、`DayDate.isoDayString`/`date(fromISODay:)`（2026-10-10 用户拍板）。计算为手动触发；检验日期=显式按钮+日历 sheet（勿再用透明 DatePicker 叠加）。
- 记录左滑删除=自绘滑动（DragGesture 露出删除按钮）——iOS 26/27 点系统 `swipeActions` 按钮会让 List 滚动归零，勿改回；配套：仅展开时渲染删除按钮、弹框状态用独立 `@Observable` + 独立子层呈现、弹框关闭后再收起行、容器 `.clipped()`。
- 输入框一律弹性宽度（min 44/max 上限），勿固定宽；多输入框勿共享同一 `@FocusState` 枚举值（真机闪退）；校验时机=失焦后提示。
- 固定列文字用单行+缩放（`lineLimit(1)`+`minimumScaleFactor`，单位等小字加 `layoutPriority`）保证等高不折行。
- 全局卡片间距 20pt；卡片 `cardStyle()` 已强制满宽；键盘工具栏「完成」已移除（滚动即收键盘）。
- Charts 系统轴有缺陷（自动补刻度、边缘标签丢失），X 轴日期一律自绘。

### 测试与验收基线

- 当前基线：**41 个单元测试 + 14 个 UI 测试**全绿（2026-10-10 最近一次全量验证；更新文档不代表重新运行测试）；UI 必须过 XXXL 大字体。
- 截图验收：`-uitest-*` 启动参数 + `simctl io screenshot`；记录页列表区用 `-uitest-history-scroll-records` 程序化滚动（页头新增后外部滚动手段全部失效）；三模式（浅/深/XXXL）用 `-uitest-force-dark` / `-uitest-force-large-text`。
- `TEST_RUNNER_` 前缀环境变量实测传不到测试进程（模式恒为 light），勿依赖——模式分支直接写 launchArguments。
- 真机跑 UI 测试会 xctrunner 签名失败，UI 测试只在模拟器跑；模拟器截图偶发空白帧须校验重拍。

### 工程与部署要点

- Bundle ID `com.lvxiulei.nephronios` **勿改**（牵动上架/备案）；显示名三处一致：商店名=备案名=CFBundleDisplayName=「eGFR计算随记」；团队 S5S65YA53Z；真机 UDID `00008150-000478D20C04401C`；模拟器（iPhone 17）`C3C99302-782D-4D21-A046-C3AF48279B0D`。
- 工程为手写 pbxproj + 文件系统同步组（objectVersion 70）；文件入 `NephronIOS/` 自动进 target；Info.plist 须以 `PBXFileSystemSynchronizedBuildFileExceptionSet` 排除出资源（否则重复打包构建失败）。
- pbxproj 被 Xcode 打开会重写（丢 `DEVELOPMENT_TEAM`、格式单行化）——改后 grep 验证；用户 Xcode 弹「Revert/Keep」须选 Revert。
- `xcodebuild`/`devicectl` 全程绝对路径（Bash cwd 会漂移）；设备 unavailable 时构建必失败，重连再试。

### 上架进度（权威清单 = APPSTORE.md，到节点主动提醒用户）

- 域名 ygysdev.cn、ECS、Apple 开发者账号均已就绪；账号已激活，ASC 已建档。
- App 备案于 2026-10-10 管局审核通过，备案号「苏ICP备2026069169号-4A」；App「我的」页已标注。
- 官网首页、隐私政策页、支持页：已上线（HTTPS 200，隐私/支持页邮箱已核验为 ygys.dev@outlook.com）。
- 公安备案（网站）已通过，号「苏公网安备32021302003304号」；index.html 页脚已改为工信部主体号「苏ICP备2026069169号」+公安号（带图标），待 scp 上线。
- 商店元数据已定稿（APPSTORE.md 第七节）并全部回填 ASC：分类/内容权利/年龄分级 4+/隐私问卷 Data Not Collected/DSA Non-trader/审核信息/定价（免费·全球 175 区·基准中国大陆 CNY）。
- 商店截图已上传：必填槽为 6.1"/6.3"（1206×2622 真机原图零处理，`screenshots/store/medium/`）；1320×2868 放大版在 `final/` 备用。注意 ASC 规格以实际槽位标注为准。
- 构建 1.0.0 (1) 已上传并处理完成；TestFlight 内部组（自动分发）已建。
- 2026-10-12 首次提审；2026-10-13 用户反馈被拒（2.1.0 Performance: App Completeness / Information Needed）。苹果因账号审核历史有限要求补资料，通知未指出具体崩溃、功能故障或网站备案问题。
- 用户已完成录屏并上传到审核回复窗口；六项英文说明已整理。回复正式发送、版本备注保存及重新提交是否完成，尚未收到用户确认；不能标记为再次等待审核。
- 跨 App 上架操作手册位于 `/Users/lvxiulei/Documents/AI/`（`01-备案与服务器基建.md` + `02-ASC上架提审手册.md`），新 App 上架以其为操作依据。
- 商业：v1 免费全球仅中文 → v1.1 一次性买断 ¥18（多档案+PDF 导出），不做订阅；IAP 前必配付费协议+银行+W-8BEN，顺手申请小企业计划（佣金 15%）。

### 当前待办

- 确认补充材料处理完成：审核消息点击「回复」发送文字与录屏；1.0.0「App 审核信息 → 备注」保存六项说明；「更新审核」后按页面提示完成重新提交，核对状态。
- 确认录屏使用最新正式版 iOS、从启动 App 开始并展示典型流程；设备系统版本及录屏实际内容尚未核验。
- web/index.html 页脚（主体备案号+公安备案号）待用户 scp 上线：`scp web/index.html root@47.116.203.151:/var/www/nephron/index.html`。
- TestFlight 真机自测建议补做一轮（正式签名包全流程回归）。
