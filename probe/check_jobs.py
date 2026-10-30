import sqlite3
c = sqlite3.connect("/AstrBot/data/data_v4.db")
c.row_factory = sqlite3.Row
rows = list(c.execute(
    "SELECT id,name,status,last_run_at,next_run_time,last_error,payload FROM cron_jobs WHERE enabled=1 ORDER BY id"))
for r in rows:
    le = (r["last_error"] or "").replace("\n", " ")[:90]
    print("[%d] %s" % (r["id"], r["name"]))
    print("     status=%s last=%s next=%s" % (r["status"], (r["last_run_at"] or "-")[:16], (r["next_run_time"] or "-")[:16]))
    if le:
        print("     err:", le)
