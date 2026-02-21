#!/bin/bash
# 定时开发任务：1 小时后自动启动开发并提交 PR
# 用法：nohup bash prompt/scheduled-dev.sh > prompt/scheduled-dev.log 2>&1 &
# 取消：kill $(cat prompt/scheduled-dev.pid)
# 实时查看日志：tail -f prompt/scheduled-dev.log

WORKDIR="/Users/hang/work/MarkdownIsAllYouNeed"
PID_FILE="$WORKDIR/prompt/scheduled-dev.pid"
DELAY=0  # 立即执行（定时使用改为 3600）

echo $$ >"$PID_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 任务已注册，将在 1 小时后（$(date -v+1H '+%H:%M:%S')）开始执行"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 取消方式：kill \$(cat $PID_FILE)"

sleep $DELAY

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始执行开发任务..."
timeout 5 osascript -e 'display notification "开始执行 v0.5.0 开发任务" with title "Claude Code" sound name "Glass"' 2>/dev/null

cd "$WORKDIR"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 启动 claude（日志实时输出）..."

# 写 prompt 到临时文件（避免 shell 转义问题）
PROMPT_FILE="/tmp/claude-dev-prompt.txt"
cat >"$PROMPT_FILE" <<'PROMPT_EOF'
开始 v0.5.0 开发工作。

## 项目上下文
- 项目：MarkdownIsAllYouNeed（iOS/macOS Markdown 编辑器，连接 GitHub 仓库）
- 工作流参考：docs/dev-workflow.md
- v0.4.0（存储优化，lazy .originals 缓存）已完成，PR #11 待 merge
- v0.5.0 主题：编辑体验优化（参考 prompt/20260220.md Round 3 中的 feature 和 bug 列表）

## 待处理问题（来自 prompt/20260220.md）

Bug fix（优先处理）：
- markdown 的链接无法跳转
- 文件可以拖拽，但是无法拖拽到指定路径下
- 手机编辑现有文件，只加了一行，但实际多加了 9 个空行，还删掉了最后一个空行

新功能：
- 编辑模式改造：点击文档进入预览模式，点击具体位置进入编辑模式，编辑功能显示在输入法上端（参考 Notion），取消 Save 按钮，退出文档即保存
- 增加 favorite 功能，支持对指定路径或文件添加到 favorite 快速访问
- 进入 git 操作时增加 discard 功能，将修改回退

## 任务（跳过 Feature Review，直接执行）
1. 读取 prompt/20260220.md 了解完整需求背景
2. 分析现有代码，评估每个 bug/feature 的实现复杂度
3. 创建 prompt/20260221.md（如果不存在）记录本轮上下文
4. 优先修复 bug，然后实现新功能
5. 创建 feature branch：feat/editing-ux-v0.5.0
6. 按 TDD 节奏开发（先写测试，再实现）
7. 确保所有测试通过（xcodebuild test）
8. 按 Conventional Commits 规范提交
9. 创建 PR（base: main），PR body 包含变更摘要、文件清单、测试计划 checklist
PROMPT_EOF

# pty.spawn 内部会 select stdin，/dev/null 立刻返回 EOF 导致 copy 循环退出。
# 改用 pty.fork 手动控制：只读 master PTY（claude 输出），不碰 stdin。
unset CLAUDECODE
python3 - "$PROMPT_FILE" <<'PYEOF'
import pty, os, sys, re, select

prompt_file = sys.argv[1]
claude_bin = os.path.expanduser('~/.local/bin/claude')
ansi_escape = re.compile(rb'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')

with open(prompt_file) as f:
    prompt = f.read().strip()

pid, master_fd = pty.fork()

if pid == 0:  # 子进程：exec claude
    os.execvp(claude_bin, [claude_bin, '--dangerously-skip-permissions', '-p', prompt])
else:  # 父进程：读 PTY 输出，写到 stdout（日志文件）
    try:
        while True:
            try:
                rfds, _, _ = select.select([master_fd], [], [], 5.0)
            except (OSError, ValueError):
                break
            if master_fd in rfds:
                try:
                    data = os.read(master_fd, 4096)
                except OSError:
                    break
                if not data:
                    break
                clean = ansi_escape.sub(b'', data)
                sys.stdout.buffer.write(clean)
                sys.stdout.buffer.flush()
    finally:
        os.waitpid(pid, 0)
PYEOF

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 任务成功完成"
    timeout 5 osascript -e 'display notification "PR 已创建，请 review！" with title "Claude Code ✓" sound name "Hero"' 2>/dev/null
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 任务执行失败，exit code: $EXIT_CODE"
    timeout 5 osascript -e 'display notification "开发任务失败，查看日志" with title "Claude Code ✗" sound name "Basso"' 2>/dev/null
fi

rm -f "$PID_FILE"
