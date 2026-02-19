#!/usr/bin/env python3
"""
飞书多维表格推送脚本（本地运行）
用法: echo '<json>' | python3 push_to_feishu.py

JSON 输入格式:
{
  "ai_records": [{...}],    # → 资讯库
  "dev_records": [{...}]    # → 开发知识库
}

⚠️ 使用前请修改下面 4 个配置项为你自己的飞书凭证和表格 ID
"""
import json, sys, urllib.request, ssl, datetime

# ============================================================
# 👇 请替换为你自己的飞书凭证（参考教程第 1-2 步获取）
# ============================================================
FEISHU_APP_ID = "cli_xxxxxxxxxxxxxxx"       # 飞书应用 App ID
FEISHU_APP_SECRET = "你的App_Secret"         # 飞书应用 App Secret

# 资讯库（第一个多维表格）
AI_APP_TOKEN = "你的app_token_1"             # 飞书多维表格 app_token
AI_TABLE_ID = "你的table_id_1"              # 飞书多维表格 table_id

# 开发知识库（第二个多维表格，如果只用一个表可以和上面相同）
DEV_APP_TOKEN = "你的app_token_2"            # 飞书多维表格 app_token
DEV_TABLE_ID = "你的table_id_2"             # 飞书多维表格 table_id
# ============================================================

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

def get_token():
    req = urllib.request.Request(
        "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal",
        data=json.dumps({"app_id": FEISHU_APP_ID, "app_secret": FEISHU_APP_SECRET}).encode(),
        headers={"Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req, context=ctx, timeout=10).read())["tenant_access_token"]

def push(token, app_token, table_id, records, label):
    if not records:
        return 0
    url = f"https://open.feishu.cn/open-apis/bitable/v1/apps/{app_token}/tables/{table_id}/records/batch_create"
    req = urllib.request.Request(url,
        data=json.dumps({"records": records}, ensure_ascii=False).encode(),
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        method="POST")
    result = json.loads(urllib.request.urlopen(req, context=ctx, timeout=30).read())
    if result.get("code") == 0:
        n = len(result["data"]["records"])
        print(f"[{label}] ✅ {n} 条")
        return n
    print(f"[{label}] ❌ {result.get('msg')}")
    return 0

def main():
    data = json.load(sys.stdin)
    token = get_token()
    ts = int(datetime.datetime.now().timestamp() * 1000)
    total = 0

    for item in data.get("ai_records", []):
        item.setdefault("日期", ts)
        link = item.pop("原文链接", None)
        fields = {k: v for k, v in item.items()}
        if link:
            fields["原文链接"] = {"link": link, "text": link} if isinstance(link, str) else link
        data.setdefault("_ai", []).append({"fields": fields})

    if data.get("_ai"):
        total += push(token, AI_APP_TOKEN, AI_TABLE_ID, data["_ai"], "资讯库")

    dev_recs = []
    for item in data.get("dev_records", []):
        item.setdefault("日期", ts)
        item.setdefault("状态", "已整理")
        dev_recs.append({"fields": item})
    if dev_recs:
        total += push(token, DEV_APP_TOKEN, DEV_TABLE_ID, dev_recs, "开发知识库")

    print(f"共 {total} 条")

if __name__ == "__main__":
    main()
