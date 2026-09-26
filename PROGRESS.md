# PROGRESS.md

## 更新记录：方案 A「失焦后校验」落地（2026-09-26·六）

- 用户选定校验时机方案 A：输入中绝不提示（"3"、"7" 等中间值不再弹红字）；光标离开输入框（点别处/收起键盘/点计算）才校验，错则红字+红描边；再次编辑立即清除。
- 实现：VM 增加失焦校验标记（ageWasValidated/creatinineWasValidated + 对应编辑/失焦方法）；视图在 TextField 文字变化时清除标记、焦点离开时置位；两输入框错误态加红色描边。
- 新增 `CalculatorViewModelTests`（6 个用例：中间值不提示、失焦出现、再编辑清除、合法/空值不提示、中间值计算被拒但无红字）。
- 验证：40 单测 + 8 UI 全过；已装用户 iPhone。

## 更新记录：检验日期控件重做（2026-09-26·五）

- 用户反馈检验日期控件失效。原实现是"透明 DatePicker 叠加自定义外观"，命中依赖透明层，不可靠（还可能被键盘残留层吞掉点击）。
- 重做：日期块改为显式按钮，点击弹出日历面板（graphical 日历 + 完成按钮，sheet 中等高度呈现、可下拉关闭）；选中即更新、外观保持 2026-09-26 样式；打开时先收起键盘。
- 新增 `testDatePickerOpensAndCloses` UI 测试；全量 34 单测 + 8 UI 全过；已装用户 iPhone。

## 更新记录：单位完整显示（2026-09-26·四）

- 用户反馈内嵌单位（μmol/L|mg/dL）被截断。修复：标签列改为定宽（ScaledMetric 60），年龄/血肌酐两框改为填满剩余宽度（天然等宽），单位胶囊文字加 `fixedSize` 永不截断——输入区只需容纳三位数，空间足够。
- 验证：默认与 XXL 大字体截图均确认两单位完整显示、两框等宽；相关 UI 测试通过；已装用户 iPhone。

## 更新记录：方案 C 落地 + 输入框定宽统一（2026-09-26·三）

- 用户选定方案 C：年龄/血肌酐改为行式（标签左、输入框右），血肌酐单位（μmol/L|mg/dL）以 iOS 分段小胶囊内嵌于输入框右侧；两框统一 238×42（宽度经 ScaledMetric 随动态字体缩放），截图验收确认完全一致。
- 尿蛋白两行与血压高压/低压输入框改为固定宽度（90 / 73pt）：此前 minWidth 会因标签长短不同（"尿蛋白肌酐比值"比"尿蛋白定量"长）导致右侧输入框宽度不等——固定宽度后逐像素一致。
- 单位切换由系统分段 Picker 改为自定义胶囊分片（白底选中片+阴影），带 VoiceOver 标签与选中态。
- 验证：34 单测 + 7 UI 全过；已装用户 iPhone。

## 更新记录：输入区改版筹备（2026-09-26·二）

- ① 年龄标签去除"岁"字（占位仍为「如 45」）。
- ③ 「计算 eGFR」按钮：结果已展示且必填参数未变时自动变浅并停用；任何必填参数变化后结果失效、按钮恢复可点（`displayResult` 驱动）。相关 UI 测试通过。
- ② 年龄/血肌酐/单位输入区三种重设计方案：`design-proposals.html`（浏览器打开）——A 双列对齐+整行单位；B 行式统一（与检验日期同构，推荐）；C 单位内嵌输入框。待用户选定后在 App 实现。
- 注：用户 iPhone 当前不可用（连接断开），恢复后需重装最新构建。

## 更新记录：可选指标区 1:1 复刻小程序 + 弹层呈现层修复（2026-09-26）

### 复刻「添加其他检验指标（可选）」（对照小程序源码逐项实现）

- 折叠头：居中标题 + 圆圈 +/− 符号（展开 − / 收起 +）。
- 展开面板：浅绿底（#F4FAF6）+ 描边（#CAE5DA）圆角面板。
- 血压整行块：名称/单位左侧，高压、低压两个居中输入框以 "/" 分隔。
- 尿酸 / 红细胞 / 钾 / 磷 2×2 指标格：名称左上、单位右上、下方居中输入框（占位「选填」）。
- 尿蛋白区（#EDF5F0 底）：「尿蛋白」小节标题 + 两条左右行（肌酐比值 g/g.Cr、定量 g/L）。
- 说明文字 + 分隔线 + 保存行（已填写 N 项 / 补充至… + 绿色「保存补充信息」按钮，含完成态与置灰态）。
- 可选卡片与结果卡一同出现（对应小程序 `wx:if="{{result}}"`）；删除旧 OptionalMetricsGrid；「✓ 已补充」文案对齐小程序改为「✓ 已保存」。全部配色取自小程序 wxss（含深色变体）。

### 修复：对照弹层改为 fullScreenCover 呈现

- 现象：真实键入过（甚至仅弹出过一次键盘再收起）后，自定义 `.overlay` 弹层上的按钮点击被系统残留的键盘层吞掉（阶梯实验 A/B 定位；启动参数直接触发则正常）。
- 修复：弹层改 `fullScreenCover`（真实 UIKit 呈现层，不受残留层影响），外观不变（遮罩+居中卡）；点击「计算 eGFR / 保存这次记录」先收键盘。
- 验证：34 单测 + 7 UI 测试全过（两条同日期路径真实走通）；弹层截图验收；已安装用户 iPhone。

## 更新记录：间距统一 / 移除意见反馈 / 版本 1.0.0（2026-09-25 晚·第七次）

- **间距节奏统一**（了解页 + 我的页）：卡片内"标题→正文"统一 12pt（原 10/14 混杂）、标题下说明小字 4pt、卡片内行距 12pt、卡片间 16pt 不变。
- **移除「意见反馈」功能**：删除反馈卡、复制模板逻辑、toast 提示与多余 UIKit 引用。
- **版本号**：`MARKETING_VERSION` 0.1.0 → **1.0.0**（模拟器 Info.plist 已验证显示 1.0.0）。
- 验证：全量测试 34 单测 + 7 UI 全过；已安装到用户 iPhone（安装成功，启动时手机处于锁屏，解锁后点图标即可）。
- 另：计算 Tab 图标定稿为九宫格 `square.grid.3x3`（`calculator` 符号名在新版 SF Symbols 中不存在，渲染为空白，已用像素检测验证过）；「计算 eGFR」按钮去除图标只留文字。

## 更新记录：修复折叠头点击闪烁（2026-09-25 晚·第六次）

- 问题（用户反馈）：了解页「使用的计算公式 CKD-EPI 2021 成人血肌酐公式」点击箭头展开时标题行闪一下。
- 原因（两个叠加）：① 折叠头 Button 用系统默认样式，按下时整个标签短暂变暗（高亮闪烁）；② 箭头是 `chevron.up`/`chevron.down` 两个符号瞬间替换，无过渡。
- 修复（了解页公式区 + 计算页可选指标区统一处理）：
  - 折叠头改 `.buttonStyle(.plain)`，去除系统按下变暗；
  - 箭头改为单个 `chevron.up` + `rotationEffect`（0°↔180° 平滑翻转，随展开动画联动）。
- 验证：录屏逐帧检查展开动画全程标题行稳定无变暗；新增 `testKnowledgeFormulaToggle` UI 测试；全量 34 单测 + 7 UI 测试全过；已重装用户 iPhone。

## 更新记录：统一卡片宽度（2026-09-25 晚·第五次）

- 问题（用户反馈）：「了解」「我的」两页的第二张卡片比上下卡片窄约 25pt——像素测量确认（左缘均 48，第二卡右缘 1069–1087 vs 其他卡 1157）。
- 原因：这两张卡内容为“图标+文字”行，无贪婪子元素（Spacer / maxWidth 按钮），卡片收缩到最长文字行宽度；其他卡片恰好含贪婪元素才满宽。
- 修复：`CardBackground`（`.cardStyle()`）统一加 `.frame(maxWidth: .infinity, alignment: .leading)`，全 App 所有卡片强制等宽。
- 验证：像素复测两页三卡全部 left=48 / right=1157 / 宽 1109；全量测试 34 单测 + 6 UI 全过；已重装用户 iPhone。

## 更新记录：按 apple-design / write-swift 技能规范统一审视（2026-09-25 晚·第四次）

### write-swift（现代 Swift 规范）

- 删除冗余 `@MainActor` 注解（`RecordStore`、`CalculatorViewModel`）——工程已启用 MainActor 默认隔离，按规范不应重复标注。
- 重复用例参数化：CKD-EPI 参考值 4 例、单位换算 2 例、边界值 2 例、区间文案 11 例、非法日期 6 例全部改为 `@Test(arguments:)`（函数数 37→34，参数用例实际执行数更多，覆盖不减反增）。
- 移除无意义的 `@Suite(.serialized)`；清理测试死代码（`_ = morning`）与挂空的 `.navigationTitle`（无 NavigationStack）。

### apple-design（Apple 设计规范）

- 动画全面换用无回弹弹簧：卡片展开/收起、结果卡出现、对照弹层 `easeInOut` → `.smooth`；按钮按压 `easeOut` → `.smooth`；图表选中吸附 → `.snappy`。
- 结果大号数值改用 `@ScaledMetric(relativeTo: .largeTitle)`，随动态字体缩放（原先固定 54pt 不缩放，违反 Dynamic Type）。
- 多模态反馈：保存成功 `.sensoryFeedback(.success)`、保存失败 `.error`、记录删除 `.impact(light)`。
- 复核符合项：语义字体、VoiceOver 标签、深浅色对比度、遮罩聚焦（scrim）、透明度对称过渡、无过度动画——维持不变。

### 验证

- 全量测试：34 单测函数（含参数化展开）+ 6 UI 测试全过，0 编译警告。
- 截图抽查：XXXL 下结果数值随字体放大、滚动后数值/单位/双按钮完整无截断（`10-conformance-*.png`）。
- 已重新签名构建并安装到用户 iPhone 17。

## 更新记录：计算改为手动触发 + 检验日期行改版（2026-09-25 晚·第三次）

### 变更 1：取消输入即算，新增「计算 eGFR」按钮

- 输入卡底部新增主绿「计算 eGFR」按钮（必填项未合法时置灰）；结果卡只在点击后出现。
- 输入变化后已展示的结果自动失效（隐藏），需重新计算——避免保存与输入不符的结果。
- 保存 / 同日期对照 / 补充等动作均以「当前展示的结果」为准。

### 变更 2：检验日期行改版

- 「检验日期」标签在左，日期字段同行右侧；自定义外观显示 `2026-09-25`（yyyy-MM-dd）+ 日历图标；底层仍为系统 DatePicker（中文弹层、禁选未来日期），透明覆盖实现。

### 验证与交付

- 全量测试：37 单测 + 6 UI 全过（UI 测试流程更新为先点「计算 eGFR」再保存；新增 `-uitest-autocalculate` 截图钩子）。
- 截图：`09-calculator-manual-input.png`（未计算：无结果卡、按钮在、日期 2026-09-25 + 日历图标）、`09-calculator-manual-result.png`（计算后结果卡出现）。
- 已重新签名构建并安装到用户 iPhone 17。

## 更新记录：修复可选指标展开动画（2026-09-25 晚·第二次）

- 问题：展开「添加其他检验指标」时内容带 `.move(edge: .top)` 位移过渡，视觉上从「这次检验」卡片上方滑下来、覆盖其上。
- 修复：位移过渡改为纯 `opacity`，卡片内容加 `.clipped()` 裁剪——展开/收起表现为卡片自身向下伸缩，内容在卡片边界内渐入；「了解」页公式折叠区同样处理。
- 验证：录屏（`simctl recordVideo` + 场景切帧）确认动画全程无内容覆盖上方卡片；新增 `testOptionalMetricsToggle` UI 测试（展开后行存在、收起后隐藏）；全量测试 37 单测 + 6 UI 全过；已重新安装到用户 iPhone。

## 更新记录：移除备份功能 + 修复可选指标布局（2026-09-25 晚）

### 变更 1：移除「我的 → 数据备份」（用户决定：本地 App 不需要该功能）

- 删除 `Storage/BackupService.swift`、`Models/BackupDTO.swift`、`BackupServiceTests.swift`（14 个备份单测随之移除）。
- 「我的」Tab 移除导出/导入/确认弹层/分享面板，新增简洁的「本机存储」卡片（记录数 + 数据留存提示）。
- 隐私与边界、意见反馈、版本号保持不变。

### 变更 2：修复可选指标区域在大字体下的布局溢出（真机反馈 IMG_8307）

- 原因：行内「名称 + Spacer + 输入框 + 单位」各自 `fixedSize`，大字体下最小宽度超过屏宽导致左右裁切；血压双输入框同行加剧挤压；各行输入框起点错位。
- 修复：改为三列 `Grid`（名称列换行 / 弹性输入列 / 单位列贴右对齐跨行对齐），血压拆为「血压·高压」「血压·低压」两行，全部 8 行统一网格。
- 验证：`08-optional-grid-default.png`（默认字体，单位放大复核 mmHg 完整）、`08-optional-grid-xxxl.png`（XXXL 长名称换行无截断）、`08-settings-no-backup.png`（我的页无备份入口）。

### 变更后验证

- `xcodebuild test`：**TEST SUCCEEDED**（37 单测 + 5 UI 测试全过，0 编译警告）。
- 重新签名构建并安装到用户 iPhone 17（团队 S5S65YA53Z）。

---

## 最终状态：MVP 完成 ✅（2026-09-25）

全部四个 Tab 功能落地，51 个单元测试 + 5 个 UI 测试通过，构建无编译警告，14 张模拟器截图完成视觉验收。未执行 git commit（按需求约束）。

> 注：备份功能于当晚按用户要求移除，当前测试基线为 37 个单元测试，详见上方更新记录。

---

## 已实现的文件与能力

### 工程
- `NephronIOS.xcodeproj`（手写，objectVersion 70 文件系统同步组，零第三方工具）+ 共享 Scheme
- 三 Target：`NephronIOS` / `NephronIOSTests`（Swift Testing）/ `NephronIOSUITests`（XCTest）
- 设置：iOS 17.0+、`com.lvxiulei.nephronios`、显示名「eGFR 肾康随记」、Swift 6 语言模式、`DEFAULT_ACTOR_ISOLATION = MainActor`（App target）

### App（NephronIOS/，29 个 Swift 文件全部参与编译）
| 目录 | 内容 |
|---|---|
| `App/` | 入口（ModelContainer + 全局 RecordStore 注入 + 启动失败退回内存模式）、主题（#F7F8F4/#0F5B50/#17312C + 深色变体）、四 Tab 根视图、UI 测试启动参数钩子 |
| `Domain/` | CKD-EPI 2021 计算/校验/区间文案（与参考项目逐字对齐）、DayDate 日期策略（startOfDay + 严格 yyyy-MM-dd + zh_CN 格式）、OptionalMetrics 值类型 |
| `Models/` | RecordModel（SwiftData，基础字段覆盖 + 可选指标成对合并）、备份 DTO（与模型分离） |
| `Storage/` | RecordStore（CRUD/同日期查最新/更新合并/整体替换，失败回滚 + Logger）、BackupService（导出/校验/还原：schemaVersion+exportedAt+records+SHA-256）、SeedData |
| `Features/Calculator/` | 输入卡（性别/年龄/肌酐+单位/日期不可选未来）、结果卡（大号数值+mL/min/1.73m²+区间+免责声明+保存/已保存/查看记录）、可选指标折叠区（7 项、单位右对齐、“选填”、已填写 N 项、补充至日期、保存补充信息）、同日期“记录对照”居中弹层（更新/保留新记录/遮罩关闭）、键盘“完成”工具栏 |
| `Features/History/` | 双摘要、Swift Charts 趋势（<2 条单点、按日期+创建时间排序、X 轴仅首尾 MM/dd、拖动吸附、竖线+选中卡含已填指标且不含长单位）、三列记录列表、删除确认、空状态 |
| `Features/Knowledge/` | 估算值说明、三条提示、公式折叠区（适用范围/单位换算/医院公式差异/表达式）、底部就医提示 |
| `Features/Settings/` | 记录数、备份说明、导出（系统分享 .nephronbackup）、导入（fileImporter→校验→数量与替换确认→恢复）、隐私三行、反馈模板复制（不自动附带数据）、Bundle 真实版本号 |

### 测试
- **NephronIOSTests（51 个，Swift Testing）**：CKD-EPI 女/男计算（参考值由参考项目 TS 公式独立生成）、μmol↔mg/dL 一致性、年龄/肌酐边界与错误文案、区间文案 11 档、日期解析（严格格式/roundtrip）、保存/查询/删除、同日期查最新（按 createdAt）、更新不增计数、保留新记录增计数、可选指标合并（未填保留/已填覆盖/半对血压不合并/补充不新建）、趋势排序（含同日多记录）、备份导出字段/确定性/checksum/损坏 JSON/错误 schema/篡改/伪造合法 checksum 的非法字段（年龄、肌酐、半对血压、坏日期）、导入失败不触碰原数据、整体替换、空备份
- **NephronIOSUITests（5 个，XCTest）**：空状态进入计算页 + 记录空态跳转、填写必填项→计算→保存→✓已保存→记录 1 条、同日期对照弹层→更新后仍 1 条、同日期对照→保留新记录后 2 条、深色+大字体下关键按钮可见可点标签完整

## 执行过的命令与结果

| 命令 | 结果 |
|---|---|
| `xcodebuild -list -project NephronIOS.xcodeproj` | 3 targets / Debug+Release / 1 scheme |
| `xcodebuild ... build`（iPhone 17, iOS 27.0） | **BUILD SUCCEEDED**，0 个 Swift 编译警告 |
| `xcodebuild ... test`（同 destination） | **TEST SUCCEEDED**：51 单测 + 5 UI 全过 |
| 网络依赖检查 | `URLSession/Network/CFNetwork` 引用 0 处；package dependencies 0 |
| 截图验收（`simctl io screenshot`，14 张，screenshots/） | 逐张经视觉模型检查通过 |

注：构建输出中的 `appintentsmetadataprocessor: Metadata extraction skipped` 为 Xcode 27 模板级工具提示（所有新工程均出现），非本工程代码警告；测试运行中 3 条 XCTest 运行期提示（Invalid frame dimension）来自自动化框架对动画中元素的 frame 查询，非编译警告。

## 截图验收清单（screenshots/）

1. `03-calculator-empty.png` 首次打开计算空状态（标题/副标题/仅本机保存徽标/输入卡）✅
2. `03-calculator-result.png` 计算结果（86.2 / mL/min/1.73m² / CKD-EPI 2021 / 60–89 区间 / 双按钮）✅
3. `03-calculator-optional.png` 展开的可选指标（7 项、单位右对齐、“选填”、已填写 0 项、请先保存上方 eGFR）✅
4. `03-calculator-comparison.png` 同日期“记录对照”弹层（徽标/日期标题/已有 eGFR 预览/保存于/或/双按钮）✅
5. `04-history-empty.png` 记录空状态（图标/文案/去计算 eGFR）✅
6. `04-history-single.png` 单条记录趋势（单点不伪造趋势、X 轴 09/22、选中卡完整日期）✅
7. `04-history-multi.png` 多条趋势（7 条、选中 2026-09-25 竖线、选中卡含血压/尿酸/钾、列表三列）✅
8. `05-knowledge.png` 了解页（估算值/三提示/公式折叠区）✅
9. `05-settings.png` 我的页（5 条记录/备份说明/导出导入/隐私三行/反馈/版本 0.1.0）✅
10. `06-dark-calculator.png` / `06-dark-history.png` 深色模式两页（暗色变体协调、对比度足够、图表清晰）✅
11. `07-largetext-calculator.png` / `07-largetext-history.png` / `07-largetext-calculator-bottom.png` 最大动态字体（数值单位完整、按钮不截断、列表换行正常）✅

## 开发中遇到并解决的问题

1. **Swift 6 默认 MainActor 隔离 vs `@Model` 宏 / XCTestCase 子类冲突** → Domain 层标记 `nonisolated`；测试 target `DEFAULT_ACTOR_ISOLATION = nonisolated`。
2. **Swift Testing 并行 + 同进程多 ModelContainer 触发 SwiftData SIGTRAP** → 测试共享单一内存容器（`TestStore`），每用例独立 ModelContext 并先清空。
3. **悬浮 Tab 栏遮挡滚动内容** → ScrollView 统一 `contentMargins(.bottom, 96)`。
4. **数字键盘无收起键、键盘遮挡悬浮 Tab 栏导致 UI 测试点击丢失** → 键盘工具栏“完成”按钮 + `@FocusState` + `scrollDismissesKeyboard(.immediately)`。
5. **同日期保存被错误豁免（savedRecordID 相同则静默新建）** → 修复为：同日期记录存在一律弹对照层（有单测与 UI 测试双重覆盖）。
6. **UI 测试点击键盘“完成”被对照弹层全屏遮罩拦截、意外关闭弹层** → 重排测试时序：触发弹层的保存后不收键盘，弹层操作完成后再收键盘切 Tab。

## 当前遗留问题

- 无功能性遗留。次要事项：
  - 未提供 App 图标（README 已列入上架前事项）；
  - Xcode 27 模板级 `appintentsmetadataprocessor` 提示无法在工程层面关闭（非代码警告）。

## 下一步（App Store 上架前需用户完成）

见 `README.md`「未来上架前仍需完成」：开发者团队/签名、正式图标、App Store Connect 隐私问卷、公开隐私政策页面、分类与年龄分级、以及未来若接入任何在线服务需重新评估隐私声明。
