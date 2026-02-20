# OpenClaw 多龙虾部署指南：从踩坑到最佳实践

> 基于 2026-02-17~18 实战经验，覆盖 3 只龙虾的完整部署过程
> OpenClaw 版本：2026.2.13 | VPS：DigitalOcean 4GB Ubuntu 24.04

---

## 目录

1. [为什么要多龙虾？](#1-为什么要多龙虾)
2. [两种隔离方案对比](#2-两种隔离方案对比)
3. [推荐方案：OPENCLAW_HOME 完全隔离](#3-推荐方案openclaw_home-完全隔离)
4. [完整部署流程（以龙虾2号为例）](#4-完整部署流程以龙虾2号为例)
5. [OpenRouter 接入指南](#5-openrouter-接入指南)
6. [飞书频道配置](#6-飞书频道配置)
7. [systemd 服务管理](#7-systemd-服务管理)
8. [踩坑全记录](#8-踩坑全记录)
9. [完整配置参考](#9-完整配置参考)
10. [运维速查表](#10-运维速查表)

---

## 1. 为什么要多龙虾？

不同龙虾可以承担不同角色：

| 龙虾 | 模型 | 频道 | 定位 |
|------|------|------|------|
| 小九 | 智谱 GLM-4.7 | Telegram | 日常助手 |
| 小七 | 智谱 GLM-4.7 | Telegram + 飞书 | 知识捕手 |
| 龙虾2号 | Claude Sonnet 4.5 (OpenRouter) | 飞书 | 高级推理 |

每个龙虾独立配置、独立运行、互不干扰。

---

## 2. 两种隔离方案对比

OpenClaw 支持两种多实例方式，但**只推荐一种**。

### 方案 A：`--profile` 参数（不推荐）

```bash
openclaw --profile claude setup
openclaw --profile claude configure
```

**工作原理**：配置存在 `~/.openclaw-claude/`，但工作区共享 `~/.openclaw/workspace-claude/`

**致命问题**：

| 问题 | 影响 |
|------|------|
| configure 向导会同时修改主实例配置 | 小九的配置可能被污染 |
| 工作区在主实例目录下 | 文件混乱 |
| 插件安装经常失败 | npm install 报错，残留文件阻塞 |
| auth-profiles 写入主实例 | 多个 auth profile 导致 401 轮询 |

**真实案例**：龙虾2号首次部署使用 `--profile claude`，遇到：
- SSH 连接中断（configure 向导交互式输入太慢）
- Feishu 插件 npm install 失败
- 插件残留文件阻止重装：`plugin already exists (delete it first)`
- `duplicate plugin id detected` 警告

### 方案 B：`OPENCLAW_HOME` 完全隔离（强烈推荐）

**工作原理**：通过 `HOME` 环境变量让每个实例使用完全独立的目录

```
/root/.openclaw/          ← 小九（主实例）
/root/y1home/.openclaw/   ← 小七（完全隔离）
/root/y2home/.openclaw/   ← 龙虾2号（完全隔离）
```

**优势**：
- 配置、工作区、会话、缓存 100% 隔离
- 不会互相污染
- 每个实例可以独立升级、重启、回滚
- systemd 服务管理清晰

---

## 3. 推荐方案：OPENCLAW_HOME 完全隔离

### 核心原理

OpenClaw 根据 `$HOME` 环境变量定位配置目录：

```
$HOME/.openclaw/openclaw.json    ← 主配置
$HOME/.openclaw/workspace/       ← 工作区（SOUL.md 在这里）
$HOME/.openclaw/agents/          ← 会话数据
```

通过在 systemd 服务中设置不同的 `HOME`，实现完全隔离：

```ini
# 小九服务
Environment=HOME=/root

# 小七服务
Environment=HOME=/root/y1home

# 龙虾2号服务
Environment=HOME=/root/y2home
```

### 目录结构规划

```
/root/
├── .openclaw/                    ← 小九（默认 HOME=/root）
│   ├── openclaw.json
│   └── workspace/SOUL.md
│
├── y1home/
│   └── .openclaw/                ← 小七（HOME=/root/y1home）
│       ├── openclaw.json
│       └── workspace/SOUL.md
│
├── y2home/
│   └── .openclaw/                ← 龙虾2号（HOME=/root/y2home）
│       ├── openclaw.json
│       └── workspace/SOUL.md
│
└── .config/systemd/user/         ← 所有服务文件
    ├── openclaw-gateway.service        ← 小九
    ├── openclaw-gateway-y1.service     ← 小七
    └── openclaw-gateway-y2.service     ← 龙虾2号
```

---

## 4. 完整部署流程（以龙虾2号为例）

### 第一步：创建目录

```bash
mkdir -p /root/y2home/.openclaw/{agents/main/sessions,canvas,workspace}
```

### 第二步：编写 openclaw.json

> 不要用 `openclaw configure` 向导！直接手写配置文件，避免踩坑。

```bash
cat > /root/y2home/.openclaw/openclaw.json << 'EOF'
{
  "meta": {
    "lastTouchedVersion": "2026.2.13"
  },
  "auth": {
    "profiles": {
      "openrouter:default": {
        "provider": "openrouter",
        "mode": "api_key"
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "openrouter/anthropic/claude-sonnet-4.5"
      },
      "models": {
        "openrouter/anthropic/claude-sonnet-4.5": {
          "alias": "Claude Sonnet 4.5"
        }
      },
      "compaction": {
        "mode": "safeguard"
      }
    }
  },
  "models": {
    "providers": {
      "openrouter": {
        "api": "openai-responses",
        "baseUrl": "https://openrouter.ai/api/v1",
        "models": [
          {
            "id": "anthropic/claude-sonnet-4.5",
            "name": "Claude Sonnet 4.5",
            "contextWindow": 200000,
            "maxTokens": 16384
          }
        ]
      }
    }
  },
  "messages": {
    "ackReactionScope": "group-mentions"
  },
  "commands": {
    "native": "auto",
    "nativeSkills": "auto"
  },
  "channels": {
    "feishu": {
      "enabled": true,
      "appId": "你的飞书App ID",
      "appSecret": "你的飞书App Secret",
      "dmPolicy": "open",
      "groupPolicy": "open",
      "streamMode": "partial"
    }
  },
  "gateway": {
    "port": 20789,
    "mode": "local",
    "bind": "loopback",
    "auth": {
      "mode": "token",
      "token": "自己生成一个随机token"
    }
  },
  "plugins": {
    "entries": {
      "feishu": {
        "enabled": true
      }
    }
  }
}
EOF
```

### 第三步：创建 SOUL.md

```bash
cat > /root/y2home/.openclaw/workspace/SOUL.md << 'EOF'
# 龙虾2号

你是龙虾2号，一个基于 Claude Sonnet 4.5 的 AI 助手。

## 基础原则
- 用中文回复
- 简洁、准确、有帮助

## Autonomy — 自主行动原则
- 遇到不确定的事实，主动使用 web_search 搜索验证
- 不要说"我无法联网"——你有搜索工具，用它
EOF
```

### 第四步：创建 systemd 服务

```bash
cat > /root/.config/systemd/user/openclaw-gateway-y2.service << 'EOF'
[Unit]
Description=OpenClaw Gateway - Y2 (龙虾2号)
After=network-online.target
Wants=network-online.target

[Service]
ExecStart="/usr/bin/node" "/usr/lib/node_modules/openclaw/dist/index.js" gateway --port 20789
Restart=always
RestartSec=5
KillMode=process
Environment=HOME=/root/y2home
Environment="PATH=/root/.local/bin:/root/.npm-global/bin:/root/bin:/root/.nvm/current/bin:/root/.fnm/current/bin:/root/.volta/bin:/root/.asdf/shims:/root/.local/share/pnpm:/root/.bun/bin:/usr/local/bin:/usr/bin:/bin"
Environment=OPENCLAW_GATEWAY_PORT=20789
Environment=OPENCLAW_GATEWAY_TOKEN=你的gateway-token
Environment="OPENCLAW_SYSTEMD_UNIT=openclaw-gateway-y2.service"
Environment=OPENCLAW_SERVICE_MARKER=openclaw
Environment=OPENCLAW_SERVICE_KIND=gateway
Environment=OPENCLAW_SERVICE_VERSION=2026.2.13
Environment=ANTHROPIC_API_VERSION=2023-06-01
Environment=OPENROUTER_API_KEY=你的OpenRouter-API-Key
Environment=OPENCLAW_GATEWAY_MODE=proxy

[Install]
WantedBy=default.target
EOF
```

**关键点**：
- `HOME=/root/y2home` — 这是隔离的核心
- `--port 20789` — 每个实例用不同端口
- `OPENROUTER_API_KEY` — API Key 通过环境变量传入，不写在 json 里

### 第五步：启动

```bash
systemctl --user daemon-reload
systemctl --user enable openclaw-gateway-y2
systemctl --user start openclaw-gateway-y2
```

### 第六步：验证

```bash
# 检查状态
systemctl --user is-active openclaw-gateway-y2

# 查看日志
journalctl --user -u openclaw-gateway-y2 --no-pager -n 20

# 检查端口
ss -tlnp | grep 20789
```

---

## 5. OpenRouter 接入指南

### 获取 API Key

1. 注册 https://openrouter.ai
2. Settings → API Keys → Create Key
3. 充值额度（Claude Sonnet 4.5 约 $3/百万 token 输入，$15/百万 token 输出）

### 查询可用模型 ID（重要！）

> 模型 ID 必须精确匹配 OpenRouter 上的 ID，不能用 Anthropic 官方 ID。

```bash
# 查询所有 Claude 模型
curl -s https://openrouter.ai/api/v1/models | python3 -c "
import json, sys
data = json.load(sys.stdin)
for m in data.get('data', []):
    if 'claude' in m['id'].lower():
        print(f\"{m['id']:50s} {m['name']}\")" | sort
```

**2026 年 2 月实测可用模型**：

| OpenRouter 模型 ID | 说明 |
|-------------------|------|
| `anthropic/claude-sonnet-4.5` | Claude Sonnet 4.5（推荐） |
| `anthropic/claude-sonnet-4` | Claude Sonnet 4 |
| `anthropic/claude-3.7-sonnet` | Claude 3.7 Sonnet |
| `anthropic/claude-3.7-sonnet:thinking` | Claude 3.7 Sonnet 思维链 |
| `anthropic/claude-3.5-sonnet` | Claude 3.5 Sonnet |

### 配置三件套

OpenClaw 中使用 OpenRouter 需要配置三个地方：

**① auth.profiles — 认证方式**
```json
"auth": {
  "profiles": {
    "openrouter:default": {
      "provider": "openrouter",
      "mode": "api_key"
    }
  }
}
```

**② agents.defaults.model — 指定默认模型**
```json
"agents": {
  "defaults": {
    "model": {
      "primary": "openrouter/anthropic/claude-sonnet-4.5"
    },
    "models": {
      "openrouter/anthropic/claude-sonnet-4.5": {
        "alias": "Claude Sonnet 4.5"
      }
    }
  }
}
```

模型引用格式：`openrouter/{OpenRouter模型ID}`

**③ models.providers — 告诉 OpenClaw 如何与 OpenRouter 通信（必须！）**
```json
"models": {
  "providers": {
    "openrouter": {
      "api": "openai-responses",
      "baseUrl": "https://openrouter.ai/api/v1",
      "models": [
        {
          "id": "anthropic/claude-sonnet-4.5",
          "name": "Claude Sonnet 4.5",
          "contextWindow": 200000,
          "maxTokens": 16384
        }
      ]
    }
  }
}
```

> **这一步是最容易遗漏的！** 没有 `models.providers` 配置，OpenClaw 内置模型注册表不认识你的模型，会报 `Unknown model` 错误。

**④ API Key — 通过 systemd 环境变量**
```ini
Environment=OPENROUTER_API_KEY=sk-or-v1-你的key
```

---

## 6. 飞书频道配置

### OpenClaw 端配置

```json
"channels": {
  "feishu": {
    "enabled": true,
    "appId": "cli_xxxxx",
    "appSecret": "xxxxx",
    "dmPolicy": "open",
    "groupPolicy": "open",
    "streamMode": "partial"
  }
},
"plugins": {
  "entries": {
    "feishu": {
      "enabled": true
    }
  }
}
```

**说明**：
- `dmPolicy: "open"` — 允许任何人私聊
- `groupPolicy: "open"` — 允许在群里使用
- `streamMode: "partial"` — 流式输出（打字机效果）
- 飞书插件使用系统级安装（`/usr/lib/node_modules/openclaw/extensions/feishu/`），无需每个实例单独安装

### 飞书开放平台配置（必做！）

在 https://open.feishu.cn 你的应用中：

**① 事件与回调 → 订阅方式**
- 选择：**使用长连接接收事件**（不是 Webhook）

**② 事件订阅 → 添加事件**
- `im.message.receive_v1` — 接收消息

**③ 权限管理 → 开通权限**
- `im:message` — 获取与发送消息
- `im:message.receive_v1` — 读取用户发给机器人的消息
- `im:resource` — 获取消息中的资源文件

**④ 版本管理 → 创建版本并发布**
- 不发布版本 = 无法收发消息！

**⑤ 可用性 → 可用范围**
- 设置哪些人可以使用这个机器人

### 飞书接入踩坑要点

| 问题 | 原因 | 解决 |
|------|------|------|
| 机器人不回复 | 未发布版本 | 创建版本并发布 |
| 收不到消息 | 订阅方式选了 Webhook | 改为长连接 |
| 权限不足 | 未开通消息权限 | 开通 im:message 系列 |
| 只有部分人能用 | 可用范围限制 | 检查可用性设置 |

---

## 7. systemd 服务管理

### 端口规划

| 实例 | 端口 | 服务名 |
|------|------|--------|
| 小九 | 18789 | openclaw-gateway |
| 小七 | 18790 | openclaw-gateway-y1 |
| 龙虾2号 | 20789 | openclaw-gateway-y2 |
| 后续... | 20790+ | openclaw-gateway-yN |

### 常用命令

```bash
# 查看所有龙虾状态
for svc in openclaw-gateway openclaw-gateway-y1 openclaw-gateway-y2; do
  echo "$svc: $(systemctl --user is-active $svc)"
done

# 重启某个龙虾
systemctl --user restart openclaw-gateway-y2

# 查看实时日志
journalctl --user -u openclaw-gateway-y2 -f

# 查看端口占用
ss -tlnp | grep -E "18789|18790|20789"
```

### 看门狗（推荐）

已有的看门狗脚本 `/root/openclaw-watchdog.sh`，建议扩展覆盖所有实例：

```bash
#!/bin/bash
for svc in openclaw-gateway openclaw-gateway-y1 openclaw-gateway-y2; do
  if ! systemctl --user is-active --quiet "$svc"; then
    echo "$(date): $svc is down, restarting..."
    systemctl --user restart "$svc"
  fi
done
```

---

## 8. 踩坑全记录

### 踩坑 1：`--profile configure` 污染主实例配置

**现象**：运行 `openclaw --profile claude configure` 后，小九的配置被修改

**根因**：configure 向导的 bug，会同时写入主实例的配置文件和 auth-profiles

**教训**：
- 永远用 OPENCLAW_HOME 方案，不用 `--profile`
- 新实例的配置手写 JSON，不用 configure 向导

### 踩坑 2：Feishu 插件 npm install 失败

**现象**：
```
Failed to install @openclaw/feishu: npm install failed
```
再次尝试：
```
plugin already exists: /root/.openclaw-claude/extensions/feishu (delete it first)
```

**根因**：`--profile` 模式下插件安装到 profile 目录，npm install 网络失败后残留文件

**教训**：
- 用 OPENCLAW_HOME 方案时，直接使用系统级插件（`/usr/lib/node_modules/openclaw/extensions/feishu/`）
- 无需给每个实例单独安装插件

### 踩坑 3：Unknown model 错误

**现象**：
```
Agent failed before reply: Unknown model: openrouter/anthropic/claude-sonnet-4-5-20250929
```

**根因**：
1. OpenClaw 内置模型注册表不包含所有 OpenRouter 模型
2. 需要 `models.providers.openrouter` 配置块来告诉 OpenClaw 如何处理未注册模型
3. `models` 数组是 Zod schema 强制要求的，不能省略

**修复**：添加完整的 `models.providers` 配置（见第5节）

### 踩坑 4：模型 ID 格式不对

**现象**：
```
400 anthropic/claude-sonnet-4-5-20250929 is not a valid model ID
```

**根因**：Anthropic 官方 API 的模型 ID（`claude-sonnet-4-5-20250929`）和 OpenRouter 的模型 ID（`anthropic/claude-sonnet-4.5`）不一样！

**教训**：
- 永远用 `curl https://openrouter.ai/api/v1/models` 查询真实 ID
- OpenRouter 的 ID 更简短，用点分版本号（4.5）而非日期后缀

### 踩坑 5：配置字段名写错导致服务崩溃

**现象**：写了 `tools.web_search` 导致两只龙虾同时崩溃

**根因**：OpenClaw 用 Zod schema 严格校验配置，未定义的字段直接报错退出

**教训**：
- 改配置前先备份：`cp openclaw.json openclaw.json.bak`
- 改完立即检查服务状态：`systemctl --user is-active xxx`
- 正确路径是 `tools.web.search`（不是 `tools.web_search`）

### 踩坑 6：SSH 连接中断丢失配置进度

**现象**：configure 向导运行到一半，SSH 断开

**根因**：交互式命令执行时间长，SSH 空闲超时

**教训**：
- 不要在 SSH 终端跑交互式向导
- 走"本地写脚本 → scp 上传 → bash 执行"路径
- 配置手写 JSON，不依赖 configure 向导

### 踩坑 7：`models.providers` 缺少 `models` 数组

**现象**：
```
Config invalid
models.providers.openrouter.models: Invalid input: expected array, received undefined
```

**根因**：Zod schema 要求 `models` 字段必须是数组

**修复**：即使只有一个模型，也必须写成数组格式

---

## 9. 完整配置参考

### 龙虾2号最终配置（OpenRouter + 飞书）

```json
{
  "meta": {
    "lastTouchedVersion": "2026.2.13"
  },
  "auth": {
    "profiles": {
      "openrouter:default": {
        "provider": "openrouter",
        "mode": "api_key"
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "openrouter/anthropic/claude-sonnet-4.5"
      },
      "models": {
        "openrouter/anthropic/claude-sonnet-4.5": {
          "alias": "Claude Sonnet 4.5"
        }
      },
      "compaction": {
        "mode": "safeguard"
      }
    }
  },
  "models": {
    "providers": {
      "openrouter": {
        "api": "openai-responses",
        "baseUrl": "https://openrouter.ai/api/v1",
        "models": [
          {
            "id": "anthropic/claude-sonnet-4.5",
            "name": "Claude Sonnet 4.5",
            "contextWindow": 200000,
            "maxTokens": 16384
          }
        ]
      }
    }
  },
  "messages": {
    "ackReactionScope": "group-mentions"
  },
  "commands": {
    "native": "auto",
    "nativeSkills": "auto"
  },
  "channels": {
    "feishu": {
      "enabled": true,
      "appId": "cli_xxxxxxxxxx",
      "appSecret": "你的App Secret",
      "dmPolicy": "open",
      "groupPolicy": "open",
      "streamMode": "partial"
    }
  },
  "gateway": {
    "port": 20789,
    "mode": "local",
    "bind": "loopback",
    "auth": {
      "mode": "token",
      "token": "你的gateway-token"
    }
  },
  "plugins": {
    "entries": {
      "feishu": {
        "enabled": true
      }
    }
  }
}
```

### 模型提供商配置模板

**智谱 AI（直连）**：
```json
"auth": {
  "profiles": {
    "zai:default": { "provider": "zai", "mode": "api_key" }
  }
},
"agents": {
  "defaults": {
    "model": { "primary": "zai/glm-4.7" }
  }
}
```
API Key 通过 systemd `Environment=ZAI_API_KEY=xxx` 传入。

**OpenRouter（转发各家模型）**：
```json
"auth": {
  "profiles": {
    "openrouter:default": { "provider": "openrouter", "mode": "api_key" }
  }
},
"agents": {
  "defaults": {
    "model": { "primary": "openrouter/anthropic/claude-sonnet-4.5" }
  }
},
"models": {
  "providers": {
    "openrouter": {
      "api": "openai-responses",
      "baseUrl": "https://openrouter.ai/api/v1",
      "models": [{ "id": "anthropic/claude-sonnet-4.5", "name": "Claude Sonnet 4.5", "contextWindow": 200000, "maxTokens": 16384 }]
    }
  }
}
```
API Key 通过 systemd `Environment=OPENROUTER_API_KEY=xxx` 传入。

---

## 10. 运维速查表

### 一键状态检查

```bash
echo "=== 龙虾军团 ===" && \
for svc in openclaw-gateway openclaw-gateway-y1 openclaw-gateway-y2; do
  echo "  $svc: $(systemctl --user is-active $svc 2>/dev/null || echo 'not found')"
done && \
echo "" && echo "=== 端口 ===" && \
ss -tlnp | grep -E "18789|18790|20789"
```

### 改配置标准流程

```bash
# 1. 备份
cp /root/y2home/.openclaw/openclaw.json /root/y2home/.openclaw/openclaw.json.bak

# 2. 编辑（用 python3 修改 JSON 更安全）
python3 -c "
import json
with open('/root/y2home/.openclaw/openclaw.json') as f:
    c = json.load(f)
# ... 修改 ...
with open('/root/y2home/.openclaw/openclaw.json', 'w') as f:
    json.dump(c, f, indent=2, ensure_ascii=False)
"

# 3. 重启
systemctl --user restart openclaw-gateway-y2

# 4. 验证
sleep 5 && systemctl --user is-active openclaw-gateway-y2

# 5. 如果挂了，回滚
# cp /root/y2home/.openclaw/openclaw.json.bak /root/y2home/.openclaw/openclaw.json
# systemctl --user restart openclaw-gateway-y2
```

### 新增龙虾检查清单

- [ ] 规划端口号（不与现有冲突）
- [ ] 创建独立 HOME 目录（`/root/yNhome/.openclaw/`）
- [ ] 手写 openclaw.json（不用 configure 向导）
- [ ] 如用 OpenRouter：查询真实模型 ID + 配置 `models.providers`
- [ ] 如接飞书：创建飞书应用 + 配置长连接 + 发布版本
- [ ] 创建 SOUL.md
- [ ] 创建 systemd 服务文件
- [ ] 启动并验证日志
- [ ] 更新看门狗脚本覆盖新实例
- [ ] 发消息测试

---

## 附录：配置字段速查

| 配置路径 | 用途 | 注意 |
|---------|------|------|
| `auth.profiles` | 认证提供商 | provider 名必须匹配 |
| `agents.defaults.model.primary` | 默认模型 | 格式：`provider/modelId` |
| `agents.defaults.models` | 模型白名单 | key 必须匹配 primary |
| `models.providers` | 自定义提供商 | models 数组不能省略 |
| `channels.feishu` | 飞书频道 | appId + appSecret |
| `channels.telegram` | Telegram 频道 | botToken |
| `plugins.entries` | 启用插件 | 飞书需要 feishu 插件 |
| `messages.tts` | 语音合成 | 飞书端建议设为 off |
| `tools.web.search` | 联网搜索 | 不是 tools.web_search！ |
| `tools.media.audio` | 语音识别 | 必须显式指定 base 模型 |
| `gateway.port` | 服务端口 | 每个实例不同 |

---

*作者：大王 | 公众号：持续进化营*
*最后更新：2026-02-18*
*基于 OpenClaw 2026.2.13 + DigitalOcean 4GB VPS 实战验证*
