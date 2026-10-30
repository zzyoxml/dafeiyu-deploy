import sqlite3, json, uuid, datetime

c = sqlite3.connect("/AstrBot/data/data_v4.db")
c.row_factory = sqlite3.Row

GROUPS = ["<群号A>", "<群号B>", "<群号C>"]

# 找晨间(0 9)和晚安(30 23)两个任务的最新定义
rows = list(c.execute("SELECT * FROM cron_jobs WHERE enabled=1 ORDER BY id"))
targets = {}
for r in rows:
    ce = r["cron_expression"].strip()
    if ce == "0 9 * * *":
        targets["morning"] = dict(r)
    elif ce == "30 23 * * *":
        targets["night"] = dict(r)

print("找到任务:", list(targets.keys()))
if len(targets) < 2:
    raise SystemExit("没找齐晨/晚安任务，中止")

now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")

for kind, t in targets.items():
    payload = json.loads(t["payload"])
    base_note = payload.get("note") or t["description"]
    for gid in GROUPS:
        # 已存在就跳过（幂等）
        ex = c.execute("SELECT COUNT(*) FROM cron_jobs WHERE name=? AND payload LIKE ?",
                       (t["name"] + "·" + gid, "%GroupMessage:%" + gid + "%")).fetchone()[0]
        if ex:
            print("  跳过已存在:", t["name"], gid)
            continue
        new_payload = {
            "session": "default:GroupMessage:" + gid,
            "sender_id": payload.get("sender_id", "<主人QQ>"),
            "note": base_note + "（投递到群 " + gid + "）",
            "origin": "tool",
        }
        c.execute(
            "INSERT INTO cron_jobs (created_at, updated_at, job_id, name, description, job_type,"
            " cron_expression, timezone, payload, enabled, persistent, run_once, status,"
            " last_run_at, next_run_time, last_error)"
            " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (now, now, str(uuid.uuid4()), t["name"] + "·" + gid, t["description"],
             t["job_type"], t["cron_expression"], t["timezone"],
             json.dumps(new_payload, ensure_ascii=False), 1, 1, 0, "pending",
             None, None, None),
        )
        print("  已建:", t["name"] + "·" + gid)

# 原任务改成只私聊你的那份（描述里写清）
for kind, t in targets.items():
    c.execute("UPDATE cron_jobs SET description=? WHERE id=?",
              (t["description"].replace("在本群发送", "私聊发送给主人（各群播报由分群任务负责）"), t["id"]))
print("原任务描述已改为仅私聊")

c.commit()

# 验证
print()
print("=== 当前全部启用的播报任务 ===")
for r in c.execute("SELECT id,name,cron_expression,payload FROM cron_jobs WHERE enabled=1 ORDER BY id"):
    p = json.loads(r["payload"])
    print("  [%d] %s @ %s -> %s" % (r["id"], r["name"], r["cron_expression"], p.get("session")))
