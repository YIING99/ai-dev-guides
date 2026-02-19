#!/bin/bash
# 敏感信息检查脚本
# 用法: bash check_sensitive.sh <文件或目录>

set -euo pipefail

TARGET="${1:-.}"
FOUND=0

echo "🔍 扫描敏感信息: $TARGET"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_pattern() {
    local label="$1"
    local pattern="$2"
    local results
    results=$(grep -rnE "$pattern" "$TARGET" --include='*.md' 2>/dev/null || true)
    if [ -n "$results" ]; then
        echo ""
        echo "⚠️  $label:"
        echo "$results" | head -10
        FOUND=$((FOUND + 1))
    fi
}

# 真实 IP 地址（排除 127.0.0.1 和 0.0.0.0）
check_pattern "可能的真实 IP 地址" '\b(1[0-9]{2}|2[0-4][0-9]|25[0-5])\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\b'

# 飞书 App ID
check_pattern "飞书 App ID" 'cli_[0-9a-f]{16}'

# 飞书 app_token
check_pattern "可能的飞书 app_token" 'app_token.*[A-Za-z0-9]{20,}'

# 飞书 table_id
check_pattern "飞书 table_id" 'tbl[A-Za-z0-9]{14,}'

# Telegram Bot Token
check_pattern "Telegram Bot Token" '[0-9]{8,}:AA[A-Za-z0-9_-]{30,}'

# OpenRouter Key
check_pattern "OpenRouter API Key" 'sk-or-v1-[A-Za-z0-9]+'

# 通用 Secret/Password 上下文
check_pattern "可能的密钥/密码" '(secret|password|passwd).*[:=]\s*["\x27][A-Za-z0-9]{16,}'

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$FOUND" -eq 0 ]; then
    echo "✅ 未发现明显敏感信息"
else
    echo "⚠️  发现 $FOUND 类潜在敏感信息，请人工复核"
fi
