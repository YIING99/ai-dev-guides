# OpenClaw 斜杠命令完整清单

> 适用版本：OpenClaw v2026.2.x | 适用渠道：Telegram / 飞书 / Discord / Slack

## 日常高频（必记 5 个）

| 命令 | 作用 | 示例 |
|------|------|------|
| `/new` | 新建会话，清空上下文 | `/new` |
| `/compact` | 压缩上下文，保留关键信息 | `/compact` 或 `/compact 保留API配置` |
| `/stop` | 停止当前正在生成的回复 | `/stop` |
| `/status` | 查看状态（模型/token/会话） | `/status` |
| `/help` | 显示可用命令列表 | `/help` |

## 模型与回复控制

| 命令 | 别名 | 作用 | 参数 |
|------|------|------|------|
| `/model` | - | 查看/切换当前模型 | `/model` 查看 · `/model provider/name` 切换 |
| `/models` | - | 列出可用模型 | `/models` 列出提供商 · `/models zai` 看具体模型 |
| `/think` | `/thinking` `/t` | 设置思考深度 | `off` / `low` / `medium` / `high` / `xhigh` |
| `/verbose` | `/v` | 切换详细输出 | `on` / `off` |
| `/reasoning` | `/reason` | 切换推理可见性 | `on` / `off` / `stream` |
| `/usage` | - | 用量与费用显示 | `off` / `tokens` / `full` / `cost` |

## 会话管理

| 命令 | 作用 | 说明 |
|------|------|------|
| `/new` | 新建会话 | 旧记录归档保留，不会丢失历史 |
| `/reset` | 重置会话 | 与 `/new` 效果相同 |
| `/compact` | 压缩上下文 | 可带参数：`/compact 保留搜索配置相关内容` |
| `/context` | 查看上下文构成 | `/context list` 查看 token 占用详情 |
| `/stop` | 停止当前生成 | 回复太长或方向不对时使用 |

## 身份与信息

| 命令 | 别名 | 作用 |
|------|------|------|
| `/whoami` | `/id` | 查看发送者 ID 和身份 |
| `/commands` | - | 列出当前可用的所有命令 |
| `/help` | - | 显示帮助信息 |

## 语音控制（TTS）

| 命令 | 作用 |
|------|------|
| `/tts on` | 开启语音回复 |
| `/tts off` | 关闭语音回复 |
| `/tts status` | 查看 TTS 当前状态 |
| `/tts audio 要朗读的文字` | 将指定文字转为语音 |
| `/tts provider edge` | 切换引擎（`edge` / `openai` / `elevenlabs`） |
| `/tts help` | 查看完整用法 |

## 群组专用

| 命令 | 作用 |
|------|------|
| `/activation mention` | 设为 @机器人 才回复 |
| `/activation always` | 所有消息都回复 |
| `/send on` / `off` | 开启/关闭群组发送 |
| `/allowlist add/remove` | 管理群组白名单 |

## 子代理管理

| 命令 | 作用 |
|------|------|
| `/subagents list` | 列出活跃子代理 |
| `/subagents stop [id]` | 停止指定子代理 |
| `/subagents log [id]` | 查看子代理日志 |
| `/subagents info [id]` | 查看子代理详情 |

## 高级管理（默认禁用）

以下命令需在 `openclaw.json` 中显式开启：

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
| `/config unset path` | 清除配置项 | 高 |
| `/debug show` | 查看调试状态 | 中 |
| `/debug set path value` | 设置调试覆盖值 | 高 |
| `/bash 命令` | 在服务器执行 shell 命令 | **极高** |
| `/restart` | 重启 OpenClaw | 高 |

## 注意事项

1. **飞书用户**：所有命令必须带 `/` 前缀。如遇命令无响应，参考 [飞书斜杠命令修复教程](../feishu-slash-fix/)
2. **Telegram 用户**：命令会显示在输入框的菜单中，点击即可
3. `/config`、`/debug`、`/bash` 默认禁用，需在配置中显式开启
4. `/bash` 命令可在服务器上执行任意 shell 命令，**请谨慎开启**

---

*基于 OpenClaw v2026.2.13 源码整理 | 公众号：持续进化营 | [返回目录](../../)*
