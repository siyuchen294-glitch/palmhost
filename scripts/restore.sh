#!/data/data/com.termux/files/usr/bin/bash
export PREFIX=/data/data/com.termux/files/usr
export HOME=/data/data/com.termux/files/home
export PATH=$PREFIX/bin:/system/bin
export LD_LIBRARY_PATH=$PREFIX/lib
cd $HOME
echo "=== 清理安装临时文件 ==="
R=$PREFIX/var/lib/proot-distro/containers/ubuntu/rootfs
rm -f $R/root/tts/chattts_assets.tar
proot-distro login ubuntu -- /bin/bash -c "apt-get clean; rm -rf /root/.cache/pip /tmp/* 2>/dev/null" 2>&1 | tail -1
echo "=== 启动 QQ + bot + watchdog ==="
setsid nohup proot-distro login ubuntu -- /bin/bash /root/run_qq.sh > $HOME/qq_daemon.log 2>&1 < /dev/null &
sleep 45
setsid nohup proot-distro login ubuntu -- /bin/bash /root/bot/run_bot.sh > $HOME/bot_daemon.log 2>&1 < /dev/null &
sleep 8
setsid bash $HOME/watchdog.sh >> $HOME/watchdog.out 2>&1 < /dev/null &
sleep 10
echo "=== 状态 ==="
tail -6 $R/root/logs/qq.log
tail -3 $R/root/bot/data/bot.log
df -h /data | tail -1
