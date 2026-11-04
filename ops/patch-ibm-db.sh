#!/bin/bash
# 本地开发补丁：把 ibm_db 的原生绑定替换成形态完整的桩，
# 让 ToolJet 服务端能正常启动，只是 IBM Db2 这一个数据源不可用。
#
# 背景：
#   plugins 的依赖用 --ignore-scripts 安装（否则 oracledb / ibm_db / hana-client 会从
#   厂商站点下载上百 MB 的原生驱动，构建会卡死）。
#   但 server/src/modules/data-sources/types/index.ts 会在启动时 require 全部数据源驱动，
#   而 ibm_db/lib/odbc.js 第 59 行无条件 `require("bindings")("odbc_bindings")` → 抛错
#   → 服务端启动即崩溃。
#
#   实测结论（2026-11-03）：
#     require('oracledb')       → 成功（v6 thin 模式是纯 JS，不需要原生绑定）
#     require('@sap/hana-client')→ 成功
#     require('ibm_db')         → 失败（唯一有问题的）
#
#   ToolJet 侧只用两个接口（packages/ibmdb/lib/index.ts）：
#     第 6 行  const ibmdb = require('ibm_db');       ← 加载期
#     第 69 行 ibmdb.open(connStr, (err, conn) => ...) ← 连接期
#
# 本补丁只替换 node_modules/ibm_db/lib/odbc.js（已被 plugins/.gitignore 忽略），
# 仓库 tracked 文件零改动。原文件备份为 odbc.js.orig，脚本可重复执行。
set -e
P=/home/nmebr/tooljet/plugins/node_modules/ibm_db/lib/odbc.js

if [ ! -f "$P.orig" ]; then
  cp "$P" "$P.orig"
  echo "已备份原文件 → $P.orig"
fi

cat > /tmp/odbc-stub.js <<'STUB'
/* LOCAL DEV STUB (see _tools/patch-ibm-db.sh)
 *
 * ibm_db 的原生 binding（odbc_bindings.node）没有编译：plugins 的依赖是用
 * --ignore-scripts 安装的，为的是避开 IBM DB2 CLI 客户端上百 MB 的下载。
 *
 * 原始实现会在模块加载期无条件执行 require("bindings")("odbc_bindings")，
 * 找不到 .node 文件就抛错。而 ToolJet 的 server/src/modules/data-sources/types/index.ts
 * 会在启动时 require 全部数据源驱动，于是整个服务端起不来。
 *
 * 这里保留 ibm_db 的导出形状（构造器 + prototype + open/openSync 等），
 * 让 require 成功；真正建立数据库连接时通过回调返回一个明确的错误。
 */
'use strict';

var MESSAGE =
  'ibm_db native binding is unavailable in this local dev container (IBM Db2 data source is disabled)';

function unavailable() {
  throw new Error(MESSAGE);
}

function Stub() {
  unavailable();
}
Stub.prototype.execute = unavailable;
Stub.prototype.fetch = unavailable;
Stub.prototype.fetchAll = unavailable;
Stub.prototype.fetchSync = unavailable;
Stub.prototype.fetchAllSync = unavailable;
Stub.prototype.close = unavailable;
Stub.prototype.open = unavailable;

function ibmDbModule() {
  unavailable();
}
ibmDbModule.prototype = Stub.prototype;

module.exports = ibmDbModule;
module.exports.Database = Stub;
module.exports.ODBC = Stub;
module.exports.ODBCConnection = Stub;
module.exports.ODBCStatement = Stub;
module.exports.ODBCResult = Stub;
module.exports.Pool = Stub;
module.exports.getElapsedTime = function () {
  return ' :: ';
};
module.exports.debug = function () {};
module.exports.convertRowsToColumns = function (rows) {
  return rows;
};
module.exports.open = function (connStr, options, cb) {
  var err = new Error(MESSAGE);
  if (typeof options === 'function') {
    cb = options;
  }
  if (typeof cb === 'function') {
    cb(err, null);
    return;
  }
  throw err;
};
module.exports.openSync = unavailable;
module.exports.createDbSync = unavailable;
module.exports.dropDbSync = unavailable;
module.exports.close = unavailable;
STUB

cp /tmp/odbc-stub.js "$P"
echo "✓ 已写入桩实现"

echo "--- 语法检查 ---"
docker run --rm -v /home/nmebr/tooljet/plugins/node_modules:/nm node:22.23.4-bookworm \
  node --check /nm/ibm_db/lib/odbc.js && echo "  ✓ 语法正确"

echo
echo "===== 验证：require 整个 dist/server.js（服务端的行为）====="
docker run --rm --entrypoint sh \
  -v /home/nmebr/tooljet/plugins:/app/plugins \
  -w /app/plugins tooljet-plugins:development -c '
  node -e "
    try {
      const m = require(\"/app/plugins/dist/server.js\");
      const keys = Object.keys(m);
      console.log(\"✓ require 成功，导出 \"+keys.length+\" 个符号\");
      console.log(\"  样例: \"+keys.slice(0,8).join(\", \"));
    } catch(e) {
      console.log(\"✗ 失败: \"+e.message);
      console.log(e.stack.split(String.fromCharCode(10)).slice(0,8).join(String.fromCharCode(10)));
    }
  " 2>&1
' 2>&1

echo
echo "===== 验证：ibmdb.open 的错误是否走回调（而非同步抛）====="
docker run --rm --entrypoint sh \
  -v /home/nmebr/tooljet/plugins:/app/plugins \
  -w /app/plugins tooljet-plugins:development -c '
  node -e "
    const ibmdb = require(\"ibm_db\");
    ibmdb.open(\"DSN=x\", (err, conn) => {
      console.log(err ? \"✓ 回调收到错误: \"+err.message : \"✗ 未报错\");
    });
  " 2>&1
' 2>&1
echo "===== DONE ====="
