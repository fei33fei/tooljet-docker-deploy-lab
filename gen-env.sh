#!/bin/bash
# 生成 ToolJet 开发环境 .env（幂等：已存在则不覆盖，避免换掉 LOCKBOX_MASTER_KEY）
set -e
cd ~/tooljet

if [ -f .env ] && grep -q "LOCKBOX_MASTER_KEY=" .env && ! grep -q "LOCKBOX_MASTER_KEY=0000000" .env; then
  echo ".env 已存在且已初始化，跳过生成（不覆盖已有密钥）"
  exit 0
fi

PG_PASS=$(openssl rand -hex 16)
PGRST_SECRET=$(openssl rand -hex 32)

cat > .env <<EOF
# ===== ToolJet 开发环境（Debian WSL2 + 原生 Docker Engine）=====
# 由 gen-env.sh 生成于 $(date '+%Y-%m-%d %H:%M:%S')
# 注意：LOCKBOX_MASTER_KEY 一旦确定不可更改，否则已加密的凭据将无法解密

# ---------- 基础 ----------
TOOLJET_HOST=http://localhost:8082
SERVER_HOST=localhost
TOOLJET_EDITION=ce
LOG_LEVEL=info
ORM_LOGGING=
CHECK_FOR_UPDATES=false

# ---------- 密钥 ----------
LOCKBOX_MASTER_KEY=$(openssl rand -hex 32)
SECRET_KEY_BASE=$(openssl rand -hex 64)
MFA_MASTER_SECRET=$(openssl rand -hex 32)

# ---------- 主数据库（ToolJet 自身的应用/用户/权限表）----------
PG_DB=tooljet_production
PG_USER=tooljet
PG_HOST=postgres
PG_PORT=5432
PG_PASS=${PG_PASS}

# ---------- ToolJet 内置数据库（no-code DB）----------
TOOLJET_DB=tooljet_db
TOOLJET_DB_USER=tooljet
TOOLJET_DB_HOST=postgres
TOOLJET_DB_PORT=5432
TOOLJET_DB_PASS=${PG_PASS}
TOOLJET_DB_RECONFIG=true
TOOLJET_DB_STATEMENT_TIMEOUT=60000

# ---------- PostgREST（ToolJet 内置库的 REST 层）----------
PGRST_HOST=postgrest
PGRST_SERVER_PORT=3000
PGRST_DB_URI=postgres://tooljet:${PG_PASS}@postgres:5432/tooljet_db
PGRST_DB_SCHEMAS=public
PGRST_DB_ANON_ROLE=tooljet
PGRST_JWT_SECRET=${PGRST_SECRET}
PGRST_DB_PRE_CONFIG=postgrest.pre_config

# ---------- Redis ----------
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_USERNAME=
REDIS_PASSWORD=
REDIS_DB=
REDIS_TLS=

# ---------- 工作流 / 队列 ----------
WORKER=
TOOLJET_QUEUE_DASH_PASSWORD=$(openssl rand -hex 12)
TOOLJET_WORKFLOW_SANDBOX_BYPASS=true

# ---------- 邮件（开发环境关闭）----------
DEFAULT_FROM_EMAIL=hello@tooljet.io
SMTP_DISABLED=true

# ---------- 功能开关 ----------
DISABLE_SIGNUPS=false
ENABLE_MULTIPLAYER_EDITING=true
COMMENT_FEATURE_ENABLE=true
SCIM_ENABLED=false
SCIM_BASIC_AUTH_USER=tooljet
SCIM_BASIC_AUTH_PASS=$(openssl rand -hex 12)
SCIM_HEADER_AUTH_TOKEN=$(openssl rand -hex 16)
USER_SESSION_EXPIRY=60
EOF

# .env.test 是 compose 里 server 服务的挂载点，缺失会被 docker 创建成目录，必须先建
cp .env .env.test
echo "sed -i 's/^PG_DB=.*/PG_DB=tooljet_test/' .env.test" >/dev/null

echo "=== .env 已生成 ==="
echo "LOCKBOX_MASTER_KEY : $(grep '^LOCKBOX_MASTER_KEY=' .env | cut -c1-30)...（64 hex）"
echo "PG_DB              : $(grep '^PG_DB=' .env | cut -d= -f2)"
echo "TOOLJET_DB        : $(grep '^TOOLJET_DB=' .env | cut -d= -f2)"
echo "PGRST_DB_URI       : $(grep '^PGRST_DB_URI=' .env | cut -d= -f2 | sed 's/:[^:@]*@/:***@/')"
echo "文件权限          : $(stat -c '%a %U:%G' .env) / .env.test"
