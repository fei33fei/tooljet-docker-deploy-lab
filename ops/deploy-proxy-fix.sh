#!/bin/bash
set -e
echo "=== 备份并部署代理自适应包装脚本 ==="
if [ ! -f /usr/local/bin/dockerd-proxy.sh.bak ]; then
  cp /usr/local/bin/dockerd-proxy.sh /usr/local/bin/dockerd-proxy.sh.bak
  echo "  已备份原脚本 -> dockerd-proxy.sh.bak"
fi
cp /mnt/d/Fey/Desktop/code/_tools/dockerd-proxy.sh /usr/local/bin/dockerd-proxy.sh
chmod +x /usr/local/bin/dockerd-proxy.sh
echo "  新脚本大小: $(stat -c%s /usr/local/bin/dockerd-proxy.sh) 字节"
echo
echo "=== 重启 dockerd ==="
systemctl restart docker
sleep 8
echo "  docker 状态: $(systemctl is-active docker)"
echo
echo "=== 启动判定日志 ==="
journalctl -u docker --no-pager -o cat -n 60 2>/dev/null | grep -a 'dockerd-proxy' | tail -3 || echo "  (未捕获到判定日志)"
echo
echo "=== 容器恢复情况 ==="
docker ps --format "{{.Names}}  {{.Status}}" 2>/dev/null
echo
echo "=== 测试拉取 alpine:3 ==="
docker pull alpine:3 2>&1 | tail -4
