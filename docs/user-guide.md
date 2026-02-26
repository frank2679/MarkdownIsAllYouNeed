# User Guide

> **Markdown Is All You Need** — 在 iPhone 上编辑 GitHub 仓库中的 Markdown 文件，支持 WYSIWYG 预览、格式工具栏、Git 提交推送。

---

## 登录方式

App 支持两种 GitHub 登录方式，按需选择。

---

### 方式一：OAuth 登录（推荐）

OAuth 登录通过浏览器完成授权，不需要手动创建 Token，适合大多数用户。

**步骤：**

1. 打开 App，进入登录界面
2. 点击 **Login with GitHub**
3. 系统弹出 Safari 视图，跳转至 GitHub 授权页面
4. 使用你的 GitHub 账号登录并点击 **Authorize**
5. 授权成功后自动返回 App，完成登录

**授权范围（Scopes）：**

| Scope | 用途 |
|-------|------|
| `repo` | 读写仓库文件（clone、pull、commit、push） |
| `user` | 读取用户基本信息（头像、用户名） |
| `gist` | 创建 Gist（Share as Gist 功能需要） |

> **注意：** 如果你的账号已通过旧版 OAuth 登录（不含 `gist` scope），需要在 App 设置中退出后重新登录，以获取完整权限。

---

### 方式二：PAT 登录（个人访问令牌）

PAT（Personal Access Token）方式适合不希望走 OAuth 授权流程、或需要精细控制权限的用户。

**步骤：**

**第一步 — 在 GitHub 上创建 Token**

1. 登录 GitHub，进入 **Settings → Developer settings → Personal access tokens → Tokens (classic)**
2. 点击 **Generate new token (classic)**
3. 填写 Token 名称（如 `MarkdownIsAllYouNeed`）
4. 设置过期时间（建议 90 天或无过期）
5. 勾选以下权限：

   | 权限 | 说明 |
   |------|------|
   | ✅ `repo` | 仓库读写（必选） |
   | ✅ `gist` | 创建 Gist（Share as Gist 需要） |
   | ✅ `read:user` | 读取用户信息（可选，用于显示头像） |

6. 点击 **Generate token**，复制生成的 Token（页面离开后无法再次查看）

**第二步 — 在 App 中填入 Token**

1. 打开 App，进入登录界面
2. 点击 **Login with PAT**
3. 将复制的 Token 粘贴到输入框
4. 点击确认，完成登录

> **安全提示：** Token 会加密保存在 iOS Keychain 中，不会明文存储。

---

## 基本使用流程

### 1. 克隆仓库

登录后在仓库列表中选择一个仓库，点击 **Clone** 将文件下载到本地。

### 2. 浏览与编辑文件

- 在文件树中点击 Markdown 文件进入编辑器
- 默认显示**预览模式**，点击文档任意位置切换为**编辑模式**
- 编辑模式下，键盘上方的工具栏提供：
  - **Undo / Redo** — 撤销/重做
  - **H1 / H2** — 标题（再次点击取消）
  - **Bold / Italic / Strikethrough** — 加粗/斜体/删除线（再次点击取消）
  - **列表、代码、引用、分割线、链接**
  - **收起键盘**（右侧固定按钮）
- 收起键盘 = 保存并切换回预览

### 3. 提交与推送

- 进入 Git 面板，查看已修改的文件
- 填写 Commit 消息，点击 **Commit & Push**

### 4. 分享文件

在编辑器右上角 `···` 菜单中：

| 选项 | 说明 | 前提 |
|------|------|------|
| **Share Link** | 分享 GitHub 文件链接 | 公开仓库 |
| **Share as Gist** | 创建公开 Gist 并分享链接 | Token 需要 `gist` scope |
| **Export HTML** | 导出当前渲染的 HTML 文件 | 无 |

---

## 常见问题

**Q: Share as Gist 提示 "HTTP 404 — token may be missing 'gist' scope"**

A: 你的 Token 缺少 `gist` 权限。
- OAuth 用户：退出登录后重新授权
- PAT 用户：在 GitHub 上重新生成包含 `gist` scope 的 Token，并在 App 中重新登录

**Q: Clone 很慢或失败**

A: Clone 通过 GitHub API 逐文件下载，大型仓库耗时较长。建议在 Wi-Fi 环境下操作。

**Q: 文件内容消失（进入 App 时编辑区空白）**

A: iOS 可能在后台将 WebView 进程终止（常见于长时间后台）。App 会自动检测并重新加载内容，无需手动操作。
