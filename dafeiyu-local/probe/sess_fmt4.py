import sqlite3
c = sqlite3.connect("/AstrBot/data/data_v4.db")
# user_id 就是 unified_msg_origin；找群格式
seen = []
for (uid,) in c.execute("SELECT DISTINCT user_id FROM platform_message_history LIMIT 400"):
    if uid and ("Group" in uid or "Friend" in uid) and uid not in seen:
        seen.append(uid)
for s in seen[:20]:
    print(s)
