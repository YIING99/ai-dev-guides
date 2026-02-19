#!/bin/bash
# ============================================================
# OpenClaw 飞书斜杠命令一键修复脚本
# 适用版本: OpenClaw v2026.2.x
# 作用: 修复飞书中 /status /help /new 等命令无响应的问题
# 用法: bash fix.sh
# 仓库: https://github.com/YIING99/ai-dev-guides
# ============================================================

set -e

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   OpenClaw 飞书斜杠命令一键修复                  ║"
echo "║   github.com/YIING99/ai-dev-guides              ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# ---- 1. 检测所有启用飞书的 OpenClaw 实例 ----
CONFIGS=()
for dir in /root/.openclaw /root/*/.openclaw; do
    config="$dir/openclaw.json"
    [ -f "$config" ] || continue
    if python3 -c "
import json, sys
with open('$config') as f:
    cfg = json.load(f)
if cfg.get('channels', {}).get('feishu', {}).get('enabled', False):
    sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
        CONFIGS+=("$config")
    fi
done

if [ ${#CONFIGS[@]} -eq 0 ]; then
    echo "❌ 未找到启用飞书的 OpenClaw 实例。"
    echo "   请确认 openclaw.json 中 channels.feishu.enabled = true"
    exit 1
fi

echo "📋 检测到 ${#CONFIGS[@]} 个飞书实例："
for cfg in "${CONFIGS[@]}"; do
    echo "   ✦ $cfg"
done
echo ""

# ---- 2. 修复配置 ----
FIXED=0
for cfg in "${CONFIGS[@]}"; do
    python3 -c "
import json
with open('$cfg') as f:
    config = json.load(f)
if 'commands' not in config:
    config['commands'] = {}
if config['commands'].get('useAccessGroups') == False:
    print(f'   ⏭  SKIP {\"$cfg\"} (已修复)')
else:
    config['commands']['useAccessGroups'] = False
    with open('$cfg', 'w') as f:
        json.dump(config, f, indent=4, ensure_ascii=False)
    print(f'   ✅ FIXED {\"$cfg\"}')
"
    FIXED=$((FIXED + 1))
done
echo ""

# ---- 3. 修复飞书扩展源码默认值 ----
BOT_TS="/usr/lib/node_modules/openclaw/extensions/feishu/src/bot.ts"
if [ -f "$BOT_TS" ]; then
    if grep -q 'useAccessGroups !== false' "$BOT_TS"; then
        sed -i 's/useAccessGroups !== false/useAccessGroups === true/g' "$BOT_TS"
        echo "   ✅ FIXED $BOT_TS (源码默认值)"
    else
        echo "   ⏭  SKIP $BOT_TS (已修复或版本不同)"
    fi
else
    echo "   ⚠️  未找到 $BOT_TS (可能未安装飞书扩展)"
fi
echo ""

# ---- 4. 重启服务 ----
echo "🔄 正在重启 OpenClaw 服务..."
export XDG_RUNTIME_DIR=/run/user/$(id -u)

RESTARTED=0
for svc in $(systemctl --user list-units 'openclaw*' --no-pager --plain --no-legend 2>/dev/null | awk '{print $1}'); do
    systemctl --user restart "$svc" 2>/dev/null && {
        echo "   ✅ 重启: $svc"
        RESTARTED=$((RESTARTED + 1))
    } || true
done

if [ $RESTARTED -eq 0 ]; then
    echo "   ⚠️  未找到 systemd 服务，请手动重启 OpenClaw"
fi

sleep 3
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   ✅ 修复完成！                                  ║"
echo "║                                                  ║"
echo "║   验证: 在飞书中发送 /status                     ║"
echo "║   预期: 应收到状态信息回复                        ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
