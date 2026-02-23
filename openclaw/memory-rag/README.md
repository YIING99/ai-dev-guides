# 给 OpenClaw 龙虾装上长期记忆：Memory RAG 配置指南

> **作者**：KingMaker
> **日期**：2026-02-23
> **适用版本**：OpenClaw Gateway v2026.2.x
> **难度**：零编程基础可操作（跟着复制粘贴即可）
> **预计耗时**：30-60 分钟

---

## 这篇教程解决什么问题？

你的 OpenClaw 龙虾是不是这样？

- 你发给它一篇 2000 字的文章，它当场分析得头头是道
- 过了两天你问"之前那篇关于 XX 的文章呢"——**它完全不记得**
- 你每天和它聊天，但它的"长期记忆"里永远只有 daily 心跳日志
- 你配了飞书多维表格，知识写进去了，但龙虾**搜不出来**

**根本原因**：OpenClaw 默认不开启语义搜索。你的龙虾有嘴（能说）有手（能写飞书），但没有脑子里的"知识检索系统"。

**这篇教程教你**：用 30 分钟给龙虾装上一套 Memory RAG 系统——用自然语言就能从历史知识中精准召回内容。

---

## 最终效果

配置完成后，你的龙虾可以：

```
你："之前有没有讲过美国手机号的？"
龙虾：找到了！Tello eSIM，5美元月租美国手机号……（精准召回）

你："帮我找一下关于 AI 幻觉的记录"
龙虾：找到了！信任链污染定律——描述≠现实……（精准召回）
```

搜索引擎：向量语义匹配（70%）+ 关键词精确匹配（30%），中文优化。

---

## 前置条件

在开始之前，确认你有以下准备：

| 条件 | 说明 | 没有的话 |
|------|------|---------|
| **一只 OpenClaw 龙虾** | 已经能正常对话的 OpenClaw Gateway 实例 | 先装 OpenClaw |
| **VPS 或服务器** | 龙虾运行的机器，能 SSH 登录 | 可以用 DigitalOcean $6/月 |
| **Embedding API Key** | 用于将文本转为向量（本教程用智谱 ZAI） | 下面第一步会教你申请 |
| **知识内容** | 你想让龙虾记住的知识（文章、笔记、经验……） | 至少准备 5-10 条 |

**可选但推荐**：
- 飞书多维表格（结构化存储 + 可视化管理）
- 飞书应用（用于 API 同步）

---

## 第一步：申请 Embedding API Key

Embedding 模型是 Memory RAG 的核心——它把文本转化为"数字指纹"（向量），让计算机能理解语义相似度。

### 推荐：智谱 ZAI embedding-3

**为什么选它**：
- 中文语义理解优秀（比通用多语言模型好很多）
- 2048 维向量（信息密度高）
- 兼容 OpenAI 接口协议（OpenClaw 原生支持）
- 成本低（按量付费）

**申请步骤**：

1. 打开 [智谱 AI 开放平台](https://open.bigmodel.cn/)
2. 注册账号并登录
3. 进入「控制台」→「API Keys」→ 创建一个新的 API Key
4. **重要**：进入「资源包」页面，确认 embedding 有可用额度
   - 注意：GLM Coding Pro 套餐**不包含** embedding 用量，需要单独订阅

**记下你的 API Key**，后面要用。格式类似：`xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.xxxxxxxxxxxxxxxx`

### 备选方案

| 模型 | 优点 | 缺点 | 适合场景 |
|------|------|------|---------|
| **ZAI embedding-3（推荐）** | 中文好，2048维 | 需付费 | 中文为主的知识库 |
| OpenAI text-embedding-3-small | 多语言，生态好 | 需翻墙，贵 | 英文为主 |
| Gemini embedding-001 | 免费额度 | 日限额容易打满 | 测试用 |
| 本地 embeddinggemma | 免费离线 | 中文差，占内存 | 不推荐 |

---

## 第二步：配置 memorySearch

SSH 登录你的 VPS，编辑 OpenClaw 配置文件。

### 2.1 找到你的 openclaw.json

```bash
# 如果你只有一个龙虾实例
cat ~/.openclaw/openclaw.json

# 如果你有多个实例，找到对应实例的配置
# 例如第二只龙虾的配置可能在 /root/bot2-home/.openclaw/openclaw.json
cat /root/bot2-home/.openclaw/openclaw.json
```

### 2.2 添加 memorySearch 配置

在 `openclaw.json` 的 `agents.defaults` 中添加 `memorySearch` 块。

**如果你用 ZAI embedding-3**：

```json
{
  "agents": {
    "defaults": {
      "memorySearch": {
        "provider": "openai",
        "model": "embedding-3",
        "remote": {
          "baseUrl": "https://open.bigmodel.cn/api/paas/v4/",
          "apiKey": "你的ZAI-API-Key填这里"
        },
        "query": {
          "hybrid": {
            "enabled": true,
            "vectorWeight": 0.7,
            "textWeight": 0.3,
            "candidateMultiplier": 4
          }
        },
        "cache": {
          "enabled": true,
          "maxEntries": 10000
        }
      }
    }
  }
}
```

**如果你用 OpenAI embedding**：

```json
{
  "agents": {
    "defaults": {
      "memorySearch": {
        "provider": "openai",
        "model": "text-embedding-3-small",
        "remote": {
          "apiKey": "你的OpenAI-API-Key填这里"
        },
        "query": {
          "hybrid": {
            "enabled": true,
            "vectorWeight": 0.7,
            "textWeight": 0.3,
            "candidateMultiplier": 4
          }
        },
        "cache": {
          "enabled": true,
          "maxEntries": 10000
        }
      }
    }
  }
}
```

**关键参数解释**（小白必读）：

| 参数 | 含义 | 建议值 | 为什么 |
|------|------|--------|--------|
| `provider` | 接口协议 | `"openai"` | ZAI 兼容 OpenAI 协议，所以写 openai |
| `model` | Embedding 模型名 | `"embedding-3"` | ZAI 的模型名 |
| `remote.baseUrl` | API 地址 | 智谱的 URL | 不填则默认 OpenAI 官方 |
| `vectorWeight` | 语义搜索权重 | `0.7` | 70% 靠语义理解 |
| `textWeight` | 关键词搜索权重 | `0.3` | 30% 靠精确匹配 |
| `candidateMultiplier` | 候选扩展倍数 | `4` | 搜 4 倍候选再排序，提高精度 |

### 2.3 验证配置

```bash
# 检查 JSON 格式是否正确（不报错就是 OK）
python3 -c "import json; json.load(open('openclaw.json'))"
```

---

## 第三步：准备知识文件

这是**最关键的一步**——你要告诉龙虾"记住什么"。

### 3.1 知识文件存放位置

```bash
# 进入你的龙虾 workspace 的 memory 目录
# 路径格式：{你的openclaw配置目录}/workspace/memory/
ls ~/.openclaw/workspace/memory/

# 多实例用户示例
ls /root/bot2-home/.openclaw/workspace/memory/
```

如果 `memory/` 目录不存在，创建它：

```bash
mkdir -p ~/.openclaw/workspace/memory/
```

### 3.2 知识文件格式

**每条知识 = 一个独立的 .md 文件。** 这是本方案的核心原则。

文件模板（复制后修改内容）：

```markdown
## [2026-02-20] 这里写标题（15字以内）
- **类型**：📰 文章摘录 | **来源**：公众号 | **评级**：⭐⭐ 值得加工
- **标签**：标签1, 标签2, 标签3

**核心洞察**：用 2-5 句话总结这条知识的核心内容。
不需要写原文全文，写你自己的理解和提炼。
包含关键数据、关键结论、关键方法。

**关键论点**：
- 论点1：具体的事实或观点
- 论点2：具体的事实或观点

**行动项**：基于这条知识，下一步可以做什么

**搜索关键词**：同义词1, 同义词2, 英文缩写, 口语化表达, 场景词
```

### 3.3 文件命名

- **有飞书记录**：用飞书记录 ID 命名，如 `recvbmdEE6JDXb.md`
- **无飞书**：用有意义的短名，如 `tello-esim.md`、`n26-bank.md`
- **避免**：中文文件名、空格、特殊字符

### 3.4 实际案例

以一篇关于 Tello eSIM 的知识为例：

**文件名**：`tello-esim.md`

```markdown
## [2026-02-16] Tello eSIM：5美元月租美国手机号
- **类型**：🔗 工具发现 | **来源**：公众号 | **评级**：⭐⭐ 值得加工
- **标签**：海外工具, 开发技巧, eSIM, 支付工具

**核心洞察**：Tello 是基于 T-Mobile 网络的虚拟运营商（MVNO），
提供真实美国手机号码（非VoIP虚拟号），支持 eSIM 线上购买，
月租5美元起。通过 WiFi Calling 技术在国内可用，
能接收银行/券商验证码、注册 AI 服务。

**关键论点**：
- 三大优势：实体运营商号码、eSIM线上购买、WiFi Calling
- 对比：Google Voice 免费但易封号、Ultra Mobile 需实体卡

**行动项**：试用 Tello eSIM，写"必备海外工具"系列文章

**搜索关键词**：Tello, eSIM, 美国手机号, 虚拟号码, 海外号码,
T-Mobile, WiFi Calling, 接收验证码, 注册AI服务, 月租5美元
```

### 3.5 搜索关键词怎么写？

搜索关键词**不是给人看的，是给搜索引擎看的**。写的时候想：

> "如果用户用什么词来搜索，应该能找到这条知识？"

包含三类词：
1. **核心概念**：Tello, eSIM, T-Mobile
2. **中文同义词**：美国手机号, 虚拟号码, 海外号码
3. **使用场景**：接收验证码, 注册AI服务, 月租5美元

### 3.6 为什么一条知识 = 一个文件？

这是本方案最重要的设计决策。对比：

```
❌ 错误做法：10 条知识合并在 1 个大文件里
   → 搜索引擎按固定长度切分（chunk），一个 chunk 可能包含
     A 记录的后半段 + B 记录的前半段
   → 搜索"Tello eSIM"命中的 chunk，开头却是 GLM-5 的内容
   → 精度暴跌

✅ 正确做法：10 条知识 = 10 个独立文件
   → 每个文件刚好一个 chunk
   → 搜索命中 = 完整的一条知识
   → 精度最高
```

实测数据：拆分文件后，搜索精度提升 23%（Tello 从 0.632 → 0.777）。

---

## 第四步：构建向量索引

知识文件准备好后，需要"向量化"——让搜索引擎理解每条知识的语义。

### 4.1 构建索引

```bash
# ⚠️ 多实例用户必须先设 HOME！
# 如果你只有一个龙虾，跳过这行
export HOME=/root/bot2-home   # 改成你的龙虾配置目录的父目录

# 进入 OpenClaw 目录
cd ~/.openclaw   # 或你的实例目录，如 /root/bot2-home/.openclaw

# 构建索引（--force 表示强制重建）
npx openclaw memory index --force
```

**成功标志**：
```
Memory index updated (main).
```

**常见报错和解决方案**：

| 报错 | 原因 | 解决 |
|------|------|------|
| `No API key found for provider openai` | HOME 没设对，读了别的实例配置 | `export HOME=` 设为正确路径 |
| `ECONNREFUSED` | API 地址不通 | 检查 `remote.baseUrl` 是否正确 |
| `401 Unauthorized` | API Key 无效 | 检查 Key 是否正确、是否有 embedding 额度 |
| 无任何输出 | memory/ 目录为空 | 先创建知识文件 |

### 4.2 测试搜索

```bash
# 测试一下！
npx openclaw memory search '你的搜索词'

# 示例
npx openclaw memory search '美国手机号'
npx openclaw memory search 'AI幻觉防治'
```

**理想结果**：
```
0.777 memory/tello-esim.md:1-16
## [2026-02-16] Tello eSIM：5美元月租美国手机号
...
```

格式说明：`分数 文件路径:行范围`
- 分数越高越相关（1.0 = 完美匹配）
- 0.3 以上通常就是有效结果

---

## 第五步：管理 Daily 日志（防止噪音污染）

OpenClaw 会自动在 memory/ 目录生成 daily 心跳日志（`2026-02-23.md`），内容大量是"✅ 正常，无异常"。

**这些日志会严重干扰搜索精度**——90% 是噪音，被向量化后挤占真正知识的排名。

### 5.1 创建归档脚本

```bash
# 在你的龙虾 HOME 目录下创建脚本
cat > ~/move-daily-logs.sh << 'EOF'
#!/bin/bash
# 将 daily 日志从 memory 目录移到 archive，防止污染搜索索引
# 注意：只移走昨天及更早的文件，不碰今天的（龙虾正在写）

MEMORY_DIR=$HOME/.openclaw/workspace/memory
ARCHIVE_DIR=$HOME/.openclaw/workspace/daily-archive
TODAY=$(date +%Y-%m-%d)

mkdir -p "$ARCHIVE_DIR"

for f in "$MEMORY_DIR"/20[0-9][0-9]-[0-9][0-9]-[0-9][0-9].md; do
    [ -f "$f" ] || continue
    FILENAME=$(basename "$f" .md)
    # 跳过今天的文件（龙虾正在写）
    [ "$FILENAME" = "$TODAY" ] && continue
    mv "$f" "$ARCHIVE_DIR/" 2>/dev/null
done
EOF

chmod +x ~/move-daily-logs.sh
```

### 5.2 设置自动定时任务

```bash
# 添加 cron：每天早上 6 点归档一次（daily 日志按天生成，一天一次足够）
(crontab -l 2>/dev/null; echo '# 每天归档 daily 日志（防止污染搜索索引）'; echo '0 6 * * * $HOME/move-daily-logs.sh') | crontab -

# 验证
crontab -l | grep move-daily
```

### 5.3 手动执行一次

```bash
# 先跑一次，把已有的 daily 文件归档
~/move-daily-logs.sh

# 检查结果
echo "=== memory 目录（应该只有知识文件 + 今天的 daily）==="
ls ~/.openclaw/workspace/memory/

echo "=== archive 目录（归档的 daily 文件）==="
ls ~/.openclaw/workspace/daily-archive/
```

---

## 第六步：设置双写机制（可选但强烈推荐）

如果你的龙虾会自动捕获知识到飞书多维表格，那需要确保**飞书写了 → memory/ 也有**。

### 6.1 方案 A：SOUL.md 双写规则

在你的龙虾 SOUL.md 中追加以下内容：

```markdown
### 🔴 双写规则：知识必须同时写入 memory 搜索索引

**每次成功写入飞书多维表格后，必须同时在 memory/ 目录
创建对应的知识文件。** 这是确保语义搜索能找到这条知识的
关键步骤，不可省略。

#### 触发条件
- 每次通过 feishu_bitable 成功创建记录后

#### 文件命名
- 使用飞书返回的记录 ID：`memory/{record_id}.md`

#### 文件格式
按如下模板填写：

## [日期] 标题
- **类型**：内容类型 | **来源**：来源平台 | **评级**：评级
- **标签**：标签列表
- **飞书记录**：record_id

**核心洞察**：提炼的核心内容

**个人思考**：个人思考

**行动项**：下一步行动

**搜索关键词**：同义词, 场景词, 英文缩写（5-10个）

#### 执行方式
使用 exec 工具写入文件。

#### 自检
写入后确认文件存在：ls -la memory/{record_id}.md
```

### 6.2 方案 B：Cron 自动同步脚本

如果你有飞书多维表格，可以设置定时脚本从飞书拉取新记录。

**创建同步脚本**（完整版）：

```bash
cat > ~/sync_feishu_to_memory.py << 'PYEOF'
#!/usr/bin/env python3
"""飞书 AI资讯库 → memory/ 目录同步脚本"""
import json, os, sys, urllib.request
from datetime import datetime

# ========== 修改以下配置 ==========
FEISHU_APP_ID = "你的飞书应用ID"
FEISHU_APP_SECRET = "你的飞书应用密钥"
BITABLE_APP_TOKEN = "你的多维表格app_token"
TABLE_ID = "你的表格table_id"
MEMORY_DIR = os.path.expanduser("~/.openclaw/workspace/memory")
# ==================================

def get_token():
    url = "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal"
    data = json.dumps({"app_id": FEISHU_APP_ID, "app_secret": FEISHU_APP_SECRET}).encode()
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=15) as r:
        result = json.loads(r.read())
    return result["tenant_access_token"]

def get_records(token, page_token=None):
    url = f"https://open.feishu.cn/open-apis/bitable/v1/apps/{BITABLE_APP_TOKEN}/tables/{TABLE_ID}/records?page_size=100"
    if page_token: url += f"&page_token={page_token}"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())

def get_text(val):
    if val is None: return ""
    if isinstance(val, str): return val
    if isinstance(val, list): return ", ".join(str(v) for v in val)
    if isinstance(val, dict): return val.get("text", val.get("link", str(val)))
    return str(val)

def format_date(ts):
    if not ts: return datetime.now().strftime("%Y-%m-%d")
    try: return datetime.fromtimestamp(int(ts)/1000).strftime("%Y-%m-%d")
    except: return datetime.now().strftime("%Y-%m-%d")

def to_md(rid, f):
    title = get_text(f.get("标题", "无标题"))
    ctype = get_text(f.get("内容类型", ""))
    src = get_text(f.get("来源平台", ""))
    rating = get_text(f.get("公众号素材评级", ""))
    tags = get_text(f.get("标签", ""))
    insight = get_text(f.get("核心洞察", ""))
    think = get_text(f.get("我的思考", ""))
    action = get_text(f.get("行动项", ""))
    date = format_date(f.get("日期"))
    kw = ", ".join(set([title] + ([str(t) for t in f.get("标签",[])] if isinstance(f.get("标签"), list) else [])))

    lines = [f"## [{date}] {title}",
             f"- **类型**：{ctype} | **来源**：{src} | **评级**：{rating}",
             f"- **标签**：{tags}", f"- **飞书记录**：{rid}", ""]
    if insight: lines += [f"**核心洞察**：{insight}", ""]
    if think: lines += [f"**个人思考**：{think}", ""]
    if action: lines += [f"**行动项**：{action}", ""]
    if kw: lines += [f"**搜索关键词**：{kw}", ""]
    return "\n".join(lines)

def main():
    print(f"[{datetime.now():%Y-%m-%d %H:%M}] 同步开始...")
    existing = {f[:-3] for f in os.listdir(MEMORY_DIR) if f.startswith("rec") and f.endswith(".md")}
    print(f"  已有 {len(existing)} 个文件")

    token = get_token()
    records, pt = [], None
    while True:
        r = get_records(token, pt)
        records += r.get("data",{}).get("items",[])
        if not r["data"].get("has_more"): break
        pt = r["data"].get("page_token")
    print(f"  飞书共 {len(records)} 条记录")

    n = 0
    for item in records:
        rid = item.get("record_id","")
        if not rid or rid in existing: continue
        with open(os.path.join(MEMORY_DIR, f"{rid}.md"), "w") as f:
            f.write(to_md(rid, item.get("fields",{})))
        n += 1
        print(f"  + {rid} - {get_text(item.get('fields',{}).get('标题',''))}")

    if n > 0:
        print(f"  新增 {n} 个文件，重建索引...")
        os.system(f"cd {os.path.dirname(MEMORY_DIR)}/../ && npx openclaw memory index --force 2>&1 | tail -3")
    else:
        print("  无新增")
    print("同步完成")

if __name__ == "__main__":
    main()
PYEOF

chmod +x ~/sync_feishu_to_memory.py
```

**设置定时运行**：

```bash
# 每6小时同步一次
(crontab -l 2>/dev/null; echo '# 每6小时从飞书同步新记录到 memory'; echo '30 */6 * * * /usr/bin/python3 $HOME/sync_feishu_to_memory.py >> /tmp/feishu-sync.log 2>&1') | crontab -
```

---

## 第七步：验证一切正常

### 7.1 完整检查清单

逐项运行以下命令，全部通过就代表配置成功：

```bash
echo "=== 1. 配置文件检查 ==="
python3 -c "
import json, os
c = json.load(open(os.path.expanduser('~/.openclaw/openclaw.json')))
ms = c.get('agents',{}).get('defaults',{}).get('memorySearch',{})
print('  provider:', ms.get('provider','❌ 未配置'))
print('  model:', ms.get('model','❌ 未配置'))
print('  hybrid:', '✅ 开启' if ms.get('query',{}).get('hybrid',{}).get('enabled') else '❌ 未开启')
" 2>/dev/null || echo "  ❌ 配置文件解析失败"

echo ""
echo "=== 2. 知识文件检查 ==="
echo "  文件数量: $(ls ~/.openclaw/workspace/memory/*.md 2>/dev/null | wc -l)"
echo "  最新文件:"
ls -lt ~/.openclaw/workspace/memory/*.md 2>/dev/null | head -3

echo ""
echo "=== 3. 搜索测试 ==="
npx openclaw memory search '测试搜索' 2>/dev/null | head -5
echo "(如果有结果显示分数和文件名，就是成功了)"

echo ""
echo "=== 4. Cron 任务检查 ==="
crontab -l 2>/dev/null | grep -E 'move-daily|sync_feishu' || echo "  ⚠️ 未设置定时任务"
```

### 7.2 搜索测试用例

用你的知识内容测试几个搜索：

```bash
# 用知识标题搜索（应该高分命中）
npx openclaw memory search '你的某条知识标题'

# 用同义词搜索（测试语义理解）
npx openclaw memory search '换一种说法描述你的知识'

# 用口语化表达搜索（测试自然语言）
npx openclaw memory search '之前好像有一篇讲XX的'
```

**分数参考**：
- 0.7+ 精准命中
- 0.4-0.7 相关命中
- 0.3-0.4 模糊相关
- <0.3 可能不相关

---

## 常见问题 FAQ

### Q1：搜索没有任何结果？

**排查步骤**：
1. `ls ~/.openclaw/workspace/memory/` 确认有 .md 文件
2. `npx openclaw memory index --force` 重建索引
3. 检查 openclaw.json 中 memorySearch 配置是否正确
4. 多实例用户：确认 `export HOME=` 设对了

### Q2：搜索结果不准，总是命中无关内容？

**可能原因**：
1. memory/ 中有 daily 心跳日志（大量噪音）→ 运行归档脚本
2. 多条知识合并在一个大文件中 → 拆分为独立文件
3. 搜索关键词缺失 → 给每个文件加 `**搜索关键词**` 行

### Q3：新增知识后需要重建索引吗？

- **SOUL.md 双写**：龙虾创建文件后，OpenClaw 会自动增量索引（下次搜索时）
- **手动添加文件后**：需要运行 `npx openclaw memory index --force`
- **Cron 同步脚本**：脚本会自动重建索引

### Q4：VPS 内存不够跑 Embedding 模型？

不需要本地跑！本方案用**云端 API**（ZAI embedding-3），本地只需：
- SQLite 数据库文件（几 MB）
- 不占 GPU、不占大内存
- 3.8GB VPS 完全够用

### Q5：没有飞书怎么办？

完全可以不用飞书！核心是 memory/ 目录中的 .md 文件。

你可以：
- 手动创建 .md 文件
- 用任何笔记工具导出 .md
- 写个脚本从 Notion/Obsidian/其他平台同步

飞书多维表格只是**锦上添花**（结构化存储 + 可视化管理）。

### Q6：多个龙虾能共享一套知识库吗？

可以，但需要注意：
- 方案一：所有龙虾的 memory/ 指向同一目录（软链接）
- 方案二：用 rsync 定期同步
- 方案三：各实例独立维护，按需手动复制共享的知识文件

### Q7：hybrid search 的 70/30 权重要调吗？

默认的 70% 向量 + 30% BM25 适合大多数场景。如果你发现：
- 语义搜索太模糊，命中不相关内容 → 降低 vectorWeight（如 0.6）
- 关键词搜索太死板，找不到同义词 → 提高 vectorWeight（如 0.8）

---

## 核心原则速查卡

配置完成后，记住这三条原则，长期受用：

### 原则一：一条知识 = 一个文件 = 一个 chunk

不要把多条知识塞进一个大文件。独立文件 = 精准搜索。

### 原则二：搜索关键词是给机器看的

每个文件底部的 `**搜索关键词**` 行，是 BM25 搜索通道的燃料。
写同义词、场景词、英文缩写——用户可能用什么词搜到这条知识？

### 原则三：噪音是精度的天敌

memory/ 目录只放高质量知识文件。日志、心跳、临时文件统统归档到别处。
信息越多 ≠ 知识越多。选择性遗忘是知识管理的核心能力。

---

## 方案架构一图流

```
你对龙虾说话 / 发文章
         ↓
    龙虾提炼知识
         ↓
   ┌─────┴─────┐
   ↓           ↓
飞书多维表格   memory/{id}.md    ← 双写
(结构化存储)   (向量化存储)
   ↓           ↓
可视化管理    Hybrid Search
标签/评级     vector 70% + BM25 30%
   ↓           ↓
   └─────┬─────┘
         ↓
  用户问"之前那篇..."
         ↓
    精准召回 ✅
```

---

## 附录：文件位置速查

| 文件 | 路径 | 作用 |
|------|------|------|
| OpenClaw 配置 | `~/.openclaw/openclaw.json` | memorySearch 配置 |
| 知识文件目录 | `~/.openclaw/workspace/memory/` | 存放 .md 知识文件 |
| SOUL.md | `~/.openclaw/workspace/SOUL.md` | 龙虾灵魂 + 双写规则 |
| 向量索引 | `~/.openclaw/memory/main.sqlite` | SQLite 向量数据库 |
| Daily 归档 | `~/.openclaw/workspace/daily-archive/` | 归档的心跳日志 |
| 归档脚本 | `~/move-daily-logs.sh` | cron 每天归档 daily |
| 同步脚本 | `~/sync_feishu_to_memory.py` | cron 每6小时同步飞书 |

---

---

*作者：大王 | 公众号：持续进化营*
