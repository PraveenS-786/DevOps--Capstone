#!/bin/bash
echo "==============================" >> /var/log/system-health.log
echo "Timestamp: $(date)" >> /var/log/system-health.log
echo "----- CPU Usage -----" >> /var/log/system-health.log
top -bn1 | grep "Cpu(s)" >> /var/log/system-health.log
echo "----- Memory Usage -----" >> /var/log/system-health.log
free -h >> /var/log/system-health.log
echo "----- Disk Usage -----" >> /var/log/system-health.log
df -h >> /var/log/system-health.log
echo "" >> /var/log/system-health.log
