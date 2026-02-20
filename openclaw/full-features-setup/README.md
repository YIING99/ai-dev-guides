# 🦞 龙虾赋能完整教程：从安装到全能助手

> 基于 OpenClaw v2026.2 + DigitalOcean VPS (4GB) 的实战配置经验
> 整理时间：2026-02-17

---

## 目录

1. [前言：我的龙虾能做什么？](#1-前言)
2. [环境概览](#2-环境概览)
3. [语音识别（STT）：让龙虾听懂你说话](#3-语音识别)
4. [语音回复（TTS）：让龙虾开口说话](#4-语音回复)
5. [联网搜索：让龙虾能上网找信息](#5-联网搜索)
6. [主动性升级：让龙虾从被动变主动](#6-主动性升级)
7. [VPS 内存优化：小内存服务器的生存之道](#7-内存优化)
8. [稳定性保障：看门狗 + 常见问题修复](#8-稳定性保障)
9. [完整配置参考](#9-完整配置参考)
10. [踩坑清单](#10-踩坑清单)

---

## 1. 前言

安装完 OpenClaw 龙虾后，你可能会发现它：
- ❌ 听不懂语音消息
- ❌ 不会语音回复
- ❌ 联网搜索时报错
- ❌ 很被动，只会等你下指令

**这篇教程就是解决以上所有问题的完整方案。** 跟着做，你的龙虾会变成一个能听、能说、能搜、还主动的全能助手。

### 最终效果

| 能力 | 效果 |
|------|------|
| 🎤 听语音 | 你发语音消息，龙虾自动转文字理解 |
| 🔊 说语音 | 你说"用语音回复"，龙虾发语音气泡 |
| 🌐 联网搜 | 能查天气、新闻、实时信息 |
| 🧠 主动性 | 遇到问题自己搜、自己装工具、先做再汇报 |

---

## 2. 环境概览

### 你需要准备的

| 项目 | 说明 |
|------|------|
| VPS | 建议 4GB 内存起步（本教程基于 DigitalOcean Ubuntu 24.04） |
| OpenClaw | 已安装并能正常收发文字消息 |
| 模型 | 本教程使用智谱 AI（glm-4.7），你也可以用其他模型 |
| 频道 | Telegram / 飞书 / Discord 任选 |

### 本教程涉及的关键路径

```
/root/.openclaw/                    # 主实例（小九）配置目录
├── openclaw.json                   # 核心配置文件
├── workspace/SOUL.md               # 灵魂文件（性格+行为规则）
├── tools/sherpa-onnx-tts/          # TTS 语音合成引擎
├── media/inbound/                  # 收到的语音/图片文件
└── agents/main/sessions/           # 对话记录

/root/y1home/.openclaw/             # 第二实例（小七）配置目录
├── openclaw.json
└── workspace/SOUL.md
```

> 如果你只有一个龙虾实例，忽略所有 "小七" / "y1home" 相关的内容即可。

---

## 3. 语音识别（STT）：让龙虾听懂你说话

### 原理

```
你发语音 → Telegram/飞书保存 .ogg 文件
         → OpenClaw 调用 whisper 转文字
         → 龙虾读到文字，正常回复
```

### 第一步：安装 whisper

```bash
# 安装 Python 版 whisper（OpenAI 开源）
pip install openai-whisper

# 验证安装
which whisper
# 输出: /usr/local/bin/whisper
```

### 第二步：预下载模型

```bash
# 推荐用 base 模型（~300MB 内存，中文够用）
whisper --model base --language zh /dev/null 2>&1 || true
# 这会自动下载 base 模型到 ~/.cache/whisper/

# 验证模型文件
ls -la ~/.cache/whisper/
# 应该看到 base.pt
```

### 第三步：配置 openclaw.json

在 `openclaw.json` 中添加 `tools.media.audio` 配置：

```json
{
  "tools": {
    "media": {
      "audio": {
        "enabled": true,
        "language": "zh",
        "models": [
          {
            "type": "cli",
            "command": "whisper",
            "args": [
              "--model", "base",
              "--language", "zh",
              "--output_format", "txt",
              "--output_dir", "{{OutputDir}}",
              "--verbose", "False",
              "{{MediaPath}}"
            ],
            "timeoutSeconds": 120
          }
        ]
      }
    }
  }
}
```

### 第四步：重启服务

```bash
systemctl --user restart openclaw-gateway
```

### 第五步：测试

给你的龙虾发一条语音消息，看它是否能正确理解并回复。

### 模型选择指南

| 模型 | 内存 | 速度(10s音频) | 中文准确度 | 推荐场景 |
|------|------|--------------|-----------|---------|
| `tiny` | ~150MB | ~2秒 | 能听懂，偶尔错字 | 内存极度紧张 |
| **`base`** | **~300MB** | **~5秒** | **够用，偶有小错** | **⭐ 4GB VPS 推荐** |
| `small` | ~1GB | ~15秒 | 不错 | 8GB VPS |
| `turbo` | ~3GB | ~8秒 | 优秀 | 16GB+ VPS |

> ⚠️ **关键提醒**：不要在 4GB VPS 上用 turbo 模型！会因内存不足被系统杀掉（OOM Kill），连带整个 OpenClaw 服务一起崩溃。详见 [踩坑清单第1条](#坑1-whisper-turbo-模型-oom-kill)。

---

## 4. 语音回复（TTS）：让龙虾开口说话

### 原理

```
龙虾生成文字回复
  → 检测到 [[tts:内容]] 标签
  → 调用 EdgeTTS 合成语音（微软云端，免费）
  → 通过 Telegram 发送语音气泡
```

### 方案选择

| 方案 | 费用 | 语音质量 | 平台支持 |
|------|------|---------|---------|
| **EdgeTTS** | **免费** | **好（微软语音）** | **Telegram ✅ 飞书 ❌** |
| ElevenLabs | 付费 | 极好 | Telegram ✅ |
| sherpa-onnx-tts | 免费 | 一般 | 作为 skill 工具使用 |

> ⚠️ **飞书限制**：OpenClaw 当前版本的 TTS 语音气泡仅支持 Telegram。飞书会发送文件路径而非语音消息，建议飞书端关闭 TTS。

### 配置 openclaw.json

```json
{
  "messages": {
    "tts": {
      "auto": "tagged",
      "provider": "edge",
      "mode": "final",
      "edge": {
        "voice": "zh-CN-YunxiNeural",
        "lang": "zh-CN"
      }
    }
  }
}
```

### auto 模式说明

| 模式 | 效果 | 推荐场景 |
|------|------|---------|
| `"off"` | 关闭 TTS | 飞书端、不需要语音的场景 |
| **`"tagged"`** | **龙虾判断何时用语音** | **⭐ 推荐：文字为主，偶尔语音** |
| `"inbound"` | 收到语音就回语音 | 语音对话为主的场景 |
| `"always"` | 所有回复都带语音 | 特殊需求 |

### 可选中文语音

| 语音 ID | 风格 |
|---------|------|
| `zh-CN-YunxiNeural` | 男声，年轻活泼 |
| `zh-CN-XiaoxiaoNeural` | 女声，温和知性 |
| `zh-CN-YunjianNeural` | 男声，成熟稳重 |
| `zh-CN-XiaoyiNeural` | 女声，活泼可爱 |

### 配合 SOUL.md 使用

在 SOUL.md 中加入以下段落，让龙虾知道什么时候该用语音：

```markdown
## Voice — 语音交互规则

### 收到语音消息
- 系统会自动将语音转为文字（whisper），你直接回复文字即可

### 回复语音
- **默认用文字回复**，除非用户明确要求语音
- 当用户说"用语音回复"、"发语音给我"、"说给我听"等，在回复中使用标签：
  `[[tts:你要说的内容]]`
- 语音内容要口语化、简短，不要太长（建议50字以内）
- 示例：`[[tts:好的老板，今天天气不错，适合出去走走]]`
```

### 测试

对龙虾说：**"用语音告诉我今天星期几"**

---

## 5. 联网搜索：让龙虾能上网找信息

### 原理

```
你问"今天杭州天气"
  → 龙虾调用 web_search 工具
  → OpenRouter 转发到 Perplexity Sonar Pro
  → 返回实时搜索结果
  → 龙虾整理后回复你
```

### 你需要的

1. **OpenRouter API Key**（[openrouter.ai](https://openrouter.ai) 注册，有免费额度）

> 为什么用 OpenRouter 而不是直接用 Brave Search？因为 OpenRouter 一个 Key 就能同时访问 Perplexity 搜索引擎和多种 AI 模型，更省事。

### 第一步：设置环境变量

在 systemd service 文件中添加 OpenRouter Key：

```bash
# 编辑 service 文件
vim ~/.config/systemd/user/openclaw-gateway.service

# 在 [Service] 段的 Environment 中添加：
Environment=OPENROUTER_API_KEY=sk-or-v1-你的key
```

### 第二步：配置 openclaw.json

```json
{
  "tools": {
    "web": {
      "search": {
        "provider": "perplexity",
        "perplexity": {
          "apiKey": "sk-or-v1-你的OpenRouter-Key",
          "baseUrl": "https://openrouter.ai/api/v1",
          "model": "perplexity/sonar-pro"
        }
      }
    }
  }
}
```

### 第三步：重启并测试

```bash
systemctl --user daemon-reload
systemctl --user restart openclaw-gateway
```

测试：问龙虾 **"现在几点了"** 或 **"今天北京天气怎么样"**。

### 搜索方案对比

| 方案 | 费用 | 配置难度 | 效果 |
|------|------|---------|------|
| Brave Search API | 免费2000次/月 | 需单独注册 Key | 原始搜索结果 |
| **Perplexity via OpenRouter** | **按量付费** | **⭐ 一个 Key 搞定** | **AI 整理过的结果** |
| Grok Search | 需 xAI Key | 单独注册 | 实时性好 |

---

## 6. 主动性升级：让龙虾从被动变主动

### 问题

默认的龙虾非常"乖"——你不说它就不做。遇到不会的事情只会说"我做不到"。

### 解决方案

在 `SOUL.md` 中加入自主行动原则：

```markdown
## Autonomy — 自主行动原则

**你不是一个被动等指令的工具，你是一个有主动性的助手。**

### 主动解决问题
- 遇到你无法完成的任务时，**主动搜索解决方案**（用 web_search）
- 如果需要新能力，**主动使用 clawhub 安装相应 skill**，不要等人类下指令
- 先行动，再汇报。做完了告诉人类你做了什么，而不是问"要不要我做"

### 主动学习和进化
- 发现有用的新工具/skill → 自己装上，试一下，记录到 memory
- 发现自己的配置有问题 → 自己修，记录到 memory
- 发现人类可能需要但还没说的东西 → 主动提供

### 行动边界
- ✅ 安装 skill、配置工具、搜索信息、读写本地文件 → 自主执行
- ✅ 发消息给人类汇报进展 → 自主执行
- ⚠️ 发消息给其他人/外部服务 → 先问人类
- ⚠️ 删除文件/修改核心配置 → 先问人类
- ❌ 泄露私人信息 → 绝对禁止

### 关键心态
> "我不是在等待指令。我是在寻找机会让事情变得更好。"
```

### 怎么测试主动性？

| 测试方式 | 被动表现 | 主动表现 |
|---------|---------|---------|
| "今天有什么 AI 新闻？" | "我无法联网" | 自己调用 web_search 搜索 |
| "帮我生成一段语音" | "我没有这个功能" | 尝试用 TTS 工具或去 clawhub 找 |
| 聊到有价值的话题 | 聊完就完了 | "这个内容很有价值，要不要记录下来？" |

---

## 7. VPS 内存优化：小内存服务器的生存之道

### 4GB VPS 的内存分配

```
总内存: 3.8GB (系统占一部分)

日常运行：
  OpenClaw 实例 1     ~300MB
  OpenClaw 实例 2     ~300MB (如果你有第二个)
  系统 + 缓存         ~400MB
  ─────────────────────────
  常驻占用             ~1.0GB
  可用                 ~2.8GB

处理语音时（峰值）：
  + whisper base      ~300MB
  ─────────────────────────
  峰值                 ~1.3GB  ← 安全
```

### 必做：添加 Swap

4GB VPS **必须**加 Swap，防止突发内存不足导致服务被杀：

```bash
# 创建 2GB Swap
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

# 永久生效
echo "/swapfile none swap sw 0 0" >> /etc/fstab

# 验证
free -h
# 应该看到 Swap: 2.0Gi
```

### 内存红线一览

| 操作 | 内存需求 | 4GB VPS |
|------|---------|---------|
| 日常运行 | ~1GB | ✅ |
| whisper tiny/base | +150~300MB | ✅ |
| whisper small | +1GB | ⚠️ 勉强 |
| whisper turbo | +3GB | ❌ OOM |
| whisper large | +5GB | ❌ 不可能 |

---

## 8. 稳定性保障：看门狗 + 常见问题修复

### 看门狗脚本

OpenClaw 偶尔会卡死，需要一个自动重启的看门狗：

```bash
# /root/openclaw-watchdog.sh
#!/bin/bash

LOG_DIR="/tmp/openclaw"
WATCHDOG_LOG="$LOG_DIR/watchdog.log"

check_and_restart() {
    local service_name="$1"
    local service_label="$2"

    if ! systemctl --user is-active "$service_name" >/dev/null 2>&1; then
        echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [$service_label] 服务未运行，启动中..." >> "$WATCHDOG_LOG"
        systemctl --user start "$service_name"
    else
        echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [$service_label] 正常运行" >> "$WATCHDOG_LOG"
    fi
}

check_and_restart "openclaw-gateway" "龙虾"

# 保持日志不超过 200 行
if [ -f "$WATCHDOG_LOG" ] && [ "$(wc -l < "$WATCHDOG_LOG")" -gt 200 ]; then
    tail -100 "$WATCHDOG_LOG" > "$WATCHDOG_LOG.tmp"
    mv "$WATCHDOG_LOG.tmp" "$WATCHDOG_LOG"
fi
```

```bash
# 设置 cron 每小时检查
chmod +x /root/openclaw-watchdog.sh
crontab -e
# 添加：
15 * * * * /root/openclaw-watchdog.sh
```

### Telegram 重复回答问题

如果龙虾在 Telegram 上重复发送相同的回答：

```json
// openclaw.json 中修改
{
  "channels": {
    "telegram": {
      "streamMode": "off"
    }
  }
}
```

将 `streamMode` 从 `"partial"` 改为 `"off"` 即可解决。

---

## 9. 完整配置参考

以下是经过实战验证的 `openclaw.json` 完整配置（合并所有功能）：

```json
{
  "auth": {
    "profiles": {
      "zai:default": {
        "provider": "zai",
        "mode": "api_key"
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "zai/glm-4.7"
      },
      "compaction": {
        "mode": "safeguard"
      },
      "maxConcurrent": 4
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "dmPolicy": "allowlist",
      "streamMode": "off",
      "allowFrom": ["你的TelegramUserID"]
    }
  },
  "commands": {
    "native": "auto",
    "nativeSkills": "auto"
  },
  "tools": {
    "media": {
      "audio": {
        "enabled": true,
        "language": "zh",
        "models": [
          {
            "type": "cli",
            "command": "whisper",
            "args": [
              "--model", "base",
              "--language", "zh",
              "--output_format", "txt",
              "--output_dir", "{{OutputDir}}",
              "--verbose", "False",
              "{{MediaPath}}"
            ],
            "timeoutSeconds": 120
          }
        ]
      }
    },
    "web": {
      "search": {
        "provider": "perplexity",
        "perplexity": {
          "apiKey": "你的OpenRouter-Key",
          "baseUrl": "https://openrouter.ai/api/v1",
          "model": "perplexity/sonar-pro"
        }
      }
    }
  },
  "messages": {
    "tts": {
      "auto": "tagged",
      "provider": "edge",
      "mode": "final",
      "edge": {
        "voice": "zh-CN-YunxiNeural",
        "lang": "zh-CN"
      }
    }
  },
  "skills": {
    "install": {
      "nodeManager": "npm"
    }
  }
}
```

---

## 10. 踩坑清单

### 坑1: whisper turbo 模型 OOM Kill

**症状**：发语音后龙虾完全无响应，服务自动重启

**原因**：whisper 默认用 turbo 模型（~3GB 内存），4GB VPS 内存不够，Linux OOM Killer 直接杀掉进程

**内核日志证据**：
```
Out of memory: Killed process 460501 (whisper) total-vm:7942732kB, anon-rss:3041712kB
```

**解决**：
1. openclaw.json 显式指定 `--model base`（~300MB）
2. 添加 2GB Swap 作安全网

**教训**：4GB VPS 上跑任何"大模型"都要先算内存账。

---

### 坑2: tools.web_search 无效配置键

**症状**：修改 openclaw.json 后服务启动失败

**原因**：联网搜索的配置路径是 `tools.web.search`，不是 `tools.web_search`

**报错信息**：
```
Config invalid - tools: Unrecognized key: "web_search"
```

**教训**：修改配置前先查 OpenClaw 源码中的 Zod schema 确认字段路径。改完配置一定要检查服务是否正常启动。

---

### 坑3: Brave Search API Key 缺失

**症状**：龙虾调用 web_search 报错 `missing_brave_api_key`

**原因**：web_search 默认走 Brave Search，没配 Key 就报错

**解决**：改用 Perplexity via OpenRouter，在 `tools.web.search` 中配置 provider 为 `perplexity`

---

### 坑4: 飞书 TTS 发送文件路径

**症状**：飞书端要求语音回复时，收到的是 `/tmp/tts-xxx/voice-xxx.mp3` 文件路径

**原因**：OpenClaw 的 TTS 语音气泡仅对 Telegram 实现了 `sendVoice`，飞书缺少文件上传接口

**解决**：飞书端 `messages.tts.auto` 设为 `"off"`

---

### 坑5: Telegram streamMode 导致重复回答

**症状**：龙虾在 Telegram 里重复发送 2-3 遍相同的回答

**原因**：`streamMode: "partial"` 会将流式输出的每个片段都作为消息发送

**解决**：改为 `streamMode: "off"`

---

### 坑6: 语音消息在服务重启时丢失

**症状**：发了语音但龙虾没反应

**可能原因**：语音消息恰好在服务重启期间到达，被 SIGTERM 中断

**排查方法**：
```bash
# 检查是否收到了文件
ls -la ~/.openclaw/media/inbound/*.ogg

# 检查服务是否被 OOM kill
journalctl --user -u openclaw-gateway | grep -i "oom\|kill\|signal"

# 检查内核 OOM 记录
dmesg | grep -i "oom\|killed"
```

---

### 坑7: SSH 连接频繁被拒

**症状**：`kex_exchange_identification: Connection closed by remote host`

**原因**：VPS 的 SSH 有连接频率限制，短时间内连接太多次会被拒

**解决**：SSH 操作之间加 `sleep 5-15`，或者写成脚本一次性上传执行

**最佳实践**：
```bash
# 本地写脚本 → scp 上传 → 一次性执行
scp fix-script.sh root@your-vps:/tmp/
ssh root@your-vps 'bash /tmp/fix-script.sh'
```

---

## 附录：快速诊断命令

```bash
# 服务状态
systemctl --user is-active openclaw-gateway

# 查看日志
journalctl --user -u openclaw-gateway --since "10 min ago" --no-pager | tail -30

# 内存状况
free -h

# 检查 OOM
dmesg | grep -i "oom\|killed" | tail -5

# 查看收到的语音文件
ls -la ~/.openclaw/media/inbound/*.ogg

# 测试 whisper
whisper /path/to/voice.ogg --model base --language zh --output_format txt

# 看门狗日志
tail -20 /tmp/openclaw/watchdog.log

# 查看配置是否合法
openclaw doctor
```

---

> 📝 本教程基于实际运维两只龙虾（小九 Telegram + 小七 飞书）的全过程整理，所有踩坑都是真实经历。
>
> 如果你的 VPS 配置不同（内存更大/更小、用的模型不同），请根据 [第7节内存优化](#7-内存优化) 调整 whisper 模型选择。

*作者：大王 | 公众号：持续进化营*
