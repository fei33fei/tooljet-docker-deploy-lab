---
type: study-note
project: ToolJet
version: 3.20.252-lts
commit: 2a22a6e1ffe7620a5c716e54fb629c55baa08273
purpose: 为「影视飓风 实习开发（27届）」岗位吃透 ToolJet，产出可写进简历的项目经历
created: 2026-11-03
updated: 2026-11-03
tags:
  - study
  - resume
  - frontend
---

# ToolJet 研读笔记 · 从「看懂」到「写进简历」

> **一句话**：ToolJet 是一个开源（AGPL-3.0）的**低代码内部工具搭建平台**——和 Retool / Appsmith 同一物种。它让非专业开发者在几分钟内拖拽出带表格、表单、图表的后台管理界面，并接上 50+ 数据源。**它本身就是 JD 里说的「内部业务系统、内部平台或工具产品」**。
>
> **本文档的定位**：不是 ToolJet 官方文档的翻译，而是**为「投影视飓风实习开发岗」定制的一路读码笔记 + 简历产出路径**。
>
> **事实标注约定**：本文所有技术结论都来自实际读码，标注了 `路径:行号`。标 `⚠️ 未实测` 的地方表示我只读了代码/配置，**没有真跑起来**。文末 §11 列出了所有「未验证 / 存疑」的部分。

---

## 0. 一句话先搞清楚：ToolJet 是干嘛的

### 0.1 产品视角

想象一个内容公司的内部运营同学，需要一个「投稿审核后台」：左边是投稿列表（按状态筛），右边是稿件详情和审核表单，能把通过的数据推到另一个系统。传统做法是排期找前端写一两周。ToolJet 的做法是：他自己拖一个表格、拖一个表单、连一下数据库和飞书机器人，十几分钟上线一个能用的后台。

**这正是「内部工具」这一品类的定义**——不需要对外发布、不需要高并发，但要求改起来快、接数据源多、权限能控住。

### 0.2 技术栈全景（真实版本号，从 `package.json` 读出）

| 层 | 技术栈 | 版本（实际声明） |
|---|---|---|
| **前端** | React | `^18.2.0` |
| | TypeScript（**仅新代码**） | `^5.9.3` |
| | 构建 | webpack 5 + babel-loader |
| | 状态管理 | zustand `^4.3.6` + immer `^9`（Redux 式 slice 组合） |
| | 路由 | react-router-dom `^6.8.1` |
| | 画布 | reactflow `^11.7.4` + `@dnd-kit` |
| | 表格 / 虚拟滚动 | `@tanstack/react-table` `^8.20.5` / `react-virtuoso` `^4.1.0` |
| | **协同编辑** | yjs `^13.5.46` + y-websocket `^1.4.5` + `@y-presence/react`（CRDT） |
| | 代码编辑器 | CodeMirror 6（JS / Python / SQL / SASS 四种语言） |
| | **API 层** | **原生 `fetch` + 自写 `handleResponse`**（axios 只用于「给用户 JS 注入 axios」，详见 §2.1） |
| | 监控 | Sentry `@sentry/react` + `web-vitals` + PostHog |
| | 测试 | Jest 29 + Testing Library + MSW 2.15 + Storybook 9 |
| | 运行环境 | Node **v22.23.4**（`.nvmrc` / `.node-version`） |
| **后端** | NestJS | `^11.1.3`（**全量 TypeScript**） |
| | ORM | TypeORM `^0.3.31` + PostgreSQL 13 |
| | 缓存 / **调度队列** | ioredis `^5.0.4` + **BullMQ `^5.58.9`**（真正在跑的工作流引擎） |
| | **权限** | CASL `@casl/ability` `^6.7.3` |
| | **代码沙箱** | isolated-vm `^5.0.4`（跑用户写的 JS）+ nsjail（跑 Python） |
| | 可观测 | OpenTelemetry（全链路）+ pino / winston + Sentry |
| | 身份 | passport-jwt + SAML + LDAP + SCIM + OAuth2（自建授权服务器，见 §3.5） |
| | MCP | `server/src/modules/mcp-oauth/`（19 个文件，完整的 OAuth2 授权服务器） |
| | ⚠️ 纸面依赖 | `@temporalio/*` **已声明但源码零引用，未启用**（详见 §2.1） |

### 0.3 规模感（让你在面试里有底气）

| 指标 | 数字 | 位置 |
|---|---|---|
| 后端业务模块 | **64** | `server/src/modules/`（实测目录数） |
| 内置组件（widget） | **83 个注册项** | `WidgetManager/configs/widgetConfig.js` 的 `widgets` 数组（实测）。实现分布在 `AppBuilder/Widgets/` 的 **67 个子目录** + **37 个一级 `.jsx`** |
| 内置数据源插件 | **49 个包 = 48 个连接器 + 1 个公共基础库**（`common`） | `plugins/packages/`（实测目录数）。本地实测 **47 个可用**——`ibmdb` 因原生驱动未装而不可用 |
| 市场插件 | **55 个** | `marketplace/plugins/`（含 anthropic、openai、gemini、mistral_ai、hugging_face） |
| 前端 source 文件 | 1730 个 `.jsx` + 851 个 `.js` | `frontend/src/` |
| 仓库体积 | ~3.15 GB，22292 个文件 | — |
| 许可 | AGPL-3.0 | `LICENSE` |

---

## 1. 为什么是 ToolJet：对齐影视飓风的 JD

> JD 来源：`D:\Fey\Desktop\个人作品集网站\简历\意向岗位以及链接\飓风影视实习开发（27届）.md`
> 投递策略：`简历\飓风影视校招填写指南_实习开发（27届）.md`

### 1.1 逐条对照

| JD 原文 | ToolJet 里的对应物 | 证据路径 |
|---|---|---|
| **「参与公司内部业务系统、内部平台或工具产品的前后端功能开发与维护」** | ToolJet **本身就是**内部工具搭建平台，自托管部署（Docker / K8s / AWS EC2 / Cloud Run） | `README.md:1`、`docker-compose.yaml` |
| 「完成前端页面开发、后端接口开发、联调测试及问题修复」 | 前端 React 画布 + 后端 NestJS 60 模块，契约式 DTO 校验 | `frontend/src/AppBuilder/`、`server/src/modules/` |
| 「参与 Web 应用的需求分析、技术方案讨论和功能实现」 | 低代码产品本身就是需求抽象工具；`docs/` 是完整 Docusaurus 产品文档站 | `docs/docs/` |
| 「协助进行系统测试、Bug 排查、**性能优化**及**线上问题定位**」 | Sentry + PostHog + web-vitals + OpenTelemetry 全埋点；虚拟滚动 / 懒加载；MSW 契约测试 | `frontend/package.json:142-153`、`server/package.json:93-104` |
| 「**利用 AI 等相关技术**」 | ⚠️ **CE 版 AI 接口全是抛 404 的桩，真实实现在锁住的 ee 子模块**（见 §2.1）。但 MCP OAuth 授权服务器、AI Builder 前端骨架、Vercel AI SDK 依赖都在 | `server/src/modules/ai/controller.ts:12-39`、`frontend/src/modules/AiBuilder/` |
| **要求 1：TypeScript / React / Node.js** | 后端 100% TS + NestJS；前端 React 18 + TS 5.9（⚠️ 主体仍是 JS，见 §1.2） | `server/src/`、`frontend/package.json` |
| **要求 3：交互、状态、接口、错误和边界条件** | 组件契约（properties / styles / fireEvent / 暴露变量）、zustand slice 状态、DTO + class-validator 边界、`getSafeRenderableValue` 防注入 | `frontend/src/AppBuilder/Widgets/Button.jsx`、`frontend/src/AppBuilder/_stores/slices/`、`server/src/dto/` |
| **要求 4：代码品味，优雅可维护** | slice 化状态管理、统一 eslint + prettier、Storybook 组件文档、app-builder 契约/一致性测试套件、husky pre-commit | `frontend/eslint.config.mjs`、`frontend/scripts/run-app-builder-tests.js`、`.husky/pre-commit` |
| **要求 5：完整 Web 应用 / Node 服务 / 全栈项目经验** | 这就是一个完整的、真实的、生产级全栈 Web 应用（6 年演进的开源项目） | 整个仓库 |
| **要求 6：开源项目、技术分享** | 真实开源仓库，产出 PR / 技术文章 | `CONTRIBUTING.md` |

### 1.2 ⚠️ 最重要的诚实边界（必须先看）

**ToolJet 前端主体是 JavaScript，不是 TypeScript。**

```
frontend/src:  1730 个 .jsx  +  851 个 .js   ← 主体
               9 个 .tsx    +  24 个 .ts     ← 新代码
```

**所以不能写**「熟练 TypeScript，因为做了 ToolJet」。面试官让你说「ToolJet 里 TS 怎么用的」，你一问三不知，比不写更糟。

**能写且站得住的说法**（与你自己的投递指南 §10.3 一致）：

> 我在一个**日活生产级**的开源全栈项目（ToolJet，AGPL，React 18 + NestJS 11 + PostgreSQL + Redis，6 年演进）里负责读写：后端全量 TypeScript、前端是 JS 主体 + TS 渐进迁移的 React 18 项目。我在这个仓库里能定位到「一次查询从前端点击到数据源返回」的完整调用链，能改组件契约与状态 slice，能补测试与类型定义。TypeScript 我自己独立写过完整项目，但在大规模 JS 代码库里做 TS 迁移的经验，我是在这里补的。

这段话**把「熟练」的举证责任转移到了「工程判断力」上**，而不是靠一个词硬撑——这正是你投递指南里写的「写了解 + 可迁移 + 正在补，反而是安全且可信的」。

---

## 2. 仓库地图：每个顶层目录在干什么

```
ToolJet/
├── frontend/          React 18 + TS 前端（Webpack 构建）
│   ├── src/
│   │   ├── AppBuilder/       ★ 核心：可视化应用构建器
│   │   │   ├── AppCanvas/        画布（渲染、选中、拖拽、快捷键、幽灵组件）
│   │   │   │   ├── RenderWidget.jsx      ★ 组件实际渲染点
│   │   │   │   ├── WidgetWrapper.jsx     选中框 / 拖拽 / 右键菜单
│   │   │   │   ├── Hooks/useCanvasDropHandler.js  拖入落点计算
│   │   │   │   └── Grid/ Selecto.jsx HotkeyProvider.jsx
│   │   │   ├── WidgetManager/    组件注册表（三层结构，见 §3.1）
│   │   │   │   ├── widgets/          组件元数据（83 个注册项）
│   │   │   │   ├── configs/widgetConfig.js  组件清单数组
│   │   │   │   └── componentTypes.js 合并通用属性 → componentTypes
│   │   │   ├── Widgets/          组件实现（平铺 .jsx + 同名目录放测试）
│   │   │   ├── RightSideBar/     右侧属性配置面板（Inspector/）
│   │   │   ├── LeftSidebar/      左侧组件树 / 数据源 / 工作流面板
│   │   │   ├── QueryPanel/       查询面板（写 SQL / 调 API）
│   │   │   ├── QueryManager/     查询编辑器
│   │   │   ├── CodeBuilder/ CodeEditor/   应用源码视图 + FixWithAi.jsx
│   │   │   ├── RealTimeEditor/   ★ 协同编辑（Yjs）
│   │   │   ├── Viewer/           运行态预览
│   │   │   ├── _stores/          ★ 42 个 slice 组成的状态层
│   │   │   ├── _contexts/        ModuleContext / SubcontainerContext（仅两个）
│   │   │   └── _hooks/ _helpers/ _utils/
│   │   ├── _stores/        另一批早期全局 store（zustand）
│   │   ├── _services/      ★ 40+ 个 API service
│   │   ├── _helpers/       handle-response.js（统一响应处理）/ auth-header.js
│   │   ├── modules/        Appbuilder / AiBuilder
│   │   └── ToolJetUI/ _ui/ _components/   自研 UI 组件库
│   └── scripts/       run-app-builder-tests.js 等工程脚本
│
├── server/            NestJS 11 后端（100% TypeScript）
│   ├── src/main.ts    ★ bootstrap：端口 3000、前缀 /api、全局管道
│   ├── src/modules/   ★ 60+ 业务模块，结构高度一致：
│   │                    controller.ts / service.ts / repository.ts
│   │                    dto/ / guards/ / ability/ / interfaces/ / types/
│   │   ├── apps/ app/ data-queries/ data-sources/ workflows/
│   │   ├── casl/ ability/ roles/ group-permissions/ app-permissions/
│   │   ├── ai/ mcp-oauth/ plugins/ tooljet-db/ git-sync/ audit-logs/
│   │   ├── events/       ★ yjs.gateway.ts（WebSocket 协同）
│   │   └── request-context/ session/ users/ organizations/
│   ├── src/entities/  TypeORM 实体
│   ├── test/modules/<domain>/unit|e2e/
│   └── lib/utils.ts   ★ isolated-vm 沙箱
│
├── plugins/           49 个数据源连接器（lerna monorepo）
│   ├── packages/       airtable / postgres / mongodb / s3 / stripe / slack ...
│   ├── schemas/        每个插件的查询 schema
│   └── _templates/     ★ 新插件脚手架模板
│
├── marketplace/       55 个社区插件（含 AI 类）
├── queryPanel/ cli/   查询面板子项目 / @tooljet/cli 脚手架工具
├── docs/              Docusaurus 官方文档站
├── cypress-tests/     E2E（4 套 config：主 / appbuilder / workflows）
├── docker/ + docker-compose.yaml
└── AGENTS.md          官方给 AI Agent 的说明（只有 3 行）
```

### 2.1 ⚠️ 五个必须知道的「坑点」

> 这五条是我**实际验证过**的，也是面试里最容易露馅的地方。

| 坑 | 事实（已验证） | 影响 |
|---|---|---|
| **EE 子模块是空的** | `frontend/ee`、`server/ee` 是**未初始化的 git submodule**（`.gitmodules` 指向私有仓库 `ToolJet/ee-server.git`），本地是空目录 | 企业版功能源码不可见。**别说你读过 ToolJet 的 AI 实现**——CE 的 `server/src/modules/ai/controller.ts:12-39` 每个方法体都是 `throw new NotFoundException()`，是纯桩 |
| **Temporal 是纸面依赖** | `server/package.json:105-108` 声明了 `@temporalio/*`，但**全仓库 `server/src` 零 import**（已 grep 验证） | 真正在跑的工作流/定时调度是 **BullMQ**（`server/src/modules/workflows/processors/`）。把 Temporal 说成「我在用的调度引擎」会当场翻车 |
| **前端 API 层不是 axios** | 全仓库 `frontend/src` 只有 **2 处** import axios（`queryPanelSlice.js:8`、`libraryLoader.js:4`），且都是「给用户 JS 注入 axios 库」的业务线 | 主流路径是 **原生 `fetch` + `config.apiUrl` + `authHeader()` + `handleResponse()`**（`_helpers/handle-response.js:19`）。**没有统一 axios 拦截器** |
| **TS 占比低** | 见 §1.2 | 不能拿「TS 熟练」当主要卖点 |
| **`ai-stack/` 不存在** | 根 `AGENTS.md` 提到 `ai-stack/SETUP.md`，但这个 tag 里没有该目录（属 EE 侧内容） | 同上 |

---

## 3. 必读的五条链路

> 这是「吃透」的核心。每条链路读完，你就能回答一个具体的面试问题。

### 3.1 链路 ①　组件的三层注册机制 + 完整生命周期（React 侧）

**注册是三层的**，这本身就是一个值得讲的设计：

```
① 元数据层：frontend/src/AppBuilder/WidgetManager/widgets/<name>.js
   └ 由 widgets/index.js:1-171 统一 re-export

② 清单层：frontend/src/AppBuilder/WidgetManager/configs/widgetConfig.js:87
   └ export const widgets = [...]   （逐类注释的组件清单）

③ 合并层：frontend/src/AppBuilder/WidgetManager/componentTypes.js
   ├ :3-28   universalProps（所有组件共有的属性）
   ├ :30-42 把 widgets map 成 componentTypes
   └ :56     导出 componentTypeDefinitionMap
```

**关键设计**：右侧属性面板（Inspector）**不手写表单**，而是**读这份元数据数组自动渲染**——`RightSideBar/Inspector/Inspector.jsx:37` 引入、`:182` 按组件名查找、`:1016` 兜底渲染 `DefaultComponent`。**加一个新组件不需要写属性面板**，这是低代码平台可扩展性的核心。

**组件 → React 实现的映射**在 `frontend/src/AppBuilder/_helpers/editorHelpers.js:115-199` 的 `AllComponents` 表（Table 用 lazy import `:80`），查询函数 `getComponentToRender` 在 `:204`。渲染发生在 `AppCanvas/RenderWidget.jsx:218`。

**Table 组件的完整生命周期**（行号已核对）：

| 步骤 | 关键文件:行号 |
|---|---|
| 拖入画布 | `AppCanvas/Hooks/useCanvasDropHandler.js:24 handleDrop` → `:83/:94 addComponentToCurrentPage` → `componentsSlice.js:1395` |
| 画布出现 | `AppCanvas/WidgetWrapper.jsx` → `AppCanvas/RenderWidget.jsx:218` → `Widgets/NewTable/Table.jsx` |
| 属性面板配置 | `RightSideBar/Inspector/Inspector.jsx:339 setComponentProperty` → `componentsSlice.js:2202` → `:2290 saveComponentPropertyChanges` → `:2181` → `:2528 saveComponentChanges`（落库） |
| 依赖登记 | `componentsSlice.js:388 generateDependencyGraphForRefs` / `:1127 addToDependencyGraph` |
| 触发查询 | `queryPanelSlice.js:355 runQuery` → `:693 dataqueryService.run` → `_services/dataquery.service.js:99` |
| 渲染结果 | `resolvedSlice.js:313 setResolvedQuery` → `:759 getResolvedComponent` → `RenderWidget.jsx:101` → `Widgets/NewTable/_hooks/useTable.js` |
| Table 私有状态 | `Widgets/NewTable/_stores/tableStore.js`、`_stores/slices/columnSlice.js` |

**组件收到的 props 契约（这就是低代码组件的「接口定义」）**：

| prop | 含义 |
|---|---|
| `properties` | 行为属性（text、loadingState、disabledState、visibility…） |
| `styles` | 样式属性（backgroundColor、fontWeight、borderRadius…） |
| `fireEvent` | 事件触发器（onClick / onSelect…） |
| `setExposedVariable` / `setExposedVariables` | **把组件内部状态暴露成可被别的组件引用的变量**——低代码的组件间通信机制 |
| `id` / `dataCy` | 组件唯一 id / Cypress 测试选择器 |

**`Button.jsx:41-62` 是极好的 React 教学样本**，它同时展示了四件事：

```jsx
// 1) props 解构 + 默认值
const { height, properties, styles, fireEvent, id, dataCy, setExposedVariable } = props;

// 2) 本地 state 镜像（编辑态 properties 可以被随时改，组件自身状态要同步过来）
const [label, setLabel] = useState(typeof properties.text === 'string' ? properties.text : '');
const [disable, setDisable] = useState(disabledState || loadingState);

// 3) useEffect 单向同步：properties 变 → 本地 state 变
useEffect(() => {
  if (typeof properties.text === 'string') {
    setLabel(properties.text);
    setExposedVariable('buttonText', properties.text);  // 暴露给外部引用
  }
}, [properties.text]);

// 4) 防御式写法：先比后 set，避免无谓重渲染
useEffect(() => { disable !== disabledState && setDisable(disabledState); }, [disabledState]);
```

**为什么这段值得你讲**：它不是教科书式的 `useState` 例子，而是「**外部配置驱动 + 内部状态镜像 + 单向数据流**」的真实工业写法——正好对应 JD 第 3 条「在交互、状态上有自己的理解」。

配套看：`frontend/src/AppBuilder/Widgets/utils.js`（`getSafeRenderableValue` 防注入渲染）。

---

### 3.2 链路 ②　状态管理：zustand + Redux 式 slice（最值得学的部分）

**入口**：`frontend/src/AppBuilder/_stores/store.js:43-86`

```js
import { create, zustandDevTools } from './utils';
import { createUserSlice } from './slices/userSlice';
import { createOrganizationSlice } from './slices/organizationSlice';
import { createComponentsSlice } from './slices/componentsSlice';
// ... 共 42 个 slice，切片清单见 store.js:46-82
import { immer } from 'zustand/middleware/immer';

const useAppBuilderStore = create(
  zustandDevTools((set, get) => ({
    ...createUserSlice(set, get),
    ...createOrganizationSlice(set, get),
    ...createComponentsSlice(set, get),
    // ...
  }))
);
```

**这是本仓库最值得学的一段**：把 Redux 的「slice 拆分」思想，嫁接到 zustand 的「无 Provider、hooks 直接订阅」模型上。42 个 slice 各自独立、按领域切分：

| 类别 | slice |
|---|---|
| **业务实体** | `componentsSlice` `dataQuerySlice` `dataSourceSlice` `appSlice` `appVersionSlice` `dataQueryFolderSlice` |
| **编辑器 UI** | `leftSideBarSlice` `rightSideBarSlice` `inspectorSlice` `modeSlice` `queryPanelSlice` `pageMenuSlice` |
| **工程能力** | `undoRedoSlice` `dependencySlice` `resolvedSlice` `multiplayerSlice` `gitSyncSlice` `debuggerSlice` `codeHinterSlice` |
| **能力边界** | `editorLicenseSlice` `licenseSlice` `fixWithAi.js` |

**三个额外的工程细节**（面试能讲出彩）：

1. `frontend/src/_stores/utils.js:12-27` 的自定义 `create` 包装了一层：每个 store 创建时把初始状态存进 `resetters` 数组，并导出 `resetAllStores()` —— **用于「切换应用 / 退出登录时一次性清空所有 store 状态」**。这是 Redux 里没有的、自造的一层基建。
2. `resolvedSlice` + `DependencyClass.js` + `dependencySlice` —— 组件依赖图与解析顺序。低代码里「组件 A 引用了组件 B 的暴露变量」必须**按依赖拓扑顺序**求值，否则渲染时拿到 undefined。这是**图算法 + 状态管理的结合**，是能讲 10 分钟的深度话题。
3. `immer` 中间件：状态更新用「改草稿」而非「不可变展开」，避免大型状态树手写展开的样板代码。

**跨组件共享状态的三条路**（不是 props drilling）：

| 方式 | 位置 |
|---|---|
| zustand selector | `RenderWidget.jsx:92-132` 全是 `useStore(...)` |
| **组件暴露变量** | `RenderWidget.jsx:219-247` `setExposedVariable` |
| **依赖图级联重算** | `componentsSlice.js:1127 addToDependencyGraph`、`:388 generateDependencyGraphForRefs` |

React Context **只有两个**：`AppBuilder/_contexts/ModuleContext.jsx`、`SubcontainerContext.jsx`——刻意克制，这是好的工程品味信号。

---

### 3.3 链路 ③　一次查询：从点击到数据源返回（前后端贯通）

**前端取数链路**：

```
AppBuilder/_hooks/useAppData.js:41   挂载时拉应用
  → _services/app.service.js:123 getApp / :153 getAppByVersion
  → useAppData.js:56-67  setApp/setPages/setQueries/setComponentNameIdMapping
  → useAppData.js:68     initDependencyGraph
  → queryPanelSlice.js:355 runQuery → :693 dataqueryService.run
  → _services/dataquery.service.js:93-116  POST /data-queries/:id/versions/:vid/run
```

**结果回流**：`resolvedSlice.js:313 setResolvedQuery` → `:759 getResolvedComponent` → `RenderWidget.jsx:101-132` 读 `resolvedProperties / resolvedStyles / resolvedValidation`。

**后端链路**（NestJS 标准分层）：

```
server/src/main.ts:40 bootstrap()  ← 全局前缀 /api（:105）、端口 3000（:156）
  → data-queries/controller.ts:138 @Post(':id/run')
       ↑ :137 挂 QueryAuthGuard, AppFeatureAbilityGuard
  → data-queries/service.ts:259 runQueryForApp → :291 dataQueryUtilService.runQuery
  → data-queries/util.service.ts:67 runQuery → :102 fetchServiceAndParsedParams
  → util.service.ts:521 pluginsSelectorService.getService(pluginId, kind)
  → util.service.ts:169 service.run(sourceOptions, parsedQueryOptions, ...)
       ↑ :118-124 AbortController 超时控制
       ↑ :190-240 OAuth 过期刷新分支
  → plugins/packages/postgresql/lib/index.ts:153 pgConnection.query(query)   ← 真正跑 SQL
```

**TypeORM 分两层**（这是个容易混淆但值得讲清楚的点）：

| 层 | 用途 | 位置 |
|---|---|---|
| **元数据库** | ToolJet 自身的应用/用户/权限表 | `server/src/entities/`、`server/ormconfig.ts`、`src/migration-helpers/db-migrations-datasource.ts:4` |
| **用户自建库（ToolJet Database）** | 用户在平台里建的表 | `modules/tooljet-db/services/tooljet-db-data-operations.service.ts:414`（`SET search_path`）、`:441`、`:448-483`（`createQueryRunner` + 事务 + 行数上限校验）；连接工厂 `server/src/helpers/tooljet_db.helper.ts:26,212` |

---

### 3.4 链路 ④　权限：CASL + 多租户（对应「谁能做什么」）

```
server/src/modules/casl/
├── casl-ability.factory.ts:6-32       Actions / Subjects / AppAbility 类型
├── abilities/apps-ability.factory.ts   具体 ability
└── check_policies.decorator.ts         @CheckPolicies() 装饰器
      ↑ server/src/modules/app/ability-factory.ts:14 createAbility
        → :28-37 abilityService.resourceActionsPermission
        → :47 defineAbilityFor → :54 build
      ↑ server/src/modules/ability/service.ts:32 resourceActionsPermission
        → :40 判断 admin 组 → :43-64 把 group 权限 OR 合并
        → :80-107 按资源类型细分（APP / MODULES / GLOBAL_DATA_SOURCE + granular）
```

**Guard 在最后一道关**：`server/src/modules/app/guards/ability.guard.ts:56 canActivate`
- `:76-80` 取 orgId（`app.organizationId || user.organizationId || 请求头 tj-workspace-id`）
- `:91-147` 依次做 license / public / superAdmin 校验
- `:157-165` 造 ability → `:174` `ability.can(feature, subject, resourceId)`

**多租户模型**：`organizations/` `organization-users/` `group-permissions/` `app-permissions/` `users/` `roles/` `scim/` `request-context/` `session/`。

> **这套「资源 → 角色 → 组 → 用户 → ability → 守卫」的链路，是真实生产级权限系统**，比教学 demo 复杂得多。而且**和你三水小程序的双角色设计是同一类问题**——可以在面试里把两者串起来讲。

---

### 3.5 链路 ⑤　四个硬骨头（挑一个吃透，用于技术分享）

| 主题 | 位置 | 为什么值得讲 |
|---|---|---|
| **协同编辑（CRDT）** | 服务端 `server/src/modules/events/yjs.gateway.ts:10` `@WebSocketGateway({ path: '/yjs' })`、`:24-44` 用 cookie `tj_auth_token` 校验 JWT（失败关连接，错误码 4000）、`:37 setupWSConnection(connection, request, { docName: appId })`；前端 `AppBuilder/RealTimeEditor/RealtimeEditor.jsx`、`_stores/slices/multiplayerSlice.js`；开关 `.env.example` `ENABLE_MULTIPLAYER_EDITING=true` | 多人同时改同一个应用画布，冲突怎么解。分布式协同经典题，面试官会追问 |
| **代码沙箱** | `server/lib/utils.ts:44` `new ivm.Isolate({ memoryLimit: WORKFLOW_JS_MEMORY_LIMIT_MB \|\| 20 })`、`:136` `script.runSync(context, { timeout: WORKFLOW_JS_TIMEOUT_MS \|\| 100 })`、`:80-115` 注入 npm bundle 与安全 `require`；Python 侧 `modules/workflows/services/python-executor.service.ts`（nsjail，`.env.example` 有 `TOOLJET_WORKFLOW_SANDBOX_BYPASS`） | 用户可以写任意 JS 跑在服务器上 → **必须隔离**。安全边界怎么做，是「边界条件」的最佳注脚 |
| **工作流 / 定时任务** | `modules/workflows/processors/workflow-execution.processor.ts`、`workflow-schedule.processor.ts`；队列参数集中化在 `modules/workflows/constants/queue-config.ts`（优先级 `:12-16`、重试 `:30-35`、保留策略 `:43-47`、并发 `:88`）；Bull Board 在 `/jobs`（`server/src/main.ts:213-216` 已从前缀排除） | 有状态、可重试、分布式的工作流编排，比 cron 强在哪 |
| **MCP OAuth 授权服务器** ⭐ | `server/src/modules/mcp-oauth/` **19 个文件**：`service.ts`(38KB) `revocation.ts` `protocol.ts` `policy.ts` `security-policy.ts` `http-security.ts` `scope.interceptor.ts` `throttle.guard.ts` `delegation.guard.ts` `refresh-retry.ts` `identity.service.ts`…**该目录自带一份 7.7KB 的 `AGENTS.md`** | **完整实现了一个 OAuth2 授权服务器**（浏览器同意流、令牌签发/吊销、scope 上限与 PAT 能力对齐、只信任配置代理 CIDR 的限流、委托授权）。这是全仓库工程密度最高的一块，也是最容易被低估的「非 CRUD 代码」 |

> ⚠️ 注意：CE 的 AI 模块是空壳（`server/src/modules/ai/controller.ts` 全是 `throw new NotFoundException()`）。**AI Builder 的真实实现在 ee 子模块里，你拿不到。**所以「AI」这条要讲就讲 MCP OAuth + AI Builder 前端骨架，别编源码细节。

---

## 4. 研读路线图（4 周，每周必须有产出物）

> **核心原则**：**「看过」不值钱，「改过 + 说得清为什么这么改」才值钱。** 下面每一周的产出物，都是可以直接截图进作品集附件的东西。

### 第 1 周：跑起来 + 摸清一条链路

| 动作 | 产出物 |
|---|---|
| ✅ 按 §6 把项目跑起来，界面上手（**2026-11-03 已完成**：8082 / 3000 / 登录页全部实测通过） | 一张**自己画的时序图**：一次查询从前端点击 → fetch → NestJS controller → plugin → PostgreSQL → 返回渲染 |
| 通读 `Button.jsx` + `WidgetManager/configs/widgetConfig.js` + `componentTypes.js` | 一段**组件契约笔记**：低代码组件的 props 协议 + 三层注册机制 + 属性面板自动生成原理 |
| 改一个组件的样式（不碰逻辑），提一个 PR | 一个真实 PR 链接 |

**验收**：能不看代码，口述「ToolJet 里点一下表格的刷新按钮，发生了什么」。

### 第 2 周：吃透状态层

| 动作 | 产出物 |
|---|---|
| 通读 `store.js` + 10 个核心 slice | **一篇技术文章**：《zustand 也能做 Redux：ToolJet 的 42 个 slice 是怎么组织的》 |
| 深挖 `dependencySlice` / `resolvedSlice` / `DependencyClass.js` | 图算法在状态管理里的应用笔记 |
| 动手：新增一个自己的 slice（例如「调试面板」状态） | 一个能跑的 PR |

**验收**：能讲清「为什么用 immer 而不是手写不可变更新」「为什么 slice 要按领域切而不是按功能切」「为什么 Context 只留两个」。

### 第 3 周：吃透后端与接口契约

| 动作 | 产出物 |
|---|---|
| 通读 `server/src/modules/data-queries/` 全部文件 | **接口契约文档**：DTO 字段、校验规则、错误码、超时与 OAuth 刷新分支 |
| 通读 `plugins/_templates/` + `plugins/packages/common/` | 一篇《如何给低代码平台写一个数据源连接器》 |
| 动手：给某个插件加一个操作 / 加一个接口 + Jest 单测 | PR + 测试覆盖率截图 |

**验收**：能讲清「一个 SQL 查询从接口到拿到数据，中间做了哪几层校验和转换」「元数据库和用户自建库为什么要分两套 TypeORM」。

### 第 4 周：啃一个硬骨头 + 产出技术分享

| 动作 | 产出物 |
|---|---|
| 选 §3.5 里的一个（建议 **MCP OAuth 授权服务器** 或 **CRDT 协同编辑**） | 深度技术文章 1 篇（3000 字以上，有源码引用） |
| 修一个真实 issue（GitHub 搜 `good first issue` / `help wanted`） | 一个被合并的 PR（**这比读代码值钱十倍**） |
| 跑一次完整测试：`frontend` 的 `test:app-builder` + `server` 的 `test:e2e` | 测试通过截图 |

**验收**：简历上能写「向 ToolJet 提交并合入 PR #xxxx，修复了 xxx」，且能复述你改的那段代码为什么这么改。

---

## 5. 需要真正动手的「最小改动集」

> 你的投递指南 §10.4 说「这是本岗性价比最高的一次投入」。ToolJet 让这件事的成本大幅下降——**它本身就是现成的 TS/React/Node 项目，不需要你自己搭**。

按「性价比 × 面试可讲度」排序：

| 优先级 | 改动 | 难度 | 面试可讲度 |
|---|---|---|---|
| ⭐⭐⭐⭐⭐ | **给 ToolJet 提一个被合并的 PR**（修 bug / 加测试 / 补 TS 类型） | 中 | 极高——「我给一个大型开源项目提过 PR」 |
| ⭐⭐⭐⭐⭐ | **写 2–3 篇技术文章**（JD 第 6 条「技术分享优先」明确加分） | 低 | 极高——直接对应 JD 第 6 条 |
| ⭐⭐⭐⭐ | 把项目里某个 JS 模块**迁成 TypeScript**（补类型定义） | 中 | 高——正好补上你 TS 的短板，且**能说清为什么原代码需要迁移** |
| ⭐⭐⭐⭐ | 给某个 widget 补一组**契约测试 / 边界测试**（仓库已有 `test:app-builder` 的 contracts / parity 模式可参考） | 中 | 高——直接对应 JD 第 4 条「系统测试、Bug 排查」 |
| ⭐⭐⭐ | ✅ **在本地起一套完整环境**（PG + Redis + PostgREST + 前后端 + plugins），写一篇**从零到一的部署笔记** → **已完成，见 `部署说明.md`**（含 9 个真实踩坑，其中 3 个是上游 compose/Dockerfile 自身的疏漏） | 中 | 中高——对应 JD「内部平台」的运维视角 |
| ⭐⭐⭐ | 读 `server/src/modules/mcp-oauth/` 并写一篇 OAuth2 授权服务器剖析 | 中 | 中高——「安全边界」话题，区分度很高 |
| ⭐⭐ | 做一次**性能剖析**（虚拟滚动 / 列表渲染 / 首屏）并提优化 | 高 | 中高——对应 JD 第 4 条「性能优化」 |

---

## 6. 环境搭建（已实测跑通）

> ✅ **已实测**（2026-11-03 23:00）。下面的拓扑、命令、验收项都是本机真跑出来的结果，不是从文档推导的。
> 完整踩坑记录见同目录的 **`部署说明.md` §5**——一共 9 个真实的坑，其中 **3 个是上游 compose / Dockerfile 自身的疏漏**，
> 另外几个是国内网络环境放大的问题。

### 6.0 部署架构（已验证）

```
Windows 11 宿主机
  └─ WSL2 (Debian 13)  · systemd 已启用 · memory=16GB
       └─ Docker Engine 29.9.2（原生 systemd 服务，不用 Docker Desktop）
            └─ compose 项目 tooljet
                 postgres 5432 · redis 6379 · postgrest 3001
                 plugins（tsc -b --watch）· server 3000 · client 8082
```

源码放在 `/home/nmebr/tooljet`（Debian **ext4**）。放 ext4 不是讲究，是实测出来的硬约束：
写 2000 个小文件 ext4 19ms vs DrvFs 8009ms（**421×**），而且 **DrvFs 上 inotify 完全不触发**，
webpack 热更新必然失效。Windows 侧那份克隆只作只读参考，**git 提交一律在 WSL 侧做**。

### 6.1 拓扑与端口（均已验证可访问）

| 服务 | 端口 | 说明 |
|---|---|---|
| `client` | **8082** | 前端 webpack dev server |
| `server` | **3000** | NestJS API（全局前缀 `/api`） |
| `postgres` | 5432 | 主数据库 |
| `redis` | 6379 | 缓存 + 队列 |
| `postgrest` | 3001 | ToolJet 内置数据库的 REST 层 |
| Bull Board | `/jobs` | 队列监控（`server/src/main.ts:213-216` 已从 `/api` 前缀排除） |

### 6.2 步骤（容器版，实际跑通的顺序）

> 下面这套是**容器化**的，和上游文档里「宿主机 npm install + 本地起服务」的写法完全不同。
> 原因：本机 Windows 侧原生跑不动（npm 脚本里有 POSIX 命令、DrvFs 上 inotify 不触发热更新）。

```bash
# 0. 前置：WSL2 (Debian) + 原生 Docker Engine（systemd 服务），不用 Docker Desktop
#    源码放在 WSL 的 ext4 上：/home/nmebr/tooljet

# 1. 环境变量（gen-env.sh 幂等生成 .env / .env.test）
bash gen-env.sh
#   关键项：LOCKBOX_MASTER_KEY（aes-256-gcm 主密钥）、SECRET_KEY_BASE、
#           PG_DB / PG_USER / PG_PASS、PGRST_JWT_SECRET、TOOLJET_DB_*
#   ⚠️ LOCKBOX_MASTER_KEY 一旦定了就不能改，改了已有密文全部解不开

# 2. 构建三个镜像（server 3.8G / client 6.1G / plugins 3.4G）
bash deploy-tooljet.sh build

# 3. 起 PG + Redis + PostgREST，并预建两个库
bash deploy-tooljet.sh infra

# 4. plugins 容器必须先产出编译产物（client.js / dist/server.js），
#    否则 server / client 会报 "Cannot find module @tooljet/plugins/..."
bash deploy-tooljet.sh app      # 内含等待插件产物就绪的循环

# 5. 种子数据 + 插件注册
bash deploy-tooljet.sh seed
#   → 账号 dev@tooljet.io / password（server/scripts/seeds.ts 自动创建）
#   → 首次启动 server 的 entrypoint 已自动跑过 db:setup（建库 + 迁移 + 示例数据）

# 6. 验证
bash deploy-tooljet.sh verify
```

**本地安装 plugins 依赖（必须做，否则 plugins 容器找不到 tsc）**：

```bash
# plugins 服务的 bind mount 会遮蔽镜像里的 node_modules（上游 compose 漏了匿名卷），
# 所以依赖要装到宿主侧 bind mount 里
docker run --rm \
  -v /home/nmebr/tooljet/plugins:/app/plugins -w /app/plugins \
  -e npm_config_registry=https://registry.npmmirror.com \
  -e npm_config_replace_registry_host=always \
  node:22.23.4-bookworm \
  npm ci --ignore-scripts --no-audit --no-fund
# 实测 26 秒 / 1656 个包 / 1.1G；npm ci 不会改 package-lock.json
```

### 6.2.1 已验证的验收项（2026-11-03 实测）

| 项 | 结果 |
|---|---|
| `GET :3000/api/health` | **200** `{"works":"yeah",...}` |
| `GET :8082/` | **200**，SPA index.html |
| `GET :8082/main.js` | **200**，14140006 字节 |
| `POST :3000/api/authenticate` | **200**，返回完整用户对象（`admin:true`） |
| 浏览器打开 8082 | 跳 `/login?redirectTo=/`，**登录页完整渲染** |
| plugins 容器 | `tsc -b --watch` → **Found 0 errors** |
| client 容器 | `webpack 5.105.3 compiled successfully`（0 错误） |
| `db:seed` / `plugins:install` | 退出码均 0；users 1 行、organizations 1 行 |
| Windows 宿主机直连 | 8082 / 3000 均 200（WSL2 localhost 转发正常） |
| 仓库工作树 | `git status --porcelain` = **0 条** |

**数据库迁移有两套**（`server/package.json:28-30`）：
- `db:migrate`：**结构**迁移（TypeORM migration，datasource = `src/migration-helpers/db-migrations-datasource.ts`）
- `db:migrate:data`：**数据**迁移（单独一个 datasource）

`db:setup` 已经把它们串起来了。

**Windows 注意**（你这次克隆已经踩过）：
- git 长路径：`git config --global core.longpaths true`（否则 checkout 会 `Filename too long`）
- `npm run` 的脚本里有 `bash scripts/run-e2e.sh`、`cp -a`、`rm -rf` 等 POSIX 命令，**Windows 原生 PowerShell 下部分会失败**，e2e 建议在 WSL / Git Bash 里跑
- **WSL 内存**：`.wslconfig` 的 `memory` 至少 16GB。构建期（npm + dockerd + blinko 同时跑）8GB 会撑爆 WSL VM，触发发行版崩溃

### 6.3 上游 compose / Dockerfile 的三个真实疏漏（踩坑记录）

这三条是**上游自己的问题**，不是本机环境问题，也是我认为最能体现"读大型生产级项目"的部分：

| # | 疏漏 | 现象 | 处理 |
|---|---|---|---|
| 1 | **`plugins` 服务漏了匿名卷** | 上游 compose 里 `server` 用 `/app/server/node_modules/`、`client` 用 `/app/frontend/node_modules/` 两个**匿名卷**保住镜像里的依赖，但 `plugins` 只有 `- ./plugins:/app/plugins` 一个 bind mount → 镜像里的 `node_modules` 被整个遮蔽 → 容器里 `sh: 1: tsc: not found`（退出码 127）→ 连带 `client` 报 `Can't resolve '@tooljet/plugins/client'`、`server` 报 `Cannot find module '@tooljet/plugins/dist/server'` | 在**宿主 bind mount 里**装依赖（`npm ci --ignore-scripts`，26 秒 / 1656 包 / 1.1G） |
| 2 | **`plugins` 服务只跑 watch 不 build** | 上游 `command: npm run --prefix plugins start` = `tsc -b --watch`，产不出 `client.js`（前端要）和 `dist/server.js`（后端要）——这两个都是构建产物 | compose override 改成 `sh -c "cd /app/plugins && npm run build && npm run start"` |
| 3 | **`postgrest` 官方镜像不能设 healthcheck** | 镜像里连 `sh` 都没有 → healthcheck 恒失败 → 容器永远 unhealthy | override 里移除该 healthcheck（它本身启动正常） |

另外两条**不是上游疏漏、但同样致命**的坑（细节见 `部署说明.md` §5）：

- **server 启动时 require 全部数据源驱动**（`server/src/modules/data-sources/types/index.ts:4`）。
  为绕过原生驱动下载而用的 `--ignore-scripts`，会让 `ibm_db` 的原生 binding 缺失，
  `ibm_db/lib/odbc.js:59` 在**模块加载期**就抛错 → **整个服务端起不来**。
  实测三个驱动里只有 `ibm_db` 有这个问题（`oracledb` v6 thin 模式是纯 JS、`@sap/hana-client` 均 `require` 成功），
  处理方式是把 `odbc.js` 换成保留导出形状的桩，让 `require` 成功、连接期才报错。
  **代价：IBM Db2 这一个数据源在本地不可用，其余 48 个正常。**
- **plugins 依赖装在容器里还是宿主里，必须和 bind mount 的遮蔽关系对上**——
  这条是 1 的根因，只加 `ENV PATH` 是治标（我第一版就是这么错的）。

### 6.4 常用命令

```bash
# 前端
cd frontend
npm run typecheck        # tsc --noEmit
npm run lint             # eslint
npm run test             # jest
npm run test:app-builder # ★ 专用的 app-builder 测试套件（contracts / parity / coverage 三种模式）
npm run test:layout      # 布局校验
npm run storybook        # 组件文档站

# 后端
cd server
npm run lint
npm run test             # jest（server/jest.config.ts:18 testRegex: test/modules/.*/unit/.*spec\.ts$）
npm run test:e2e         # bash scripts/run-e2e.sh
npm run db:reset         # 推倒重建

# 根级（跨包）
npm run db:setup / db:seed / plugins:install / plugins:reload
npm run build            # plugins → frontend → server 全量构建
```

---

## 7. 简历怎么写

### 7.1 项目经历条目（建议新增，排在三水小程序之后）

**项目名称**：ToolJet 低代码内部工具平台（开源贡献者）
**项目角色**：开源社区贡献者 / 二次开发者
**起止时间**：待定
**项目链接**：https://github.com/ToolJet/ToolJet（可补上你的 PR 链接）

**描述（保守版，事实优先）**：

> 参与开源低代码内部工具搭建平台 ToolJet（AGPL，React 18 + NestJS 11 + PostgreSQL + Redis，6 年演进、64 个后端模块、83 个可视化组件、48 个数据源连接器）的源码研读与贡献。负责方向为前端组件契约与状态管理：在 zustand + Redux 式 slice 架构（42 个领域切片 + immer）中定位并修复组件状态同步问题；为组件补齐 TypeScript 类型定义与边界测试；读通「一次查询从前端点击经 NestJS 分层到数据源插件执行」的完整调用链，并完成本地全栈容器环境（PostgreSQL + Redis + PostgREST + 前后端 + 49 个数据源插件）搭建——期间定位并绕过上游 compose/Dockerfile 的三处疏漏（插件依赖目录被 bind mount 遮蔽、插件产物未编译即被前后端引用、postgrest 镜像无 shell 致健康检查恒失败）。贡献以 PR 与技术文章形式产出。

**描述（有 PR 后升级版）**：

> 向 ToolJet 提交并合入 PR #xxx（<一句话说清改了什么、为什么>），涉及 <文件/模块路径>。此前完成该模块的源码研读与测试补充，并输出技术文章《<文章标题>》<链接>。

### 7.2 技能栏怎么改

按你投递指南 §3 的分组法，加一条：

```
前端与客户端：React 18（组件契约设计、状态管理、Hooks）、TypeScript（类型定义与渐进迁移）、
              zustand / Redux slice 模式、webpack；微信原生、Vue
后端与接口：NestJS（controller / service / repository 分层）、TypeORM、PostgreSQL、
            RESTful / DTO + 校验、Redis / BullMQ
工程与质量：Jest / Testing Library / MSW、ESLint + Prettier、Git workflow、OpenTelemetry + Sentry
```

**注意措辞**：写「React 18（组件契约设计、状态管理、Hooks）」是准确的；写「熟练掌握 TypeScript、React、Node.js 全家桶」不安全。

### 7.3 作品附件里加一页

在作品附件 PDF 里加一页「ToolJet 研读笔记」：
- 左半：手绘的「一次查询的完整调用链」时序图
- 右半：你提的 PR 截图 + 技术文章链接 + 本地跑起来的服务截图

这一页同时证明了三件事：**读代码能力、全栈链路理解、真实产出**。

---

## 8. 面试可能被追问的问题（提前准备答案）

| 问题 | 答题骨架 |
|---|---|
| 「你说你做过 React，怎么讲的？」 | 讲 ToolJet 的**组件契约**：props 是协议的，不是随意的；properties（行为）/ styles（样式）/ fireEvent（事件）/ exposed variables（跨组件通信）四类分离。再对比你三水小程序的双角色状态机 |
| 「组件之间怎么共享状态？」 | 三条路：① zustand selector；② **组件暴露变量**（`setExposedVariable`）——低代码场景下数据流是**画布上的有向图**，靠依赖图拓扑排序求值；③ 依赖图级联重算。再讲 `resolvedSlice` |
| 「状态更新为什么用 immer？」 | ToolJet 的状态树很深（组件树 + 布局 + 样式 + 依赖），手写不可变展开是灾难；immer 让「写草稿」即可。代价是不可变假设失效的场景要绕开 |
| 「后端怎么保证安全？」 | 三层：① DTO + class-validator 入参校验；② CASL ability + `@CheckPolicies` 装饰器的授权（`ability.guard.ts:56` 是最后一道关）；③ `organizationId` 多租户隔离。凭据用 `LOCKBOX_MASTER_KEY` + aes-256-gcm 加密 |
| 「用户写的 JS 怎么防止搞坏服务器？」 | `isolated-vm` 独立 V8 isolate，与主进程内存隔离（`server/lib/utils.ts:44`，内存上限 20MB、执行超时 100ms）；Python 侧用 nsjail |
| 「遇到线上问题怎么定位？」 | Sentry（前端 `@sentry/react` + 后端 `@sentry/nestjs`）、OpenTelemetry 全链路 trace/span、PostHog 行为分析、`web-vitals` 采集真实用户性能；队列侧有 Bull Board `/jobs` |
| 「你这个项目你到底改了什么？」 | **给具体 PR 号 + 具体文件 + 为什么这么改 + 怎么验证的**。答不出这四要素就不要写进简历 |

---

## 9. 红线（绝对不能说的话）

1. ❌「我熟练 TypeScript / React / Node.js」→ ToolJet 前端是 JS 主体，露馅必崩
2. ❌「我读过 ToolJet 的企业版 AI 源码」→ `server/ee` 是未初始化的私有 submodule；CE 的 AI controller 是抛 404 的桩
3. ❌「ToolJet 用 Temporal 做工作流编排」→ Temporal **源码零引用**，是纸面依赖；真正在跑的是 BullMQ
4. ❌「ToolJet 前端用 axios 做统一请求封装」→ 主流是原生 `fetch` + `handleResponse`；axios 只有 2 处，且是给用户注入用的
5. ❌「我给 ToolJet 提过 PR」→ 没提就是没提，PR 号是唯一凭证
6. ❌「我在 ToolJet 负责了 XX 模块」→ 你是贡献者/研读者，不是模块负责人
7. ❌「ToolJet 的性能优化让我提升了 60%」→ 任何没实测过的数字都不要写
8. ❌ 把「跑通本地环境」说成「部署过生产环境」→ 前者是学习，后者是经历

> 这份清单和你 `投递指南` §10.1 的原则完全一致：**宁可诚实写「了解 + 在补」，也别写一个撑不住的「熟练」。** 你的 JD 是实习岗、日薪 300，他们要的是能带、能写、能自测的人，不是大神——**诚实 + 有真实产出，比夸大词法更有竞争力。**

---

## 10. 附：事实来源与复核记录

| 结论 | 来源 |
|---|---|
| 技术栈与版本 | `frontend/package.json`、`server/package.json`、`plugins/package.json`、根 `package.json` |
| 端口与环境变量 | `docker-compose.yaml`、`.env.example`、`server/src/main.ts:105,156,213-216` |
| 目录结构 | 实际文件系统遍历 |
| 组件注册三层 + Inspector 自动渲染 | `WidgetManager/widgets/index.js:1-171`、`configs/widgetConfig.js:87`、`componentTypes.js:3-56`、`RightSideBar/Inspector/Inspector.jsx:37,182,1016` |
| 组件契约 | `frontend/src/AppBuilder/Widgets/Button.jsx:11-62` |
| slice 架构 | `frontend/src/AppBuilder/_stores/store.js:43-86`、`slices/`（42 个） |
| zustand 包装与 resetAllStores | `frontend/src/_stores/utils.js:12-27` |
| 完整生命周期行号 | `useCanvasDropHandler.js:24,83,94`、`Inspector.jsx:339`、`componentsSlice.js:2202,2290,2181,2528`、`queryPanelSlice.js:355,693`、`resolvedSlice.js:313,759`、`RenderWidget.jsx:101,218` |
| 权限链路 | `server/src/modules/casl/casl-ability.factory.ts:6-32`、`app/ability-factory.ts:14,28-37,47,54`、`ability/service.ts:32,40,43-64,80-107`、`app/guards/ability.guard.ts:56,76-80,91-147,157-165,174` |
| 查询执行链路 | `data-queries/controller.ts:137,138`、`service.ts:259,291`、`util.service.ts:67,102,118-124,169,190-240,521`、`plugins/packages/postgresql/lib/index.ts:153` |
| 协同编辑 | `server/src/modules/events/yjs.gateway.ts:10,24-44,37`、`frontend/src/AppBuilder/RealTimeEditor/RealtimeEditor.jsx` |
| 沙箱 | `server/lib/utils.ts:44,80-115,136`、`modules/workflows/services/python-executor.service.ts` |
| MCP OAuth | `server/src/modules/mcp-oauth/`（19 个文件 + 自带 `AGENTS.md`） |
| 测试与规范 | `frontend/jest.config.js:151,156-157,163`、`server/jest.config.ts:18`、`server/scripts/run-e2e.sh`、`cypress-tests/`、`.husky/pre-commit` |
| JD 原文 | `个人作品集网站\简历\意向岗位以及链接\飓风影视实习开发（27届）.md` |
| 投递策略与诚实边界 | `个人作品集网站\简历\飓风影视校招投递填写指南_实习开发（27届）.md` |

### 已复核的三处「纠错」（初稿曾写错，已改）

| 初稿的错误 | 复核方法 | 结论 |
|---|---|---|
| 「后端用 Temporal 做工作流编排」 | `grep '@temporalio' server/src` | **零匹配** → 纸面依赖，实际是 BullMQ |
| 「前端 API 层是统一 axios 封装」 | `grep "from 'axios'" frontend/src` | **仅 2 处**（都是给用户 JS 注入）→ 主流是 fetch + handleResponse |
| 「AI 能力在 `server/src/modules/ai`」 | 读 `server/src/modules/ai/controller.ts:12-39` | **全是 `throw new NotFoundException()`** 的桩 → 实现在锁住的 ee 子模块 |

### 仍未验证 / 不确定

- ~~§6 的环境搭建步骤 —— **未实测**~~ → **已实测跑通**（2026-11-03），见 §6.1 / §6.2.1 验收表与 `部署说明.md`
- 链路 ③④⑤ 的**逐行调用栈**未全部验证（目录与关键函数已确认）
- `docs/` 文档站内容尚未通读
- EE 子模块内的 AI 实现 —— 源码不可见
- `plugins/packages/*` 内部实现只抽查了 `postgresql`，其余 48 个未逐一确认
- GitHub star 数等外部数据 —— 本文档未引用具体数字，避免记错

---

## 11. 下一步动作清单

- [x] 按 §6 把本地环境跑起来（`db:setup` + `db:seed` + `plugins:install` + 前后端 + plugins）—— **2026-11-03 完成，实测通过**
- [x] 写部署笔记（`部署说明.md`，18.5KB，含 9 个真实踩坑 + 完整验收表）
- [ ] 在 Obsidian 里建一篇「ToolJet 研读日志」，每周补一次（§4 的产出物直接往里放）
- [ ] 找 2–3 个 `good first issue`，确认能改（**下一步优先级最高**）
- [ ] 画出那张查询时序图（第 1 周产出物）
- [ ] 写出第 1 篇文章（zustand slice 架构）
- [ ] 简历补上 ToolJet 条目（§7.1），作品附件加一页（§7.3）
- [ ] **投递前把 §9 的红线逐条自查一遍**
