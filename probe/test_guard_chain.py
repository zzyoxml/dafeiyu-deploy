"""离线验证 reply-guard 的限流与滞后拦截决策。"""
import sys
import time

sys.path.insert(0, "/AstrBot")
import importlib.util

s = importlib.util.spec_from_file_location(
    "g", "/AstrBot/data/plugins/dsh-reply-guard/main.py")
g = importlib.util.module_from_spec(s)
s.loader.exec_module(g)

print("=" * 60)
print("① 限流：连发 15 条，第 11 条起应被拦")
allowed = blocked = 0
for i in range(1, 16):
    ok = g._rate_take("test:Group:<群号A>")
    if ok:
        allowed += 1
    else:
        blocked += 1
print(f"   允许 {allowed} 条，拦截 {blocked} 条（应 10 / 5）")
print(f"   剩余额度 {g._rate_left('test:Group:<群号A>')}（应 0）")
print()

print("② 滑动窗口过期（模拟 61 秒后额度恢复）")
U = "test:Group:<群号A>"
g._WINDOW[U].clear()      # 等价于时间前进 61s，旧记录全部过期
g._WINDOW[U].append(time.time() - 61)
print(f"   窗口里放一条 61 秒前的记录后，剩余额度 = {g._rate_left(U)}（应 10）")
ok = g._rate_take(U)
print(f"   再取一次 = {ok}（应 True）")
print()

print("③ 不同会话隔离")
a = g._rate_take("test:Group:A")
b = g._rate_take("test:Group:B")
c = g._rate_take("test:Private:C")
print(f"   三个不同会话各自首条: A={a} B={b} C={c}（应全 True）")
print()

print("④ 点名判定（点名必须放行）")
for t, want in [
    ("@小鲸鱼 /唱歌", True), ("小鲸鱼你在吗", True), ("鲸鱼", True),
    ("给老子唱歌", False), ("今天好热", False),
    ("<BOT_QQ>", True),
]:
    got = g._named(t)
    print(f"   {'✅' if got == want else '❌'} {t!r:20} → {got} (应 {want})")
print()

print("⑤ 滞后判定模拟")
UNO = "sim:Group:1"
g._SEQ[UNO] = 0
g._LAST_REPLY[UNO] = 0

def sim(lag, text, idle=5):
    """手动推进序号 lag 条后，判断本句是否会被拦。"""
    g._SEQ[UNO] = 1 + lag
    g._LAST_REPLY[UNO] = 1
    g._LAST_REPLY_TS[UNO] = time.time() - idle
    cur = g._SEQ[UNO]
    last = g._LAST_REPLY[UNO]
    l = cur - last
    if g._named(text) or l <= g.STALE_LAG or idle > 600:
        return "放行"
    return "拦截"

for lag, text, idle in [
    (3, "今天好热", 5),        # 积压少 → 放行
    (11, "今天好热", 5),       # 积压 11 > 10，没点名 → 拦
    (11, "@小鲸鱼 在吗", 5),   # 点名 → 放行
    (30, "今天好热", 700),     # 空闲超 600s → 放行
    (10, "今天好热", 5),       # 恰好 10 → 放行（不 >10）
]:
    r = sim(lag, text, idle)
    print(f"   滞后{lag:2d}句 空闲{idle:3d}s {text!r:18} → {r}")
