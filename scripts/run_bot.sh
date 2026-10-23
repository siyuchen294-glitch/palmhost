#!/bin/bash
mkdir -p /root/bot/data
cd /root/bot
while true; do
  echo "=== bot start $(date) ===" >> /root/bot/data/bot.log
  python3 /root/bot/bot.py >> /root/bot/data/stdout.log 2>&1
  echo "=== bot exited rc=$? $(date), restart in 5s ===" >> /root/bot/data/bot.log
  sleep 5
done
