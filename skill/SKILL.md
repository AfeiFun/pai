---
name: pai
description: 架构师派活：用 pai-run 把实现任务派给执行方模型（默认 deepseek = Claude Code 外壳经 opencode go 跑 deepseek-v4.1-flash；deepseek-dsh = DeepSeek Harness（dsh）外壳跑同一模型；另有 sonnet；默认模型用 pai-m 切换，模型表在 models.json），在 Otty 当前 tab 右侧分屏可见执行，执行方写结构化回执（成败都写）自动感知完成、画面长时间不动判卡死，架构师亲自重跑 verification 验收。当用户输入 /pai <任务>，或说"派活 / 让 deepseek 做 / 派给 sonnet / 委托实现"时使用——即使用户没提"分屏"或"pai-run"这些词。但只派值得派的活：几步就能自己做完的小改动直接做，不派（测试派活链路本身除外）。
---

# pai — 架构师派活（左 Claude · 右执行方 · 效率为先 · 信任执行方）

ARGUMENTS 就是任务描述。分工先想清楚——**你贵且慢，执行方快且强**：

**你只做三件事**（吃全局认知和判断力的活）：

1. **定方向**：做什么 · 为什么 · 及格线在哪
2. **划边界**：红线 · 铁律 · 禁区 · 要沿用的既有模式（指个名字就够）
3. **验结果**：定义行为级验收标准 + 事后亲自重跑

**其余一切归执行方**（要信任它的能力）：查证（文件在哪 · 现有签名 · 上游契约实测）、实现设计（数据结构 · 组件组织 · 方案选择——红线内自主决策，不请示）、写代码、自证。

**零预查判据**：凡是要先查代码 / 先跑命令才写得出的 spec 内容，一概不写——改成给执行方的查证指令（"照 X 既有模式自己读"、"上游契约自己实测，以实测为准"）。你查到细节再转述，执行方还得核对一遍 = 同一细节处理两遍，纯浪费。spec 凭已有认知（CLAUDE.md / 文档 / 记忆 / 对话）直接写；认知不够定方向才允许一次窄摸底，产出绝不喂进 spec。

**先判断值不值得派（第一步，先于写 spec）**：一次派活 = 写 spec + 开分屏 + 等回执 + 重跑验收，固定开销好几分钟。你自己几步就能做完的活，派出去只会更慢更贵。

- **不派、自己直接做**：单文件、几十行、已想清楚改什么的轻活（改一行文字 / 文案 / 提示词 / 配置 / 小 bug）。**用户嘴上说了"派活"也一样**——直接 Edit 做完，回复里一句话交代"这活太小，我直接改了"，不走 spec → 派 → 验收那一圈
- **派**：摊得平开销的活——多文件、有实现量（新功能 / 新模块）、要实测摸底的、或需并行 / 跨模型对照
- **例外**：用户明说是在**测试派活链路本身**（"试一下派活"、"看看分屏有没有 bug"）时，再小的任务也照派，那时派活就是目的

## 流程

### 1. spec（五段 · 粗粒度 · 直接写不预查）

框架 + 指导意见，不是施工图：

- **Objective**：做成什么样 + 为什么，方向一句话可判定
- **Files**：区域 + 范本名（"server 模块 · 照 users 路由的既有模式"这个级别）；禁碰区写明；精确路径行号不写，执行方自己定位
- **Interfaces**：只写你**拍板的新契约**（新 API 形状 / 对外行为 / 命名决策）；现状接口不抄录
- **Constraints**：红线与铁律写足（这段是你的价值）：项目边界 · 必须沿用的 pattern · 只许用编辑工具改文件、禁 sed/Python 救场 · 禁 dev 重启 · 禁 git 提交
- **Verification**：行为级、可机械重跑的验收标准及期望；写不出验证标准 = 方向还没想清楚
- 查证型未知 → 对应段写「自己实测/自己读，以实测为准，结果写进完成报告」

末尾固定一句：「完成后运行 verification 命令，并在最终消息里附上实际输出。」

### 2. 派（一条命令 · 后台跑 · 默认值全不用传）

Write spec 到 `/tmp/spec-<短名>.md`，然后 Bash **run_in_background** 跑（完成自动通知，派完就去干别的/汇报用户）：

```bash
pai-run --spec /tmp/spec-<短名>.md --cwd <工作目录>
```

- 可见性 / PATH / final / 模型都是脚本默认，不用传
- **模型**：`--model <别名>` 选 `~/.claude/skills/pai/models.json` 里的条目，不传用其 `default`（用户在终端跑 `pai-m` 选编号切换，以 models.json 为准）。三条：
  - `deepseek`（默认）= **Claude Code 外壳**经 opencode go 网关跑 `deepseek-v4.1-flash`（付费，并行别超 8 路）。右侧是完整交互 TUI，干完可在里面追问
  - `deepseek-dsh` = **dsh 外壳**（DeepSeek Harness 的 `headless` profile）经 opencode go 跑同一个 `deepseek-v4.1-flash`。dsh 没有 TUI：右侧显示的是 `--json` 事件流渲染（工具调用 / 结果 / 文本），跑完进程退出、pane 回到 shell，不能在里面追问。用于跟 Claude Code 外壳对照，或 CC 外壳跑不顺时换着用
  - `sonnet` = Claude Code 本体跑 `claude-sonnet-5-5[1m]`（自己的登录态，1M 上下文），活难或 deepseek 连续不过时用
- 加 / 换模型只改 models.json：`harness` 只有 `claude`（缺省）和 `dsh` 两种；`"disabled": true` 临时下线；`bin` 写死 CLI 路径；`context` 写真实上下文窗口。claude 外壳每次生成 `--settings` 临时文件覆盖网关 / 上下文（`base_url` 不带 `/v1`），默认 `--effort high`（条目 `effort` 可覆盖）；dsh 外壳每次生成 `--patch` 叠加层注入 `provider` / `model`，key 从条目 `api_key` 经 `api_key_env` 环境变量传入（临时 0600 文件，读完即删）。不传关思考参数
- **完成回执**：脚本自动在 spec 末尾追加回执契约——执行方结束时（成功或失败都要）写 JSON 回执 `outcome / summary / files_modified / verification_output`；脚本读到即返回并打印 `RECEIPT_*` 行。spec 里不用自己写这段
- **timeout 默认 1800s（30 分钟）**：只是兜底，执行方写回执会提前返回；短任务不会被拖慢。改动面大 / 含实测 / 你预估会超 20 分钟时，显式加 `--timeout 3600`（1 小时）
- **返回码**：`0` 回执 succeeded · `1` 回执 failed（立即返回，不等超时）· `4` 回执读不出 / 执行方进程退出了却没写回执 · `124` 超时 · `125` 疑似卡死 · `3` 开不出 Otty 分屏
- `125`（右侧画面去掉数字/转圈后 `PAI_STALL_SEC`=300 秒没变、也没回执）：输出里带最后一屏。还在正常干活（长思考 / 长命令）→ `pai-run --wait <META>` 接着等同一单；真卡住了 → 看最后一屏判断原因，告诉用户，别盲目重派
- 结尾 `REQUESTED` 是脚本请求的外壳/模型/思考程度/上下文/网关，`OBSERVED` 是 CLI 自己记下的（CC 会话记录 `~/.claude/projects/…jsonl`、dsh 会话记录 `~/.dsh/sessions/…`）；两者对不上 → 先报告用户，不当正常验收
- stdout `VISIBLE_TAB=0` → **立刻停下**让用户检查（是不是不在 Otty 里 / Otty 控制 socket 连不上），没有 headless 兜底
- 命令不存在/失败 → 停下告知用户，不找替代路径
- 不要覆盖 `OTTY_PANE_ID`——脚本靠它分屏
- 若返回码 124：执行方没写回执就撞上限了——先看右侧 TUI 是否还在干活；还在就 `pai-run --wait <META>` 续等，别杀、别当实现失败处理
### 3. 验收（快 · 只看两样）

1. `git diff --stat` 看改动范围合理性（对照回执 `RECEIPT_FILES`，多改/少改都要追问）
2. **亲自重跑 verification**，以自己跑出的结果为准——回执里的 `verification_output` 只是执行方的说法，不能代替重跑

回执 `failed` → 读 `RECEIPT_SUMMARY` 看卡在哪，判断是 spec 问题还是执行问题，再决定写增量 spec 还是找用户。不读抓屏文件（那是回查过程用的，不是验收依据）；不 review 实现风格——相信执行方，风格问题由 verification 和用户审阅兜底。

验收不过 → 差异写成**增量 spec** 再派一次。增量 spec 必须**自包含**（每次 pai-run 都是全新 session · 旧 TUI 被杀掉换新 · 执行方不记得上一轮）：写清哪条验收没过 + 期望差异；上一轮改了什么不用转述，让执行方自己 `git diff` 工作区看。

**止损硬规则**：连续 2 轮验收不过 → 停下向用户汇报（大概率是方向 / spec 的问题，不是执行方的问题），**绝不自己下场写实现救火**——那会让整个派活机制名存实亡。

## Agent 中间人（仅一种场景，其余一律直派）

**并行派多个 spec**——每路看护放子代理隔离，避免穿插污染你的上下文

## 分屏行为（脚本全自动，你不用管）

- 只支持 Otty：用 `otty pane split --direction right --no-focus` 在当前 pane 右侧切 50/50（`LAYOUT=otty-split`，`PANE_ID` 形如 `p_xxx`），焦点留左边
- 派活前只关掉**本会话（当前 pane）派出的**上一单 pai pane——记录按派活方 pane 分开存（`/tmp/pai-jobs/last-split-pane.<pane_id>`），别的会话正在跑的 pai pane 不会被关，多个会话可以同时派活；Otty 的 pane 列表没有坐标，**不碰用户自己的 pane**（同 tab 还有别的 pane 时只告警，分屏可能不均）
- 干完右侧 pane 留着供翻看（Claude Code 外壳的 deepseek / sonnet 还能追问）；完成靠回执文件——**不要自己发明轮询或等进程退出**（续等用 `pai-run --wait <META>`）
- 若执行方 CLI 弹出首次目录信任确认（cwd 是没信任过的目录时会出现），`otty pane capture --pane <p_id> --lines 60` 抓画面看选项，再 `otty pane send-text --pane <p_id> '<按键>'`（回车写 `\r`）处置

## 项目规则优先

所在项目 CLAUDE.md 有更具体派活规则时以它为准，本 skill 只是默认流程。
