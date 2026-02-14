# Working Copy + Obsidian：iOS 上编辑 GitHub Markdown 完整指南

> 零开发成本，在 iPhone/iPad 上实现"GitHub 仓库 Markdown 所见即所得编辑"。

---

## 1. 需要安装的 App

| App | 价格 | 用途 |
|-----|------|------|
| [Working Copy](https://apps.apple.com/app/working-copy-git-client/id896694807) | 免费版可 clone/commit；**Pro 内购（约 ¥148 买断）才能 Push 和链接目录** | Git 客户端：clone、pull、commit、push |
| [Obsidian](https://apps.apple.com/app/obsidian-connected-notes/id1557175442) | 免费 | Markdown 所见即所得编辑器 |

> **注意**：Working Copy Pro 是必需的，免费版无法完成 Push 和目录链接。学生可通过 [GitHub Student Developer Pack](https://education.github.com/pack) 免费获取 Pro。

---

## 2. 初始设置

### 2.1 配置 Working Copy

1. 打开 Working Copy
2. 点击左上角 **"+"** → **"Clone repository"**
3. 选择 **"Sign in to GitHub"**，通过浏览器完成 OAuth 授权
4. 授权完成后，在仓库列表中找到你的目标仓库，点击 clone
5. 等待 clone 完成

### 2.2 让 Working Copy 出现在 iOS 文件系统中

1. 打开 iOS 自带的 **"文件"（Files）** App
2. 点击左侧边栏底部的 **"..."** → **"编辑边栏"**
3. 找到 **Working Copy**，打开它的开关
4. 点击 **"完成"**
5. 现在你应该能在 Files 侧边栏看到 "Working Copy" 作为一个存储位置，展开后可以看到所有 clone 的仓库

### 2.3 在 Obsidian 中打开 Working Copy 的仓库（关键步骤）

> **注意**：旧版教程中的 "Link Repository to Folder" 功能已经是旧版特性，2022 年 5 月之后下载的 Working Copy 不再提供该入口。现在的正确做法是**从 Obsidian 侧直接打开 Working Copy 中的目录**。

1. 打开 **Obsidian**
2. 在 Vault 选择界面，点击 **"Open folder as vault"**（打开文件夹作为仓库）
3. 在弹出的 iOS Files 文件选择器中，**左侧边栏选择 "Working Copy"**
4. 找到你 clone 好的仓库文件夹，点击选中
5. 点击 **"Open"**
6. Obsidian 就会将该仓库作为 Vault 打开，你可以看到仓库中的所有文件

> 这样 Obsidian 和 Working Copy 操作的是 **同一份文件**，在 Obsidian 中的编辑会直接反映在 Working Copy 中（反之亦然）。

---

## 3. 日常使用工作流

### 3.1 拉取最新内容（Pull）

```
打开 Working Copy → 进入仓库 → 点击顶部"↓"按钮（Pull）→ 获取远端最新变更
```

拉取后，Obsidian 中的文件会自动更新（因为它们读取的是同一个目录）。

### 3.2 编辑 Markdown

1. 打开 Obsidian
2. 在文件列表中找到要编辑的 `.md` 文件
3. 点击进入编辑模式（Obsidian 默认是 Live Preview 模式，即所见即所得）
4. 正常编辑，修改会自动保存到本地文件

**Obsidian 编辑器支持**：
- 标题、粗体、斜体、删除线
- 有序/无序/任务列表
- 代码块（语法高亮）
- 引用、分割线、表格
- 图片、链接
- 数学公式（LaTeX）
- Mermaid 图表

### 3.3 提交并推送（Commit & Push）

编辑完成后，切换到 Working Copy 提交：

1. 打开 Working Copy → 进入仓库
2. 你会看到 **"Modified"** 标记，点击查看变更的文件列表
3. 点击每个文件可以查看 **diff**（变更对比）
4. 点击右上角 **"Commit"**
5. 输入 commit message（提交说明）
6. 点击 **"Commit"** 确认
7. 点击 **"↑"**（Push）将提交推送到 GitHub

### 3.4 完整流程图

```
┌─────────────────────────────────────────────────┐
│                  开始工作                         │
└─────────────────┬───────────────────────────────┘
                  ▼
┌─────────────────────────────────────────────────┐
│  Working Copy: Pull 拉取最新                      │
└─────────────────┬───────────────────────────────┘
                  ▼
┌─────────────────────────────────────────────────┐
│  Obsidian: 编辑 Markdown（自动保存）               │
└─────────────────┬───────────────────────────────┘
                  ▼
┌─────────────────────────────────────────────────┐
│  Working Copy: 查看 diff → Commit → Push          │
└─────────────────────────────────────────────────┘
```

---

## 4. 进阶配置

### 4.1 Obsidian 推荐设置

打开 Obsidian → 左下角齿轮（Settings）：

| 设置项 | 推荐值 | 原因 |
|--------|--------|------|
| Editor → Default editing mode | **Live Preview** | 所见即所得 |
| Files & Links → New link format | **Relative path** | 与 GitHub 兼容 |
| Files & Links → Use Wikilinks | **关闭** | 使用标准 Markdown 链接语法，GitHub 可正常渲染 |
| Files & Links → Default location for new attachments | **In subfolder under current folder** 或指定 `assets` | 图片存放位置与 GitHub 约定一致 |

### 4.2 Obsidian 推荐插件（社区插件）

先在设置中开启 **Community plugins**，然后安装：

| 插件 | 用途 |
|------|------|
| **Advanced Tables** | 更方便地编辑 Markdown 表格，Tab 键跳转单元格 |
| **Paste image rename** | 粘贴图片时自动重命名，避免文件名冲突 |
| **Linter** | 格式化 Markdown，保持风格统一 |

### 4.3 Working Copy 快捷操作

- **iPad 分屏**：左边 Working Copy 看 diff，右边 Obsidian 编辑
- **通知**：Working Copy 支持设置远端变更通知，有人 push 了新内容会提醒你 pull

---

## 5. 处理常见场景

### 5.1 新建文件

直接在 Obsidian 中新建文件即可，Working Copy 会自动检测到新文件（显示为 Untracked），commit 时选中它即可。

### 5.2 插入图片

1. 在 Obsidian 中编辑时，直接粘贴图片或点击插入
2. 图片会保存到你配置的附件目录（如 `assets/`）
3. 在 Working Copy 中 commit 时，记得同时勾选图片文件和 `.md` 文件

### 5.3 冲突处理

如果 push 失败（远端有其他人的更改）：

1. Working Copy 会提示冲突
2. 先 **Pull**（Working Copy 会尝试自动合并）
3. 如果有冲突，Working Copy 会标记冲突文件，手动编辑解决
4. 解决后重新 commit & push

### 5.4 多仓库管理

- Working Copy 中可以 clone 多个仓库
- 每个仓库链接到不同的目录
- 在 Obsidian 中为每个仓库创建独立的 Vault，通过底部 Vault 切换器切换

---

## 6. 这个方案的局限

| 局限 | 说明 |
|------|------|
| 需要切换 App | 编辑在 Obsidian，Git 操作在 Working Copy，不如一体化 App 流畅 |
| Working Copy Push 需付费 | 免费版只能 clone 和 commit，push 需要内购买断（约 ¥148） |
| 无 AI 辅助 | Obsidian 本身没有 AI Chat 功能（需额外安装社区插件或使用其他 AI App） |
| Obsidian 特有语法 | Obsidian 的 `[[wikilinks]]` 和 `![[embed]]` 在 GitHub 上不渲染，需关闭 wikilinks |
| 大仓库性能 | 非常大的仓库 clone 较慢，Obsidian 索引也会慢 |

---

## 7. 总结

这个组合可以 **零开发成本** 满足"在 iOS 上用 WYSIWYG 编辑 GitHub 仓库中的 Markdown"这个核心需求。如果用下来发现切换 App 的体验可以接受，那就不需要从头开发；如果觉得体验不够好，至少明确了自研 App 需要重点优化的地方。
