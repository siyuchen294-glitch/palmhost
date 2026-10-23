#!/data/data/com.termux/files/usr/bin/bash
export PREFIX=/data/data/com.termux/files/usr
export HOME=/data/data/com.termux/files/home
export PATH=/data/data/com.termux/files/usr/bin:/system/bin
export LD_LIBRARY_PATH=/data/data/com.termux/files/usr/lib
sleep 20
termux-wake-lock 2>/dev/null
setsid nohup proot-distro login ubuntu -- /bin/bash /root/run_qq.sh > $HOME/qq_daemon.log 2>&1 < /dev/null &
sleep 5
setsid nohup proot-distro login ubuntu -- /bin/bash /root/bot/run_bot.sh > $HOME/bot_daemon.log 2>&1 < /dev/null &
echo "boot start $(date)" >> $HOME/boot.log
