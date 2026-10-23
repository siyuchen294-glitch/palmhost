# 03 · 部署全流程

从一台**空手机**到机器人上线。全程不需要 root。

## 准备

| 物料 | 说明 |
| --- | --- |
| 闲置 Android 手机 | 本项目用 vivo X80 Pro / Android 16，理论上 Android 8+ 均可 |
| 充电器 | 要长期插电，务必用**足功率**的；劣质充电器会导致电量不升反降 |
| 电脑 | 仅用于 adb 装 APK、看日志调试 |

## Step 1 · 装 Termux 三件套

**必须用 F-Droid 版 Termux**，Google Play 版已停止维护且签名不同，装不上插件。

| APK | 作用 |
| --- | --- |
| `termux-arm64.apk` | 终端环境本体 |
| `termux-boot.apk` | 开机自启 |
| `termux-widget.apk` | 桌面一键启动（可选） |

```powershell
$adb = '<项目>\tools\platform-tools\adb.exe'
& $adb install -r termux-arm64.apk
& $adb install -r termux-boot.apk
& $adb install -r termux-widget.apk
```

安装后务必打开一次 Termux 完成初始化，并在系统设置里**关闭电池优化 / 允许后台活动**，否则息屏即被杀。

## Step 2 · Termux 内配环境

```bash
pkg update -y && pkg upgrade -y
pkg install -y proot-distro x11-repo termux-api
termux-setup-storage          # 授权存储（可选）
proot-distro install ubuntu   # 装 Ubuntu 24.04
proot-distro login ubuntu
```

进入容器后：

```bash
apt update && apt install -y xvfb wget curl python3 python3-pip fonts-noto-cjk
```

> `fonts-noto-cjk` 必装。缺中文字体时 QQ 界面全是方块，虽然不影响协议层，但排查问题时会瞎。

## Step 3 · 装 Linux QQ

下载 aarch64 版 Linux QQ 的 deb（`.deb` 用 `dpkg -i` 装，或直接解包到 `/opt/QQ`），装完确认：

```bash
ls /opt/QQ/qq
```

然后关掉自动更新（重要，见 [08-踩坑](08-pitfalls.md)）。

## Step 4 · 装 NapCat

NapCat 的 Shell 版安装脚本会把它解到 QQ 的 `app_launcher` 目录并打补丁：

```bash
bash napcat-install.sh
```

装完路径：

```
/opt/QQ/resources/app/app_launcher/napcat
```

配置 OneBot：HTTP 3000、WS 3001。**务必设 token**（本项目用环境变量注入，不写进仓库）。

## Step 5 · 首次登录（唯一一次人工介入）

```bash
xvfb-run -a -s "-screen 0 720x1280x24" /opt/QQ/qq --no-sandbox
```

终端会打印二维码 / 或输出到文件，扫码登录。

> 也可以用 adb 把二维码图片拉到电脑上看，脚本见 `scripts/`。

登录成功后记下 QQ 号，之后启动都带 `-q <BOT_QQ>` 免扫码。

## Step 6 · 部署 bot

```bash
mkdir -p /root/bot/data/{logs,stickers,tts}
# 把 bot.py / tts.py / run_bot.sh 传进去（scp 或 adb push，或 base64 管道，见下）
```

**没有 ssh 时怎么传文件**：项目里所有 `.py` 都配了一份 `.b64`，就是为这个准备的：

```bash
# 电脑侧编码
[Convert]::ToBase64String([IO.File]::ReadAllBytes('bot.py')) > bot.py.b64
# 手机侧解码
base64 -d bot.py.b64 > /root/bot/bot.py
```

## Step 7 · 配开机自启

```bash
mkdir -p ~/.termux/boot
cp start-qq.sh ~/.termux/boot/start-qq.sh
chmod +x ~/.termux/boot/start-qq.sh
```

脚本内容见 [scripts/boot-qq.sh](../scripts/boot-qq.sh)。

## Step 8 · 验收清单

逐条打勾才算上线：

- [ ] `pgrep -f run_qq.sh` 有进程
- [ ] `pgrep -f run_bot.sh` 有进程
- [ ] `tail /root/logs/qq.log` 没有停在二维码
- [ ] 给机器人发一条私聊，能回
- [ ] **锁屏息屏 5 分钟后再发一条，仍能回** ← 最容易被忽略
- [ ] 手机重启后自动恢复，无需人工
- [ ] `df -h /data` 剩余空间 > 3G（TTS 缓存和表情包会涨）
