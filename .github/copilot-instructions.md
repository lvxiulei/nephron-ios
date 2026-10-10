# 提交信息规范

本仓库的提交信息（commit message）遵循以下规范，生成提交信息时请严格遵守。

## 格式

```
<type>: <subject>
```

- **type（必须）**：用于说明本次提交的类别，取值见下方类型表。
- **subject（必须）**：提交目的的简短描述，不超过 50 个字符，且结尾不加句号或其他标点符号。
- 不要输出 scope 或括号，即不要写成 `feat(posts): ...` 这种形式。

示例：

```
feat: add tag filtering to post list
fix: prevent layout shift on cover images
chore: bump next to 15.3.2
```

## 类型表

| 类型 | 描述 |
|:-------|:-------|
| feat | 新功能、新特性（feature） |
| perf | 代码相关，比如提高性能、体验 |
| fix | 修复一个 bug |
| docs | 文档（documentation） |
| style | 格式修改，不影响代码功能 |
| refactor | 代码重构，内部处理逻辑、算法逻辑发生较大改变 |
| chore | 构建过程或辅助工具的变动，比如构建流程、依赖管理等（无法判断的提交推荐用这个） |
| revert | 回滚到上一个版本 |
| merge | 代码合并 |
| sync | 同步主线或分支的 Bug |
| test | 测试用例修改，或增加测试代码 |
| ci | 用于提交 CI 配置文件和脚本的修改 |
| release | 发布新版本 |

## 其他要求

- subject 与 body 一律使用英文，采用祈使句（add，而不是 added / adds），首字母小写。
- 只描述暂存区 diff 中真实存在的改动，不要编造。
- 一次提交只输出一个 type，按主要目的选择；无法判断时使用 chore。
- 直接输出提交信息原文，不要用 Markdown 代码块包裹，不要加 emoji 或署名。
