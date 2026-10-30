import sqlite3, json
c = sqlite3.connect("/AstrBot/data/data_v4.db")
c.row_factory = sqlite3.Row
r = c.execute("SELECT content FROM conversations WHERE user_id='default:GroupMessage:<群号B>'").fetchone()
content = r["content"]
# content 是历史 JSON，取最后几条
try:
    hist = json.loads(content)
    if isinstance(hist, list):
        print("历史条数:", len(hist))
        for m in hist[-6:]:
            role = m.get("role")
            rc = m.get("content")
            if isinstance(rc, list):
                texts = [x.get("text", "")[:150] for x in rc if isinstance(x, dict)]
                rc = " | ".join(texts)
            print("---", role, "---")
            print(str(rc)[:400])
    else:
        print(type(hist), str(hist)[:400])
except Exception as e:
    print("解析失败:", e)
    print(content[:500])
