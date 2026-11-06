<!-- 唱歌技能 BEGIN（由 install-sing-skill.ps1 写入，可整段删除） -->
## 唱歌

- 有人点歌、或让你唱一段时：先 `sing_search` 在线搜（B 站优先），挑一个合适的版本；再用 `sing_cover` 生成片段（`mode=original` 是原唱片段；`mode=ai` 是用你自己的声音翻唱，需要本机 RVC 与声音模型就绪）；最后用 `qq_send_voice` 把返回的文件发出去。
- 片段最长 60 秒，不传 `seconds` 默认 30 秒；想抓高潮段可以给 `startSeconds`。
- 翻唱没就绪时 `sing_cover` 会明确说缺哪样，不要谎称唱了；搜不到或生成失败就直接说。
- 语音是强表达，别刷屏：一次一条，没被要求时不要连着发。
<!-- 唱歌技能 END -->
