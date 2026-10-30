import sqlite3, json

c = sqlite3.connect("/AstrBot/data/data_v4.db")
c.row_factory = sqlite3.Row

# 给全部 9 个任务的 note / description 加硬性发送指令
HARD = (
    "【必须执行】你必须调用 send_message_to_user 工具把播报发到 session 指定的会话，"
    "禁止只输出文字结果。发送后任务才算完成。"
)

n = 0
for r in c.execute("SELECT id,name,description,payload FROM cron_jobs").fetchall():
    p = json.loads(r["payload"])
    note = p.get("note") or ""
    desc = r["description"] or ""
    if "必须执行" not in note:
        p["note"] = HARD + note
        if "必须执行" not in desc:
            desc = HARD + desc
        c.execute("UPDATE cron_jobs SET description=?, payload=? WHERE id=?",
                  (desc, json.dumps(p, ensure_ascii=False), r["id"]))
        n += 1

c.commit()
print("已给 %d 个任务加硬性发送指令" % n)

# 验证一个
r = c.execute("SELECT payload FROM cron_jobs WHERE id=3").fetchone()
print()
print("job3 新 note 前 100 字:")
print(json.loads(r["payload"])["note"][:100])
