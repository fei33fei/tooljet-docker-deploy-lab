#!/usr/bin/env bash
# Docker daemon 启动包装：代理自适应
#
# 背景：宿主 172.28.240.1:3068 的代理对 WSL 流量可能整体失效（TCP 可连但 CONNECT 被 reset），
# 此时若仍强制走代理，docker pull 会全部失败。因此启动前做一次真实 HTTPS 探测：
#   探测通过 -> 使用代理（保留原行为）
#   探测失败 -> 直连（registry-mirrors 已配，直连国内镜像源可正常拉取）
set -u

GW="$(ip route | awk '/^default/{print $3; exit}')"
PROXY_URL="http://${GW}:3068"

proxy_ok() {
  # 必须是一次真实 HTTPS 代理请求；仅 TCP 可连接不算数
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' -x "${PROXY_URL}" --max-time 6 \
          https://registry-1.docker.io/v2/ 2>/dev/null)"
  [ "${code}" != "000" ] && [ -n "${code}" ]
}

if proxy_ok; then
  echo "[dockerd-proxy] 代理可用 (${PROXY_URL})，启用代理"
  export HTTP_PROXY="${PROXY_URL}"
  export HTTPS_PROXY="${PROXY_URL}"
  export NO_PROXY="localhost,127.0.0.1,::1,.blinko-network,postgres,blinko-postgres,blinko-website,172.16.0.0/12,192.168.0.0/16,10.0.0.0/8"
else
  echo "[dockerd-proxy] 代理不可用 (${PROXY_URL})，改为直连（依赖 registry-mirrors）"
  unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
  export NO_PROXY="*"
fi

exec /usr/bin/dockerd "$@"
