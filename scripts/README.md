# scripts

以下脚本**取自运行中的手机**（Termux 侧 `/data/data/com.termux/files/home` 与容器内 `/root/`），逻辑未改动。

| 文件 | 运行位置 | 作用 |
| --- | --- | --- |
| `boot-qq.sh` | Termux，放 `~/.termux/boot/` | 开机自启入口 |
| `start_all.sh` | Termux | 一键起 QQ + bot + watchdog |
| `watchdog.sh` | Termux | 每 60s 巡检，重建消失的 proot 会话 |
| `restore.sh` | Termux | 清理临时文件后恢复全套并打印状态 |
| `run_bot.sh` | 容器内 `/root/bot/` | bot 重启循环 |
| `supervisor.sh` | 容器内 `/root/` | QQ 重启循环（xvfb + QQ） |
| `run_qq.sh.example` | 容器内 `/root/` | QQ 入口包装（含 `-q` 免扫码） |

## 使用前必须改

1. `<BOT_QQ>` → 你的机器人 QQ 号
2. 容器名 `ubuntu` → 若 `proot-distro install` 用了别的名字要同步改
3. 确认已 `pkg install termux-api`（`termux-wake-lock` 依赖它）

## 为什么脚本里要写死一堆 export

Termux:Boot 执行脚本时环境**极其干净**，不继承交互式 shell 的 PATH。不显式 export，`proot-distro` 会直接 command not found——而这个坑在终端里手动跑完全正常，排查起来非常费时间。
