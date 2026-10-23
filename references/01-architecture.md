# 01 · 整体架构

## 进程树（实机）

```
Termux (com.termux, 非 root)
├─ termux-wake-lock                    ← 阻止 Android 冻结 Termux
├─ watchdog.sh                         每 60s 巡检，主循环常驻
│
├─ proot-distro login ubuntu -- /root/run_qq.sh
│    └─ supervisor.sh:  while true → xvfb-run /opt/QQ/qq --no-sandbox
│         └─ QQ 主进程
│              └─ NapCat 注入模块
│                   ├─ OneBot HTTP  :3000
│                   ├─ OneBot WS    :3001
│                   └─ NapCat WebUI http://127.0.0.1:6099
│
└─ proot-distro login ubuntu -- /root/bot/run_bot.sh
     └─ run_bot.sh:     while true → python3 /root/bot/bot.py
          └─ bot.py  ── WS 连 127.0.0.1:3001
```

**关键点：QQ 和 bot 跑在同一个 proot 容器里**，所以 bot 连 NapCat 用 `127.0.0.1` 即可，不需要端口映射到局域网。这也顺带消除了把 OneBot 端口暴露出去的风险。

## 端口

| 端口 | 服务 | 可见范围 |
| --- | --- | --- |
| 3000 | OneBot HTTP | 容器内 |
| 3001 | OneBot WebSocket | 容器内（bot 用这个） |
| 6099 | NapCat WebUI | 容器内，**token 每次启动都变**，要从 qq.log 捞 |

## 数据流

```
QQ 消息 ──► NapCat ──WS──► bot.py
                             ├─ 入口过滤（注入/任务型请求）
                             ├─ 记忆读取（按 QQ 号）
                             ├─ DeepSeek API 调用
                             ├─ 表情包决策（强制 / 概率 / 冷却）
                             └─ 语音决策（mirror / always / off）
                                    │
                                    ▼
                              edge-tts 合成 mp3
                                    │
      ◄──── NapCat ◄── 文本 / 图片 / 语音 ──┘
```

## 路径约定

Termux 侧：

```
/data/data/com.termux/files/home              Termux home（$HOME）
  ├─ .termux/boot/start-qq.sh                 Termux:Boot 开机入口
  ├─ start-all.sh                             一键起全套
  ├─ watchdog.sh                              巡检脚本
  └─ watchdog.log / boot.log / qq_daemon.log  各层日志
```

容器侧（rootfs = `$PREFIX/var/lib/proot-distro/containers/ubuntu/rootfs`）：

```
<rootfs>/opt/QQ                                             Linux QQ
<rootfs>/opt/QQ/resources/app/app_launcher/napcat           NapCat
<rootfs>/root/run_qq.sh                                     QQ 入口（含 -q 免扫码参数）
<rootfs>/root/supervisor.sh                                 QQ 守护循环
<rootfs>/root/logs/qq.log                                   QQ 日志
<rootfs>/root/bot/bot.py                                    bot 主程序
<rootfs>/root/bot/tts.py                                    TTS 模块
<rootfs>/root/bot/run_bot.sh                                bot 守护循环
<rootfs>/root/bot/data/config.json                          用户覆盖配置
<rootfs>/root/bot/data/history.json                         记忆
<rootfs>/root/bot/data/logs/YYYY-MM-DD.jsonl                聊天备份
<rootfs>/root/bot/data/stickers/                            表情包池
<rootfs>/root/bot/data/tts/                                 语音缓存
```

## 启动链路（全自动）

```
开机
 └─ Termux:Boot
      └─ ~/.termux/boot/start-qq.sh
           ├─ termux-wake-lock
           ├─ sleep 20                      ← 等系统把网络和存储挂好
           ├─ proot 会话1：run_qq.sh        → supervisor → xvfb + QQ + NapCat
           ├─ sleep 5
           └─ proot 会话2：run_bot.sh       → bot.py 连 WS
```

`start-all.sh` 是同一套流程的手动版（多一个 watchdog 会话），开机脚本不启 watchdog，由 Termux 会话自身承载。
