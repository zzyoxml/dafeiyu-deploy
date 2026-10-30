import sqlite3, json, uuid, datetime

c = sqlite3.connect("/AstrBot/data/data_v4.db")
c.row_factory = sqlite3.Row

now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")
GROUPS = ["<群号A>", "<群号B>", "<群号C>"]
OWNER = "<主人QQ>"

# ---------- 1. 清空全部播报类任务（保留库表结构）----------
gone = 0
for r in c.execute("SELECT id,name FROM cron_jobs").fetchall():
    c.execute("DELETE FROM cron_jobs WHERE id=?", (r["id"],))
    gone += 1
print("已清空 %d 条旧任务（含机器人自建/我建的/原生遗留）" % gone)

# ---------- 2. 重建：每群一条 + 私聊一条，cron 用北京时间 ----------
MORNING_NOTE = ("每天 09:00 发送早安问候+每日趣闻+国内外大事 2-3 条。"
                "先联网搜索当天趣闻与大事各2-3条，避免敏感政治争议，"
                "语气轻松简短，小鲸鱼身份。只发到目标会话，不要私聊重复发送。")
NIGHT_NOTE = ("每天 23:30 发送晚安问候+今日热点回顾 2-3 条。"
              "先联网搜索当天热点，避免敏感政治争议，"
              "语气轻松温柔，小鲸鱼身份。只发到目标会话，不要私聊重复发送。")

def add(name, desc, cron, session, note):
    payload = {"session": session, "sender_id": OWNER, "note": note, "origin": "tool"}
    c.execute(
        "INSERT INTO cron_jobs (created_at, updated_at, job_id, name, description, job_type,"
        " cron_expression, timezone, payload, enabled, persistent, run_once, status,"
        " last_run_at, next_run_time, last_error)"
        " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (now, now, str(uuid.uuid4()), name, desc, "active_agent",
         cron, "Asia/Shanghai", json.dumps(payload, ensure_ascii=False),
         1, 1, 0, "pending", None, None, None))

for gid in GROUPS:
    add("晨间播报·" + gid, "每天 09:00 给群 " + gid + " 发早安播报",
        "0 9 * * *", "default:GroupMessage:" + gid, MORNING_NOTE)
    add("晚安播报·" + gid, "每天 23:30 给群 " + gid + " 发晚安播报",
        "30 23 * * *", "default:GroupMessage:" + gid, NIGHT_NOTE)

add("晨间播报·私聊", "每天 09:00 私聊给主人发早安播报",
    "0 9 * * *", "default:FriendMessage:" + OWNER, MORNING_NOTE)
add("晚安播报·私聊", "每天 23:30 私聊给主人发晚安播报",
    "30 23 * * *", "default:FriendMessage:" + OWNER, NIGHT_NOTE)

# 下班提醒也重建（原来 17:50 被按 UTC 解析成 09:50 UTC=北京 17:50，碰巧对；
# 现在容器是 CST，直接写北京时间）
add("下班提醒", "每天 17:50 私聊提醒主人下班", "50 17 * * *",
    "default:FriendMessage:" + OWNER, "提醒用户：快到 18:00 了，准备下班啦。")

c.commit()

# ---------- 3. 验证 ----------
print()
print("=== 重建后的任务表 ===")
for r in c.execute("SELECT id,name,cron_expression,payload,status FROM cron_jobs ORDER BY id"):
    p = json.loads(r["payload"])
    print("  [%d] %-14s %s -> %s" % (r["id"], r["name"], r["cron_expression"], p.get("session")))
