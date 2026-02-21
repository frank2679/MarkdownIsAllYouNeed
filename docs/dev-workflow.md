# 开发工作流程

本文档描述 MarkdownIsAllYouNeed 项目的标准开发流程，适用于每个版本的迭代。

---

## 总体流程

```
需求整理 → Feature Review → TDD 开发 → 上机验证 → PR & CI
```

---

## 第一步：需求整理（prompt 文件）

每轮开发开始前，在 `prompt/` 目录下创建一个以日期命名的文件（如 `prompt/20260220.md`），写明：

- 当前版本状态（已验证的功能、已知问题）
- 本轮要解决的问题或新增的功能
- 特殊约定（开发风格、优先级等）

这个文件是 AI 协作开发的上下文入口，也是后续 review 的依据。

---

## 第二步：Feature Review（开发前）

**目的**：在动手写代码前，对齐实现方案，避免方向偏差。

**输出产物**：在 `docs/` 下创建 `v{版本号}-feature-review.md`，内容包括：

- 每个功能的入口、操作步骤、预期结果
- 边界情况 & 已知限制
- 回归验证清单（已有功能不能被破坏）

**流程**：
1. AI 提出实现方案
2. 开发者 review 并确认（或提出修改意见）
3. 确认后才开始写代码

参考示例：[v0.3.0 feature review](./v0.3.0-feature-review.md)

---

## 第三步：TDD 开发

遵循 **先写测试，再写实现** 的节奏：

### 3.1 建立测试基础设施（仅首次）

- 在 `project.pbxproj` 中添加 `{ProjectName}Tests` XCTest target
- 创建 `{ProjectName}Tests/` 目录及初始测试文件
- 用 `xcodebuild -list` 验证 target 被识别

### 3.2 每个功能的开发节奏

```
1. 写测试（描述期望行为）
2. 运行测试 → 看到 Red（失败）
3. 写最少代码让测试通过 → Green
4. 重构代码（保持 Green）
```

### 3.3 测试组织

| 文件 | 测试内容 |
|------|----------|
| `DiffEngineTests.swift` | diff 算法的各种 case |
| `FileTypeDetectorTests.swift` | 文件类型识别（md/text/image/binary/hidden） |
| `FileManagerServiceTests.swift` | 文件 CRUD、move、buildFileTree |

每个测试用例：
- `setUp()` 中用 UUID 创建临时目录（隔离副作用）
- `tearDown()` 中删除临时目录
- 测试方法命名格式：`test{被测方法}_{场景}_{预期结果}`

---

## 第四步：上机验证

开发完成、单元测试全绿后，按 `docs/v{版本号}-feature-review.md` 中的步骤在真机或模拟器上逐项验证：

1. 打开 Xcode，按 `⌘U` 确认所有单元测试通过
2. 按 feature review 文档逐一验证新功能
3. 执行回归验证清单，确认已有功能未被破坏

验证通过后告知 AI："上机验证通过，commit 这些改动"。

---

## 第五步：提交 & PR

### 5.1 分支策略

- 所有开发在 feature branch 上进行，命名规范：`feat/{功能描述}-v{版本号}`
  - 示例：`feat/file-operations-v0.3.0`
- 不直接向 `main` 提交，所有变更通过 PR 合并

### 5.2 提交规范

commit message 遵循 [Conventional Commits](https://www.conventionalcommits.org/)：

```
feat: 添加文件拖拽移动功能
fix: 修复 context menu 路由到父目录的问题
ci: 添加 GitHub Actions 测试工作流
test: 补充 FileManagerService move 测试
docs: 更新 v0.3.0 feature review 文档
```

### 5.3 创建 PR

```bash
# 推送 feature branch
git push -u origin feat/{功能描述}-v{版本号}

# 创建 PR（base: main）
gh pr create --base main --head feat/... --title "..." --body "..."
```

PR body 包含：
- 变更摘要（bullet points）
- 涉及的文件清单
- 测试计划 checklist

---

## 第六步：CI 自动验证

每个 PR 触发 `.github/workflows/tests.yml`，自动在 GitHub Actions 上运行单元测试。

**当前 CI 配置**：
- Runner：`macos-15`（Xcode 16.x，iPhone 16 模拟器）
- 测试命令：`xcodebuild test -scheme MarkdownEditor`
- 注意事项：`Config/Debug.xcconfig` 包含 OAuth 密钥，已在 `.gitignore` 中排除；CI 中自动生成占位文件

**PR 合并条件**：CI 测试全部通过。

---

## 附：文件目录约定

```
MarkdownIsAllYouNeed/
├── prompt/                    # 每轮开发的需求文件（按日期命名）
│   └── YYYYMMDD.md
├── docs/                      # 文档
│   ├── dev-workflow.md        # 本文件：开发流程
│   └── v{版本号}-feature-review.md   # 每版本的 feature review
├── .github/
│   └── workflows/
│       └── tests.yml          # CI 配置
├── Config/
│   └── Debug.xcconfig         # 本地密钥（已 gitignore，不提交）
└── MarkdownEditor/
    ├── MarkdownEditor/        # 主 App 源码
    └── MarkdownEditorTests/   # 单元测试
```

---

## 附：版本规划

| 版本 | 主题 | 状态 |
|------|------|------|
| v0.1.0 | MVP：GitHub 登录、clone、编辑、push | 已发布 |
| v0.2.0 | 稳定性修复（table 渲染、icon、路径修复） | 已发布 |
| v0.3.0 | 文件操作（新建、重命名、删除、拖拽移动）+ 测试基础设施 | 已发布 |
| v0.4.0 | 存储优化（lazy .originals 缓存，减少 ~50% 占用） | PR #11 待 merge |
| v0.5.0 | 编辑体验优化（Notion 风格编辑模式、favorite、discard、bug 修复） | 进行中 |
| v0.6.0+ | AI Chat 功能 | 待规划 |
