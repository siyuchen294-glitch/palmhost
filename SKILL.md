---
name: palmhost
description: 把一台闲置安卓手机变成 7×24 在线的 QQ AI 机器人宿主。通过 adb 连接手机，在机内搭建 Termux + proot Ubuntu + Linux QQ + NapCat + Python bot 的完整链路，做到开机自启、断线自愈、免扫码登录。当用户提到「用手机跑机器人」「闲置手机利用起来」「手机部署 QQ bot」「Termux 部署 NapCat」「把手机当服务器」「手机托管 bot」「安卓跑 AI 机器人」时使用本 skill。
disable-model-invocation: false
---

# 掌宿 · PalmHost

> **掌心即机房。** 一台躺抽屉里的安卓手机，变成 7×24 在线的机器人宿主。

你的任务不是「写一个机器人」，而是**把一台手机改造成能长期托管机器人的服务器**：装环境、拉起链路、上自启、上守护、验收。用户只需要做两次人工动作：扫码登录、以及在手机上点几个系统设置。

---

## 先判断这件事该不该做

开始前和用户确认三件事，**任何一个不成立就停下来**：

| 前置条件 | 为什么 |
| --- | --- |
| 有一台**闲置**安卓手机（Android 8+，能长期插电） | 主用机会被各种省电策略弄死，且你会上手改系统设置 |
| 用户**接受封号风险** | 个人 QQ 号跑协议侧机器人违反用户协议，这是硬事实，不是吓唬 |
| 用途是**自用聊天**，不是营销/引流 | 群发和加好友会显著提高封号概率，也违背这个 skill 的设计意图 |

如果用户只是想「用 AI 聊天」，其实不需要手机——直接用网页/客户端更省事。**手机方案的价值只有一个：7×24 在线且不占电脑。**

---

## 执行流程

严格按阶段推进。**每个 stage 结束必须先过 gate，不通过就不要进下一阶段**——手机环境的问题会层层放大，早发现比重装便宜得多。

### Stage 0 · 环境自检

```powershell
$adb = '<项目路径>\tools\platform-tools\adb.exe'
& $adb version
& $adb devices
```

**Gate**：`adb devices` 输出里出现 `<序列号>  device`。

- 显示 `unauthorized` → 让用户看手机屏幕，点「允许 USB 调试」
- 列表为空 → 90% 是**充电线不是数据线**；换线，再 `adb kill-server; adb start-server`
- 没有 adb → 让用户装 Android Platform Tools（或下载 Google 官方压缩包解压）

### Stage 1 · 装 Termux 三件套

**必须用 F-Droid 版 Termux**。Google Play 版已停止维护、签名不同、装不上插件——这是新手最常踩的第一个坑。

| APK | 作用 | 必需 |
| --- | --- | --- |
| Termux | 终端环境本体 | ✅ |
| Termux:Boot | 开机自启 | ✅ |
| Termux:Widget | 桌面一键启停 | 可选 |

```powershell
& $adb install -r termux-arm64.apk
& $adb install -r termux-boot.apk
```

装完**先让用户手动打开一次 Termux**（初始化文件系统，否则后续命令全失败）。

**Gate**：在 Termux 里敲 `echo ok` 有输出。

### Stage 2 · 系统设置（这一步不做，后面全白干）

引导用户在手机上设置，**逐条确认**：

1. 设置 → 应用 → Termux → 电池 → **不受限制 / 关闭智能省电**
2. 同上 → Termux:Boot → 关闭电池优化
3. 国产 ROM（vivo/小米/OPPO/华为）→ **自启动管理 / 后台运行白名单** 放行 Termux 与 Termux:Boot
4. 开发者选项 → **充电时不休眠**（保持唤醒）

**Gate**：用户明确回复「都设好了」。

> 这一 stage 看着琐碎，但它决定了后面「能不能息屏活着」。**绝大多数「跑一晚上就掉线」都是这里没做。**

### Stage 3 · Termux 内装 Linux 环境

```bash
pkg update -y && pkg upgrade -y
pkg install -y proot-distro termux-api
proot-distro install ubuntu
proot-distro login ubuntu
```

进容器后：

```bash
apt update && apt install -y xvfb wget curl python3 python3-pip fonts-noto-cjk
```

**Gate**：容器内 `python3 -V` 有版本输出；`fc-list | grep -i noto` 有中文字体。

### Stage 4 · 装 Linux QQ + 锁版本

装 aarch64 版 Linux QQ（deb 包 `dpkg -i`，或解包到 `/opt/QQ`）。

```bash
ls /opt/QQ/qq
```

**立刻关闭自动更新**——NapCat 是注入式方案，QQ 一升级注入点就变，机器人直接废。记下当前版本号并锁住。

**Gate**：`/opt/QQ/qq` 存在且可执行。

### Stage 5 · 装 NapCat 并配 OneBot

运行 NapCat 的 Shell 安装脚本，它会解到 `/opt/QQ/resources/app/app_launcher/napcat` 并给 QQ 打补丁。

OneBot 配置目标：

| 服务 | 端口 | 备注 |
| --- | --- | --- |
| HTTP | 3000 | 可选 |
| WebSocket | 3001 | **bot 用这个** |
| WebUI | 6099 | token 每次启动随机，从 qq.log 里捞 |

**必须设 OneBot token**，且**不要写死进代码或提交进仓库**（用环境变量）。

**Gate**：NapCat 启动日志出现 OneBot server started。

### Stage 6 · 首次扫码登录（唯一的人工环节）

```bash
xvfb-run -a -s "-screen 0 720x1280x24" /opt/QQ/qq --no-sandbox
```

xvfb 是虚拟屏，二维码不会自动打印到终端。**把屏幕截图拉到电脑上看**：

```powershell
& $adb shell screencap -p /sdcard/qr.png
& $adb pull /sdcard/qr.png .
```

扫码登录成功后，记下 QQ 号。**之后所有启动都带 `-q <QQ号>` 免扫码**——这是整套方案能无人值守的前提。

**Gate**：带 `-q` 重启一次，确认跳过二维码直接进主界面。

### Stage 7 · 部署 bot

在容器内建目录并把 bot 代码放进去：

```bash
mkdir -p /root/bot/data/{logs,stickers,tts}
```

**没有 ssh 时怎么传文件**：用 base64 管道。项目里所有 `.py` 都留一份 `.b64` 就是为这个准备的：

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('bot.py')) > bot.py.b64
```
```bash
base64 -d bot.py.b64 > /root/bot/bot.py
```

bot 需要的最小能力：连 WS 3001、按 QQ 号维护记忆、调 LLM、可选 TTS。

**Gate**：`python3 /root/bot/bot.py` 能连上 NapCat 且不报错退出。

### Stage 8 · 开机自启 + 守护

按 [references/04-daemon.md](references/04-daemon.md) 部署四层防线，脚本在 [scripts/](scripts/)。

```bash
mkdir -p ~/.termux/boot
cp scripts/boot-qq.sh ~/.termux/boot/start-qq.sh
chmod +x ~/.termux/boot/start-qq.sh
```

**Gate**：`pgrep -f run_qq.sh` 与 `pgrep -f run_bot.sh` 都有进程。

### Stage 9 · 验收（7 项，逐条打勾）

- [ ] QQ 与 bot 进程都在
- [ ] `tail /root/logs/qq.log` 没有停在二维码
- [ ] 私聊发一条，机器人能回
- [ ] **锁屏息屏 5 分钟后仍能回** ← 最容易被跳过，也最容易失败
- [ ] 手机重启后自动恢复，无需人工
- [ ] `df -h /data` 剩余 > 3G
- [ ] 守护日志没有异常重启风暴

前 6 项全绿才算交付。第 4 项不过就回去查 Stage 2 和 wake-lock。

---

## 六条铁律

违反任何一条，这套东西都活不过一周。

1. **后台启动必须写全 `setsid nohup ... < /dev/null &`**
   三个缺一不可。尤其是 `< /dev/null`——漏掉它，proot 会话会在父 shell 退出时被回收，表现为「刚起来就没了」。

2. **`termux-wake-lock` 必须调**
   不调则 Android Doze 冻结 Termux，症状是「亮屏立刻回、息屏不回」。

3. **QQ / bot / 看门狗三层都要有重启循环**
   只靠外层看门狗会有几十秒空窗；只靠内层循环则整个 proot 会话消失时没人重建。

4. **配置只持久化「与默认值的差异」**
   整份写盘会导致代码里改了新默认值却被旧文件永久锁死。详见 [references/05-config.md](references/05-config.md)。

5. **锁死 QQ 版本，关闭自动更新**
   注入式方案的宿命成本。

6. **密钥不进代码、不进仓库、不进日志**
   API key / OneBot token 走环境变量。怀疑泄露就去服务商后台**吊销重发**，不要在本地修补。

---

## 排障

遇到问题先查 → [references/08-pitfalls.md](references/08-pitfalls.md)（12 个真实故障）

常见症状速查：

| 症状 | 先怀疑 |
| --- | --- |
| 完全没反应 | 进程没了 → 看 `pgrep` |
| 亮屏能回、息屏不回 | wake-lock / 电池优化 |
| 重启后 QQ 不在但 bot 在 | 少了 `< /dev/null` |
| 某天突然 OneBot 端口没了 | QQ 自动更新破坏了 NapCat |
| 深夜固定掉线 | 充电器功率不足触发省电 |

详细运维命令见 [references/09-ops.md](references/09-ops.md)。

---

## 参考

| 文档 | 内容 |
| --- | --- |
| [references/01-architecture.md](references/01-architecture.md) | 进程树、端口、数据流、路径 |
| [references/02-selection.md](references/02-selection.md) | 为什么 Termux+proot、为什么 NapCat、为什么放弃 LangBot |
| [references/03-deployment.md](references/03-deployment.md) | 完整部署细节 |
| [references/04-daemon.md](references/04-daemon.md) | 四层守护防线（重点） |
| [references/05-config.md](references/05-config.md) | 配置管理：DEFAULTS 单一事实来源 |
| [references/06-group-state.md](references/06-group-state.md) | 群聊四态状态机 |
| [references/07-tts.md](references/07-tts.md) | ARM 上 TTS 的真实边界 |
| [references/08-pitfalls.md](references/08-pitfalls.md) | 踩坑记录 |
| [references/09-ops.md](references/09-ops.md) | 运维与排障 |
| [references/10-security.md](references/10-security.md) | 权限模型、注入防护、封号风险 |
| [scripts/](scripts/) | 实机验证过的启动与守护脚本 |

---

## 边界

- 本 skill **不提供** bot 业务代码本身，只负责「把手机变成能跑 bot 的宿主」。bot 逻辑由用户/其智能体自行实现。
- 不适用于官方 QQ 机器人开放平台（那条路不需要手机，也不允许个人号）。
- **不能消除封号风险**，只能降低概率。交付时务必把这句话原样告诉用户。
