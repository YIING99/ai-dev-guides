# OpenClaw 飞书斜杠命令修复实战：从「已读不回」到「秒级响应」

> 你的 AI 助手在飞书里对 `/status` 视而不见？不是它不想理你，是它被「安保系统」误杀了。

---

## 问题现象

你部署了 OpenClaw AI 助手，接入了飞书。Telegram 里一切正常，斜杠命令丝滑运行。

但在飞书里：

| 你发的命令 | Telegram 表现 | 飞书表现 |
|-----------|-------------|---------|
| `/status` | 立即返回状态信息 | **无响应** |
| `/help` | 显示帮助列表 | **无响应** |
| `/new` | 重置会话并问好 | **无响应** |
| `/compact` | 压缩上下文 | **无响应** |
| `你好` | 正常回复 | 正常回复 |

普通聊天正常，但**所有斜杠命令在飞书里全部静默失败**——没有报错，没有提示，就是「已读不回」。

---

## 排查过程

### 第一步：确认症状

SSH 上服务器，查看日志：

```bash
# 查看小七（Y1实例）的日志
XDG_RUNTIME_DIR=/run/user/0 journalctl --user -u openclaw-gateway-y1 --no-pager -n 50 | grep dispatch
```

发现关键差异：

```
# 普通消息 → 正常
dispatch complete (queuedFinal=true, replies=1)

# 斜杠命令 → 全部为0
dispatch complete (queuedFinal=false, replies=0)
```

`replies=0` 意味着命令被处理了，但**回复在内部被丢弃**，从未送达飞书。

### 第二步：注入调试日志

在飞书扩展的 `bot.ts` 中临时添加一行调试日志（后面有一键脚本），观察关键变量：

```
DEBUG content="/status" commandAuthorized=false CommandAuthorized=false
```

**核心发现：`commandAuthorized` 对所有飞书消息都是 `false`！**

这就解释了一切——OpenClaw 的命令处理链中，`commandAuthorized=false` 会导致所有 directive-only 命令（纯命令，不带其他文本）的回复被静默丢弃为 `undefined`。

### 第三步：追溯根因

顺着 `commandAuthorized` 的计算链路追踪：

```
飞书 bot.ts 第559行:
const useAccessGroups = cfg.commands?.useAccessGroups !== false;
                                                      ^^^^^^^^^^^
                                                      问题在这里！
```

**`!== false` vs `=== true` 的天壤之别：**

| 表达式 | `undefined` 的结果 | 含义 |
|--------|-------------------|------|
| `cfg.commands?.useAccessGroups !== false` | `true` | **默认开启**访问控制 |
| `cfg.commands?.useAccessGroups === true` | `false` | **默认关闭**访问控制 |

飞书扩展用了 `!== false`，导致 `useAccessGroups` **默认为 `true`**。

而 Telegram、Discord、Slack 等内置渠道默认不启用 accessGroups。这就是为什么 Telegram 正常、飞书不正常。

### 完整的故障链

```
useAccessGroups 默认 true
    ↓
检查发送者是否在 allowFrom 列表中
    ↓
dmPolicy="open" 且未配置 allowFrom → 列表为空 → configured=false
    ↓
resolveCommandAuthorizedFromAuthorizers 返回 false
    ↓
commandAuthorized = false
    ↓
command.isAuthorizedSender = false
    ↓
directive-only 命令 → return { kind: "reply", reply: void 0 }
    ↓
getReplyFromConfig 返回 undefined → replies=0
    ↓
飞书用户看到的：已读不回
```

---

## 一键修复

### 方法一：配置修复（推荐）

在 `openclaw.json` 的 `commands` 部分添加一行：

```json
{
    "commands": {
        "native": "auto",
        "nativeSkills": "auto",
        "useAccessGroups": false
    }
}
```

然后重启服务即可。

### 方法二：一键修复脚本

将以下脚本保存为 `fix_feishu_commands.sh`，上传到 VPS 执行：

```bash
#!/bin/bash
# OpenClaw 飞书斜杠命令一键修复脚本
# 适用版本: OpenClaw v2026.2.x
# 作用: 修复飞书中斜杠命令无响应的问题

set -e

echo "=== OpenClaw 飞书斜杠命令修复工具 ==="
echo ""

# 自动检测所有 OpenClaw 实例
CONFIGS=()
for dir in /root/.openclaw /root/*/. ; do
    config="$dir/.openclaw/openclaw.json"
    [ -f "$config" ] || config="$dir/openclaw.json"
    [ -f "$config" ] || continue

    # 检查是否启用了飞书
    if python3 -c "
import json, sys
with open('$config') as f:
    cfg = json.load(f)
feishu = cfg.get('channels', {}).get('feishu', {})
if feishu.get('enabled', False):
    sys.exit(0)
else:
    sys.exit(1)
" 2>/dev/null; then
        CONFIGS+=("$config")
    fi
done

if [ ${#CONFIGS[@]} -eq 0 ]; then
    echo "未找到启用飞书的 OpenClaw 实例。"
    echo "请确认 openclaw.json 中 channels.feishu.enabled = true"
    exit 1
fi

echo "检测到 ${#CONFIGS[@]} 个飞书实例："
for cfg in "${CONFIGS[@]}"; do
    echo "  - $cfg"
done
echo ""

# 修复每个实例的配置
for cfg in "${CONFIGS[@]}"; do
    python3 -c "
import json

with open('$cfg') as f:
    config = json.load(f)

if 'commands' not in config:
    config['commands'] = {}

if config['commands'].get('useAccessGroups') == False:
    print(f'SKIP $cfg (已修复)')
else:
    config['commands']['useAccessGroups'] = False
    with open('$cfg', 'w') as f:
        json.dump(config, f, indent=4, ensure_ascii=False)
    print(f'FIXED $cfg')
"
done

# 修复飞书扩展源码中的默认值 bug
BOT_TS="/usr/lib/node_modules/openclaw/extensions/feishu/src/bot.ts"
if [ -f "$BOT_TS" ]; then
    if grep -q 'useAccessGroups !== false' "$BOT_TS"; then
        sed -i 's/useAccessGroups !== false/useAccessGroups === true/g' "$BOT_TS"
        echo "FIXED $BOT_TS (源码默认值修复)"
    else
        echo "SKIP $BOT_TS (已修复或版本不同)"
    fi
fi

echo ""

# 重启所有 OpenClaw 服务
echo "正在重启 OpenClaw 服务..."
export XDG_RUNTIME_DIR=/run/user/$(id -u)

for svc in $(systemctl --user list-units 'openclaw*' --no-pager --plain --no-legend 2>/dev/null | awk '{print $1}'); do
    systemctl --user restart "$svc" 2>/dev/null && echo "  重启: $svc" || true
done

sleep 3

echo ""
echo "=== 修复完成 ==="
echo ""
echo "验证方法: 在飞书中发送 /status，应能收到状态回复"
echo ""
```

**使用方式：**

```bash
# 1. 上传到 VPS
scp fix_feishu_commands.sh root@你的VPS地址:/tmp/

# 2. 执行
ssh root@你的VPS地址 "bash /tmp/fix_feishu_commands.sh"

# 3. 验证: 在飞书中发送 /status
```

---

## 飞书常用斜杠命令完整清单

修复后，以下命令在飞书中均可正常使用。

### 日常高频（必记 5 个）

| 命令 | 作用 | 使用场景 | 示例 |
|------|------|---------|------|
| `/new` | 新建会话 | 切换话题、清空上下文 | `/new` |
| `/compact` | 压缩上下文 | 对话太长、快要超限 | `/compact` 或 `/compact 保留配置相关` |
| `/stop` | 停止生成 | 回复跑偏或太长 | `/stop` |
| `/status` | 查看状态 | 了解模型、token、会话信息 | `/status` |
| `/help` | 显示帮助 | 忘记有哪些命令 | `/help` |

### 模型与回复控制

| 命令 | 别名 | 作用 | 参数说明 |
|------|------|------|---------|
| `/model` | - | 查看/切换模型 | `/model` 查看，`/model provider/name` 切换 |
| `/models` | - | 列出可用模型 | `/models` 列出提供商，`/models zai` 列出该提供商的模型 |
| `/think` | `/thinking`、`/t` | 设置思考深度 | `off` / `low` / `medium` / `high` |
| `/verbose` | `/v` | 切换详细输出 | `on` / `off` |
| `/reasoning` | `/reason` | 切换推理可见性 | `on` / `off` / `stream` |
| `/usage` | - | 用量与费用显示 | `off` / `tokens` / `full` / `cost` |

### 会话管理

| 命令 | 作用 | 注意事项 |
|------|------|---------|
| `/new` | 新建会话，旧记录归档保留 | 不会丢失历史，只是开始新对话 |
| `/reset` | 重置会话（同 `/new`） | 两个命令效果相同 |
| `/compact` | 压缩上下文 | 可带参数指定保留重点：`/compact 保留API配置` |
| `/context` | 查看上下文构成 | `/context list` 查看 token 占用详情 |
| `/stop` | 停止当前生成 | 回复太长或方向不对时使用 |

### 身份与信息

| 命令 | 别名 | 作用 |
|------|------|------|
| `/whoami` | `/id` | 查看你的发送者 ID 和身份信息 |
| `/commands` | - | 列出当前可用的所有命令 |

### 语音控制（TTS）

| 命令 | 作用 |
|------|------|
| `/tts on` | 开启语音回复 |
| `/tts off` | 关闭语音回复 |
| `/tts status` | 查看 TTS 当前状态 |
| `/tts audio 你要朗读的文字` | 将指定文字转为语音 |
| `/tts provider edge` | 切换语音引擎（edge/openai/elevenlabs） |
| `/tts help` | 查看 TTS 完整用法 |

### 高级管理（需配置启用）

以下命令默认禁用，需在 `openclaw.json` 中显式开启：

```json
{
    "commands": {
        "config": true,
        "debug": true,
        "bash": true
    }
}
```

| 命令 | 作用 | 安全级别 |
|------|------|---------|
| `/config show` | 查看当前配置 | 中 |
| `/config set path value` | 修改运行时配置 | 高 |
| `/debug show` | 查看调试状态 | 中 |
| `/bash 命令` | 在服务器执行 shell 命令 | **极高**（谨慎开启） |

### 群组专用

| 命令 | 作用 |
|------|------|
| `/activation mention` | 设为 @机器人 才回复 |
| `/activation always` | 设为所有消息都回复 |
| `/send on/off` | 开启/关闭群组消息发送 |
| `/allowlist add/remove` | 管理群组白名单 |

### 子代理管理

| 命令 | 作用 |
|------|------|
| `/subagents list` | 列出活跃的子代理 |
| `/subagents stop [id]` | 停止指定子代理 |
| `/subagents log [id]` | 查看子代理日志 |
| `/subagents info [id]` | 查看子代理信息 |

---

## 不带斜杠怎么办？意图识别兜底

如果你的用户习惯不加斜杠直接输入命令文字，可以在 AI 的工具文档（`TOOLS.md`）中添加意图识别规则：

```markdown
### 用户意图识别规则

当用户发送以下内容（不带斜杠）时，主动引导使用对应命令：

| 用户可能说的 | 引导使用 |
|------------|---------|
| "新会话"、"new"、"清空"、"重新开始" | 请发送 `/new` 开始新会话 |
| "压缩"、"compact"、"太长了" | 请发送 `/compact` 压缩上下文 |
| "停"、"stop"、"别说了" | 请发送 `/stop` 停止回复 |
| "状态"、"status" | 请发送 `/status` 查看状态 |
| "我是谁"、"whoami" | 请发送 `/whoami` 查看身份 |
| "用量"、"费用"、"usage" | 请发送 `/usage cost` 查看用量 |
```

这样即使用户忘了加 `/`，AI 也能引导他们使用正确的命令格式。

---

## 技术原理：为什么 Telegram 正常、飞书不行？

### 架构差异

```
Telegram: 内置渠道 → nativeCommands: true → 原生命令菜单 → 命令无需授权检查
飞书:     外部扩展 → 无 nativeCommands → 文本命令模式 → 需要 commandAuthorized
```

### 默认值差异

| 渠道 | useAccessGroups 默认值 | 命令是否直接可用 |
|------|---------------------|---------------|
| Telegram | 不涉及（原生命令） | 直接可用 |
| Discord | 不涉及（原生命令） | 直接可用 |
| Slack | 不涉及（原生命令） | 直接可用 |
| **飞书** | **`true`**（bug） | **需要配置才可用** |

### 根因总结

飞书扩展 `bot.ts` 第559行：

```typescript
// Bug: undefined !== false → true → 默认开启访问控制
const useAccessGroups = cfg.commands?.useAccessGroups !== false;

// 正确: undefined === true → false → 默认关闭访问控制
const useAccessGroups = cfg.commands?.useAccessGroups === true;
```

一个 `!==` 和 `===` 的差异，导致飞书用户的所有斜杠命令全部静默失败。

---

## 经验提炼

### 1. 「静默失败」是最危险的 Bug

这个 Bug 的「恶毒」之处在于：
- **不报错**——日志里没有 ERROR
- **不提示**——用户看不到任何反馈
- **部分正常**——普通聊天完全没问题

如果命令返回一个报错信息「未授权」，排查 5 分钟就能解决。但它选择了**静默丢弃**，让你以为是「飞书不支持」。

### 2. 默认值的哲学

```
!== false  →  "除非明确禁止，否则开启"  →  安全但可能破坏功能
=== true   →  "除非明确开启，否则关闭"  →  宽松但更易用
```

对于「安全功能」（如访问控制），选择 `!== false` 是合理的。
但对于「用户可能根本不知道这个配置项存在」的场景，`=== true` 才是正确选择。

### 3. 调试的金钥匙：注入观测点

当代码路径太复杂时，最有效的方法不是「读更多代码」，而是**注入观测点**：

```typescript
// 一行调试日志，胜过读 1000 行源码
log(`DEBUG commandAuthorized=${commandAuthorized}`);
```

确认了 `commandAuthorized=false`，直接定位问题，比分析 58000 行代码高效 100 倍。

---

## 快速自检清单

你的 OpenClaw + 飞书是否有这个问题？逐项检查：

- [ ] 飞书中发送 `/status`，是否有回复？
- [ ] 飞书中发送 `/help`，是否有回复？
- [ ] `openclaw.json` 中是否有 `"useAccessGroups": false`？
- [ ] 如果没有回复，运行一键修复脚本
- [ ] 修复后再次发送 `/status` 验证

---

*作者：大王 | 2026-02-19 | 公众号：持续进化营*
*环境：OpenClaw v2026.2.13 + 飞书扩展 @openclaw/feishu*
*本文基于真实排查过程提炼，非虚构案例*
