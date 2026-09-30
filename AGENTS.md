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

## 项目现状（截至 2026-09-29；逐次变更明细见 PROGRESS.md，上架权威清单见 APPSTORE.md）

### 已交付功能

- **四个 Tab**：计算 / 记录 / 了解 / 我的。MVP 于 2026-09-25 完成，此后历经约 30 轮用户反馈迭代（明细见 PROGRESS.md 更新记录）。
- **计算 Tab**：性别/年龄/血肌酐（μmol/L|mg/dL 胶囊切换）/检验日期输入；手动点「计算 eGFR」出结果（CKD-EPI 2021），结果大号数值+区间+免责声明+保存；可选指标折叠区 7 项（血压/尿酸/红细胞/钾/磷/尿蛋白肌酐比值/尿蛋白定量，1:1 复刻小程序，配色取自其 wxss）；同日期保存弹「记录对照」居中卡（更新/保留新记录）。
- **记录 Tab**：页头（变化要连起来看）+ 双摘要卡（已记录次数/最近 eGFR）+ 趋势卡（图表 210pt 固定、X 轴仅首尾日期 chartOverlay 自绘、长按吸附选中、52pt 固定指标条）+ 记录列表（含表头「检验信息|eGFR」、自绘左滑删除带确认弹框）+ 空状态。
- **了解 Tab**：估算值说明、三条提示、CKD-EPI 公式折叠区、就医提示。
- **我的 Tab**：本机存储说明（备份功能已按用户决定移除）、隐私边界、版本号。
- **上架收尾**：App 图标（Assets.xcassets 单尺寸 1024）、显示名「eGFR计算随记」、分类 healthcare-fitness、出口合规声明（Info.plist `ITSAppUsesNonExemptEncryption=NO`）均已接入工程。

### 既定交互/设计决策（勿回退）

- 备份/导出导入已整体移除；计算为手动触发；检验日期=显式按钮+日历 sheet（勿再用透明 DatePicker 叠加）。
- 记录左滑删除=自绘滑动（DragGesture 露出删除按钮）——iOS 26/27 点系统 `swipeActions` 按钮会让 List 滚动归零，勿改回；配套：仅展开时渲染删除按钮、弹框状态用独立 `@Observable` + 独立子层呈现、弹框关闭后再收起行、容器 `.clipped()`。
- 输入框一律弹性宽度（min 44/max 上限），勿固定宽；多输入框勿共享同一 `@FocusState` 枚举值（真机闪退）；校验时机=失焦后提示。
- 固定列文字用单行+缩放（`lineLimit(1)`+`minimumScaleFactor`，单位等小字加 `layoutPriority`）保证等高不折行。
- 全局卡片间距 20pt；卡片 `cardStyle()` 已强制满宽；键盘工具栏「完成」已移除（滚动即收键盘）。
- Charts 系统轴有缺陷（自动补刻度、边缘标签丢失），X 轴日期一律自绘。

### 测试与验收基线

- 当前基线：**40 个单元测试 + 12 个 UI 测试**全绿；UI 必须过 XXXL 大字体。
- 截图验收：`-uitest-*` 启动参数 + `simctl io screenshot`；记录页列表区用 `-uitest-history-scroll-records` 程序化滚动（页头新增后外部滚动手段全部失效）；三模式（浅/深/XXXL）用 `-uitest-force-dark` / `-uitest-force-large-text`。
- `TEST_RUNNER_` 前缀环境变量实测传不到测试进程（模式恒为 light），勿依赖——模式分支直接写 launchArguments。
- 真机跑 UI 测试会 xctrunner 签名失败，UI 测试只在模拟器跑；模拟器截图偶发空白帧须校验重拍。

### 工程与部署要点

- Bundle ID `com.lvxiulei.nephronios` **勿改**（牵动上架/备案）；显示名三处一致：商店名=备案名=CFBundleDisplayName=「eGFR计算随记」；团队 S5S65YA53Z；真机 UDID `00008150-000478D20C04401C`；模拟器（iPhone 17）`C3C99302-782D-4D21-A046-C3AF48279B0D`。
- 工程为手写 pbxproj + 文件系统同步组（objectVersion 70）；文件入 `NephronIOS/` 自动进 target；Info.plist 须以 `PBXFileSystemSynchronizedBuildFileExceptionSet` 排除出资源（否则重复打包构建失败）。
- pbxproj 被 Xcode 打开会重写（丢 `DEVELOPMENT_TEAM`、格式单行化）——改后 grep 验证；用户 Xcode 弹「Revert/Keep」须选 Revert。
- `xcodebuild`/`devicectl` 全程绝对路径（Bash cwd 会漂移）；设备 unavailable 时构建必失败，重连再试。

### 上架进度（权威清单 = APPSTORE.md，到节点主动提醒用户）

- 已购：域名 ygysdev.cn（3 年）、阿里云 ECS 上海 2核2G Ubuntu 24.04（¥99/年）、Apple 开发者 ¥688（**等「membership active」激活邮件**——扣费确认邮件≠激活邮件）。
- 商店元数据全套已定稿（名称/副标题/关键词/分类/描述/免责声明），见 APPSTORE.md 第七节。
- 流程：激活后 ASC 建档（SKU nephron-001）→ 记数字 Apple ID → beian.aliyun.com 提交 App 备案（域名+ECS 实例+刷脸，管局约一周）→ 备案期间备好隐私政策页/支持页（部署到自己服务器，/nephron/privacy.html、support.html）与 6.9" 商店截图 → 备案号回填 ASC → Archive 上传 → TestFlight 自测 → 提审。
- 商业：v1 免费全球仅中文 → v1.1 一次性买断 ¥18（多档案+PDF 导出），不做订阅；IAP 前必配付费协议+银行+W-8BEN，顺手申请小企业计划（佣金 15%）。

### 当前待办

- 等 Apple 激活邮件（唯一外部阻塞）。
- 用户已反馈、被叫停未落地的三处记录页 UI：①页头「变」「每」首字被挡（尚未定位，优先按结构性修复处理）；②文案「串成你的 eGFR 趋势」改字（用户写作「足成」，疑为「组成」笔误，落地前与用户确认一字）；③列表表头「检验信息|eGFR」并入卡片背景成圆角卡顶。接到指示后再动。
