# OpenClaw 龙虾接入飞书：傻瓜式完整教程

> 本教程基于实战经验编写，包含所有踩过的坑。适用于已在 VPS 上运行 OpenClaw + Telegram 的用户，新增飞书频道。

---

## 一、你将实现什么？

在不影响现有 Telegram 机器人的情况下，让同一个 OpenClaw 龙虾同时接入飞书：

```
                    ┌── Telegram（已有，不动）
VPS 龙虾 (OpenClaw) ┤
                    └── 飞书（新增）
同一个大脑，多个嘴巴。对话记忆、AI 模型全部共享。
```

---

## 二、前置条件

| 条件 | 说明 |
|------|------|
| VPS 上已运行 OpenClaw | 版本 ≥ 2026.2.2 |
| 已有 Telegram 频道正常工作 | 确认小七/小九能正常聊天 |
| 飞书账号 | 需要有创建应用权限（企业管理员或个人版） |

---

## 三、飞书开放平台配置（最重要！约 15 分钟）

### 3.1 创建自建应用

1. 打开浏览器，访问 **飞书开放平台**：https://open.feishu.cn
2. 登录你的飞书账号
3. 点击右上角 **「创建应用」**
4. 选择 **「企业自建应用」**
5. 填写应用信息：
   - 应用名称：如「我的知识库助手」
   - 应用描述：随便写
   - 应用图标：随便选
6. 点击 **「创建」**

### 3.2 记录凭证（后面要用）

创建完成后，进入应用详情页：

1. 点击左侧菜单 **「凭证与基础信息」**
2. 找到并记录：
   - **App ID**（格式：`cli_xxxxxxxxxx`）
   - **App Secret**（一串字母数字）

> ⚠️ App Secret 相当于密码，不要泄露！

### 3.3 开启机器人能力

1. 左侧菜单 → **「添加应用能力」**
2. 找到 **「机器人」** → 点击 **「添加」**
3. 机器人名称保持默认即可

### 3.4 配置事件订阅（关键步骤！）

> ⚠️ **这一步不做，机器人就收不到消息！** 这是最常见的坑。

1. 左侧菜单 → **「事件与回调」**
2. 在「订阅方式」区域：
   - 选择 **「使用长连接接收事件」**（不是 Webhook！）
   - 这很重要：长连接模式不需要公网域名

3. 点击 **「添加事件」**，搜索并添加以下事件：

| 事件名 | Event Key | 说明 |
|--------|-----------|------|
| 接收消息 | `im.message.receive_v1` | **必须！** 机器人收到消息时触发 |

4. 点击 **「保存」**

### 3.5 配置权限

1. 左侧菜单 → **「权限管理」**
2. 搜索并开启以下权限：

| 权限名称 | 权限 Key | 说明 |
|---------|----------|------|
| 获取与发送单聊、群组消息 | `im:message` | **必须** |
| 以应用的身份发消息 | `im:message:send_as_bot` | **必须** |
| 获取群组信息 | `im:chat:readonly` | 群聊需要 |
| 读取用户信息 | `contact:user.base:readonly` | 识别用户 |

3. 点击每个权限后面的 **「开通」** 按钮

### 3.6 发布应用

> ⚠️ **不发布 = 应用不生效！**

1. 左侧菜单 → **「版本管理与发布」**
2. 点击 **「创建版本」**
3. 填写版本号（如 1.0.0）和更新说明
4. 点击 **「发布」**
5. 如果是企业应用，需要管理员审批通过

### 3.7 测试机器人可用性

1. 打开飞书客户端
2. 搜索你创建的机器人名称（如「我的知识库助手」）
3. 应该能找到并打开对话窗口
4. 先不用发消息（VPS 还没配好）

---

## 四、VPS 配置（约 5 分钟）

### 4.1 了解你的目录结构

如果你有多个龙虾实例，先确认要给哪个加飞书：

```bash
# 查看所有 OpenClaw 配置文件
find /root -maxdepth 4 -name 'openclaw.json' 2>/dev/null

# 查看运行中的服务
systemctl --user list-units 'openclaw*'
```

常见结构：
```
小九 → /root/.openclaw/openclaw.json        (主实例)
小七 → /root/y1home/.openclaw/openclaw.json  (第二实例)
```

> ⚠️ **确认要改哪个配置文件，不要改错！**

### 4.2 备份配置

```bash
# 假设要给小七加飞书（改成你自己的路径）
CONFIG="/root/y1home/.openclaw/openclaw.json"
cp "$CONFIG" "${CONFIG}.before-feishu"
echo "已备份"
```

### 4.3 添加飞书频道配置

```bash
python3 << 'PYEOF'
import json

# ⚠️ 改成你自己的配置文件路径
CONFIG_FILE = '/root/y1home/.openclaw/openclaw.json'

# ⚠️ 改成你自己的 App ID 和 App Secret
FEISHU_APP_ID = 'cli_xxxxxxxxxx'
FEISHU_APP_SECRET = 'xxxxxxxxxxxxxxxx'

c = json.load(open(CONFIG_FILE))

# 添加飞书频道
c['channels']['feishu'] = {
    'enabled': True,
    'appId': FEISHU_APP_ID,
    'appSecret': FEISHU_APP_SECRET,
    'dmPolicy': 'open',        # 私聊开放
    'groupPolicy': 'open',     # 群聊开放
    'streamMode': 'partial'    # 流式回复
}

# 添加飞书插件
c.setdefault('plugins', {}).setdefault('entries', {})['feishu'] = {
    'enabled': True
}

json.dump(c, open(CONFIG_FILE, 'w'), indent=2, ensure_ascii=False)
print('飞书频道配置完成！')
PYEOF
```

### 4.4 重启服务

```bash
# 查看你的服务名
systemctl --user list-units 'openclaw*'

# 只重启要改的那个（不要重启其他实例！）
# 小七的服务名示例：
systemctl --user restart openclaw-gateway-y1

# 小九的服务名示例（如果改的是小九）：
# systemctl --user restart openclaw-gateway
```

### 4.5 验证启动

```bash
# 查看最近日志
journalctl --user -u openclaw-gateway-y1 --no-pager -n 15
```

**成功标志（必须看到这 3 行）**：

```
[feishu] [default] starting Feishu provider (你的应用名)
Feishu WebSocket connection established
[ws] ws client ready
```

如果看到这 3 行，VPS 端就配好了。

---

## 五、测试

1. 打开飞书
2. 找到机器人「我的知识库助手」
3. **先试私聊**：直接给机器人发「你好」
4. **再试群聊**：把机器人拉进群，@机器人 发消息

---

## 六、踩坑记录（重要！）

### 坑 1：白名单为空导致无响应

**症状**：飞书连接正常，但发消息没反应
**原因**：`dmPolicy: "allowlist"` 但 `allowFrom: []`（白名单为空）
**解决**：

```json
// ❌ 错误 - 白名单模式但没有添加任何人
"dmPolicy": "allowlist",
"allowFrom": []

// ✅ 正确方案 1 - 开放模式
"dmPolicy": "open"

// ✅ 正确方案 2 - 白名单模式 + 添加飞书用户 ID
"dmPolicy": "allowlist",
"allowFrom": ["ou_xxxxxxxxxx"]
```

> 飞书用户 ID 格式是 `ou_xxxxx`，和 Telegram 的纯数字 ID 不同！不能复用。

### 坑 2：飞书开放平台没有配置事件订阅

**症状**：VPS 日志一切正常，但收不到任何消息
**原因**：飞书开放平台没有：
1. 订阅 `im.message.receive_v1` 事件
2. 或者没选择「长连接」订阅方式
**解决**：回到飞书开放平台 → 事件与回调 → 检查配置

### 坑 3：应用未发布

**症状**：搜不到机器人 / 发消息无响应
**原因**：应用创建了但没有发布版本
**解决**：飞书开放平台 → 版本管理 → 创建版本 → 发布

### 坑 4：群聊策略也是白名单

**症状**：私聊可以但群里@没反应
**原因**：`groupPolicy` 也设成了 `allowlist`
**解决**：改为 `"groupPolicy": "open"`

### 坑 5：改错了另一个龙虾的配置

**症状**：改了配置但目标龙虾行为没变 / 另一个龙虾出问题了
**原因**：多实例场景下改错了配置文件
**预防**：
```bash
# 改之前永远先确认路径！
echo "要改的是: $CONFIG"
cat "$CONFIG" | python3 -c "import json,sys; c=json.load(sys.stdin); print('Telegram bot:', c['channels']['telegram']['botToken'][:15])"
```

---

## 七、日常运维

### 查看飞书连接状态

```bash
journalctl --user -u openclaw-gateway-y1 --no-pager -n 20 | grep feishu
```

### 查看详细日志

```bash
grep feishu /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log | tail -20
```

### 重启服务

```bash
systemctl --user restart openclaw-gateway-y1
```

### 查看当前飞书配置

```bash
python3 -c "
import json
c = json.load(open('/root/y1home/.openclaw/openclaw.json'))
print(json.dumps(c['channels']['feishu'], indent=2, ensure_ascii=False))
"
```

---

## 八、配置参数速查表

| 参数 | 可选值 | 说明 |
|------|--------|------|
| `enabled` | `true` / `false` | 是否启用飞书频道 |
| `appId` | `cli_xxx` | 飞书应用 ID |
| `appSecret` | 字符串 | 飞书应用密钥 |
| `dmPolicy` | `open` / `allowlist` | 私聊策略 |
| `groupPolicy` | `open` / `allowlist` | 群聊策略 |
| `allowFrom` | `["ou_xxx"]` | 白名单用户列表（仅 allowlist 模式） |
| `streamMode` | `partial` / `none` | 是否流式回复（飞书卡片更新） |

---

## 九、完整配置文件示例

```json
{
  "channels": {
    "telegram": {
      "enabled": true,
      "dmPolicy": "allowlist",
      "botToken": "你的Telegram Bot Token",
      "groupPolicy": "allowlist",
      "streamMode": "partial",
      "allowFrom": ["你的Telegram用户ID"]
    },
    "feishu": {
      "enabled": true,
      "appId": "cli_xxxxxxxxxx",
      "appSecret": "你的App Secret",
      "dmPolicy": "open",
      "groupPolicy": "open",
      "streamMode": "partial"
    }
  },
  "plugins": {
    "entries": {
      "telegram": { "enabled": true },
      "feishu": { "enabled": true }
    }
  }
}
```

---

## 十、关键文件位置

| 文件 | 路径 | 说明 |
|------|------|------|
| 主实例配置 | `/root/.openclaw/openclaw.json` | 小九的配置 |
| 第二实例配置 | `/root/y1home/.openclaw/openclaw.json` | 小七的配置 |
| 主实例服务 | `openclaw-gateway.service` | 小九的 systemd 服务 |
| 第二实例服务 | `openclaw-gateway-y1.service` | 小七的 systemd 服务 |
| 运行日志 | `/tmp/openclaw/openclaw-YYYY-MM-DD.log` | 当日日志 |
| 备份配置 | `openclaw.json.before-feishu` | 加飞书前的备份 |

---

*教程编写：2026 年 2 月 15 日*
*基于 OpenClaw v2026.2.2-3 + 飞书开放平台实战经验*
*包含所有实际踩过的坑和解决方案*
