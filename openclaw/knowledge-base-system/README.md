# 我用 AI 龙虾 + 飞书，搭了一套自动化个人知识库

> 零基础实战：从部署到打通多维表格，一条消息就能沉淀知识

---

## 前言：为什么我要搞这个？

做公众号写 AI 内容，每天刷推特、看公众号、和 Claude 聊天，脑子里冒出的想法、看到的干货、踩过的坑……多到根本记不住。

之前的做法：微信收藏 → 再也不看。备忘录随手记 → 找不到。

我想要的很简单：
- **随手一扔就能存**——不管是一个链接、一段感悟、还是一个工具发现
- **自动帮我整理好**——标题、标签、分类、重点提炼，不用我动手
- **以后找得到、用得上**——写公众号时直接从库里捞素材

最终我用 **OpenClaw（龙虾）+ 飞书多维表格** 搭了这套系统。整个过程大概花了两天时间，从零开始，踩了不少坑。这篇文章把完整的实战过程分享出来。

**适合谁看：** 对 AI 自动化感兴趣、想搭建个人知识管理系统的朋友。不需要编程基础，但需要一点折腾精神。

---

## 一、先看效果：它到底能干啥？

### 日常使用场景

**场景 1：看到一篇好文章**

我在 Telegram 或飞书上给龙虾小七发一个链接：

```
https://mp.weixin.qq.com/s/xxx
这篇关于 MCP 的文章写得不错，核心观点值得记录
```

小七会自动回复：

```
✅ 已捕获：MCP 远程服务器支持的意义
📂 类型：📰 文章摘录 | 来源：公众号
💎 核心洞察：MCP 支持远程部署改变了本地依赖的局限性
🏷️ MCP  开发技巧
📝 素材评级：⭐⭐ 值得加工 | 成熟度：🌿 萌芽
💡 行动项：测试远程配置，可写一篇实操教程
```

然后**自动写入飞书多维表格**，所有字段自动填好。

**场景 2：脑子里冒出一个想法**

```
突然觉得：AI 技术本身不是壁垒，未来一定傻瓜化。
真正的壁垒是把 AI 落地到真实商业场景里。
```

小七识别为「认知升级」，提炼后存入知识库。

**场景 3：写公众号前找素材**

```
帮我整理一下最近关于 MCP 的素材
```

小七从多维表格里检索，按时间排序输出素材清单，标注哪些可以直接用、哪些需要重新加工。

### 最终效果

飞书多维表格里，每条知识都是结构化的：

| 标题 | 内容类型 | 来源 | 素材评级 | 标签 |
|------|---------|------|---------|------|
| MCP 远程服务器的意义 | 📰 文章摘录 | 公众号 | ⭐⭐ 值得加工 | MCP, 开发技巧 |
| 技术不是壁垒 | 🧠 认知升级 | 个人思考 | ⭐⭐⭐ 可直接成文 | 行业趋势 |
| Cursor 0.46 新功能 | 🔗 工具发现 | 推特 | ⭐ 备用素材 | AI工具 |

---

## 二、整体架构：搞清楚有哪些零件

在动手之前，先搞清楚整个系统的组成：

```
你（手机/电脑）
  │
  ├── Telegram / 飞书 发消息
  │
  ▼
龙虾小七（运行在 VPS 上）
  │
  ├── 接收你的消息
  ├── AI 大脑（智谱 GLM）自动分析和提炼
  ├── 调用飞书 API 写入多维表格
  │
  ▼
飞书多维表格（你的知识库）
  │
  ├── AI 资讯库：文章、灵感、工具、认知、方法论
  └── 开发知识库：技术操作、踩坑记录、命令配置
```

### 需要准备的东西

| 序号 | 东西 | 费用 | 说明 |
|-----|------|------|------|
| 1 | DigitalOcean VPS | ~$6/月 | 龙虾运行的服务器 |
| 2 | 飞书账号 | 免费 | 个人版即可 |
| 3 | 智谱 AI API | 免费额度 | 龙虾的 AI 大脑 |
| 4 | Telegram 账号 | 免费 | 可选，消息入口之一 |
| 5 | 一台电脑 | - | 用来配置，Mac/Win 都行 |

总成本：**每月 6 美元**（约 40 多人民币），用智谱免费额度的话前期零成本。

---

## 三、第一步：买一台 VPS

### 为什么需要 VPS？

龙虾需要 24 小时在线，你的电脑不可能一直开着。VPS 就是一台远程服务器，永远在线。

### DigitalOcean 开通步骤

1. 访问 [digitalocean.com](https://www.digitalocean.com)，注册账号
2. 创建 Droplet（就是一台虚拟服务器）：
   - **系统选：Ubuntu 24.04**
   - **配置选最便宜的**：1 vCPU、1GB 内存、$6/月（龙虾很轻量，够用）
   - **地区选新加坡**（离中国近，延迟低）
   - **认证方式：SSH Key**（比密码安全，下面教你生成）

### 生成 SSH Key（如果没有的话）

在你的电脑终端里执行：

```bash
ssh-keygen -t rsa -b 4096
```

一路回车就行。然后复制公钥：

```bash
cat ~/.ssh/id_rsa.pub
```

把输出的内容粘贴到 DigitalOcean 的 SSH Key 设置里。

### 连接 VPS

创建完成后，DigitalOcean 会给你一个 IP 地址（比如 `你的服务器IP`）。

```bash
ssh root@你的IP地址
```

看到命令行提示符就表示连上了。

> **踩坑提醒：** 如果你是 Mac 用户，可能需要加 `-4` 参数强制用 IPv4：
> ```bash
> ssh -4 root@你的IP地址
> ```

---

## 四、第二步：部署龙虾（OpenClaw）

### 安装 Node.js

龙虾基于 Node.js 运行：

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs
```

验证：

```bash
node --version  # 应该显示 v22.x
npm --version   # 应该显示 10.x
```

### 安装 OpenClaw

```bash
npm install -g openclaw
```

验证：

```bash
openclaw --version
```

### 配置龙虾

运行配置向导：

```bash
openclaw configure
```

这个向导会问你几个问题：

1. **AI 模型选择**：选智谱 AI（zai），模型选 `glm-4.7`
2. **API Key**：去 [open.bigmodel.cn](https://open.bigmodel.cn) 注册，创建 API Key
3. **频道配置**：先配 Telegram（后面教飞书）

### 配置 Telegram 机器人

1. 在 Telegram 里搜索 `@BotFather`
2. 发送 `/newbot`，按提示创建机器人
3. 拿到 **Bot Token**（一串类似 `123456:ABC-DEF` 的字符串）
4. 把 Token 填入 OpenClaw 配置

### 启动龙虾

先手动测试能不能跑起来：

```bash
openclaw gateway
```

看到 `listening on ws://127.0.0.1:18789` 就表示成功了。按 `Ctrl+C` 停止。

### 设为开机自启（systemd 服务）

手动启动一关终端就停了，需要做成服务：

```bash
# 创建 systemd 用户服务目录
mkdir -p ~/.config/systemd/user

# 创建服务文件
cat > ~/.config/systemd/user/openclaw-gateway.service << 'EOF'
[Unit]
Description=OpenClaw Gateway
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/openclaw gateway
Restart=always
RestartSec=10
Environment=HOME=/root

[Install]
WantedBy=default.target
EOF

# 启用并启动
systemctl --user daemon-reload
systemctl --user enable openclaw-gateway
systemctl --user start openclaw-gateway

# 确保用户服务在 SSH 断开后继续运行
loginctl enable-linger root
```

验证：

```bash
systemctl --user status openclaw-gateway
```

看到 `active (running)` 就 OK 了。

> **踩坑提醒：** `loginctl enable-linger root` 这一步很关键！没有它，你一关 SSH 终端，龙虾就停了。

---

## 五、第三步：注入灵魂（让龙虾变成知识捕手）

龙虾默认只是一个普通的 AI 聊天助手。要让它变成「知识捕手」，需要编辑它的灵魂文件。

### 灵魂文件在哪？

```bash
ls ~/.openclaw/workspace/
# 你会看到：SOUL.md  IDENTITY.md  USER.md  TOOLS.md 等
```

### 编辑 SOUL.md

这是龙虾的「性格设定」。用 `nano` 编辑器打开：

```bash
nano ~/.openclaw/workspace/SOUL.md
```

把内容替换为你的知识捕手设定。核心要点：

```markdown
## 核心工作流程

### 第一步：识别输入类型
- 📰 文章摘录（带链接或转述外部文章）
- 💡 灵感闪现（纯文字短句/脑暴）
- 🔗 工具发现（新工具/平台/服务）
- 🧠 认知升级（认知变化）
- 📝 方法论（做法/流程）
- 🗣️ 对话精华（AI 对话中的有价值结论）

### 第二步：结构化提炼
自动生成：标题、核心洞察、行动项、标签、素材评级

### 第三步：回复确认后写入飞书多维表格
```

> **关键设计：知识提炼三层法**
>
> 收到外部内容时，龙虾不是简单搬运，而是三层提炼：
> - **L1 事实层**：提取技术干货（方法/工具/数据）
> - **L2 洞察层**：用自己的话重述核心价值
> - **L3 行动层**：和你的实际场景怎么结合
>
> 这样每条知识入库时就自带「原创度标签」，以后写文章时一目了然。

---

## 六、第四步：接入飞书

这是整个系统中最关键也最容易踩坑的一步。

### 6.1 创建飞书应用

1. 打开 [飞书开放平台](https://open.feishu.cn)
2. 创建一个企业自建应用（个人版飞书也可以）
3. 填写应用名称（比如「我的知识库助手」）
4. 记下 **App ID** 和 **App Secret**

### 6.2 配置应用权限

在应用管理后台 → 权限管理，添加以下权限：

| 权限 | 说明 |
|------|------|
| `im:message` | 接收和发送消息 |
| `im:message:send_as_bot` | 以机器人身份发消息 |
| `bitable:app` | 读写多维表格 |
| `contact:contact.base:readonly` | 读取通讯录基础信息 |

### 6.3 配置事件订阅

**这一步很多人会卡住！**

1. 进入「事件与回调」设置
2. **订阅方式必须选「长连接」**（不是 Webhook！）
3. 添加事件：`im.message.receive_v1`（接收消息事件）

> **踩坑提醒：** 选错了订阅方式整个就不通。OpenClaw 使用 WebSocket 长连接，不支持 Webhook 回调。

### 6.4 发布应用

1. 进入「版本管理与发布」
2. 创建一个版本
3. 提交发布（自建应用秒过，不需要审核）

> **踩坑提醒：** 不发布版本，权限不生效！很多人配了半天发现不工作，就是忘了这一步。

### 6.5 在 OpenClaw 中配置飞书

编辑龙虾的配置文件：

```bash
nano ~/.openclaw/openclaw.json
```

在 `channels` 部分添加飞书配置：

```json
{
  "channels": {
    "feishu": {
      "enabled": true,
      "appId": "你的App ID",
      "appSecret": "你的App Secret",
      "dmPolicy": "open",
      "groupPolicy": "open",
      "streamMode": "partial"
    }
  },
  "plugins": {
    "entries": {
      "feishu": { "enabled": true }
    }
  }
}
```

重启龙虾：

```bash
systemctl --user restart openclaw-gateway
```

### 6.6 验证飞书连接

查看日志：

```bash
journalctl --user -u openclaw-gateway --since "5 min ago" --no-pager
```

看到这些就表示连接成功：

```
[feishu] feishu[default]: bot open_id resolved: ou_xxxxx
[feishu] feishu[default]: WebSocket client started
[ws] ws client ready
```

现在在飞书里找到你的机器人，发一条消息试试！

> **踩坑提醒：** 如果机器人不回复，检查：
> 1. `dmPolicy` 和 `groupPolicy` 是否设为 `"open"`
> 2. 应用是否已发布版本
> 3. 事件订阅是否选了「长连接」

---

## 七、第五步：创建飞书多维表格

### 7.1 创建表格

1. 在飞书中新建一个多维表格
2. 命名为「AI 资讯库」

### 7.2 添加字段

多维表格默认只有一个「文本」字段，你需要手动添加这些字段：

| 字段名 | 类型 | 说明 |
|--------|------|------|
| 标题 | 文本 | 知识条目的标题 |
| 内容类型 | 单选 | 📰 文章摘录 / 💡 灵感闪现 / 🔗 工具发现 / 🧠 认知升级 / 📝 方法论 / 🗣️ 对话精华 |
| 来源平台 | 单选 | 公众号 / 推特 / Reddit / 个人思考 / AI对话 / 其他 |
| 原文链接 | 超链接 | 原始文章的 URL |
| 原始输入 | 文本 | 你发给龙虾的原始内容 |
| 核心洞察 | 文本 | AI 提炼的核心观点 |
| 我的思考 | 文本 | 你的个人批注 |
| 行动项 | 文本 | 下一步行动 |
| 标签 | 多选 | AI工具 / MCP / Claude / 自动化 / 内容创作 / 开发技巧 等 |
| 关联技术栈 | 多选 | Claude Code / OpenClaw / 飞书 等 |
| 公众号素材评级 | 单选 | ⭐ 备用素材 / ⭐⭐ 值得加工 / ⭐⭐⭐ 可直接成文 |
| 内容成熟度 | 单选 | 🌱 种子 / 🌿 萌芽 / 🌳 成熟 |
| 已用于创作 | 复选框 | 标记是否已用于文章 |
| 日期 | 日期 | 捕获时间 |

> **省事方法：** 也可以用飞书 API 批量创建字段，我写了一个脚本可以一键搞定（文末附链接）。

### 7.3 授权应用访问表格

**这一步很容易忘！**

1. 打开你刚创建的多维表格
2. 点击右上角「分享」
3. 搜索你的应用名称（如「我的知识库助手」）
4. 设为「可编辑」权限

> **踩坑提醒：** 飞书的权限分两层：
> - **应用级权限**（开发者后台配置）= 全局的 API 能力
> - **文档级权限**（分享设置）= 具体表格的访问权限
>
> 两层都要配！只配了应用权限没分享表格，会报 403 错误。

### 7.4 获取表格的关键参数

打开多维表格，看浏览器地址栏：

```
https://xxx.feishu.cn/base/xxxxxxxxxxxxxxxx?table=tblxxxxxxxxxxxxxxxx
```

- `xxxxxxxxxxxxxxxx` → 这是 **app_token**
- `tblxxxxxxxxxxxxxxxx` → 这是 **table_id**

把这两个值记下来，后面要用。

---

## 八、第六步：让龙虾写入多维表格

### 8.1 OpenClaw 内置的飞书工具

好消息：OpenClaw 自带 `feishu_bitable` 插件，启动时会自动注册 6 个多维表格操作工具。不需要额外安装。

你需要做的是在龙虾的 TOOLS.md 里告诉它表格信息：

```bash
nano ~/.openclaw/workspace/TOOLS.md
```

添加：

```markdown
## 多维表格
- app_token: 你的app_token
- table_id: 你的table_id

写入时必须填写以下全部字段：
标题、内容类型、来源平台、原始输入、核心洞察、
我的思考、行动项、标签、关联技术栈、
公众号素材评级、内容成熟度、已用于创作、日期
```

### 8.2 在 SOUL.md 中添加写入指令

在龙虾的灵魂文件中明确告诉它**怎么写、写什么**：

```markdown
## 写入规范

使用 feishu_bitable 工具创建记录，必须填写以下全部字段：

内容类型用单选值：📰 文章摘录 / 💡 灵感闪现 / 🔗 工具发现 / 🧠 认知升级 / 📝 方法论 / 🗣️ 对话精华
来源平台用单选值：公众号 / 推特 / Reddit / 个人思考 / AI对话 / 其他
标签用多选数组：["AI工具", "MCP", "Claude"] 等
日期用毫秒时间戳
超链接字段格式：{"link": "url", "text": "[来源·作者] 主题描述"}
```

### 8.3 重启并测试

```bash
systemctl --user restart openclaw-gateway
```

然后在飞书上发一条消息给龙虾，看它是否能正确提炼并写入多维表格。

---

## 九、进阶：每日自动沉淀

除了实时捕获，还可以设置一个 cron 定时任务，每天自动整理当天的对话记录并沉淀到飞书。

### 原理

```
每天 23:00 (北京时间)
  → 读取龙虾当天的对话记录
  → 用 AI 自动整理和分类
  → 写入飞书多维表格
```

### 创建沉淀脚本

创建 `/root/feishu_daily_digest.sh`，核心逻辑：

1. 获取飞书 Token
2. 从龙虾的 session 文件中提取当日对话
3. 调用智谱 AI 分析对话，提取有价值内容
4. 通过飞书 API 批量写入多维表格

### 设置 cron 定时任务

```bash
crontab -e
```

添加一行（UTC 15:00 = 北京时间 23:00）：

```
0 15 * * * /bin/bash /root/feishu_daily_digest.sh >> /tmp/openclaw/digest-cron.log 2>&1
```

---

## 十、实际使用效果和感受

跑了这套系统之后，我的使用习惯变成了：

### 日常

1. 刷到好文章 → 链接扔给小七 → 自动入库
2. 脑子冒出想法 → 语音发给小七 → 自动提炼入库
3. 和 Claude Code 开发完 → `/feishu-push` → 开发经验自动入库

### 写公众号时

1. 打开飞书多维表格
2. 按标签筛选、按素材评级排序
3. ⭐⭐⭐ 的内容直接可以扩展成文章
4. 每条记录都有「核心洞察」和「行动项」，不用重新回忆

### 最大的改变

**知识不再是一次性的了。**

以前看一篇文章，当时觉得「好有道理」，过两天就忘了。现在每条信息都经过提炼、结构化、存入数据库，变成了可以反复调用的「数字资产」。

---

## 踩坑清单（血泪总结）

把我踩过的坑统一列出来，希望你能少走弯路：

| 坑 | 现象 | 解决方案 |
|---|------|---------|
| 飞书事件订阅选错模式 | 龙虾收不到消息 | 必须选「长连接」，不是 Webhook |
| 应用没发布版本 | 权限不生效，403 | 创建版本并发布 |
| 多维表格没授权应用 | 写入 403 Forbidden | 表格分享→添加应用→可编辑 |
| SSH 断开后龙虾停了 | 服务消失 | `loginctl enable-linger root` |
| IPv6 连接 VPS 失败 | SSH 超时 | 加 `-4` 参数强制 IPv4 |
| dmPolicy 设为 allowlist | 龙虾不回消息 | 改为 `"open"` 或添加你的 ID |
| 飞书 sheets vs bitable | API 不通 | sheets = 电子表格，bitable = 多维表格，API 完全不同 |
| 字段名不匹配 | 写入失败或字段为空 | 单选值必须与预设选项完全一致 |

---

## 成本和资源

| 项目 | 费用 | 备注 |
|------|------|------|
| DigitalOcean VPS | $6/月 | 最低配就够 |
| 智谱 AI API | 免费起步 | 有免费额度，够用很久 |
| 飞书 | 免费 | 个人版足够 |
| Telegram | 免费 | 可选 |
| **总计** | **~$6/月** | **约 40 元人民币** |

---

## 写在最后

我是一个做了 12 年外贸的人，2025 年才第一次接触 AI 编程。搭这套系统的过程中，我最深的体会是：

**AI 技术本身不是壁垒，傻瓜化部署是早晚的事。真正的壁垒是——你能不能让 AI 融入到真实的工作和生活场景里，解决实际问题。**

这套知识管理系统不复杂，技术含量也不算高。但它实实在在解决了我「信息焦虑」的问题——看到的好东西不再随风消散，而是变成了可以反复调用的数字资产。

如果你也有类似的需求，不妨动手试试。有问题欢迎在评论区交流。

---

*作者：KING | AI Coding Native Builder*
*公众号：[你的公众号名称]*

---

> **附：本文用到的关键资源**
>
> - OpenClaw 官网：openclaw.com
> - 飞书开放平台：open.feishu.cn
> - 智谱 AI：open.bigmodel.cn
> - DigitalOcean：digitalocean.com
> - 文中提到的脚本和配置文件，关注公众号回复「龙虾知识库」获取
