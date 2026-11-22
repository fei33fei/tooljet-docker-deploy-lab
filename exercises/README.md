# ToolJet UI 缺陷练习清单

> **这是什么**：把上游 `good first issue` 里的 UI 缺陷当**可动手的小练习**——本地部署已跑通，源码就在手边，每条都练一个具体能力（读 token、找生效行、用 DevTools 取计算值、改样式、验证不回归）。
>
> **产出分两路**：练习记录存进本目录 → 推 `fei33fei/tooljet-docker-deploy-lab`；**本地部署踩到的真缺陷按「一缺陷一 PR」提交上游**（fork `fei33fei/ToolJet`，已提 #19199–#19203，理由见 `本地复现学习路径.md` §8）。仍不参与 issue 认领与指派。
>
> **本地部署怎么跑、怎么测** → [`../本地化部署与测试说明.md`](../本地化部署与测试说明.md)（五阶段流程 + 31 条测试用例）
>
> **工作方法与三张时序图** → [`本地复现学习路径.md`](本地复现学习路径.md)
> **单条练习怎么写** → [`00-模板.md`](00-模板.md)
>
> 证据分级：✅ 本机实测　🧭 读文件推出、未实跑　🚧 未验证的推断

---

## 状态表

| 状态 | 含义 |
|:--|:--|
| ⬜ todo | 未开始 |
| 🟡 doing | 进行中 |
| ✅ done | 已完成并存档（含 before/after 截图与验证记录） |

| 编号 | issue | 现象 | 根因定位 | 难度 | 状态 |
|:--|:--|:--|:--|:--|:--|
| E1 | [#18146](https://github.com/ToolJet/ToolJet/issues/18146) | 暗色模式工作区设置页 toggle 未选中态看不见 | `frontend/src/_styles/theme.scss:13251`（`background-color: var(--base)`，暗色 `1f2936` 与页面同色）✅ | 🟢 | ⬜ todo |
| E2 | [#18145](https://github.com/ToolJet/ToolJet/issues/18145) | 登录页 4 个输入框边框色不对 | `#dadcde` 硬编码散落 `theme.scss` 7 处 + `TooljetDatabase/Forms/` 4 文件 ✅ | 🟢 | ⬜ todo |
| E3 | [#18151](https://github.com/ToolJet/ToolJet/issues/18151) | disabled 按钮的图标颜色不对 | 应走 `--icon-on-solid`（`componentdesign.scss:44`、`tailwind.config.js:53`）✅ | 🟢 | ⬜ todo |
| E4 | [#18153](https://github.com/ToolJet/ToolJet/issues/18153) | OpenAI logo 暗色模式看不见 | 数据源图标需暗色变体，参考 `frontend/src/_styles/global-datasources.scss` 🧭 | 🟡 | ⬜ todo |
| E5 | [#18152](https://github.com/ToolJet/ToolJet/issues/18152) | Anthropic logo 暗色模式看不见 | 同 E4 🧭 | 🟡 | ⬜ todo |
| E6 | [#18149](https://github.com/ToolJet/ToolJet/issues/18149) | Workspace settings > Groups 页 hover 时 tab 抖动 | hover 才加的 `border-bottom` 占布局空间 → 改绝对定位 `::after` 🧭 | 🟡 | ⬜ todo |

**建议顺序**：E1 → E3 → E2 → E6 → E4 → E5。E1 排第一是因为它把「暗色 token 实况」彻底讲透，后面几条共用同一套方法。

---

## 练习记录索引

| 编号 | 记录文件 | 截图目录 | 完成日期 |
|:--|:--|:--|:--|
| E1 | — | `assets/E1-toggle/` | — |
| E2 | — | `assets/E2-login-border/` | — |
| E3 | — | `assets/E3-disabled-icon/` | — |
| E4 | — | `assets/E4-openai-logo/` | — |
| E5 | — | `assets/E5-anthropic-logo/` | — |
| E6 | — | `assets/E6-tab-hover/` | — |

---

## 上一步先搞懂的三件事

1. **本地实例怎么起、怎么登录** → `../平台使用说明.md`（`dev@tooljet.io / password`；管理员 `nmebryz@163.com`）
2. **改代码在哪、容器怎么重建** → `../部署说明.md`（改代码与跑容器在 **WSL2** 的 `/home/nmebr/tooljet`，不是 Windows 侧目录）
3. **源码结构与模块速查** → `../ToolJet研读笔记.md`

---

## 已知的三处「issue 描述 ≠ 仓库实况」

先记住这个，做练习时会反复用上（详见 `本地复现学习路径.md` §3、§5）：

| issue | issue 里写的 | 仓库实际 |
|:--|:--|:--|
| #18146 | `var(--controls/base-active)` | **该 token 不存在**；实为 `--controls-switch-tag` / `--controls-switch-tab`（`designtheme.scss:71-72` / `:161-162`） |
| #18145 | `--border-default` 或 `#545B64` | `--border-default` = 亮 `#CCD1D5` / 暗 `#3C434B`（`componentdesign.scss:55` / `:234`），与 `#545B64` 不符 |
| #18151 | `--icon/on-solid` | 实名 `--icon-on-solid`（连字符） |

---

## 参考样本：社区做到哪一步了

社区对 E1 已有一份 PR **#18293**，停滞 30 天、只改了 SSO 列表一处 toggle、且 body 与代码的 token 名对不上。
**当作对照样本看，别当待办。** → `本地复现学习路径.md` §5
