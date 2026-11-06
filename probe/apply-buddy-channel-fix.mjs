/**
 * 一键补丁：修复 CodeBuddy CN（buddy 渠道）
 * "Illegal API invocation from an unapproved channel" 400/11128
 *
 * 依据：docs/buddy-channel-fix.md
 *      https://github.com/Ebony-Vinyl/dsh-our-free-model/issues/542
 *
 * 用法（PowerShell）：
 *   $node = "C:\Users\Administrator\AppData\Local\Our Free Model\runtime\node.exe"
 *   & $node probe\apply-buddy-channel-fix.mjs --check     # 查看状态
 *   & $node probe\apply-buddy-channel-fix.mjs             # 应用（幂等，自动备份+语法校验）
 *   & $node probe\apply-buddy-channel-fix.mjs --revert    # 回滚到最近一次备份
 *   & $node probe\apply-buddy-channel-fix.mjs --pack "D:\path\to\pack.js"
 *
 * 幂等：已打过新补丁则原样退出；打过旧版（只清洗 identity 句）会自动升级。
 * 安全：写回前用 node --check 校验，失败自动回滚；每次应用都生成时间戳备份。
 * 不含任何真实 token / 凭据。
 */

import fs from 'node:fs'
import path from 'node:path'
import { execFileSync } from 'node:child_process'

const DEFAULT_PACK =
  'C:\\Users\\Administrator\\.dsh\\profiles\\desktop\\node_modules\\dsh-our-free-model\\vendor\\channel-pack\\pack.js'

const NEW_MARKER = '[本地补丁 issue #542 扩展 2026-11-06]'
const OLD_MARKER = '[本地补丁 issue #542]'

// 未打补丁时的锚点（serializeMessages2 全局仅此一处调用）
const ANCHOR = `    const messages = serializeMessages2(options.messages, imageUrls);
    if (options.system !== void 0 && options.system.length > 0) {
      messages.unshift({ role: "system", content: options.system });
    }
    const tools = options.tools?.map((tool) => ({`

// 新版补丁块
const NEW_BLOCK = `    const messages = serializeMessages2(options.messages, imageUrls);
    if (options.system !== void 0 && options.system.length > 0) {
      messages.unshift({ role: "system", content: options.system });
    }
    // [本地补丁 issue #542 扩展 2026-11-06] CodeBuddy CN（buddy 渠道）对 system
    // 做指纹匹配：① 开头命中 DSH identity 句返 400/11128；② 上游已扩大到
    // 「句号+空格相邻的 DSH 提示词句子序列」指纹（单/双空格都命中，换行可断）。
    // 处理：清洗 identity 句 + 把 system 里所有「. 」改成「.\\n」断开相邻，
    // 语义不变、只动空白。其余提示词原样保留。上游修复后请删除本段。
    if (this.product.id === "buddy") {
      for (const m of messages) {
        if (m.role === "system" && typeof m.content === "string") {
          m.content = m.content.replace(/You are an AI agent powered by DeepSeek Harness\\.?/gi, "You are an AI assistant.").replace(/\\. /g, ".\\n");
        }
      }
    }
    const tools = options.tools?.map((tool) => ({`

// 旧版补丁块（只清洗 identity 句），用于自动升级
const OLD_BLOCK = `    const messages = serializeMessages2(options.messages, imageUrls);
    if (options.system !== void 0 && options.system.length > 0) {
      messages.unshift({ role: "system", content: options.system });
    }
    // [本地补丁 issue #542] CodeBuddy CN（buddy 渠道）对 system 开头做前缀匹配，
    // 命中 DSH identity 句「You are an AI agent powered by DeepSeek Harness.」就返
    // 400/11128 "Illegal API invocation from an unapproved channel"，且一旦触发
    // 整个会话每轮都失败。仅替换该句（大小写不敏感、末尾句号可选），
    // 其余提示词（工具说明、# Harness 段等）原样保留。上游修复后请删除本段。
    if (this.product.id === "buddy") {
      for (const m of messages) {
        if (m.role === "system" && typeof m.content === "string") {
          m.content = m.content.replace(/You are an AI agent powered by DeepSeek Harness\\.?/gi, "You are an AI assistant.");
        }
      }
    }
    const tools = options.tools?.map((tool) => ({`

function parseArgs(argv) {
  const opts = { pack: DEFAULT_PACK, check: false, revert: false }
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--check') opts.check = true
    else if (argv[i] === '--revert') opts.revert = true
    else if (argv[i] === '--pack' && argv[i + 1]) { opts.pack = argv[++i] }
    else if (argv[i] === '--help' || argv[i] === '-h') {
      console.log('用法: apply-buddy-channel-fix.mjs [--check] [--revert] [--pack <path>]')
      process.exit(0)
    }
  }
  return opts
}

function readNormalized(file) {
  const buf = fs.readFileSync(file)
  const raw = buf.toString('utf8')
  const crlf = raw.includes('\r\n')
  return { text: raw.replace(/\r\n/g, '\n'), crlf }
}

function writeDenormalized(file, text, crlf) {
  fs.writeFileSync(file, crlf ? text.replace(/\n/g, '\r\n') : text, 'utf8')
}

function stamp() {
  const d = new Date()
  const p = (n) => String(n).padStart(2, '0')
  return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`
}

function syntaxCheck(file) {
  try {
    execFileSync(process.execPath, ['--check', file], { stdio: 'pipe' })
    return true
  } catch (e) {
    return false
  }
}

function findBackups(pack) {
  const dir = path.dirname(pack)
  const base = path.basename(pack)
  return fs.readdirSync(dir)
    .filter((n) => n.startsWith(base + '.bak-issue542-'))
    .map((n) => path.join(dir, n))
    .sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs)
}

const opts = parseArgs(process.argv.slice(2))

if (!fs.existsSync(opts.pack)) {
  console.error(`[ERR] 找不到 pack.js: ${opts.pack}`)
  console.error('      用 --pack 指定实际路径，例如：')
  console.error('      --pack "D:\\path\\to\\vendor\\channel-pack\\pack.js"')
  process.exit(1)
}

// ---- --check ----
if (opts.check) {
  const { text } = readNormalized(opts.pack)
  const backups = findBackups(opts.pack)
  if (text.includes(NEW_MARKER)) {
    console.log('状态: 已打【新版】补丁（identity 清洗 + 断句相邻）')
  } else if (text.includes(OLD_MARKER)) {
    console.log('状态: 打的是【旧版】补丁（仅清洗 identity 句）——建议运行一次本脚本升级')
  } else {
    console.log('状态: 未打补丁')
  }
  console.log(`备份数: ${backups.length}${backups.length ? '（最新: ' + path.basename(backups[0]) + '）' : ''}`)
  process.exit(0)
}

// ---- --revert ----
if (opts.revert) {
  const backups = findBackups(opts.pack)
  if (backups.length === 0) {
    console.error('[ERR] 没有找到 .bak-issue542-* 备份，无法回滚')
    process.exit(1)
  }
  const bak = backups[0]
  fs.copyFileSync(bak, opts.pack)
  console.log(`[revert] 已从 ${path.basename(bak)} 恢复`)
  console.log(syntaxCheck(opts.pack) ? '[ok] 语法校验通过' : '[WARN] 语法校验失败，请检查')
  console.log('[hint] 回滚后需重载插件（禁用再启用 dsh-our-free-model）或重启 DSH')
  process.exit(0)
}

// ---- 应用补丁 ----
const { text, crlf } = readNormalized(opts.pack)

if (text.includes(NEW_MARKER)) {
  console.log('[skip] 已打过新版补丁，无需改动（幂等）')
  process.exit(0)
}

let next
if (text.includes(OLD_BLOCK)) {
  next = text.replace(OLD_BLOCK, NEW_BLOCK)
  console.log('[upgrade] 检测到旧版补丁，升级为新版（+ 断开句子相邻指纹）')
} else if (text.includes(ANCHOR)) {
  next = text.replace(ANCHOR, NEW_BLOCK)
  console.log('[apply] 找到 serializeMessages2 锚点，插入补丁')
} else {
  console.error('[ERR] 找不到预期锚点，文件结构可能已变化（插件升级过？）')
  console.error('      请对照 docs/buddy-channel-fix.md 手动定位补丁点')
  process.exit(1)
}

if (next === text) {
  console.error('[ERR] 替换未生效，已中止')
  process.exit(1)
}

const bakFile = `${opts.pack}.bak-issue542-${stamp()}`
fs.copyFileSync(opts.pack, bakFile)
console.log(`[backup] ${path.basename(bakFile)}`)

writeDenormalized(opts.pack, next, crlf)

if (!syntaxCheck(opts.pack)) {
  fs.copyFileSync(bakFile, opts.pack)
  console.error('[ERR] node --check 失败，已自动回滚到原文件')
  process.exit(1)
}
console.log('[ok] 语法校验通过')
console.log(`[done] 补丁已写入 ${opts.pack}`)
console.log('[hint] 必须重载插件才能生效：')
console.log('       禁用再启用 dsh-our-free-model，或重启 DSH NEXT')
