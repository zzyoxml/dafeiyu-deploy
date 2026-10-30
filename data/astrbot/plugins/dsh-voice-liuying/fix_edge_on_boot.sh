#!/bin/bash
# 容器重建后镜像自带 edge-tts 7.2.7 会对 Bing 返回 403。
# 本脚本在插件初始化时由 _readiness 触发一次（也可手动跑）。
pip install --index-url https://pypi.tuna.tsinghua.edu.cn/simple -q -U edge-tts 2>/dev/null
