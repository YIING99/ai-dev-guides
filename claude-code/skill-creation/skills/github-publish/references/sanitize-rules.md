# 敏感信息脱敏规则

## 必须替换的模式

| 类型 | 正则特征 | 替换为 |
|------|---------|--------|
| IPv4 地址 | `\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b` | `你的服务器IP` |
| API Key | 长字母数字串在 key/secret 上下文 | `你的API_KEY` |
| Bot Token | `\d{10}:AA[A-Za-z0-9_-]{33}` | `你的Bot_Token` |
| 飞书 App ID | `cli_[0-9a-f]{16}` | `cli_xxxxxxxxxxxxxxx` |
| 飞书 App Secret | 32 位混合字符串 | `你的App Secret` |
| 飞书 app_token | 25 位字母数字串 | `你的app_token` |
| 飞书 table_id | `tbl[A-Za-z0-9]{16}` | `你的table_id` |
| 用户 ID | 上下文中的真实 UID | `1234567890` |
| 密码/Secret | 上下文中明显的密码 | `你的密码` |

## 允许保留

- 通用示例 IP：`127.0.0.1`, `0.0.0.0`
- 通用示例 ID：`1234567890`
- 公开的项目名/包名
- 公开 URL

## 检查方法

```bash
bash ~/.claude/skills/github-publish/scripts/check_sensitive.sh <file-or-directory>
```
