#!/bin/bash
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
DAILY_CSV="$PROJECT_DIR/运营/数据/daily.csv"
ACTIONS_FILE="$PROJECT_DIR/运营/动作清单.md"

TODAY=$(date +%Y-%m-%d)
DOW=$(date +%u)
DOM=$(date +%-d)
MONTH=$(date +%-m)

DAILY_DUE="yes"
if [ -f "$DAILY_CSV" ]; then
  if tail -n +2 "$DAILY_CSV" | awk -F',' '{print $1}' | grep -qx "$TODAY"; then
    DAILY_DUE="no"
  fi
fi

CYCLES=()
[ "$DAILY_DUE" = "yes" ] && CYCLES+=("日报（昨日 5 项核心指标 + 今日预约数）")
[ "$DOW" = "1" ]   && CYCLES+=("周报（上周渠道/签单率/项目结构/老客回访/棘手问题）")
[ "$DOM" = "1" ]   && CYCLES+=("月报（营收/净利/客单价/复购/CAC/星级/医生产值/成就遗憾）")
if [ "$DOM" = "1" ] && { [ "$MONTH" = "1" ] || [ "$MONTH" = "4" ] || [ "$MONTH" = "7" ] || [ "$MONTH" = "10" ]; }; then
  CYCLES+=("季报（项目结构达标率/渠道 ROI/团队绩效/库存设备/竞品扫描）")
fi
if [ "$DOM" = "1" ] && { [ "$MONTH" = "1" ] || [ "$MONTH" = "7" ]; }; then
  CYCLES+=("半年报（品牌资产/老客 LTV/财务健康度/战略调整/团队稳定性）")
fi
if [ "$DOM" = "1" ] && [ "$MONTH" = "1" ]; then
  CYCLES+=("年报（全年财报/客群结构/团队扩编/扩店评估/明年定位/合规审计）")
fi

LAST_DAILY=""
if [ -f "$DAILY_CSV" ] && [ "$(wc -l < "$DAILY_CSV")" -gt 1 ]; then
  LAST_DAILY=$(tail -n 1 "$DAILY_CSV")
fi

PENDING_ACTIONS=""
if [ -f "$ACTIONS_FILE" ]; then
  PENDING_ACTIONS=$(grep -E '\| 待办 \||\| 进行 \|' "$ACTIONS_FILE" 2>/dev/null || true)
fi

CYCLES_TEXT=""
if [ ${#CYCLES[@]} -eq 0 ]; then
  CYCLES_TEXT="（今日无新到期复盘周期，可主动询问老板是否需要临时复盘或讨论某个专项动作。）"
else
  for c in "${CYCLES[@]}"; do
    CYCLES_TEXT="${CYCLES_TEXT}- ${c}"$'\n'
  done
fi

LAST_DAILY_TEXT="（暂无历史日报数据）"
[ -n "$LAST_DAILY" ] && LAST_DAILY_TEXT="$LAST_DAILY"

PENDING_TEXT="（无未闭环动作）"
[ -n "$PENDING_ACTIONS" ] && PENDING_TEXT="$PENDING_ACTIONS"

ADDITIONAL_CONTEXT=$(cat <<EOF
<运营复盘提示>
今天是 ${TODAY}（周${DOW}）。皓琪口腔运营工作台已加载。

【今日到期复盘周期】
${CYCLES_TEXT}
【最近一次日报数据（对比基线）】
表头：日期,新客,老客,成交单数,营收,新增线索,客诉数,今日预约
最新：${LAST_DAILY_TEXT}

【未闭环动作（必须先回顾）】
${PENDING_TEXT}

【你必须立刻做的事】
1. 主动用一句话欢迎老板，并告诉他今天要复盘哪几个周期、有几条未闭环动作。
2. 先快速过未闭环动作（让老板逐条确认状态：已完成/进行中/放弃）。
3. 按"日 → 周 → 月 → 季 → 半年 → 年"顺序，逐周期询问指标体系里规定的字段；一次问完一个周期所有字段，让老板批量回。
4. 老板回答后立刻：写入对应数据文件、与上期对比给 3 条以内红/黄/绿判断、给 1–3 条带时间窗的可执行动作并登记到动作清单。
5. 全部复盘结束后，git add/commit/push 数据更新到 claude/amazing-shannon-kh09ti 分支，commit message 格式：数据更新: ${TODAY} <周期>。
</运营复盘提示>
EOF
)

python3 -c "
import json, sys
ctx = sys.stdin.read()
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'SessionStart',
        'additionalContext': ctx
    }
}, ensure_ascii=False))
" <<< "$ADDITIONAL_CONTEXT"
