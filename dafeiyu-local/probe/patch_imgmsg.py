# -*- coding: utf-8 -*-
"""把生图失败的技术报错改成群友看得懂的人话。

原来群里看到：
    画失败了：未配置生图 API Key（环境变量 DSH_IMG_API_KEY）
这是给运维看的，群友完全不知道发生了什么，还以为机器人坏了。

改法：把「未配置 key」翻译成「我还没装画笔」，
其他技术错误也只露一句人话，细节只写进日志（管理员去查）。
"""
import sys

P = '/AstrBot/data/plugins/dsh-imagegen/main.py'
src = open(P, encoding='utf-8').read()
orig = src

# 1) 无 key 时的内部错误串：保持技术描述（进日志），
#    但在对用户回话处翻译成人话。
OLD = '''        return None, "未配置生图 API Key（环境变量 DSH_IMG_API_KEY）"'''
NEW = '''        return None, "NO_KEY"'''
if OLD not in src:
    print('MISS 1'); sys.exit(1)
src = src.replace(OLD, NEW, 1)

# 2) /画图 指令的失败回话
OLD2 = '''            yield event.plain_result(f"画失败了：{err[:200]}")'''
NEW2 = '''            # 群友不需要看到环境变量名和 HTTP 细节。
            # 真正的错误写进日志，群里只回一句能看懂的话。
            logger.warning("[imagegen] 出图失败：%s", str(err)[:300])
            if "NO_KEY" in str(err):
                yield event.plain_result(
                    "我还没装画笔 —— 生图的 key 没配上，现在只会聊天不会画画。"
                )
            elif "timeout" in str(err).lower() or "超时" in str(err):
                yield event.plain_result("画笔卡住了，等会儿再让我画一次试试。")
            else:
                yield event.plain_result("这张没画出来，换个说法我再试试？")'''
if OLD2 not in src:
    print('MISS 2'); sys.exit(1)
src = src.replace(OLD2, NEW2, 1)

open(P, 'w', encoding='utf-8').write(src)
import ast
ast.parse(src)
print('OK: 报错文案已改成人话')
print('  原始 %d -> 现在 %d 字节' % (len(open(P + '', encoding='utf-8').read()) and len(orig), len(src)))
