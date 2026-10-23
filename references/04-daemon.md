# 04 · 开机自启与进程守护

手机方案最容易翻车的不是「怎么装」，而是「**它凭什么一直活着**」。这一节是整套部署的核心。

## 四层防线

| 层 | 手段 | 解决什么 |
| --- | --- | --- |
| 1 | Termux:Boot + `~/.termux/boot/start-qq.sh` | 手机重启后自动拉起 |
| 2 | `termux-wake-lock` | 阻止 Android 冻结 Termux（息屏掉线） |
| 3 | 各层 `while true` 重启循环 | 单进程崩溃自愈 |
| 4 | `watchdog.sh` 每 60s 巡检 | proot 会话整体消失时重建 |

少任何一层都会出现「看起来在跑，其实早掉了」的情况。

## 第 1 层：开机自启

Termux:Boot 会在开机后执行 `~/.termux/boot/` 下的所有脚本。

```bash
#!/data/data/com.termux/files/usr/bin/bash
export PREFIX=/data/data/com.termux/files/usr
export HOME=/data/data/com.termux/files/home
export PATH=/data/data/com.termux/files/usr/bin:/system/bin
export LD_LIBRARY_PATH=/data/data/com.termux/files/usr/lib
sleep 20                                  # 等系统挂好网络与存储
termux-wake-lock 2>/dev/null
setsid nohup proot-distro login ubuntu -- /bin/bash /root/run_qq.sh  > $HOME/qq_daemon.log  2>&1 < /dev/null &
sleep 5
setsid nohup proot-distro login ubuntu -- /bin/bash /root/bot/run_bot.sh > $HOME/bot_daemon.log 2>&1 < /dev/null &
```

### 为什么必须 `setsid nohup ... < /dev/null`

这是整份文档里最值钱的一条经验：

- `setsid`：脱离当前会话，避免脚本退出时把子进程一起带走
- `nohup`：忽略 SIGHUP
- **`< /dev/null`**：把 stdin 接上 /dev/null。**漏掉它，proot 会话在父 shell 结束后会被回收**，表现为「刚启动就没了」或「重启后 QQ 不在了」

三个缺一不可。

## 第 2 层：wake-lock

```bash
termux-wake-lock          # 加锁
termux-wake-unlock        # 解锁（一般不需要）
```

不调用的话，Android 的 Doze / 省电策略会在息屏几分钟后冻结 Termux 进程树 —— 表现是「亮屏就回消息，息屏就不回」。

配套系统设置：

- 设置 → 电池 → 关闭 Termux 的智能省电 / 后台限制
- 开发者选项 → 保持唤醒（充电时不休眠）
- vivo 等国产 ROM 还需在「自启动管理」里放行 Termux 与 Termux:Boot

## 第 3 层：进程内重启循环

**QQ 层**（容器内 `supervisor.sh`）：

```bash
while true; do
  xvfb-run -a -s "-screen 0 720x1280x24" /opt/QQ/qq --no-sandbox >> /root/logs/qq.log 2>&1
  echo "=== QQ exited rc=$? $(date), restart in 10s ===" >> /root/logs/qq.log
  sleep 10
done
```

**bot 层**（容器内 `run_bot.sh`）：

```bash
while true; do
  python3 /root/bot/bot.py >> /root/bot/data/stdout.log 2>&1
  echo "=== bot exited rc=$? $(date), restart in 5s ===" >> /root/bot/data/bot.log
  sleep 5
done
```

## 第 4 层：看门狗（Termux 侧）

```bash
while true; do
  if ! pgrep -f "run_qq.sh" >/dev/null 2>&1; then
    setsid nohup proot-distro login ubuntu -- /bin/bash /root/run_qq.sh > $HOME/qq_daemon.log 2>&1 < /dev/null &
    sleep 10
  fi
  if ! pgrep -f "run_bot.sh" >/dev/null 2>&1; then
    setsid nohup proot-distro login ubuntu -- /bin/bash /root/bot/run_bot.sh > $HOME/bot_daemon.log 2>&1 < /dev/null &
    sleep 8
  fi
  sleep 60
done
```

### 为什么用 `pgrep -f 脚本名` 而不是查进程端口

端口探测（`curl 3001`）在 NapCat 正在重连时会误判并触发重复拉起，反而把系统搞乱。检查**守护脚本本身还在不在**更稳，也更便宜。

## 电源：被低估的故障源

手机当服务器，充电器是消耗品。项目里专门跑了 `battery-watch.log` 记录电量趋势。

**症状**：机器人跑几天后莫名掉线，看日志是进程被系统干掉。
**原因**：充电器功率不足，亮屏时耗电 > 充电，电量缓慢下降，系统进入省电模式杀后台。
**处理**：换足功率充电器 + 关闭亮屏常亮 + 观察 `battery-watch.log` 是否维持 100%。
