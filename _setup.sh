#!/usr/bin/env bash
# 大肥鱼 QQ 机器人 · 本地部署初始化（幂等）
set -euo pipefail

REPO="${1:-/opt/dafeiyu/repo}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

say "检查 Docker"
docker info >/dev/null 2>&1 || die "Docker 未运行或无权限"

say "准备数据目录"
mkdir -p data/napcat data/astrbot/plugins

say "准备 OneBot 配置与 Token"
if [ -f data/napcat/onebot11.json ]; then
  TOKEN="$(python3 -c "import json;print(json.load(open('data/napcat/onebot11.json'))['token'])" 2>/dev/null || echo "")"
  [ -n "$TOKEN" ] || TOKEN="qqbot_fallback_$(head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  say "已存在，保留原 Token"
else
  TOKEN="qqbot_$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  python3 - "$TOKEN" <<'PY'
import json, sys
tok = sys.argv[1]
cfg = {
    "http": {"enable": False, "host": "0.0.0.0", "port": 3000, "secret": "", "heartbeat_interval": 5000},
    "ws": {"enable": True, "host": "0.0.0.0", "port": 3001},
    "reverse_ws": {"enable": False, "url": ""},
    "token": tok,
}
with open("data/napcat/onebot11.json", "w", encoding="utf-8") as f:
    json.dump(cfg, f, ensure_ascii=False, indent=2)
PY
  chmod 600 data/napcat/onebot11.json
  printf '%s' "$TOKEN" > data/napcat/.token
  chmod 600 data/napcat/.token
  say "已生成新 Token"
fi

say "准备 robot.env"
if [ -f robot.env ]; then
  say "已存在，保持不变"
else
  cp robot.env.template robot.env
  chmod 600 robot.env
  say "已从模板生成 robot.env"
fi

say "拷贝插件（只拷 dsh-* 目录，跳过仓库自带的测试脚本）"
existing=$(find data/astrbot/plugins -maxdepth 1 -name 'dsh-*' -type d | wc -l)
if [ "$existing" -gt 0 ]; then
  say "已有 $existing 个插件，跳过"
else
  for d in "$REPO"/plugins/dsh-*; do
    cp -r "$d" data/astrbot/plugins/
  done
  say "已拷贝 $(find data/astrbot/plugins -maxdepth 1 -name 'dsh-*' -type d | wc -l) 个插件"
fi

say "完成"
echo
echo "OneBot Token（填 AstrBot OneBot V11 适配器时用）："
echo "  $TOKEN"
echo
echo "下一步："
echo "  1) nano robot.env      填 DSH_ACL_OWNER=你的QQ号"
echo "  2) docker compose up -d"
echo "  3) 浏览器 http://localhost:3001  扫码登录 QQ 小号"
echo "  4) 浏览器 http://localhost:6185  配置 AstrBot"