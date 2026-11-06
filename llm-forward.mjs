/**
 * 大肥鱼 QQ 机器人 · 本模型网关 TCP 转发
 *
 * 问题：DSH 的模型网关只监听 Windows 的 127.0.0.1:8326，
 *       且硬编码拒绝绑定非回环地址。
 *       Docker 容器和 WSL 都在别的网络命名空间，访问不到这个 127.0.0.1。
 *
 * 解决：在 Windows 侧起一个纯 TCP 转发，监听 0.0.0.0:18901，
 *       把流量转发到 127.0.0.1:8326。
 *       不需要管理员权限（用户态监听高位端口）。
 *       （2026-11-06：上游从 OFM 网关 18900 换成 DSH 网关 8326）
 *
 * 为什么不改 AstrBot 的 api_base 直接指向宿主：容器访问宿主机要用
 *       vEthernet 地址（172.17.144.1）或 host.docker.internal，
 *       而网关不监听那些地址。必须有这一层转发。
 *
 * 由 guard.sh 拉起；独立运行，崩溃后由守护重启。
 */

import net from 'node:net'

const LISTEN_HOST = '0.0.0.0'
const LISTEN_PORT = 18901
const TARGET_HOST = '127.0.0.1'
const TARGET_PORT = 8326

const server = net.createServer((client) => {
  const upstream = net.connect(TARGET_PORT, TARGET_HOST)

  client.on('error', () => {})
  upstream.on('error', () => { client.destroy() })

  client.pipe(upstream)
  upstream.pipe(client)

  const kill = () => { client.destroy(); upstream.destroy() }
  client.on('close', kill)
  upstream.on('close', kill)
})

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    // 已有实例在跑，正常退出即可
    process.exit(0)
  }
  console.error('forward error:', err.message)
  process.exit(1)
})

server.listen(LISTEN_PORT, LISTEN_HOST, () => {
  console.log(`forward ${LISTEN_HOST}:${LISTEN_PORT} -> ${TARGET_HOST}:${TARGET_PORT} ready`)
})
