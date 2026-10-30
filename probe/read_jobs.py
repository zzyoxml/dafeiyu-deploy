import sqlite3
c = sqlite3.connect("/AstrBot/data/data_v4.db")
tabs = [r[0] for r in c.execute("SELECT name FROM sqlite_master WHERE type='table'")]
print("TABLES:", tabs)
for t in tabs:
    tl = t.lower()
    if any(w in tl for w in ("sched", "job", "cron", "task", "future")):
        print()
        print("=== TABLE", t, "===")
        cols = [r[1] for r in c.execute("PRAGMA table_info(%s)" % t)]
        print("COLS:", cols)
        for row in c.execute("SELECT * FROM %s" % t):
            print(str(row)[:500])
