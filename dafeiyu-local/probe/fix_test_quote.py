from pathlib import Path
import subprocess

f = Path("/opt/dafeiyu/repo/plugins/dsh-quote/test_quote.py")
if f.exists():
    txt = f.read_text(encoding="utf-8", errors="ignore")
    print("=== 上游 test_quote.py 里的敏感内容 ===")
    import re
    for m in re.finditer(r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.(com|cn|org)|1[3-9][0-9]{9}",
                         txt):
        print(f"  命中: {m.group()}")

# 对比：部署层有没有这个文件
dep = Path("/opt/dafeiyu/data/astrbot/plugins/dsh-quote/test_quote.py")
print(f"\n部署层有同名文件: {dep.exists()}")

# 它是否是上游的一部分
print("\n=== 这个文件在上游仓库里存在吗 ===")
r = subprocess.run(
    ["curl", "-s", "-m", "15", "-o", "/dev/null", "-w", "%{http_code}",
     "https://raw.githubusercontent.com/nanbengxian-cyber/dafeiyu-qq-bot/main/plugins/dsh-quote/test_quote.py"],
    capture_output=True, text=True)
print(f"  HTTP {r.stdout}")

# 决定：repo/plugins 是上游拷贝，测试文件不该进我们的仓库
print("\n=== 处理：从仓库排除所有 test_*.py（测试脚本含真实数据）===")
gi = Path("/opt/dafeiyu/.gitignore")
s = gi.read_text(encoding="utf-8")
if "test_*.py" not in s:
    s += "\n# 上游/本地的测试脚本含真实测试数据（邮箱等）\ntest_*.py\n"
    gi.write_text(s, encoding="utf-8")
    print("  已加 test_*.py 到 .gitignore")

# 取消跟踪
subprocess.run(["git", "-C", "/opt/dafeiyu", "rm", "--cached", "-q",
                "repo/plugins/dsh-quote/test_quote.py"],
               capture_output=True, text=True)
print("  已取消跟踪")

# 确认
r2 = subprocess.run(["git", "-C", "/opt/dafeiyu", "ls-files"],
                    capture_output=True, text=True)
left = [l for l in r2.stdout.splitlines() if "test_quote" in l]
print(f"  仍跟踪: {left if left else '无 ✅'}")
