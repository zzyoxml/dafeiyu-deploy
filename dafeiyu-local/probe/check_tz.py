import sqlite3, json
c = sqlite3.connect("/AstrBot/data/data_v4.db")
c.row_factory = sqlite3.Row
r = c.execute("SELECT payload FROM cron_jobs WHERE id=7").fetchone()
print("job7 payload:", r["payload"])
# 看看 21aa5480（id=2 原生任务）的 next 计算方式
r2 = c.execute("SELECT name,cron_expression,timezone,payload,next_run_time,status FROM cron_jobs WHERE id IN (2,4)").fetchall()
for x in r2:
    print()
    print("id=%s name=%s cron=%s tz=%s" % (x["id"], x["name"], x["cron_expression"], x["timezone"]))
    print("  next=%s status=%s" % (x["next_run_time"], x["status"]))
    print("  payload:", x["payload"][:200])
