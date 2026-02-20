# OpenClaw + 智谱 GLM 部署教程：从零搭建你的 AI Telegram 管家

> 本教程面向零基础用户，手把手教你在云服务器上部署一个 7×24 小时在线的 AI 助手，通过 Telegram 随时对话。

---

## 一、你将获得什么？

一个运行在云服务器上的 **AI Telegram 机器人**：
- 随时随地通过 Telegram 和 AI 对话
- 使用智谱 GLM 大模型（国产，速度快，中文能力强）
- 7×24 小时不间断运行
- 支持文件处理、代码编写、翻译等多种能力

---

## 二、准备工作（约 30 分钟）

### 2.1 准备一台云服务器（VPS）

**推荐：DigitalOcean**（稳定、操作简单）

1. 访问 [digitalocean.com](https://www.digitalocean.com) 注册账号
2. 创建一个 Droplet（云服务器）：
   - **系统**：Ubuntu 24.04 LTS
   - **配置**：最低 2GB 内存（推荐 4GB）
   - **区域**：新加坡（Singapore）—— 离国内近，速度快
3. 创建完成后，记下服务器的 **IP 地址**（如 `你的服务器IP`）

> 💡 **费用参考**：2GB 内存约 $12/月（约 85 元人民币）

### 2.2 获取智谱 AI 的 API Key

1. 访问 [open.bigmodel.cn](https://open.bigmodel.cn) 注册账号
2. 登录后进入「API Keys」页面
3. 点击「创建 API Key」
4. 复制保存你的 API Key（格式类似 `xxxxxxxx.xxxxxxxxxxxxxxxx`）

> ⚠️ **重要**：API Key 相当于密码，不要分享给别人！

### 2.3 创建 Telegram 机器人

1. 打开 Telegram，搜索 **@BotFather**（官方机器人管理员）
2. 发送 `/newbot`
3. 按提示输入：
   - **机器人名称**：如「超级管家小九」（显示名，随意起）
   - **机器人用户名**：如 `Y9openclawbot`（必须以 `bot` 结尾）
4. 创建成功后，BotFather 会给你一个 **Bot Token**
   - 格式类似 `1234567890:AAFFlBqK2UeCxxxxxxxxx`
   - **复制保存好！**

### 2.4 获取你的 Telegram 用户 ID

1. 在 Telegram 中搜索 **@userinfobot**
2. 发送任意消息
3. 它会回复你的用户 ID（一串数字，如 `1234567890`）
4. **记下这个 ID**，后面配置白名单用

### 2.5 准备 SSH 连接工具

**Mac 用户**：直接用系统自带的「终端」(Terminal)

**Windows 用户**：下载以下任一工具
- [PuTTY](https://www.putty.org)（免费，经典）
- Windows Terminal（Win10/11 自带，推荐）

---

## 三、连接到服务器

打开终端，输入以下命令连接服务器：

```bash
ssh root@你的服务器IP
```

例如：
```bash
ssh root@你的服务器IP
```

首次连接会提示是否信任，输入 `yes`，然后输入密码。

> 💡 **连接不上？** 试试加 `-4` 参数强制使用 IPv4：
> ```bash
> ssh -4 root@你的服务器IP
> ```

看到类似 `root@服务器名:~#` 的提示符，说明连接成功！

---

## 四、安装 OpenClaw（约 5 分钟）

### 4.1 安装 Node.js

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs
```

验证安装：
```bash
node --version
```

应该显示 `v22.x.x`。

### 4.2 安装 OpenClaw

```bash
npm install -g openclaw
```

验证安装：
```bash
openclaw --version
```

应该显示版本号，如 `2026.2.2-3`。

---

## 五、配置 OpenClaw（核心步骤）

运行配置向导：

```bash
openclaw configure
```

向导会逐步引导你完成配置。以下是每一步的操作：

### 5.1 运行位置

```
Where will the Gateway run?
→ Local (this machine)     ← 选这个
```

### 5.2 选择配置项

用**空格键**选中以下项目，然后移到 Continue 回车：

```
Select sections to configure
● Model          ← 选中（设置 AI 模型）
● Channels       ← 选中（设置 Telegram）
● Gateway        ← 选中（设置端口）
○ 其他项目       ← 不用选
● Continue       ← 最后选这个
```

### 5.3 配置 AI 模型

```
Select provider:
→ zai            ← 选择智谱 AI
```

```
Enter API Key:
→ 粘贴你的智谱 API Key
```

```
Select model:
→ glm-4.7        ← 选择 GLM 4.7
```

### 5.4 配置 Telegram

```
Select a channel:
→ Telegram (Bot API)
```

```
Enter Bot Token:
→ 粘贴你从 BotFather 获取的 Token
```

```
Configure DM access policies now?
→ Yes
```

```
DM policy:
→ allowlist      ← 白名单模式（只有你能用）
```

```
Allowed user IDs:
→ 输入你的 Telegram 用户 ID（如 1234567890）
```

### 5.5 配置 Gateway

一般保持默认即可，直接回车。

### 5.6 完成配置

向导结束后会显示配置摘要。确认无误后保存。

---

## 六、设置开机自启（systemd 服务）

让 OpenClaw 在后台持续运行，即使服务器重启也会自动启动：

```bash
openclaw gateway install
```

这条命令会自动创建系统服务并启动。

验证服务状态：

```bash
systemctl --user status openclaw-gateway
```

看到 `Active: active (running)` 说明运行正常！

> 💡 如果需要手动控制服务：
> ```bash
> # 启动
> systemctl --user start openclaw-gateway
> 
> # 停止
> systemctl --user stop openclaw-gateway
> 
> # 重启
> systemctl --user restart openclaw-gateway
> 
> # 查看日志
> journalctl --user -u openclaw-gateway --no-pager -n 20
> ```

---

## 七、测试你的 AI 管家

1. 打开 Telegram
2. 搜索你创建的机器人（如 @Y9openclawbot）
3. 发送一条消息，如「你好」
4. 等待几秒，机器人应该会回复！

### 测试成功的标志

✅ 机器人在几秒内回复了你的消息
✅ 回复内容有意义（不是报错信息）

### 如果没有回复？

依次检查：

1. **服务是否运行？**
   ```bash
   systemctl --user status openclaw-gateway
   ```
   应显示 `active (running)`

2. **查看错误日志**
   ```bash
   journalctl --user -u openclaw-gateway --no-pager -n 20
   ```
   看最后几行有没有 `error` 字样

3. **Bot Token 是否正确？**
   ```bash
   python3 -c "import json; c=json.load(open('/root/.openclaw/openclaw.json')); print(c['channels']['telegram']['botToken'][:15])"
   ```

4. **API Key 是否有效？** 直接测试智谱 API：
   ```bash
   curl -s https://open.bigmodel.cn/api/anthropic/v1/messages \
     -H "x-api-key: 你的API_KEY" \
     -H "anthropic-version: 2023-06-01" \
     -H "content-type: application/json" \
     -d '{"model":"glm-4.7","max_tokens":20,"messages":[{"role":"user","content":"回复OK"}]}'
   ```
   应该返回包含 `"text"` 的 JSON 响应

---

## 八、日常维护

### 8.1 查看运行状态

```bash
systemctl --user status openclaw-gateway
```

### 8.2 查看实时日志

```bash
journalctl --user -u openclaw-gateway -f
```

按 `Ctrl+C` 退出日志查看。

### 8.3 更新 OpenClaw

```bash
openclaw update
```

更新后需要重启：

```bash
systemctl --user restart openclaw-gateway
```

### 8.4 修改配置

```bash
openclaw configure
```

修改后重启生效：

```bash
systemctl --user restart openclaw-gateway
```

---

## 九、费用说明

| 项目 | 费用 | 说明 |
|------|------|------|
| DigitalOcean VPS | ~$12/月 | 2GB 内存最低配置 |
| 智谱 AI API | 按量付费 | GLM-4.7 约 ¥0.05/千 token |
| Telegram | 免费 | 完全免费 |
| OpenClaw | 免费 | 开源软件 |

> 💡 日常轻度使用，智谱 API 月费用通常在 **10-30 元**左右。

---

## 十、常见问题 FAQ

### Q: SSH 连不上服务器？
**A:** 检查 IP 地址是否正确。如果多次密码输错，可能被 fail2ban 封禁，等 10 分钟再试。Mac 用户试试 `ssh -4 root@IP`。

### Q: 机器人不回复消息？
**A:** 按第七章的排查步骤逐一检查。最常见的原因是服务没启动或 Bot Token 配错。

### Q: 如何让多个人使用同一个机器人？
**A:** 在 `openclaw.json` 的 `allowFrom` 数组中添加更多用户 ID：
```json
"allowFrom": ["用户ID1", "用户ID2", "用户ID3"]
```
修改后重启服务生效。

### Q: 服务器重启后机器人不工作了？
**A:** 确保 lingering 已启用：
```bash
loginctl enable-linger root
```
然后重启服务：
```bash
systemctl --user start openclaw-gateway
```

### Q: 如何换一个 AI 模型？
**A:** 运行 `openclaw configure`，在 Model 部分选择新的模型，保存后重启服务。

### Q: 如何查看 API 使用量和费用？
**A:** 登录 [open.bigmodel.cn](https://open.bigmodel.cn)，在控制台查看用量统计。

---

## 附录：关键文件位置

| 文件 | 路径 | 说明 |
|------|------|------|
| 主配置文件 | `/root/.openclaw/openclaw.json` | 所有配置都在这里 |
| 认证信息 | `/root/.openclaw/agents/main/agent/auth-profiles.json` | API Key 存储 |
| systemd 服务 | `/root/.config/systemd/user/openclaw-gateway.service` | 系统服务配置 |
| 运行日志 | `/tmp/openclaw/openclaw-*.log` | 详细日志文件 |

---

## 附录：一键部署脚本（高级用户）

如果你熟悉命令行，可以用以下脚本一键完成安装：

```bash
#!/bin/bash
# OpenClaw + GLM 一键安装脚本
# 使用方法: bash install_openclaw.sh

set -e

echo "=== 安装 Node.js ==="
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

echo "=== 安装 OpenClaw ==="
npm install -g openclaw

echo "=== 启用 lingering ==="
loginctl enable-linger root

echo "=== 安装完成 ==="
echo "请运行 openclaw configure 进行配置"
openclaw --version
```

---

*作者：大王 | 公众号：持续进化营*
*教程最后更新：2026 年 2 月*
*OpenClaw 版本：v2026.2.x*
*如有问题，请访问 [OpenClaw 官方文档](https://docs.openclaw.ai)*
