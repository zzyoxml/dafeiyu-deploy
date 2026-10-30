import sqlite3
c = sqlite3.connect("/AstrBot/data/data_v4.db")
cols = [r[1] for r in c.execute("PRAGMA table_info(platform_message_history)")]
print("pmh COLS:", cols)
# 找 session/umo 类列
cand = [x for x in cols if x in ("session_id","unified_msg_origin","umo","platform_id","message_type","user_id")]
if cand:
    q = "SELECT DISTINCT %s FROM platform_message_history LIMIT 30" % ",".join(cand)
    for row in c.execute(q):
        print(row)
