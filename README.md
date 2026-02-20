# AI Dev Guides

> 实战踩坑，一手经验。AI 开发 & 技术折腾笔记。

来自一个独立开发者的技术实战记录——不是翻译文档，是真刀真枪踩过的坑、验证过的方案、提炼过的方法论。

## 目录

### OpenClaw（AI Agent 框架）

| 教程 | 简介 | 难度 |
|------|------|------|
| [从零部署 AI Telegram 管家](openclaw/glm-deployment/) | OpenClaw + 智谱 GLM-4.7 完整部署教程，零基础可上手 | 入门 |
| [飞书频道接入指南](openclaw/feishu-setup/) | OpenClaw 接入飞书，6 个踩坑点逐一破解 | 入门 |
| [多实例部署指南](openclaw/multi-instance-deployment/) | 一台 VPS 跑多只龙虾，OPENCLAW_HOME 隔离方案 + 7 大踩坑 | 中级 |
| [全能助手进阶配置](openclaw/full-features-setup/) | 语音识别、语音合成、联网搜索、自主人格一站式开启 | 中级 |
| [龙虾 + 飞书知识库系统](openclaw/knowledge-base-system/) | 从 VPS 部署到飞书多维表格，完整知识捕获方案 | 中级 |
| [飞书斜杠命令修复实战](openclaw/feishu-slash-fix/) | 飞书中 `/status` 等命令无响应的根因分析与一键修复 | 入门 |
| [AI Agent 幻觉防治实战](openclaw/anti-hallucination/) | 当你的 AI 助手自信地说谎——描述≠现实 | 入门 |
| [飞书命令完整清单](openclaw/commands-reference/) | OpenClaw 26+ 斜杠命令分类速查 | 入门 |

### Claude Code / AI 开发

| 教程 | 简介 | 难度 |
|------|------|------|
| [接入飞书多维表格](claude-code/feishu-bitable/) | 5 步让 Claude Code 拥有长期记忆，MCP 接入飞书 | 入门 |
| [创建自定义 Skill 实战](claude-code/skill-creation/) | 从零打造「一键发布」技能，Skill 设计方法论与完整实战 | 中级 |

---

## 关于

- 作者：大王 (KING)
- 公众号：**持续进化营**（更多实战内容 & 深度解读）
- 环境：OpenClaw v2026.2.x / Claude Code / 飞书

## 使用方式

**直接阅读**：点击上方目录链接。

**一键修复脚本**：每篇教程附带可直接执行的修复脚本。

```bash
# 例：一键修复飞书斜杠命令
curl -sSL https://raw.githubusercontent.com/YIING99/ai-dev-guides/main/openclaw/feishu-slash-fix/fix.sh | bash
```

## License

MIT
