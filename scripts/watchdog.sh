#!/data/data/com.termux/files/usr/bin/bash
export PREFIX=/data/data/com.termux/files/usr
export HOME=/data/data/com.termux/files/home
export PATH=$PREFIX/bin:/system/bin
export LD_LIBRARY_PATH=$PREFIX/lib
LOG=$HOME/watchdog.log
echo "=== watchdog start $(date) ===" >> $LOG
while true; do
  if ! pgrep -f "run_qq.sh" >/dev/null 2>&1; then
    echo "$(date '+%m-%d %H:%M:%S') QQ down -> restart" >> $LOG
    setsid nohup proot-distro login ubuntu -- /bin/bash /root/run_qq.sh > $HOME/qq_daemon.log 2>&1 < /dev/null &
    sleep 10
  fi
  if ! pgrep -f "run_bot.sh" >/dev/null 2>&1; then
    echo "$(date '+%m-%d %H:%M:%S') bot down -> restart" >> $LOG
    setsid nohup proot-distro login ubuntu -- /bin/bash /root/bot/run_bot.sh > $HOME/bot_daemon.log 2>&1 < /dev/null &
    sleep 8
  fi
  sleep 60
done
