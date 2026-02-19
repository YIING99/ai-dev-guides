# 给 Claude Code 造一个「一键发布」技能：Skill 创建实战

> 你有没有这样的场景——
>
> 写完一篇技术教程，想分享到 GitHub 公开仓库，但每次都要手动做同样的事：
> 检查敏感信息、脱敏替换、放到正确目录、更新索引、git push……
>
> **如果能一句话让 AI 全部搞定呢？**
>
> 这篇教程教你用 Claude Code 的 Skill 机制，把这类重复工作流变成一句话触发。

---

## 先看效果

配置完成后，在 Claude Code 中说：

> 「把这篇教程推送到 GitHub」

或者：

> `/github-publish ~/Desktop/新教程.md`

AI 会自动走完：**内容评估 → 敏感信息脱敏 → 分类到正确目录 → 更新 README 索引 → git commit & push**。

---

## 什么是 Skill？

Skill 是 Claude Code 的「技能插件」—— 一组打包好的指令和工具，让 AI 在特定场景下变成领域专家。

```
你说话 → Claude Code → 识别匹配的 Skill → 按 Skill 流程执行
```

**核心设计原理：三层渐进式加载**

```
第 1 层  name + description ............. 始终在上下文中（~100 词）
         ↓ 触发时才加载
第 2 层  SKILL.md 正文 .................. 核心流程指令（<5000 词）
         ↓ 按需读取
第 3 层  references/ + scripts/ ......... 详细规则、可执行脚本（不限大小）
```

这样设计的好处：不浪费宝贵的上下文窗口。平时只占 100 词，用到时才展开。

---

## Skill 的文件结构

```
skill-name/
├── SKILL.md              # 必须：流程指令（AI 读这个文件来工作）
├── references/           # 可选：参考资料（详细规则、数据）
│   ├── repo-structure.md
│   └── sanitize-rules.md
├── scripts/              # 可选：可执行脚本（确定性任务）
│   └── check_sensitive.sh
└── assets/               # 可选：模板、图片等输出资源
```

**关键认知**：
- `SKILL.md` = 给 AI 的岗位说明书，定义「做什么、怎么做」
- `references/` = 需要时才查的手册，节省 token
- `scripts/` = 确定性任务交给脚本，比 AI 逐行判断更可靠

---

## 实战：创建 github-publish Skill

### 第 1 步：初始化骨架

如果安装了 skill-creator，用它的初始化脚本：

```bash
python3 ~/.claude/skills/skill-creator/scripts/init_skill.py github-publish --path ~/.claude/skills/
```

会生成：
```
~/.claude/skills/github-publish/
├── SKILL.md            # 模板，需要编辑
├── scripts/example.py  # 示例，需要替换
├── references/         # 示例，需要替换
└── assets/             # 示例，不需要可删除
```

> 没有 skill-creator？手动创建目录和 SKILL.md 也可以。

### 第 2 步：编写 SKILL.md

这是 Skill 的核心。分两部分：

#### 2.1 YAML 头部（触发条件）

```yaml
---
name: github-publish
description: 一键将教程/技术文章脱敏后推送到 GitHub 开源仓库。触发词："/github-publish"、"推送GitHub"、"发布教程"、"上传到仓库"。
---
```

**重点**：`description` 是唯一的触发机制！AI 靠这段文字判断是否调用此 Skill。必须写清楚：
- 这个 Skill **做什么**
- **什么时候**用它（触发词、场景）

#### 2.2 Markdown 正文（执行流程）

用清晰的步骤定义工作流：

```markdown
# GitHub 教程发布

## 流程

### 1. 确认输入源
用户可能提供文件路径、目录、或当前对话内容。

### 2. 内容评估
判断是否有通用分享价值，展示清单让用户确认。

### 3. 敏感信息脱敏
按 references/sanitize-rules.md 中的规则替换真实凭证。
脱敏后运行检查脚本验证。

### 4. 分类放置
按 references/repo-structure.md 放到正确目录。

### 5. 更新仓库索引
编辑 README.md，追加新教程条目。

### 6. 提交推送
git add → commit → push

### 7. 确认结果
展示推送结果和仓库链接。
```

### 第 3 步：创建参考文件

#### references/repo-structure.md — 仓库分类规则

```markdown
## 分类目录
| 目录前缀       | 适用内容                      |
|----------------|-------------------------------|
| openclaw/      | OpenClaw 框架相关             |
| claude-code/   | Claude Code CLI 相关          |
| ai-tools/      | 其他 AI 工具教程              |

## 已有教程（避免重复）
- openclaw/glm-deployment/ — 从零部署 AI Telegram 管家
- claude-code/feishu-bitable/ — 接入飞书多维表格
...
```

#### references/sanitize-rules.md — 脱敏对照表

```markdown
| 类型           | 正则特征                    | 替换为          |
|----------------|-----------------------------|-----------------|
| IPv4 地址      | \b\d{1,3}\.\d{1,3}\.…\b   | 你的服务器IP     |
| 飞书 App ID    | cli_[0-9a-f]{16}           | cli_xxxxxxx     |
| Bot Token      | \d{10}:AA[A-Za-z0-9_-]{33} | 你的Bot_Token   |
...
```

### 第 4 步：创建检查脚本

`scripts/check_sensitive.sh` — 用正则自动扫描残留敏感信息：

```bash
#!/bin/bash
# 用法: bash check_sensitive.sh <文件或目录>
set -euo pipefail
TARGET="${1:-.}"
FOUND=0

check_pattern() {
    local label="$1" pattern="$2"
    local results
    results=$(grep -rnE "$pattern" "$TARGET" --include='*.md' 2>/dev/null || true)
    if [ -n "$results" ]; then
        echo "⚠️  $label:"
        echo "$results" | head -10
        FOUND=$((FOUND + 1))
    fi
}

# 真实 IP 地址
check_pattern "可能的真实 IP" '\b(1[0-9]{2}|2[0-4][0-9]|25[0-5])\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\b'

# 飞书 App ID
check_pattern "飞书 App ID" 'cli_[0-9a-f]{16}'

# Telegram Bot Token
check_pattern "Bot Token" '[0-9]{8,}:AA[A-Za-z0-9_-]{30,}'

if [ "$FOUND" -eq 0 ]; then
    echo "✅ 未发现明显敏感信息"
else
    echo "⚠️  发现 $FOUND 类潜在敏感信息，请人工复核"
fi
```

### 第 5 步：清理和验证

```bash
# 删除不需要的示例文件
rm scripts/example.py references/api_reference.md assets/example_asset.txt
rmdir assets  # 如果不需要

# 加执行权限
chmod +x scripts/check_sensitive.sh

# 打包验证（如果有 skill-creator）
python3 ~/.claude/skills/skill-creator/scripts/package_skill.py ~/.claude/skills/github-publish
```

看到 `✅ Skill is valid!` 就完成了。

---

## 设计要点总结

### description 写好是关键

```
❌ description: "推送教程到 GitHub"          → 太简短，触发不到
✅ description: "一键将教程/技术文章脱敏后     → 完整，多个触发词
   推送到 GitHub 开源仓库。触发词：
   /github-publish、推送GitHub、发布教程"
```

### 确定性任务交给脚本

| 任务类型 | 用 AI 还是脚本？ | 原因 |
|----------|------------------|------|
| 内容评估 | AI | 需要理解语义 |
| 正则脱敏检查 | 脚本 | 确定性，可重复 |
| 目录分类 | AI | 需要判断主题 |
| 更新索引 | AI | 需要理解格式 |
| git 操作 | 脚本/命令 | 确定性 |

### references 节省 token

把详细规则放在 `references/` 下，SKILL.md 里只写「按 references/xxx.md 中的规则」。AI 需要时才读取，不用时不占上下文。

---

## 举一反三

同样的方法可以创建各种 Skill：

| Skill 名称 | 触发场景 | 核心流程 |
|------------|---------|----------|
| `feishu-push` | "推送到飞书" | 提炼对话 → 分类 → 写入多维表格 |
| `code-review` | "审查代码" | 读 diff → 检查规范 → 生成报告 |
| `deploy-check` | "部署前检查" | 环境验证 → 配置核对 → 健康检查 |
| `blog-draft` | "写篇博客" | 提炼素材 → 生成大纲 → 填充内容 |

**本质**：Skill = 把你的工作 SOP 写成 AI 能理解的格式。

---

## 常见问题

### Q: Skill 不触发怎么办？
**A:** 检查 YAML `description` 是否包含了你说的关键词。记住：`description` 是唯一的触发入口。

### Q: 怎么调试 Skill？
**A:** 直接在 Claude Code 中使用触发词，观察 AI 是否加载了 Skill。如果加载了但行为不对，修改 SKILL.md 正文。

### Q: Skill 放在哪里才会被识别？
**A:** 放在 `~/.claude/skills/` 目录下，重启 Claude Code 后自动识别。

### Q: 能不能分享给别人用？
**A:** 可以。用 `package_skill.py` 打包成 `.skill` 文件分发，或直接拷贝整个目录。

---

*本教程基于 2026-02-20 实际创建 github-publish Skill 的过程整理*
*Claude Code Skills 机制版本：2026.2.x*
