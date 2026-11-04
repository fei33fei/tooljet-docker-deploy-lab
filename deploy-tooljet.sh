#!/bin/bash
# ToolJet 容器化环境部署（分阶段，便于单独重跑）
# 用法: bash deploy-tooljet.sh [build|infra|app|seed|verify|all]
set -e
cd ~/tooljet
STAGE="${1:-all}"
COMPOSE="docker compose"

# 注意：上游 compose 里用了 container_name（postgres / redis / postgrest / client / server / plugins），
# 不是 compose 默认的「项目名-服务名-序号」，所以一律用 compose exec / compose ps，不硬编码容器名。
log() { echo; echo "########## $* ##########"; }

case "$STAGE" in
  build)
    log "阶段 1/5：构建镜像"
    $COMPOSE build --progress plain
    ;;

  infra)
    log "阶段 2/5：启动 postgres + redis"
    $COMPOSE up -d postgres redis
    echo "等待 postgres 健康..."
    for i in $(seq 1 30); do
      st=$($COMPOSE ps --format '{{.Health}}' postgres 2>/dev/null | head -1)
      [ "$st" = "healthy" ] && break
      sleep 2
    done
    echo "postgres 状态: ${st:-unknown}"

    log "预创建数据库（postgrest 启动前必须存在）"
    for db in tooljet_db tooljet_production; do
      if $COMPOSE exec -T postgres psql -U tooljet -d postgres -tAc \
          "SELECT 1 FROM pg_database WHERE datname='$db'" | grep -q 1; then
        echo "  $db 已存在"
      else
        $COMPOSE exec -T postgres psql -U tooljet -d postgres -c "CREATE DATABASE $db"
        echo "  $db 已创建"
      fi
    done
    echo "数据库列表:"
    $COMPOSE exec -T postgres psql -U tooljet -d postgres -tAc \
      "SELECT datname FROM pg_database WHERE datistemplate=false" | sed 's/^/  /'

    log "启动 postgrest"
    $COMPOSE up -d postgrest
    sleep 6
    $COMPOSE ps
    ;;

  app)
    log "阶段 3/5：启动 plugins + server + client"
    # 顺序很重要：plugins 必须先产出编译产物（client.js / dist/server.js），
    # 否则 server 会报 "Cannot find module @tooljet/plugins/dist/server"，
    # client 会报 "Can't resolve '@tooljet/plugins/client'"。
    echo "--- 先起 plugins，等编译产物就绪 ---"
    $COMPOSE up -d plugins
    echo "等待 plugins/client.js 与 plugins/dist/server.js 生成（最多 15 分钟）..."
    ready=no
    for i in $(seq 1 180); do
      if [ -f plugins/client.js ] && [ -f plugins/dist/server.js ]; then
        echo "  ✓ 插件产物就绪（约 $((i*5)) 秒）"; ready=yes; break
      fi
      sleep 5
    done
    if [ "$ready" != "yes" ]; then
      echo "  ! 插件产物未就绪，先看日志："
      $COMPOSE logs --tail=30 plugins
    fi

    echo "--- 再起 server + client ---"
    $COMPOSE up -d server client
    echo "--- 等待 server 就绪（entrypoint 会自动建库并跑迁移）---"
    for i in $(seq 1 60); do
      if $COMPOSE logs server 2>&1 | grep -q "Nest application successfully started"; then
        echo "  server 已就绪（约 $((i*10)) 秒）"; break
      fi
      sleep 10
    done
    $COMPOSE ps
    ;;

  seed)
    log "阶段 4/5：种子数据 + 插件注册"
    echo "--- db:seed ---"
    $COMPOSE exec -T server npm run db:seed 2>&1 | tail -25
    echo "--- plugins:install ---"
    $COMPOSE exec -T server npm run plugins:install 2>&1 | tail -25
    ;;

  verify)
    log "阶段 5/5：验证"
    echo "--- 容器状态 ---"
    $COMPOSE ps
    echo
    echo "--- 前端 http://localhost:8082 ---"
    curl -s -o /dev/null -w "  HTTP %{http_code}  (%{time_total}s)\n" --max-time 30 http://localhost:8082/
    echo "--- 后端 http://localhost:3000/api/health ---"
    curl -s -o /dev/null -w "  HTTP %{http_code}  (%{time_total}s)\n" --max-time 30 http://localhost:3000/api/health
    curl -s --max-time 30 http://localhost:3000/api/health 2>/dev/null | head -c 300
    echo
    echo "--- server 日志尾部 ---"
    $COMPOSE logs --tail=30 server 2>&1 | tail -30
    ;;

  all)
    bash "$0" build
    bash "$0" infra
    bash "$0" app
    bash "$0" seed
    bash "$0" verify
    ;;
esac
