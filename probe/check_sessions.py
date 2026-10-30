import sqlite3
c = sqlite3.connect("/AstrBot/data/data_v4.db")
c.row_factory = sqlite3.Row
# platform_sessions 全列出来
print("=== platform_sessions（含群号）===")
for r in c.execute("SELECT session_id, platform_id, is_group, display_name FROM platform_sessions"):
    if any(g in (r["session_id"] or "") for g in ("<群号B>", "<群号A>", "<群号C>")):
        print("  ", r["session_id"], "| group =", r["is_group"], "|", r["display_name"])
print()
print("=== conversations 的 platform_id+user_id（找群的会话）===")
cols = [r[1] for r in c.execute("PRAGMA table_info(conversations)")]
print("cols:", cols)
q = "SELECT platform_id, user_id, created_at FROM conversations"
seen = set()
for r in c.execute(q):
    u = r["user_id"] or ""
    if any(g in u for g in ("<群号B>", "<群号A>", "<群号C>")) and u not in seen:
        seen.add(u)
        print("  ", r["platform_id"], "|", u, "|", r["created_at"][:19])
    if len(seen) >= 8:
        break
