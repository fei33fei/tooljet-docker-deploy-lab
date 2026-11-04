# tooljet-docker-deploy-lab

> **ToolJet 本地容器化部署实践仓库。**
> 在完整镜像上游源码（[ToolJet/ToolJet](https://github.com/ToolJet/ToolJet)，`v3.20.252-lts` / `2a22a6e1f`）的基础上，记录如何在国内网络环境 + Windows 11 宿主机上，把这个开源低代码平台从零跑起来，并且**能改代码、能看热更新、能提 PR**。

本仓库的源码是上游 ToolJet 的完整镜像（保留全部 git 历史），**上游原文件一字未改**。我的工作在下面这些新增文件里：

| 路径 | 内容 |
|---|---|
| `deploy-tooljet.sh` | 分阶段部署脚本：`build` / `infra` / `app` / `seed` / `verify` / `all` |
| `gen-env.sh` | 生成 `.env` / `.env.test`（幂等，不覆盖已有密钥） |
| `docker-compose.override.yml` | 镜像指向、restart 策略、日志轮转、健康检查、plugins 构建命令 |
| `docker/*.Dockerfile.dev.local` | 三个镜像的本地变体（换源 / 跳过卡死的下载层 / `--ignore-scripts`） |
| `ops/` | Debian 系统侧改动：daemon 镜像源、代理自适应脚本、ibm_db 原生绑定补丁 |
| `patches/` | 两处上游缺陷的修复补丁（`git apply` 即可） |
| `部署说明.md` | 面向开发者：架构、12 个踩坑、验收表、已知限制 |
| `平台使用说明.md` | 面向使用者：平台能做什么、怎么登录、数据和密码存在哪 |
| `ToolJet研读笔记.md` | 源码研读笔记：五条必读链路、4 周研读路线、红线清单 |

---

## 1. 环境基线（全部实测，非推测）

```
Windows 11 宿主机
  └─ WSL2（Debian 13 trixie，WSL 3.0.3.0 / 内核 6.18.54.1，systemd 已启用）
       │   · .wslconfig：memory=16GB processors=8 swap=8GB
       │
       └─ Docker Engine 29.9.2 —— 原生 apt 安装 + systemd，不依赖 Docker Desktop
            │   · /etc/docker/daemon.json：4 个国内 registry 镜像源
            │   · 与 Docker Desktop 的 daemon 完全独立，不要混用
            │
            └─ compose 项目 tooljet
                 ├─ postgres    postgres:13                    0.0.0.0:5432   healthy
                 ├─ redis       redis:7-alpine                 0.0.0.0:6379   healthy
                 ├─ postgrest   postgrest/postgrest:v12.2.0    0.0.0.0:3001
                 ├─ plugins     tooljet-plugins:development    (先 build 再 watch)
                 ├─ server      tooljet-server:development     0.0.0.0:3000
                 └─ client      tooljet-client:development     0.0.0.0:8082
```

- 前端：<http://localhost:8082>　后端：<http://localhost:3000/api>
- 默认账号：`dev@tooljet.io` / `password`（`db:seed` 自动创建）
- 源码必须放在 **WSL 的 ext4**（如 `~/tooljet`）：实测写 2000 个小文件 ext4 19ms / DrvFs 8009ms（**421×**），且 **DrvFs 上 inotify 不触发 → webpack 热更新必然失效**。

---

## 2. 快速开始

```bash
# 0) 前置：WSL2 + systemd 已在 /etc/wsl.conf 开启；Docker Engine 原生安装并已 systemd 启动
#    把 ops/daemon.json 拷到 /etc/docker/daemon.json 后 systemctl restart docker

# 1) 取源码
git clone --branch v3.20.252-lts https://github.com/fei33fei/tooljet-docker-deploy-lab.git ~/tooljet
cd ~/tooljet

# 2) 生成环境变量（幂等；密钥只落在本地 .env，不入库）
bash gen-env.sh

# 3) 分阶段部署（也可直接 bash deploy-tooljet.sh all）
bash deploy-tooljet.sh build     # 构建三个镜像
bash deploy-tooljet.sh infra     # 起 postgres/redis + 预建库 + postgrest
bash deploy-tooljet.sh app       # 先起 plugins 等编译产物，再起 server/client
bash deploy-tooljet.sh seed      # db:seed + plugins:install
bash deploy-tooljet.sh verify    # 端口健康检查 + 日志尾部

# 4) 打开 http://localhost:8082，用 dev@tooljet.io / password 登录
```

> 国内网络下 `docker-compose.override.yml` 已指向 `docker/*.Dockerfile.dev.local` 三个镜像变体，
> 换源、跳过卡死下载层等处理都在镜像里完成，**无需改动仓库里的 package.json / package-lock.json**。

---

## 3. 仓库结构

```
.
├── README.md                    ← 本文（实验总览）
├── deploy-tooljet.sh            ← 分阶段部署脚本
├── gen-env.sh                   ← 环境变量生成器
├── docker-compose.override.yml  ← compose 覆盖配置
├── docker/
│   ├── client.Dockerfile.dev.local    npmmirror + xlsx 0.18.5 + 跳过 sentry-cli
│   ├── plugins.Dockerfile.dev.local   --ignore-scripts（避开厂商大包下载）
│   └── server.Dockerfile.dev.local    跳过 Oracle instantclient 层 + USTC apt 源
├── ops/
│   ├── daemon.json              registry 镜像源 + 日志轮转（→ /etc/docker/daemon.json）
│   ├── dockerd-proxy.sh         代理自适应：探测失败自动改走直连
│   ├── deploy-proxy-fix.sh      daemon 代理脚本的安装/切换
│   └── patch-ibm-db.sh          ibm_db 原生绑定 → 形态完整的桩
├── patches/
│   ├── 0001-fix-default-workspace-signup-mismatch.patch
│   └── 0002-resolve-built-in-data-source-kinds-in-query-guard.patch
├── docs/upstream-README.md      上游 README 原文（根目录 README 被本文替换）
├── 部署说明.md
├── 平台使用说明.md
├── 平台使用说明.assets/         4 张截图
├── ToolJet研读笔记.md
└── …                            其余为上游 ToolJet 源码（frontend / server / plugins / cli …）
```

---

## 4. 踩坑速查

完整记录见 [`部署说明.md`](部署说明.md)（含每一步的实测数据）。

| # | 坑 | 实测现象 | 处理 |
|---|---|---|---|
| 1 | daemon 拉不到镜像 | 直连 `registry-1.docker.io` 超时 | `/etc/docker/daemon.json` 配 4 个国内镜像源 |
| 2 | 代理反噬 | `dockerd-proxy.sh` 硬指向失效代理，WSL 流量全 000 | 改成启动时探测，失败自动走直连 |
| 3 | server 镜像卡死 | AWS S3 的 Oracle instantclient 层 **43.8 KB/s**，排在 npm install 之前 | `server.Dockerfile.dev.local` 删掉该层（thin 模式不需要它） |
| 4 | apt 太慢 | `deb.debian.org` **0.08 MB/s** | 换 `mirrors.ustc.edu.cn` **1.40 MB/s（18×）** |
| 5 | client 装依赖超时 | npmjs 直连 **636s 超时** | 换 npmmirror → **74.9s（5.2×）** |
| 6 | xlsx 装不上 | `cdn.sheetjs.com` 不可达 | 降级到 registry 版 **0.18.5**（API 一致，已验证） |
| 7 | sentry-cli 卡住 | 二进制从 GitHub 拉失败 | `SENTRYCLI_SKIP_DOWNLOAD=1` |
| 8 | **上游 compose 疏漏** | `plugins` 服务漏了匿名卷 → 镜像里 `node_modules` 被 bind mount 遮蔽 → `tsc: not found`、无限重启 | 宿主侧 `npm ci --ignore-scripts` 装进挂载目录（26s / 1656 包） |
| 9 | **上游 compose 疏漏** | 只跑 `tsc -b --watch` 产不出 `client.js` / `dist/server.js` | 改 `npm run build && npm run start`，并让 server/client 等产物就绪 |
| 10 | ibm_db 拖崩服务端 | `--ignore-scripts` 的连带后果：原生 binding 缺失 → 服务端启动即崩 | `ops/patch-ibm-db.sh` 换成保留导出形状的桩 |
| 11 | postgrest 恒 unhealthy | 官方镜像里连 sh 都没有，healthcheck 无法执行 | 移除该 healthcheck（服务本身正常） |
| 12 | WSL 内存不足 | 构建期 8GB 撑爆发行版 | `.wslconfig` 调成 16GB / swap 8GB |

---

## 5. 两处上游缺陷修复（补丁）

补丁放在 `patches/`，**不改动上游源码树**，需要时直接：

```bash
git apply patches/0001-fix-default-workspace-signup-mismatch.patch
git apply patches/0002-resolve-built-in-data-source-kinds-in-query-guard.patch
```

| 补丁 | 现象 | 根因 | 修法 |
|---|---|---|---|
| `0001` | 登录页有「创建账户」入口，但注册一律 **403 Signup is disabled** | 实例级 `ENABLE_SIGNUP`（.env 的 `DISABLE_SIGNUPS=false`）与工作区级 `organizations.enable_sign_up` 错位；上游种子脚本 `server/scripts/seeds.ts` 建默认工作区时漏给 `enableSignUp`，落到建表列默认值 `false` | 按 `.env` 推导 `enableSignUp` 写入默认工作区；顺带补齐内置数据源。**注意**：`DISABLE_SIGNUPS` 由 .env 载入，**必须走 `getEnvVars()`**，process.env 里取不到 |
| `0002` | 查询内置数据源（`runjs` / `runpy` / `restapi` / `tooljetdb` / `workflows`）被当成 UUID 查 → 404 | `ValidateQuerySourceGuard` 只认 UUID 和 query id，没处理「内置数据源 kind」这条路 | 命中 `DefaultDataSourceKinds` 时改走 `getStaticDataSourceByKind`，并补单元测试（`server/test/modules/data-queries/unit/validate-query-source.guard.spec.ts`） |

---

## 6. 验收结果（实测）

| 验收项 | 结果 |
|---|---|
| `GET /api/health` | 200 → `{"works":"yeah",...}` |
| `GET http://localhost:8082/` | 200，返回 SPA index.html |
| `GET http://localhost:8082/main.js` | 200，14.1 MB（webpack dev bundle） |
| `POST /api/authenticate` | 200，返回 admin 用户（`admin:true`，工作区 "My workspace"） |
| 浏览器登录 | 登录页完整渲染；登录后落到 `/my-workspace` 工作台，服务端 0 个 5xx |
| `plugins` 容器 | `tsc -b --watch` → **Found 0 errors** |
| `client` 容器 | `webpack 5.105.3 compiled successfully` |
| `db:seed` / `plugins:install` | 退出码 0 |
| 数据库 | `tooljet_production` 100 张表；`sample_db` 6 张表 1779 行示例数据 |
| 注册 | 修复后注册接口返回 201（探测账号已清理） |

---

## 7. 已知限制

- **IBM Db2 数据源在本地不可用**（原生 binding 桩的代价），其余 48 个数据源正常；`oracledb` / `hana-client` 经实测 `require` 正常。
- **ToolJet 内置 no-code 数据库的 REST 代理不通**：上游 dev compose 写 `PGRST_HOST=postgrest`（不带端口），server 侧拼出的 URL 与容器实际监听的 3000 不一致 —— 上游疏漏，只影响这一条链路。
- **EE 子模块为空**：`server/ee`、`frontend/ee` 是私有 submodule，CE 版 AI controller 全是抛 404 的桩。
- 重新 `npm ci` 装 plugins 依赖后，要重跑 `ops/patch-ibm-db.sh`。
- 镜像体积较大（server 3.8G / client 6.1G / plugins 3.4G），首次构建需要时间和磁盘。

---

## 8. License / 致谢

- 上游 ToolJet 采用 **AGPL-3.0**（见 [`LICENSE`](LICENSE)）；本仓库新增的脚本与文档随上游同协议发布。
- 上游项目：<https://github.com/ToolJet/ToolJet>
- 本仓库：<https://github.com/fei33fei/tooljet-docker-deploy-lab>
