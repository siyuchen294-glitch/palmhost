# 08 · 踩坑记录

按「症状 → 原因 → 解法」记录，都是真实发生过的。**如果你也这么干，大概率会踩到同样的坑。**

## 坑 1 · bot 连不上 NapCat（端口都不通）

**症状**：bot 日志刷 `Connection refused`，容器内 `curl 127.0.0.1:3001` 也不通。
**原因**：NapCat 的 OneBot 服务没在 QQ 启动后注入成功，或 WS 端口配成了 HTTP 口。
**排查**：
```bash
tail -50 /root/logs/qq.log | grep -i napcat   # 看有没有 "OneBot server started"
```
**解决**：确认 NapCat 配置里 `ws` 与 `http` 分开，bot 用 WS 3001；NapCat 注入失败时重启 QQ（`~/restart2.sh`）。

---

## 坑 2 · 重启后 QQ 不在了，但 bot 还在

**症状**：`pgrep -f run_bot.sh` 有，`pgrep -f run_qq.sh` 没有。
**原因**：开机脚本里漏了 `< /dev/null`，proot 会话被父进程回收。
**解决**：所有后台启动必须写成 `setsid nohup ... < /dev/null &`，三者缺一不可。详见 [04](04-daemon.md)。

---

## 坑 3 · 息屏 5 分钟就掉线

**症状**：亮屏立刻回消息，息屏就不回。
**原因**：Android Doze 冻结了 Termux 进程树。
**解决**：
1. `termux-wake-lock`（脚本里必须有）
2. 系统设置关闭 Termux 与 Termux:Boot 的电池优化
3. 国产 ROM 的自启动管理里放行

---

## 坑 4 · QQ 自动更新后 NapCat 失效

**症状**：某天开机后 QQ 起来了，但 OneBot 端口没了，NapCat 日志报注入失败。
**原因**：QQ 静默升级到新版本，`app_launcher` 结构变了，NapCat 补丁没打上。
**解决**：
- 锁定 QQ 版本（本项目锁 **3.2.32**）
- 关闭 QQ 自动更新
- 出事后回滚：重装对应版本 QQ → 重跑 `napcat-install.sh`

**教训：注入式方案必须锁版本，这是硬成本。**

---

## 坑 5 · pip 装 ChatTTS 时被 OOM 杀掉

**症状**：`pip install` 卡在 51% 左右，进程消失，无明确报错。
**原因**：pip 解包 torch（1.5G+）时需要大量内存，手机在解包阶段被内核 OOM killer 干掉。
**尝试过**：
- 加 swap → 有限改善，仍失败
- 电脑下载 wheel 再传 → ❌ 失败，**from/until 版本约束（`manylinux_2_28`）不匹配**
- 降版本 → 有进展，但最终性能仍不达标

**最终结论**：放弃了手机本地跑 ChatTTS，改用 edge-tts。**有些路验证到「不可行」就该停。**

---

## 坑 6 · 二维码看不到

**症状**：QQ 启动后终端没有二维码，或二维码一闪而过。
**原因**：xvfb 虚拟屏上的 GUI 内容不会自动打印到终端。
**解决**：用 adb 把截图拉到电脑看：
```powershell
& $adb shell screencap -p /sdcard/qr.png
& $adb pull /sdcard/qr.png .
```

---

## 坑 7 · 中文路径 / 中文文件名乱码

**症状**：adb push 后文件名变乱码，脚本找不到文件。
**原因**：Windows 终端默认代码页与 UTF-8 不一致。
**解决**：文件名尽量纯 ASCII；必须中文时，先在电脑侧编码成 base64 传输再解码。

---

## 坑 8 · 电量越充越少，然后掉线

**症状**：跑两天后机器人在深夜消失。
**原因**：充电器功率不足，亮屏耗电 > 充电功率，电量下降到触发省电策略。
**解决**：换足功率充电器，关掉屏幕常亮，用 `battery-watch.log` 盯电量曲线。

---

## 坑 9 · 配置改了不生效

**症状**：代码里改了默认参数，机器上还是老值。
**原因**：`config.json` 存了旧版全量快照，覆盖了新默认值。
**解决**：见 [05-配置管理](05-config.md)，`DEFAULTS` 唯一事实来源 + 只存 diff + `_version` 迁移。

---

## 坑 10 · `/persona` 能改出人格越界

**症状**：管理员改人设后，机器人开始接受「无视之前所有设定」这类指令。
**原因**：人设是软配置，被提示词注入绕过后就没有约束了。
**解决**：双层防护 —— 入口正则拦截 + `HARD_RULES` 写死在 system prompt 里，`/persona` 改不动。

---

## 坑 11 · 表情包池把手机存满

**症状**：若干周后 `df -h /data` 告急。
**原因**：`sticker_save_from_others` 会自动收录别人发的图，无上限增长。
**解决**：池子上限 100 张，FIFO 淘汰最旧；TTS 缓存的定期清理。

---

## 坑 12 · adb 连不上手机

**症状**：`adb devices` 空列表 / `unauthorized`。
**原因**：USB 线只供电不传数据、或 adb server 状态错乱。
**解决**：
```powershell
& $adb kill-server; & $adb start-server; & $adb devices
```
换数据线；手机端确认「允许 USB 调试」弹窗。
