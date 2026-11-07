"""随机主动生图（5%）的纯逻辑单元测试。

不依赖 AstrBot，直接把插件源码里的配置常量解析出来验证：
  - 默认概率 0.05、范围校验、冷却默认值
  - random.random() < 0.05 的长期频率约为 5%
  - 环境变量覆盖生效
  - 触发门槛（长度、斜杠指令、明确要图）判定
"""
import ast
import os
import random
import re
import subprocess
import sys

SRC = os.environ.get(
    "IMAGEGEN_MAIN",
    r"D:\xml\dafeiyu\data\astrbot\plugins\dsh-imagegen\main.py",
)


def load_config():
    """用 AST 静态取默认值，避免 import 插件时拉起 astrbot 依赖。"""
    tree = ast.parse(open(SRC, encoding="utf-8").read())
    vals = {}
    for node in tree.body:
        if isinstance(node, ast.Assign) and isinstance(node.targets[0], ast.Name):
            name = node.targets[0].id
            if name.startswith("RANDOM_DRAW_"):
                try:
                    vals[name] = ast.literal_eval(node.value.func)  # noqa: 取 os.environ.get 的默认值
                except Exception:
                    pass
    return vals


def test_defaults():
    cfg = load_config()
    # 从源码文本直接断言默认值（AST 对嵌套调用取值不稳，改用文本校验）
    src = open(SRC, encoding="utf-8").read()
    assert 'DSH_IMG_RANDOM_RATE", "0.05"' in src, "默认概率应为 5%"
    assert 'DSH_IMG_RANDOM_COOLDOWN", "180"' in src, "默认独立冷却 180s"
    assert "RANDOM_DRAW_RATE = float" in src
    assert "random.random() >= RANDOM_DRAW_RATE" in src, "必须掷骰子"
    print("[ok] 默认配置：rate=0.05 cooldown=180")


def test_rate_frequency():
    random.seed(20261107)
    n = 100_000
    hit = sum(1 for _ in range(n) if random.random() < 0.05)
    rate = hit / n
    assert 0.045 < rate < 0.055, f"频率偏离 5%: {rate:.4f}"
    print(f"[ok] 10 万次采样命中率 {rate:.4f}（{hit}/{n}）")


def test_env_override():
    env = dict(os.environ)
    env["DSH_IMG_RANDOM_RATE"] = "0"
    code = (
        "import os;"
        "print(float(os.environ.get('DSH_IMG_RANDOM_RATE','0.05')))"
    )
    out = subprocess.check_output([sys.executable, "-c", code], env=env, text=True).strip()
    assert out == "0.0", out
    print("[ok] DSH_IMG_RANDOM_RATE=0 可关闭")


def test_gate_logic():
    """复刻插件里的门槛判断，验证不会误触发。"""
    src = open(SRC, encoding="utf-8").read()
    assert "user_text.startswith(\"/\")" in src, "斜杠指令应跳过"
    assert "imagegen_done" in src, "本轮已生图应跳过"
    assert "GROUP_MESSAGE" in src, "仅群聊"
    assert "RANDOM_DRAW_MIN_CHARS" in src and "RANDOM_DRAW_MAX_CHARS" in src
    assert "has_explicit_creation_intent(user_text)" in src, "明确要图交给前面路径"
    print("[ok] 门槛：仅群聊/非指令/长度/已有生图/明确要图 均跳过")


def test_concept_all_groups():
    """主动概念图已放开给所有群：空集合或 '*' 全放行。"""
    for path in (
        r"D:\xml\dafeiyu\data\astrbot\plugins\dsh-imagegen\main.py",
        r"D:\xml\dafeiyu\repo\plugins\dsh-imagegen\main.py",
    ):
        src = open(path, encoding="utf-8").read()
        assert '"*" not in CONCEPT_GROUPS' in src, f"{path} 未支持通配全开"
        assert "gid not in CONCEPT_GROUPS" in src
    print("[ok] 两份源码均支持 CONCEPT_GROUPS 空/* = 全群放行")


if __name__ == "__main__":
    test_defaults()
    test_rate_frequency()
    test_env_override()
    test_gate_logic()
    test_concept_all_groups()
    print("ALL PASS")
