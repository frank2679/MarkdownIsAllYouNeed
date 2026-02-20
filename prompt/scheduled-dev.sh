#!/bin/bash
# 定时开发任务：1 小时后自动启动 v0.4.0 开发并提交 PR
# 用法：nohup bash prompt/scheduled-dev.sh > prompt/scheduled-dev.log 2>&1 &
# 取消：kill $(cat prompt/scheduled-dev.pid)

WORKDIR="/Users/hang/work/MarkdownIsAllYouNeed"
PID_FILE="$WORKDIR/prompt/scheduled-dev.pid"
LOG_FILE="$WORKDIR/prompt/scheduled-dev.log"
DELAY=3600  # 1 小时（秒）

echo $$ > "$PID_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 任务已注册，将在 1 小时后（$(date -v+1H '+%H:%M:%S')）开始执行"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 取消方式：kill \$(cat $PID_FILE)"

# 等待 1 小时
sleep $DELAY

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始执行开发任务..."

# macOS 通知：开始
osascript -e 'display notification "开始执行 v0.4.0 开发任务，预计完成后再次通知" with title "Claude Code" sound name "Glass"' 2>/dev/null

cd "$WORKDIR"

PROMPT='继续下个版本的开发工作。
上下文：
- 项目：MarkdownIsAllYouNeed（macOS Markdown 编辑器）
- 工作流参考：docs/dev-workflow.md
- 当前版本：v0.3.0（文件操作）已合并到 main
- 下一版本：v0.4.0，主题：存储优化（减少冗余空间占用）

任务（跳过 Feature Review，直接执行）：
1. 读取现有代码，理解当前存储方式（clone 的 repo 存放位置、占用情况）
2. 创建 prompt/20260221.md，记录本轮开发上下文
3. 创建 feature branch：feat/storage-optimization-v0.4.0
4. 按 TDD 节奏开发存储优化功能（先写测试，再实现）
5. 确保所有测试通过
6. 按 Conventional Commits 规范提交
7. 创建 PR（base: main），PR body 包含变更摘要、文件清单、测试计划 checklist'

# 使用 --dangerously-skip-permissions 实现无人值守自动执行
claude --dangerously-skip-permissions -p "$PROMPT"

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 任务成功完成"
    osascript -e 'display notification "PR 已创建，请醒来 review！" with title "Claude Code ✓" sound name "Hero"' 2>/dev/null
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 任务执行失败，exit code: $EXIT_CODE"
    osascript -e 'display notification "开发任务执行失败，请查看日志" with title "Claude Code ✗" sound name "Basso"' 2>/dev/null
fi

# 清理 PID 文件
rm -f "$PID_FILE"
