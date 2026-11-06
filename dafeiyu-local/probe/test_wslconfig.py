import subprocess, tempfile, os, re, time

CFG = r"C:\Users\Administrator\.wslconfig"

# 测试各候选值，看 WSL 是否报错
CANDIDATES = ["disabled", "gradual", "dropcache", "1", "true"]

def test_value(val):
    """写配置 → wsl --shutdown → 启动 → 捕获 stderr 有无告警"""
    content = f"[wsl2]\nautoMemoryReclaim={val}\nmemory=8GB\n"
    with open(CFG, "w", encoding="utf-8") as f:
        f.write(content)
    subprocess.run(["wsl", "--shutdown"], capture_output=True, timeout=90)
    time.sleep(6)
    r = subprocess.run(["wsl", "-d", "Ubuntu-24.04", "-u", "root", "--", "bash", "-c", "echo OK"],
                       capture_output=True, text=True, timeout=90)
    out = (r.stdout or "") + (r.stderr or "")
    # 判断有无告警（告警里会出现 autoMemoryReclaim 字样）
    bad = "autoMemoryReclaim" in out or "auto" in out.lower() and "wslconfig" in out.lower()
    has_ok = "OK" in out
    return has_ok, bad, out.strip()[:160]

print("=== 测试 autoMemoryReclaim 的合法值 ===")
results = {}
for v in CANDIDATES:
    ok, bad, msg = test_value(v)
    results[v] = (ok, bad)
    status = "✅ 接受" if (ok and not bad) else ("⚠ 有告警" if bad else "❌ 失败")
    print(f"  {v:10} {status}")
    if msg:
        print(f"            {msg}")
    print()

print("=== 结论 ===")
good = [v for v, (ok, bad) in results.items() if ok and not bad]
print(f"  可用值: {good}")
