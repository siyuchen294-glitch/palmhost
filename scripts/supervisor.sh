#!/bin/bash
mkdir -p /root/logs
echo "=== supervisor start $(date) ===" >> /root/logs/qq.log
while true; do
  echo "=== launching QQ $(date) ===" >> /root/logs/qq.log
  xvfb-run -a -s "-screen 0 720x1280x24" /opt/QQ/qq --no-sandbox >> /root/logs/qq.log 2>&1
  echo "=== QQ exited rc=$? $(date), restart in 10s ===" >> /root/logs/qq.log
  sleep 10
done
