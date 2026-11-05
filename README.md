# pai — 让 Claude Code 当架构师，把实现活派给别的模型

左边 Claude Code 当架构师：写 spec、定验收标准；右边 [Otty](https://otty.sh) 分屏开一个执行方模型可见地干活，干完写结构化回执，左边自动感知完成，再亲自重跑验证。

```
┌──────────────── Otty tab ────────────────┐
│ 架构师（Claude Code）  │ 执行方（右侧分屏）  │
│ 写 spec → pai-run ───▶ │ 读 spec · 改代码    │
│                        │ 跑 verification     │
│ ◀── 回执 JSON ──────── │ 写回执              │
│ 亲自重跑验收            │ （pane 留着可翻看）  │
└────────────────────────┴───────────────────┘
```

## 执行方模型

| 别名 | 外壳 | 模型 | 右侧显示 |
| --- | --- | --- | --- |
| `deepseek`（默认） | Claude Code | `deepseek-v4.1-flash`（opencode go 网关） | 完整交互 TUI，干完可追问 |
| `sonnet` | Claude Code | `claude-sonnet-5-5[1m]`（你自己的 Claude 登录态） | 完整交互 TUI，干完可追问 |
| `deepseek-dsh` | DeepSeek Harness（`dsh`） | `deepseek-v4.1-flash`（opencode go 网关） | `--json` 事件流实时渲染（工具调用 / 结果 / 文本） |

"外壳"（harness）是包在模型外面的 agent 程序——负责读写文件、跑命令、调工具、显示界面；模型只负责思考。同一个模型换外壳，可以对照哪个干得好。

## 安装

```bash
git clone https://github.com/AfeiFun/pai.git
cd pai
bash install.sh
export OPENCODE_GO_API_KEY=<你的 opencode go key>   # 建议写进 ~/.zshrc
```

装到两个地方：

- `~/.claude/skills/pai/`：`SKILL.md`（skill 说明）+ `models.json`（执行方模型表）
- `~/.local/bin/`：`pai-run`（核心：分屏、派活、读回执、判卡死）、`paimodel` / `pai-m`（切默认模型）

### 依赖（macOS）

| 依赖 | 用途 |
| --- | --- |
| [Claude Code](https://claude.com/claude-code)（`claude`） | 架构师本身 + `deepseek` / `sonnet` 的执行方外壳 |
| [Otty](https://otty.sh) | **必需**。pai-run 用 `otty pane split` 在右侧分屏；不在 Otty 里调用直接报错（返回码 3） |
| python3、jq | 脚本内部用（系统自带 / `brew install jq`） |
| DeepSeek Harness | 只有 `deepseek-dsh` 需要，默认路径 `/Applications/DeepSeek Harness.app/…/bin/dsh` |
| zstd（可选） | `deepseek-dsh` 读会话记录核对实际模型用 |

### 配 key

两条 deepseek 都走 [opencode go](https://opencode.ai) 网关。key 二选一：

- 环境变量：`export OPENCODE_GO_API_KEY=...`（推荐，key 不落文件）
- 填进 `~/.claude/skills/pai/models.json` 对应条目的 `api_key`

`sonnet` 用你自己的 Claude Code 登录态，不用配。

## 用法

在 **Otty 里开的** Claude Code 中：

```
/pai 给 xx 加一个 yy 功能
```

或者直接说「派活」「让 deepseek 做」「派给 sonnet」「用 dsh 做」。架构师会：

1. 判断值不值得派——一两行的小改动它直接改，不派
2. 写五段式 spec（Objective / Files / Interfaces / Constraints / Verification）
3. `pai-run` 在右侧分屏启动执行方，等回执（不轮询你、不占你的界面）
4. 读回执 + `git diff --stat` + **亲自重跑 verification** 验收；不过就写增量 spec 再派，连续两轮不过停下找你

### 终端命令

```bash
pai-m          # 列出模型，输编号切换默认（* 为当前默认）
pai-m -q       # 只打印当前默认别名
pai-run --spec /tmp/spec-x.md --cwd ~/Code/proj [--model sonnet] [--timeout 3600]
pai-run --wait /tmp/pai-jobs/<stamp>.meta   # 疑似卡死后续等同一单
```

### 返回码

| 码 | 含义 |
| --- | --- |
| 0 | 回执 succeeded |
| 1 | 回执 failed |
| 3 | 开不出 Otty 分屏（不在 Otty 里 / 控制 socket 连不上） |
| 4 | 回执读不出，或执行方退出了却没写回执 |
| 124 | 超时（默认 1800s） |
| 125 | 右侧画面 `PAI_STALL_SEC`（默认 300）秒没变化也没回执，疑似卡死 |

每次结束都会打印 `REQUESTED`（脚本请求的外壳 / 模型 / 网关）和 `OBSERVED`（从 CLI 自己的会话记录读出的实际模型），两者对不上说明配置没生效。

## 加 / 换模型

只改 `models.json`：

```jsonc
{
  "default": "deepseek",
  "models": {
    "my-model": {
      "name": "显示名",
      "harness": "claude",          // claude | dsh
      "model": "模型 id",
      "context": 200000,            // 真实上下文窗口
      "base_url": "https://网关",    // claude 外壳：Anthropic 兼容网关，不带 /v1；不填 = 用 Claude 登录态
      "api_key": "",                // 或用 api_key_env 指定环境变量名
      "api_key_env": "MY_KEY",
      "effort": "high",             // 可选，claude 外壳默认 high
      "disabled": false             // true = 临时下线
    }
  }
}
```

`dsh` 外壳的条目另需 `bin`（dsh 路径）、`profile`（默认 `headless`）、`provider`（dsh 里的 provider 名，如 `opencode-go`）。

## 分屏行为

- 在当前 Otty pane 右侧切 50/50（`PAI_SPLIT_PERCENT` 可调），焦点留左边
- 每次派活先关掉上一单的 pai pane；**不碰你自己开的 pane**（同 tab 还有别的 pane 时只告警）
- 干完右侧 pane 留着供翻看；完成靠回执文件判断，不等进程退出

## License

MIT
