import sqlite3, json
c = sqlite3.connect("/AstrBot/data/data_v4.db")
# 查群消息的 session 格式（从会话历史里找）
for row in c.execute("SELECT DISTINCT platform, message_type, session_id FROM conversations LIMIT 20"):
    print(row)
print("---- platform_message_history 样本 ----")
cols = [r[1] for r in c.execute("PRAGMA table_info(platform_message_history)")]
print("COLS:", cols)
