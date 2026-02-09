# MarkdownIsAllYouNeed — 技术设计方案

## 1. 关键技术决策

### 1.1 UI 框架：SwiftUI（壳）+ WKWebView（编辑器）

**结论**：App 外壳（导航、列表、设置、Git 面板）使用 **SwiftUI**，Markdown 编辑器核心使用 **WKWebView 内嵌 JS 编辑器**。

**原因**：

| 方案 | 优点 | 缺点 |
|------|------|------|
| 纯 SwiftUI/UIKit Native | 性能最佳、系统集成最好 | 实现 Typora 级别 WYSIWYG 编辑器需要数月，iOS 原生缺乏成熟的 Markdown WYSIWYG 组件 |
| 纯 WebView | 编辑器生态成熟，开发快 | 整体 App 体验不够原生 |
| **SwiftUI + WebView 混合** | **兼顾原生体验和编辑器质量** | 需要处理 Native ↔ JS 通信 |

混合方案是业界主流做法——Notion、Bear、Joplin 等 App 的编辑器核心都基于 WebView。

### 1.2 JS 编辑器选型：Milkdown

**结论**：使用 **Milkdown**（基于 ProseMirror）。

**对比**：

| 编辑器 | 类型 | Markdown 输出 | 可定制性 | 理由 |
|--------|------|--------------|---------|------|
| **Milkdown** | WYSIWYG | ✅ 原生 Markdown | 插件体系 | **专为 Markdown 设计，插件支持 LaTeX/Mermaid/表格，输出标准 Markdown** |
| Tiptap | WYSIWYG | 需转换 | 插件体系 | 更通用但非 Markdown-first |
| CodeMirror | 代码编辑 | ✅ | 高 | 偏代码编辑器，非所见即所得 |
| Vditor | WYSIWYG | ✅ | 中 | 功能全面但体积大，定制性偏弱 |

Milkdown 优势：
- 基于 ProseMirror（业界最成熟的富文本引擎）
- 输入输出都是标准 Markdown，不会破坏格式
- 插件化架构，按需加载 LaTeX / Mermaid / 表格等
- 体积小，移动端 WebView 加载快
- 未来扩展到 Android 时编辑器层可完全复用

### 1.3 本地 Git 引擎：SwiftGit2

**结论**：使用 **SwiftGit2**（libgit2 的 Swift 封装）处理本地 Git 操作。

**原因**：
- 离线支持要求本地必须有完整的 Git 能力（clone, commit, diff, merge）
- SwiftGit2 是 libgit2 的成熟 Swift 封装，支持 iOS
- 不依赖命令行 `git`，适合 App 沙盒环境
- GitHub API 仅用于 OAuth 和辅助操作（如仓库列表），核心 Git 操作走本地

### 1.4 AI Chat 引擎：多 LLM 统一接口

**结论**：自建轻量 `LLMService` 抽象层，统一 OpenAI / Anthropic / 自定义 API 的调用。

**原因**：
- 用户自行配置 API Key，需要支持多家供应商
- OpenAI 和 Anthropic 的 API 格式不同（OpenAI 用 `/chat/completions`，Anthropic 用 `/messages`）
- 通过 Protocol 抽象统一接口，新增供应商只需实现一个 adapter
- 支持 Streaming（SSE）实现打字机效果

```swift
protocol LLMProvider {
    var name: String { get }
    func sendMessage(messages: [ChatMessage], stream: Bool) -> AsyncThrowingStream<String, Error>
    func validateAPIKey() async throws -> Bool
}
```

内置实现：`OpenAIProvider`、`AnthropicProvider`、`CustomOpenAICompatibleProvider`

### 1.5 GitHub 认证：OAuth + GitHub App

**结论**：使用 GitHub OAuth App 通过 ASWebAuthenticationSession 在应用内完成授权。

**流程**：
```
App → ASWebAuthenticationSession → GitHub 授权页 → 回调 URL → 获取 access_token → 存入 Keychain
```

---

## 2. 整体架构

```
┌──────────────────────────────────────────────────────────┐
│                    SwiftUI App Shell                      │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │  RepoListView│  │FileTreeView  │  │  GitPanelView │  │
│  │  仓库列表     │  │  文件浏览器   │  │  Git 操作面板  │  │
│  └──────────────┘  └──────────────┘  └───────────────┘  │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │  LoginView   │  │  SettingsView│  │ FilePreview   │  │
│  │  登录页       │  │  设置页      │  │  文件预览      │  │
│  └──────────────┘  └──────────────┘  └───────────────┘  │
├──────────────────────────────────────────────────────────┤
│              MarkdownEditorView (WKWebView)               │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Milkdown Editor (HTML/CSS/JS)                     │  │
│  │  - WYSIWYG 编辑                                     │  │
│  │  - 工具栏 (格式化按钮)                                │  │
│  │  - 实时 Markdown 输出                                │  │
│  └────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Native ↔ JS Bridge (WKScriptMessageHandler)      │  │
│  │  - getContent() → Markdown 文本                     │  │
│  │  - setContent(markdown) → 加载内容                   │  │
│  │  - onContentChange → 通知 Native 内容变更            │  │
│  └────────────────────────────────────────────────────┘  │
├──────────────────────────────────────────────────────────┤
│                     Core Services                         │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │ GitService   │  │ GitHubAPI    │  │ FileManager   │  │
│  │              │  │ Service      │  │ Service       │  │
│  │ • clone      │  │              │  │              │  │
│  │ • pull       │  │ • OAuth      │  │ • CRUD files │  │
│  │ • commit     │  │ • list repos │  │ • tree walk  │  │
│  │ • push       │  │ • user info  │  │ • detect type│  │
│  │ • diff       │  │              │  │              │  │
│  │ • status     │  │              │  │              │  │
│  │(SwiftGit2)   │  │(URLSession)  │  │(FileManager) │  │
│  └──────────────┘  └──────────────┘  └───────────────┘  │
│  ┌──────────────┐  ┌──────────────────────────────────┐  │
│  │ AuthService  │  │ SyncEngine                       │  │
│  │              │  │                                  │  │
│  │ • login      │  │ • 检测远端变更                     │  │
│  │ • token mgmt │  │ • 冲突检测                        │  │
│  │ • keychain   │  │ • 同步状态管理                     │  │
│  └──────────────┘  └──────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐│
│  │ LLMService                                          ││
│  │ • OpenAIProvider / AnthropicProvider / CustomProvider││
│  │ • streaming chat · context injection · history mgmt ││
│  └──────────────────────────────────────────────────────┘│
├──────────────────────────────────────────────────────────┤
│                    Data Layer                              │
│  ┌──────────────────────────────────────────────────────┐│
│  │  Local Git Repos (App Sandbox/Documents)             ││
│  │  Keychain (OAuth Token, AI API Keys)                 ││
│  │  UserDefaults (Settings, Repo metadata)              ││
│  │  SwiftData / JSON (Chat history)                     ││
│  └──────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────┘
```

---

## 3. 模块详细设计

### 3.1 项目结构

```
MarkdownIsAllYouNeed/
├── App/
│   ├── MarkdownIsAllYouNeedApp.swift     # App 入口
│   └── AppState.swift                     # 全局状态
│
├── Views/
│   ├── Auth/
│   │   └── LoginView.swift                # GitHub 登录
│   ├── Repos/
│   │   ├── RepoListView.swift             # 仓库列表
│   │   └── RepoRowView.swift              # 仓库行
│   ├── Files/
│   │   ├── FileTreeView.swift             # 文件树
│   │   ├── FileRowView.swift              # 文件行
│   │   └── FilePreviewView.swift          # 非 MD 文件预览
│   ├── Editor/
│   │   ├── MarkdownEditorView.swift       # 编辑器容器 (WKWebView)
│   │   ├── EditorToolbar.swift            # Native 工具栏
│   │   └── WebView/                       # 打包的 Web 资源
│   │       ├── index.html
│   │       ├── editor.js                  # Milkdown 初始化 + Bridge
│   │       └── editor.css                 # 编辑器样式
│   ├── Git/
│   │   ├── GitPanelView.swift             # Git 操作主面板
│   │   ├── ChangesListView.swift          # 变更文件列表
│   │   ├── CommitView.swift               # 提交界面
│   │   └── ConflictView.swift             # 冲突处理界面
│   ├── Chat/
│   │   ├── ChatListView.swift             # 对话列表
│   │   ├── ChatView.swift                 # 对话详情
│   │   ├── ChatBubbleView.swift           # 消息气泡（支持 MD 渲染）
│   │   └── ChatInputView.swift            # 输入框
│   └── Settings/
│       ├── SettingsView.swift             # 设置页
│       └── APIKeyConfigView.swift         # API Key 配置
│
├── Services/
│   ├── AuthService.swift                  # OAuth + Token 管理
│   ├── GitHubAPIService.swift             # GitHub REST API
│   ├── GitService.swift                   # 本地 Git (SwiftGit2)
│   ├── FileManagerService.swift           # 文件操作
│   ├── SyncEngine.swift                   # 同步引擎
│   └── LLM/
│       ├── LLMService.swift               # 统一 Chat 接口
│       ├── OpenAIProvider.swift            # OpenAI adapter
│       ├── AnthropicProvider.swift         # Anthropic adapter
│       └── CustomProvider.swift            # 自定义 OpenAI 兼容 API
│
├── Models/
│   ├── Repository.swift                   # 仓库模型
│   ├── FileNode.swift                     # 文件树节点
│   ├── GitStatus.swift                    # Git 状态
│   ├── UserProfile.swift                  # 用户信息
│   ├── ChatConversation.swift             # 对话模型
│   ├── ChatMessage.swift                  # 消息模型
│   └── LLMConfig.swift                    # LLM 配置模型
│
├── Utilities/
│   ├── KeychainHelper.swift               # Keychain 封装
│   ├── FileTypeDetector.swift             # 文件类型识别
│   └── Constants.swift                    # 常量定义
│
└── Resources/
    └── Assets.xcassets                    # 图标资源
```

### 3.2 认证模块 (AuthService)

```swift
// 核心接口
protocol AuthServiceProtocol {
    var isAuthenticated: Bool { get }
    var currentUser: UserProfile? { get }
    func login() async throws
    func logout()
    func getAccessToken() -> String?
}
```

**流程**：
1. 注册 GitHub OAuth App，获取 Client ID / Secret
2. 用 `ASWebAuthenticationSession` 打开 GitHub 授权 URL
3. 用户授权后，通过回调 URL 拿到 `code`
4. 用 `code` 换取 `access_token`
5. Token 存入 iOS Keychain
6. 后续请求自动携带 Token

### 3.3 仓库管理模块 (GitHubAPIService + GitService)

**仓库列表**（通过 GitHub API）：
```swift
protocol GitHubAPIServiceProtocol {
    func fetchUserRepos(page: Int) async throws -> [Repository]
    func fetchStarredRepos(page: Int) async throws -> [Repository]
    func fetchUserProfile() async throws -> UserProfile
}
```

**本地 Git 操作**（通过 SwiftGit2）：
```swift
protocol GitServiceProtocol {
    func clone(url: URL, to localPath: URL, token: String) async throws
    func pull(at repoPath: URL) async throws -> MergeResult
    func commit(at repoPath: URL, message: String, files: [String]) throws
    func push(at repoPath: URL, token: String) async throws
    func status(at repoPath: URL) throws -> [FileStatus]
    func diff(at repoPath: URL, file: String) throws -> String
    func hasRemoteChanges(at repoPath: URL) async throws -> Bool
}
```

### 3.4 Markdown 编辑器模块

**架构**：Native SwiftUI 容器 + WKWebView + Milkdown

**Native → JS 通信**（通过 evaluateJavaScript）：
```javascript
// 加载内容
window.editor.setContent(markdownString)

// 获取内容
window.editor.getContent() // → returns markdown string

// 插入图片
window.editor.insertImage(relativePath, altText)
```

**JS → Native 通信**（通过 WKScriptMessageHandler）：
```javascript
// 内容变更通知
webkit.messageHandlers.contentChanged.postMessage({
    markdown: "...",
    isDirty: true
})

// 请求插入图片（触发 Native 图片选择器）
webkit.messageHandlers.requestImagePicker.postMessage({})
```

**编辑器工具栏**：使用 Native SwiftUI 工具栏，点击后调用 JS 方法：
```
[ H1 | H2 | B | I | ~ | • | ☑ | <> | "" | — | 📷 | 🔗 | ... ]
```

### 3.5 文件管理模块

```swift
struct FileNode: Identifiable {
    let id: UUID
    let name: String
    let path: String          // 相对于仓库根目录的路径
    let isDirectory: Bool
    let fileType: FileType    // .markdown, .text, .image, .binary
    var children: [FileNode]? // 目录子节点
}

enum FileType {
    case markdown    // .md, .markdown → WYSIWYG 编辑器
    case text        // .swift, .json, .txt 等 → 纯文本编辑
    case image       // .png, .jpg 等 → 图片预览
    case binary      // 其他 → 显示文件信息
}
```

### 3.6 AI Chat 模块 (LLMService)

**统一接口**：
```swift
protocol LLMProvider {
    var name: String { get }                    // "OpenAI", "Anthropic", "Custom"
    var availableModels: [String] { get }
    func sendMessage(
        messages: [ChatMessage],
        model: String,
        stream: Bool
    ) -> AsyncThrowingStream<String, Error>
    func validateAPIKey() async throws -> Bool
}

class LLMService {
    var activeProvider: LLMProvider
    func chat(conversation: ChatConversation, context: String?) -> AsyncThrowingStream<String, Error>
}
```

**上下文注入**：从编辑器进入 Chat 时，将当前文件内容作为 system message 注入：
```
System: 用户正在编辑文件 `hello.md`，内容如下：
---
{file content}
---
请基于此上下文回答用户的问题。
```

**对话持久化**：使用 SwiftData 存储对话和消息，支持离线查看历史。

**Streaming**：通过 URLSession + SSE 解析实现流式输出，AI 回复逐字显示。

### 3.7 同步引擎 (SyncEngine)

负责协调离线编辑和远端同步：

```
状态机：
  Idle → Checking → [UpToDate | HasLocalChanges | HasRemoteChanges | Conflict]

冲突处理流程：
  Push 失败 → fetch remote → 检测是否有冲突
    → 无冲突：自动 merge + push
    → 有冲突：展示 ConflictView，让用户选择
        → "Pull 并合并"：尝试 merge
        → "强制推送"：force push（需二次确认）
        → "取消"：保留本地状态
```

---

## 4. 依赖项

| 依赖 | 用途 | 集成方式 |
|------|------|---------|
| SwiftGit2 | 本地 Git 操作 | Swift Package Manager |
| KeychainAccess | Keychain 封装 | Swift Package Manager |
| Milkdown | WYSIWYG Markdown 编辑器 | npm build → 打包到 App Bundle |
| SwiftData | 对话历史持久化 | iOS 17 内置 |

**注意**：Milkdown 及其插件需要通过 npm 构建为单个 JS bundle，然后作为静态资源打包到 App 中。

---

## 5. 开发计划（分阶段）

### Phase 1：项目骨架 + 认证（~2天）
- [x] Xcode 项目初始化，SwiftUI 基本结构
- [x] GitHub OAuth 登录流程
- [x] Token 存储 (Keychain)
- [x] 用户信息展示

### Phase 2：仓库管理（~2天）
- [x] GitHub API 获取仓库列表
- [x] 仓库 Clone 到本地
- [x] 文件树浏览
- [x] 文件类型识别与分流

### Phase 3：Markdown 编辑器（~3天）
- [x] Milkdown 编辑器 Web 资源打包
- [x] WKWebView 容器
- [x] Native ↔ JS Bridge
- [x] 编辑器工具栏
- [x] 图片插入（相册/拍照 → 存入仓库）

### Phase 4：Git 工作流（~2天）
- [x] Git status / diff 展示
- [x] Commit（选文件 + 写 message）
- [x] Push
- [x] Pull + 冲突检测
- [x] 冲突处理 UI

### Phase 5：AI Chat（~2天）
- [ ] LLMService 统一接口 + OpenAI / Anthropic adapter
- [ ] Chat UI（对话列表 + 对话详情 + 流式输出）
- [ ] 上下文注入（从编辑器携带文件内容）
- [ ] 设置页：API Key 配置 + 模型选择
- [ ] 对话历史持久化 (SwiftData)

### Phase 6：离线 + 打磨（~1天）
- [ ] 离线编辑验证
- [ ] 同步状态指示
- [ ] 错误处理 & 用户提示
- [ ] 基本设置页完善

---

## 6. 风险与应对

| 风险 | 影响 | 应对 |
|------|------|------|
| SwiftGit2 在 iOS 上的兼容性 | 可能有编译/运行问题 | 备选方案：使用 GitHub API 做轻量 Git 操作，牺牲离线能力 |
| Milkdown 在 WKWebView 中的兼容性 | 部分功能异常 | 提前做 WebView PoC 验证，备选：Tiptap 或 Vditor |
| 大仓库 Clone 速度慢 | 用户体验差 | 支持 shallow clone (--depth 1)，后续按需 fetch |
| WebView 键盘交互 | iOS WebView 键盘行为不一致 | 需要自定义 inputAccessoryView，处理键盘避让 |

---

## 7. 未来扩展（非 MVP）

- AI 内联编辑（选中文字 → 改写/翻译/续写，类 Cursor 体验）
- AI 直接修改文档（用户确认后应用 diff）
- 分支切换、创建
- PR / Issue 浏览
- 全文搜索
- iPad 分屏适配
- iCloud 同步备份
- 自定义主题（暗色/亮色/自定义 CSS）
- 快捷指令 (Shortcuts) 集成
- Widget 显示最近编辑的文件
