import sqlite3, json
c = sqlite3.connect("/AstrBot/data/data_v4.db")
c.row_factory = sqlite3.Row
for x in c.execute("SELECT * FROM cron_jobs WHERE id IN (2,4,7,10,11)").fetchall():
    d = dict(x)
    print()
    print("id=%s name=%s" % (d.get("id"), d.get("name")))
    print("  cron=%r tz=%r" % (d.get("cron_expression"), d.get("timezone")))
    print("  next=%s status=%s" % (d.get("next_run_time"), d.get("status")))
    p = d.get("payload")
    if p:
        try:
            pj = json.loads(p)
            print("  session:", pj.get("session"))
        except Exception:
            print("  payload:", p[:120])
