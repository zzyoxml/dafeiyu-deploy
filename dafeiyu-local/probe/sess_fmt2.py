import sqlite3, json
c = sqlite3.connect("/AstrBot/data/data_v4.db")
# 看 conversations 的列
cols = [r[1] for r in c.execute("PRAGMA table_info(conversations)")]
print("conversations COLS:", cols)
# unified_msg_origin 样本
col = "unified_msg_origin" if "unified_msg_origin" in cols else ("umo" if "umo" in cols else cols[2])
print("用列:", col)
seen = set()
for (v,) in c.execute("SELECT DISTINCT %s FROM conversations" % col):
    if v and v not in seen:
        seen.add(v)
        print("  ", v)
    if len(seen) > 12: break
