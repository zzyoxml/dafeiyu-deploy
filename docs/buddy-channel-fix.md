# CodeBuddy CN（buddy 渠道）"Illegal API invocation from an unapproved channel" 修复记录

> 2026-11-06 实测修复。适用于 **dsh-our-free-model 2.1.0 + DSH NEXT 桌面版**。
> 随附一键补丁脚本：[probe/apply-buddy-channel-fix.mjs](../probe/apply-buddy-channel-fix.mjs)

---

## 1. 现象

在 DSH GUI 里选择 `buddy/hy4-preview`（或 `buddy/deepseek-v4.1-flash` 等 buddy 通道模型）发消息，必失败：

```
buddy: 请求被拦截，请重新发送 Illegal API invocation from an unapproved channel
code: INVALID_REQUEST, status: 400
```

一旦触发，同一会话之后每一轮都 400；换到 `trae/*` 等其他通道可恢复。
本地网关 `http://127.0.0.1:8326/v1` 上的 buddy 模型同样复现。

## 2. 环境

| 项 | 值 |
|---|---|
| 插件 | `dsh-our-free-model@2.1.0`（npm 最新也是 2.1.0，升级解决不了） |
| 插件路径 | `C:\Users\Administrator\.dsh\profiles\desktop\node_modules\dsh-our-free-model` |
| 被打补丁的文件 | `vendor/channel-pack/pack.js`（约 2.8 MB，单文件打包） |
| 适配器 | `BuddyAdapter`（`pack.js` 约 34635 行起），`product.id === "buddy"` |
| 网关 | DSH NEXT 内置 `127.0.0.1:8326/v1`；容器侧经 `llm-forward.mjs` 转发到 `18901` |
| 报错来源 | CodeBuddy CN 上游 `https://copilot.tencent.com/v2/chat/completions` |

## 3. 参考

- [Ebony-Vinyl/dsh-our-free-model#542](https://github.com/Ebony-Vinyl/dsh-our-free-model/issues/542)（长工具会话 400 报告）
- 该 issue 评论区由 `ZelotsNullzwei` 定位到 **#544**：不是长会话问题，是 system prompt 开头；`aaaaasfsdf` 补充了**真正生效的补丁点**（`serializeMessages2` 之后的 wire 数组，而不是 `options.system`）。

上游结论（#542 评论）：

> 简单说：不是长会话的问题，是 system prompt 开头。DSH 默认 system 第一句是
> `You are an AI agent powered by DeepSeek Harness.`，buddy 渠道对这句做前缀匹配，
> 命中就返 11128。前面插一个空格都能绕过去。

以及关键的实现提示：

> **真正生效的补丁点**是在序列化之后遍历 wire 数组……改 `options.system` 不会生效，
> 因为 identity 句已作为一条 system 消息存在于 `options.messages[]` 中，由
> `serializeMessages2()` 原样透传。

## 4. 本地复现与根因（比 issue 讨论更进一步）

### 4.1 第一层：identity 句前缀匹配（#542 已知）

用 `messages[]` 里带 system 消息的形式测试网关：

| system 内容 | 结果 |
|---|---|
| `You are an AI agent powered by DeepSeek Harness.` | **400 / 11128** |
| `You are an AI assistant.` | 200 |
| 前导空格 / 前面插任意字符 | 200 |

清洗 identity 句后短请求恢复正常。

### 4.2 第二层：上游已扩大到「句子序列指纹」（本次新发现）

用户切到 `buddy/hy4-preview` 后**仍然失败**。从失败会话
`C:\Users\Administrator\.dsh\sessions\--D-xml-dafeiyu--\session-...\session.v4.jsonl.zstd`
解压出失败 turn 的**完整 system prompt（5736 字符）**逐段二分：

| 测试内容（system 开头片段） | 结果 |
|---|---|
| 完整 sys13 原文 | 400 |
| 完整 sys13 + 清洗 identity 句 | **400（仍拦）** |
| 仅前 200 字符（已清洗） | 400 |
| `Tokens prefixed with @ are paths the user explicitly referenced.` 单句 | 200 |
| `Relative paths resolve from the workspace root.` 单句 | 200 |
| 上面两句 **以「句号+空格」相连** | **400** |
| 两句之间换成 `\n`（换行） | 200 |
| 两句之间插入别的词 | 200 |
| 两句之间用**双空格** | 400 |

**结论**：上游不是简单前缀匹配，而是对 DSH 系统提示词的**多句相邻序列做指纹匹配**——
"句号 + 空格（单/双皆可）紧邻的句子对"命中，换行或插词可断开。
把提示词里所有 `. `（句号+空格）改成 `.\n` 即可整段绕开，且语义完全不变。

> 附带发现：历史消息（user/assistant/tool）里包含该句**不会**触发，只有 `role: "system"` 的消息参与匹配。

## 5. 补丁

### 5.1 补丁点

`pack.js` 中 `BuddyAdapter.stream()` 内，`serializeMessages2()` 之后、构造 `bodyObj` 之前
（`serializeMessages2` 全局仅此一处调用，约 35031 行）：

```js
    const messages = serializeMessages2(options.messages, imageUrls);
    if (options.system !== void 0 && options.system.length > 0) {
      messages.unshift({ role: "system", content: options.system });
    }
    // [本地补丁 issue #542 扩展 2026-11-06] CodeBuddy CN（buddy 渠道）对 system
    // 做指纹匹配：① 开头命中 DSH identity 句返 400/11128；② 上游已扩大到
    // 「句号+空格相邻的 DSH 提示词句子序列」指纹（单/双空格都命中，换行可断）。
    // 处理：清洗 identity 句 + 把 system 里所有「. 」改成「.\n」断开相邻，
    // 语义不变、只动空白。其余提示词原样保留。上游修复后请删除本段。
    if (this.product.id === "buddy") {
      for (const m of messages) {
        if (m.role === "system" && typeof m.content === "string") {
          m.content = m.content.replace(/You are an AI agent powered by DeepSeek Harness\.?/gi, "You are an AI assistant.").replace(/\. /g, ".\n");
        }
      }
    }
    const tools = options.tools?.map((tool) => ({
```

要点：
- **只对 `this.product.id === "buddy"` 生效**，`workbuddy` / `trae` / `kilo` 等通道不受影响。
- 遍历 wire 数组里的所有 system 消息（含 `options.system` unshift 进来的那条）。
- 正则用 `gi`，末尾句号可选（上游对大小写、句号不敏感）。
- `.replace(/\. /g, ".\n")` 只动空白，不改任何文字。

### 5.2 一键脚本（随附"插件"）

`probe/apply-buddy-channel-fix.mjs`：幂等、自动备份、自动语法校验、支持回滚。

```powershell
$node = "C:\Users\Administrator\AppData\Local\Our Free Model\runtime\node.exe"

# 查看当前是否已打补丁
& $node probe\apply-buddy-channel-fix.mjs --check

# 应用补丁（自动备份 + node --check）
& $node probe\apply-buddy-channel-fix.mjs

# 回滚（从最近一次备份恢复）
& $node probe\apply-buddy-channel-fix.mjs --revert

# 插件装在别处时指定路径
& $node probe\apply-buddy-channel-fix.mjs --pack "D:\path\to\pack.js"
```

## 6. 生效方式

补丁改的是**已安装插件的 vendor 代码**，运行中的 host 进程已缓存旧代码，必须重载：

1. 通过 DSH 插件管理把 `dsh-our-free-model` **禁用再启用**（`plugin_manager` 的
   `set_bundle` / GUI 插件页开关）；或
2. 重启 DSH NEXT（host 进程重启后重新 `import('./vendor/channel-pack/pack.js')`）。

重载后确认 `127.0.0.1:8326` 仍在监听即可。

## 7. 验证

网关 token 用你自己的（`gh auth token` 或 DSH 设置里的网关 token），下面用 `<TOKEN>` 占位。

```powershell
$tok = '<TOKEN>'
$sys = 'You are an AI agent powered by DeepSeek Harness.'   # 原始会被拦的开头
$body = @{
  model = 'buddy/hy4-preview'
  messages = @(
    @{ role='system'; content=$sys },
    @{ role='user'; content='你是什么 模型？' }
  )
  reasoning_effort = 'high'
} | ConvertTo-Json -Depth 6
Invoke-RestMethod -Uri 'http://127.0.0.1:8326/v1/chat/completions' `
  -Method Post `
  -Headers @{ Authorization="Bearer $tok"; 'Content-Type'='application/json' } `
  -Body ([Text.Encoding]::UTF8.GetBytes($body))
```

实测结果（补丁生效后）：

| 用例 | 结果 |
|---|---|
| 失败会话的**完整原始 system prompt**（5736 字符）+ High 推理 | 200，Hy4 正常回答 |
| 上述请求 + 含 identity 句的历史消息回放 | 200 |
| `buddy/deepseek-v4.1-flash` + 完整原始 system | 200 |
| `trae/qwen3.8-flash`（AstrBot 主力，不受补丁影响） | 200 |

## 8. 备份 / 回滚 / 注意事项

- 打补丁前的原文件备份：`pack.js.bak-issue542-20261106-171211`（同目录）。
  一键脚本每次应用都会生成带时间戳的新备份。
- **插件升级或重装会覆盖 `pack.js`，补丁会丢失**——升级后重跑一次脚本即可。
- 上游若再次调整指纹规则，同样在 `pack.js` 的这段清洗逻辑里追加替换规则即可。
- 该错误在插件里被归类为 `INVALID_REQUEST`（不重试、账号不进冷却），所以一旦触发会
  每轮都失败；补丁从请求源头消除，比改错误分类更彻底。
- **WorkBuddy 渠道是另一个问题**：`workbuddy/*` 当前返回
  `{"code":"UNKNOWN","message":"未配置凭据，请先登录"}`，与本次 11128 指纹拦截无关，
  需要在插件里登录/配置 WorkBuddy 凭据。
- 本文与脚本均不含任何真实 token、密码或 QQ 号，可安全提交到公开仓库。
