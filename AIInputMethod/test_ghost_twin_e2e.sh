#!/bin/bash
#
# Ghost Twin 端上校准流程 E2E 真实 LLM 测试
# 直接调 Gemini API，不走 GHOSTYPE 服务端
#
# 用法: bash test_ghost_twin_e2e.sh [轮数]
# 默认跑 3 轮校准
#

set -euo pipefail

# ============================================================
# 配置
# ============================================================
GEMINI_API_KEY="AIzaSyDzLFEBQlH95unLiYVqBBgDLXaz1PwKQZ4"
GEMINI_MODEL="gemini-2.0-flash"
GEMINI_URL="https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}"
MAX_ROUNDS="${1:-3}"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ============================================================
# 状态变量（模拟客户端本地状态）
# ============================================================
LEVEL=1
TOTAL_XP=0
VERSION=1
PERSONALITY_TAGS='[]'
PROFILE_TEXT="初始档案：尚未校准"
RECORDS='[]'
XP_PER_LEVEL=10000
MAX_LEVEL=10

# 统计
PASS_COUNT=0
FAIL_COUNT=0
ROUND=0

# 临时文件
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# ============================================================
# 工具函数
# ============================================================
log_header() {
    echo ""
    echo -e "${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  $1${NC}"
    echo -e "${BOLD}════════════════════════════════════════════════════════════${NC}"
}

log_step() {
    echo -e "${CYAN}  ▸ $1${NC}"
}

log_ok() {
    echo -e "${GREEN}  ✅ $1${NC}"
    PASS_COUNT=$((PASS_COUNT + 1))
}

log_fail() {
    echo -e "${RED}  ❌ $1${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

log_info() {
    echo -e "${YELLOW}  ℹ $1${NC}"
}

# ============================================================
# 系统提示词（从 SKILL.md 提取）
# ============================================================
CALIBRATION_SYSTEM_PROMPT='你是 GHOSTYPE 的校准系统，负责两项任务：
1. 生成用于训练用户数字分身（Ghost Twin）的情境问答题
2. 分析用户的校准回答，对其数字分身的人格档案进行增量更新

# 出题模式
当用户消息包含「请根据以上信息生成一道校准挑战题」时，分析档案空缺并生成挑战题。
输出格式（严格 JSON，不要包裹在 markdown 代码块中）：
{"target_field": "form|spirit|method", "scenario": "...", "options": ["A", "B", "C"]}

注意：
- type 字段必须是 "dilemma"、"reverse_turing" 或 "prediction" 之一
- options 必须是包含 3 个字符串的数组
- 只输出 JSON，不要有其他文字

# 分析模式
当用户消息包含「请分析用户选择并输出 profile_diff」时，分析用户选择并更新档案。
输出格式（严格 JSON，不要包裹在 markdown 代码块中）：
{"profile_diff": {"layer": "form|spirit|method", "changes": {"key": "value"}, "new_tags": ["tag1", "tag2"]}, "ghost_response": "Ghost 的反馈语", "analysis": "分析说明"}

注意：只输出 JSON，不要有其他文字'

# ============================================================
# 调用 Gemini API
# ============================================================
call_gemini() {
    local system_prompt="$1"
    local user_message="$2"
    local output_file="$3"

    # 构建请求 JSON（用 python 转义特殊字符）
    python3 -c "
import json, sys
req = {
    'system_instruction': {
        'parts': [{'text': sys.argv[1]}]
    },
    'contents': [{
        'parts': [{'text': sys.argv[2]}]
    }],
    'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 2048
    }
}
print(json.dumps(req, ensure_ascii=False))
" "$system_prompt" "$user_message" > "$TMPDIR/request.json"

    local http_code
    http_code=$(curl -s -w "%{http_code}" -o "$output_file" \
        -X POST "$GEMINI_URL" \
        -H "Content-Type: application/json" \
        -d @"$TMPDIR/request.json")

    if [ "$http_code" != "200" ]; then
        echo "HTTP_ERROR:$http_code"
        return 1
    fi

    # 提取 text 字段
    python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    resp = json.load(f)
text = resp['candidates'][0]['content']['parts'][0]['text']
print(text)
" "$output_file"
}

# ============================================================
# 剥离 markdown 代码块（和 LLMJsonParser.stripMarkdownCodeBlock 一致）
# ============================================================
strip_markdown() {
    python3 -c "
import re, sys
text = sys.stdin.read().strip()
if text.startswith('\`\`\`'):
    text = re.sub(r'^\`\`\`(?:json|JSON)?\s*\n?', '', text)
    text = re.sub(r'\n?\`\`\`\s*$', '', text)
print(text.strip())
"
}

# ============================================================
# 验证 JSON 结构
# ============================================================
validate_challenge_json() {
    local json_text="$1"
    python3 -c "
import json, sys
try:
    d = json.loads(sys.argv[1])
    errors = []
    # target_field
    if 'target_field' not in d:
        errors.append('missing target_field')
    elif d['target_field'] not in ('form', 'spirit', 'method'):
        errors.append(f'invalid target_field: {d[\"target_field\"]}')
    # scenario
    if 'scenario' not in d or not d['scenario']:
        errors.append('missing/empty scenario')
    # options
    if 'options' not in d:
        errors.append('missing options')
    elif not isinstance(d['options'], list) or len(d['options']) < 2:
        errors.append(f'options must be array with >=2 items, got {d.get(\"options\")}')
    print('OK' if not errors else '|'.join(errors))
except Exception as e:
    print(f'PARSE_ERROR: {e}')
" "$json_text"
}

validate_analysis_json() {
    local json_text="$1"
    python3 -c "
import json, sys
try:
    d = json.loads(sys.argv[1])
    errors = []
    # profile_diff
    if 'profile_diff' not in d:
        errors.append('missing profile_diff')
    else:
        pd = d['profile_diff']
        if 'layer' not in pd:
            errors.append('missing profile_diff.layer')
        if 'changes' not in pd:
            errors.append('missing profile_diff.changes')
        if 'new_tags' not in pd:
            errors.append('missing profile_diff.new_tags')
        elif not isinstance(pd['new_tags'], list):
            errors.append('new_tags must be array')
    # ghost_response
    if 'ghost_response' not in d or not d['ghost_response']:
        errors.append('missing/empty ghost_response')
    # analysis
    if 'analysis' not in d or not d['analysis']:
        errors.append('missing/empty analysis')
    print('OK' if not errors else '|'.join(errors))
except Exception as e:
    print(f'PARSE_ERROR: {e}')
" "$json_text"
}

# ============================================================
# XP 计算（和 GhostTwinXP 一致）
# ============================================================
calculate_level() {
    local total_xp=$1
    local lvl=$(( total_xp / XP_PER_LEVEL + 1 ))
    if [ $lvl -gt $MAX_LEVEL ]; then lvl=$MAX_LEVEL; fi
    echo $lvl
}

current_level_xp() {
    local total_xp=$1
    local lvl=$(calculate_level $total_xp)
    if [ $lvl -ge $MAX_LEVEL ]; then
        echo $(( total_xp - (MAX_LEVEL - 1) * XP_PER_LEVEL ))
    else
        echo $(( total_xp % XP_PER_LEVEL ))
    fi
}

# 根据 challenge JSON 推断 type 并返回 XP
get_xp_reward() {
    local challenge_json="$1"
    # 尝试从 type 字段获取，如果没有就默认 dilemma
    local ctype
    ctype=$(python3 -c "
import json, sys
d = json.loads(sys.argv[1])
print(d.get('type', 'dilemma'))
" "$challenge_json" 2>/dev/null || echo "dilemma")

    case "$ctype" in
        dilemma) echo 500 ;;
        reverse_turing) echo 300 ;;
        prediction) echo 200 ;;
        *) echo 500 ;;  # 默认 dilemma
    esac
}

# ============================================================
# 构建 user message（和 MessageBuilder 一致）
# ============================================================
build_challenge_message() {
    python3 -c "
import json, sys
level = int(sys.argv[1])
version = int(sys.argv[2])
tags = json.loads(sys.argv[3])
profile_text = sys.argv[4]
records = json.loads(sys.argv[5])

parts = []
parts.append('## 当前用户档案')
parts.append(f'- 等级: Lv.{level}')
parts.append(f'- 档案版本: v{version}')
parts.append(f'- 已捕捉标签: {\", \".join(tags)}')
parts.append('- 人格档案全文:')
parts.append(profile_text)
parts.append('')
parts.append('## 最近校准记录（用于去重）')
if not records:
    parts.append('无历史记录')
else:
    for r in records[-5:]:
        parts.append(f'- [{r[\"type\"]}] {r[\"scenario\"]} → 选项{r[\"selected\"]}')
parts.append('')
parts.append('请根据以上信息生成一道校准挑战题。')
print('\n'.join(parts))
" "$LEVEL" "$VERSION" "$PERSONALITY_TAGS" "$PROFILE_TEXT" "$RECORDS"
}

build_analysis_message() {
    local challenge_json="$1"
    local selected_option="$2"

    python3 -c "
import json, sys
profile_text = sys.argv[1]
challenge = json.loads(sys.argv[2])
selected = int(sys.argv[3])
records = json.loads(sys.argv[4])

parts = []
parts.append('## 当前人格档案')
parts.append(profile_text)
parts.append('')
parts.append('## 本次挑战信息')
parts.append(f'- 类型: {challenge.get(\"type\", \"dilemma\")}')
parts.append(f'- 场景: {challenge[\"scenario\"]}')
opts = ', '.join(f'{i}: {o}' for i, o in enumerate(challenge['options']))
parts.append(f'- 选项: {opts}')
parts.append(f'- 目标层级: {challenge[\"target_field\"]}')
parts.append('')
parts.append('## 用户选择')
if selected >= 0 and selected < len(challenge['options']):
    parts.append(f'- 选项索引: {selected}')
    parts.append(f'- 选项内容: {challenge[\"options\"][selected]}')
parts.append('')
parts.append('## 校准历史')
if not records:
    parts.append('无历史记录')
else:
    for r in records[-5:]:
        parts.append(f'- [{r[\"type\"]}] {r[\"scenario\"]} → 选项{r[\"selected\"]}')
parts.append('')
parts.append('请分析用户选择并输出 profile_diff。')
print('\n'.join(parts))
" "$PROFILE_TEXT" "$challenge_json" "$selected_option" "$RECORDS"
}

# ============================================================
# 主流程
# ============================================================
log_header "Ghost Twin E2E 真实 LLM 测试"
echo -e "  模型: ${CYAN}${GEMINI_MODEL}${NC}"
echo -e "  轮数: ${CYAN}${MAX_ROUNDS}${NC}"
echo -e "  初始状态: Lv.${LEVEL}, XP: ${TOTAL_XP}"
echo ""

# 先测试 API 连通性
log_step "测试 Gemini API 连通性..."
TEST_RESP=$(call_gemini "你是一个测试助手" "回复 OK" "$TMPDIR/test_resp.json" 2>&1 || true)
if echo "$TEST_RESP" | grep -q "HTTP_ERROR"; then
    log_fail "Gemini API 不可用: $TEST_RESP"
    echo ""
    cat "$TMPDIR/test_resp.json" 2>/dev/null || true
    exit 1
fi
log_ok "API 连通 ✓"

# 主循环
for ((i=1; i<=MAX_ROUNDS; i++)); do
    ROUND=$i
    log_header "第 ${i}/${MAX_ROUNDS} 轮校准 (Lv.${LEVEL}, XP: ${TOTAL_XP})"

    # ── Step 1: 出题 ──
    log_step "Step 1: 出题 (调用 LLM)..."
    CHALLENGE_MSG=$(build_challenge_message)
    RAW_CHALLENGE=$(call_gemini "$CALIBRATION_SYSTEM_PROMPT" "$CHALLENGE_MSG" "$TMPDIR/challenge_resp.json" 2>&1)

    if echo "$RAW_CHALLENGE" | grep -q "HTTP_ERROR"; then
        log_fail "出题 API 调用失败: $RAW_CHALLENGE"
        continue
    fi

    # 剥离 markdown
    CLEAN_CHALLENGE=$(echo "$RAW_CHALLENGE" | strip_markdown)
    echo -e "  ${YELLOW}原始返回:${NC} $(echo "$RAW_CHALLENGE" | head -3)"

    # 验证 JSON
    CHALLENGE_VALID=$(validate_challenge_json "$CLEAN_CHALLENGE")
    if [ "$CHALLENGE_VALID" = "OK" ]; then
        log_ok "出题 JSON 结构合法"
    else
        log_fail "出题 JSON 结构异常: $CHALLENGE_VALID"
        echo -e "  ${RED}清洗后内容: $CLEAN_CHALLENGE${NC}"
        continue
    fi

    # 提取关键字段
    SCENARIO=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['scenario'])" "$CLEAN_CHALLENGE")
    OPTIONS=$(python3 -c "import json,sys; print(' | '.join(json.loads(sys.argv[1])['options']))" "$CLEAN_CHALLENGE")
    TARGET=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['target_field'])" "$CLEAN_CHALLENGE")
    log_info "场景: $SCENARIO"
    log_info "选项: $OPTIONS"
    log_info "目标层级: $TARGET"

    # ── Step 2: 模拟用户选择（随机选一个） ──
    NUM_OPTIONS=$(python3 -c "import json,sys; print(len(json.loads(sys.argv[1])['options']))" "$CLEAN_CHALLENGE")
    SELECTED=$((RANDOM % NUM_OPTIONS))
    SELECTED_TEXT=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['options'][$SELECTED])" "$CLEAN_CHALLENGE" "$SELECTED")
    log_step "Step 2: 用户选择选项 ${SELECTED}: ${SELECTED_TEXT}"

    # ── Step 3: 分析 ──
    log_step "Step 3: 分析 (调用 LLM)..."
    ANALYSIS_MSG=$(build_analysis_message "$CLEAN_CHALLENGE" "$SELECTED")
    RAW_ANALYSIS=$(call_gemini "$CALIBRATION_SYSTEM_PROMPT" "$ANALYSIS_MSG" "$TMPDIR/analysis_resp.json" 2>&1)

    if echo "$RAW_ANALYSIS" | grep -q "HTTP_ERROR"; then
        log_fail "分析 API 调用失败: $RAW_ANALYSIS"
        continue
    fi

    CLEAN_ANALYSIS=$(echo "$RAW_ANALYSIS" | strip_markdown)
    echo -e "  ${YELLOW}原始返回:${NC} $(echo "$RAW_ANALYSIS" | head -3)"

    ANALYSIS_VALID=$(validate_analysis_json "$CLEAN_ANALYSIS")
    if [ "$ANALYSIS_VALID" = "OK" ]; then
        log_ok "分析 JSON 结构合法"
    else
        log_fail "分析 JSON 结构异常: $ANALYSIS_VALID"
        echo -e "  ${RED}清洗后内容: $CLEAN_ANALYSIS${NC}"
        continue
    fi

    # 提取分析结果
    GHOST_RESP=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['ghost_response'])" "$CLEAN_ANALYSIS")
    NEW_TAGS=$(python3 -c "import json,sys; print(json.dumps(json.loads(sys.argv[1])['profile_diff']['new_tags'], ensure_ascii=False))" "$CLEAN_ANALYSIS")
    LAYER=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['profile_diff']['layer'])" "$CLEAN_ANALYSIS")
    log_info "Ghost 说: $GHOST_RESP"
    log_info "新标签: $NEW_TAGS"
    log_info "影响层级: $LAYER"

    # ── Step 4: 计算 XP ──
    XP_REWARD=$(get_xp_reward "$CLEAN_CHALLENGE")
    OLD_XP=$TOTAL_XP
    OLD_LEVEL=$LEVEL
    TOTAL_XP=$((TOTAL_XP + XP_REWARD))
    LEVEL=$(calculate_level $TOTAL_XP)
    CUR_LVL_XP=$(current_level_xp $TOTAL_XP)
    VERSION=$((VERSION + 1))

    log_step "Step 4: XP 计算"
    log_info "+${XP_REWARD} XP (${OLD_XP} → ${TOTAL_XP})"

    if [ $LEVEL -gt $OLD_LEVEL ]; then
        echo -e "  ${GREEN}${BOLD}  🎉 升级! Lv.${OLD_LEVEL} → Lv.${LEVEL}${NC}"
    fi

    log_info "当前: Lv.${LEVEL}, 等级内 XP: ${CUR_LVL_XP}/10000"

    # ── Step 5: 合并标签（去重） ──
    PERSONALITY_TAGS=$(python3 -c "
import json, sys
old = json.loads(sys.argv[1])
new = json.loads(sys.argv[2])
merged = list(old)
for t in new:
    if t not in merged:
        merged.append(t)
print(json.dumps(merged, ensure_ascii=False))
" "$PERSONALITY_TAGS" "$NEW_TAGS")
    log_info "累计标签: $PERSONALITY_TAGS"

    # ── Step 6: 追加校准记录 ──
    CTYPE=$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('type','dilemma'))" "$CLEAN_CHALLENGE")
    RECORDS=$(python3 -c "
import json, sys
records = json.loads(sys.argv[1])
records.append({
    'type': sys.argv[2],
    'scenario': sys.argv[3],
    'selected': int(sys.argv[4]),
    'xp': int(sys.argv[5])
})
# 保留最近 20 条
if len(records) > 20:
    records = records[-20:]
print(json.dumps(records, ensure_ascii=False))
" "$RECORDS" "$CTYPE" "$SCENARIO" "$SELECTED" "$XP_REWARD")

    log_ok "第 ${i} 轮完成"
    echo ""
done

# ============================================================
# 汇总
# ============================================================
log_header "测试汇总"
echo -e "  总轮数:   ${BOLD}${MAX_ROUNDS}${NC}"
echo -e "  通过检查: ${GREEN}${PASS_COUNT}${NC}"
echo -e "  失败检查: ${RED}${FAIL_COUNT}${NC}"
echo ""
echo -e "  最终状态:"
echo -e "    等级:   Lv.${LEVEL}"
echo -e "    总 XP:  ${TOTAL_XP}"
echo -e "    等级内: $(current_level_xp $TOTAL_XP)/10000"
echo -e "    版本:   v${VERSION}"
echo -e "    标签:   ${PERSONALITY_TAGS}"
echo -e "    记录数: $(python3 -c "import json,sys; print(len(json.loads(sys.argv[1])))" "$RECORDS")"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}${BOLD}  🎉 全部通过!${NC}"
    exit 0
else
    echo -e "${RED}${BOLD}  ⚠️  有 ${FAIL_COUNT} 项检查失败${NC}"
    exit 1
fi
