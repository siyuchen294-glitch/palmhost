# 09 · 运维与排障

## 日志地图

| 日志 | 位置 | 看什么 |
| --- | --- | --- |
| QQ 主日志 | `<rootfs>/root/logs/qq.log` | 是否停在二维码、NapCat 是否注入成功 |
| bot 运行日志 | `<rootfs>/root/bot/data/bot.log` | 启动/退出记录、`[llm Xms]` 延迟 |
| bot stdout | `<rootfs>/root/bot/data/stdout.log` | Python 异常栈 |
| 看门狗 | `~/watchdog.log` | 什么时候拉起过什么 |
| 开机 | `~/boot.log` | 开机脚本是否执行 |
| 电量 | `<项目>/battery-watch.log` | 充电是否跟得上 |

`<rootfs>` = `/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs`

## 常用 adb 命令

```powershell
$adb = '<项目>\tools\platform-tools\adb.exe'
$h   = '/data/data/com.termux/files/home'
$R   = '/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs'

# 看 bot 日志
& $adb shell run-as com.termux tail -30 "$R/root/bot/data/bot.log"

# 看 QQ 日志
& $adb shell run-as com.termux tail -50 "$R/root/logs/qq.log"

# 一键起全套
& $adb shell run-as com.termux /data/data/com.termux/files/usr/bin/bash "$h/start-all.sh"

# 看进程
& $adb shell run-as com.termux ps -ef | Select-String "run_qq|run_bot|watchdog"

# 看剩余空间
& $adb shell -d "df -h /data"
```

## 三条恢复路径（从轻到重）

| 脚本 | 作用 | 什么时候用 |
| --- | --- | --- |
| `restart2.sh` | 只重启 QQ | 掉线、卡在二维码 |
| `restore.sh` | 清理临时文件 + 起 QQ + bot + watchdog | 常规恢复 |
| `start-all.sh` | 全量拉起 | 手机重启后、或一切都不明原因 |

## 管理员命令速查

私聊或群聊发（群里发命令只走私聊回执）：

```
/status                      运行状态
/persona [set <内容>]        人设
/model /temp /turns /limit   模型参数
/sticker [prob|cd|clear]     表情包
/voice off|mirror|always     语音模式
/voice name <音色>            换音色
/group list|add|del|mode|state|engage|mute|sleep|rate
/friends /approve <n> /reject <n> /autoapprove on|off
/logs [QQ] [条数] /backup    聊天记录与备份
/mem [clear <QQ>] /reset     记忆管理
/status /config              状态与完整配置
```

## 排障对照表

| 现象 | 先看 | 处理 |
| --- | --- | --- |
| 完全不回 | `pgrep run_qq` `pgrep run_bot` | 缺哪个重启哪个 |
| QQ 在但 bot 不回 | bot.log 有没有异常栈 | 看 stdout.log，多是 API key 失效或网络 |
| 群里不回（私聊正常） | `/group state <群号>` | 可能处于静默/休眠，或限流中 |
| 回复慢 | `[llm Xms]` | 正常 1–2s；明显变慢是网络或 API 限流 |
| 语音发不出 | bot.log 的 tts 段 | edge-tts 网络问题，会自动降级纯文字 |
| 空间不足 | `df -h /data` | 清 TTS 缓存、表情包池、pip cache |

## 记忆与备份

- **记忆**：按 QQ 号独立存 `history.json`，`{summary, msgs[]}`，超 6000 字自动压缩成 200 字要点
- **备份**：每条消息落 `data/logs/YYYY-MM-DD.jsonl`，`/backup` 可把当天文件直接发到 QQ

> 备份是纯文本 JSONL，出问题时可读性远好于数据库，强烈建议保留这个设计。
