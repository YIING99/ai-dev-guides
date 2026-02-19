---
name: github-publish
description: 一键将教程/技术文章脱敏后推送到 GitHub 开源仓库。触发词："/github-publish"、"推送GitHub"、"发布教程"、"上传到仓库"、"开源分享"。用于将本地 Markdown 教程文件脱敏、分类、更新索引、提交并推送到公开 GitHub 仓库。
---

# GitHub 教程发布

将本地教程/技术文章脱敏后推送到你的 GitHub 公开仓库。

> ⚠️ 使用前请修改 references/repo-structure.md 中的仓库路径和目录分类。

## 流程

### 1. 确认输入源

用户可能提供：
- 具体文件路径（如 `~/Desktop/xxx.md`）
- 目录路径（批量扫描）
- 当前对话内容（从对话中提炼文章）

如果未提供路径，主动询问。

### 2. 内容评估

逐文件判断：

**收录标准：**
- 有通用分享价值的教程/实战文章
- 与已有教程不重复（查 references/repo-structure.md）
- 非内部运维文档、非纯日志

**跳过标准：**
- 内部架构备案/运维指导书（含真实架构细节）
- 与已有教程内容重叠
- 纯终端日志、PDF、截图（无上下文）

展示评估清单让用户确认。

### 3. 敏感信息脱敏

按 references/sanitize-rules.md 中的规则替换真实凭证。

脱敏后运行检查脚本：
```bash
bash ~/.claude/skills/github-publish/scripts/check_sensitive.sh <file>
```

### 4. 分类放置

根据内容主题决定目录，规则见 references/repo-structure.md。
文件统一命名为 `README.md`，放入对应子目录。

### 5. 更新仓库索引

编辑仓库根目录的 README.md，在对应分类表格中追加新行。
格式：`| [标题](路径/) | 简介 | 难度 |`

### 6. 提交推送

```bash
git add <新文件> README.md
git commit -m "新增教程：<标题列表>"
git push origin main
```

### 7. 确认结果

推送成功后展示仓库链接和新增教程路径。
