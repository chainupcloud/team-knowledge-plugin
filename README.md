# team-knowledge — Claude Code Plugin

把团队的"知识纪律"封装成 Claude Code 行为契约：查询走三级渐进索引，沉淀走 archiver，维护走 lint/promote，全程不污染主上下文、不破坏知识库主分支。

---

## 1. 这个 plugin 是什么

它是一个 **Claude Code Plugin**，安装后会让团队所有成员的 Claude Code 在跟代码打交道时，自动按统一规则与一个共享的"团队知识库"交互。

它不包含知识本身。知识存在另一个独立的 Git 仓库（默认 clone 到 `~/.team-knowledge/`），由团队共同维护。Plugin 只规定 Claude **怎么读、怎么写、怎么提示**这个知识库。

两个 repo 的边界：

| | Plugin（本仓库） | 知识库（独立 repo） |
|---|---|---|
| **本质** | 行为/UX 契约 | 内容 + schema + 校验工具 |
| **谁维护** | 工具作者 | 业务团队 |
| **更新频率** | 偶尔 | 高频（每周新条目） |
| **跨团队** | 一份给所有团队 | 每团队一份 |
| **分发** | `/plugin install` | `git clone` |
| **离开 Claude 还能用吗** | 不能 | 能（lint/promote 可裸跑） |

---

## 2. 工作原理：三个运行时回路

Plugin 把 Claude 与知识库的交互建模成三个独立但互相喂数据的回路。

### 回路 A：查询（每次任务自动触发）

```
用户提问
   │
   ▼
[skill: team-knowledge] 自动激活（基于 description 匹配）
   │
   ▼
Step 1. 读 knowledge-catalog.md (Layer A，≤80 行)
   │       告诉 Claude 该看哪个分类
   ▼
Step 2. 读对应 catalog.md (Layer B，每条一行)
   │       按 tags + maturity 过滤
   ▼
Step 3. 只读真正相关的 TK-*.md / BK-*.md (Layer C)
   │       50-200 行/条
   ▼
（如需大范围搜索）
   │
   ▼
[subagent: knowledge-explorer] 多角度扫描，只回传摘要
   │
   ▼
Claude 给出答案 + knowledgeReferences 字段
```

**核心约束**：永远不跳级，永远不在主上下文里 `grep` 整个知识库。Layer A 只 80 行 token 几乎为零；Layer C 按需懒读；大范围检索委托给 haiku 模型的 subagent，结果以摘要形式回传，避免污染主上下文。

### 回路 B：沉淀（任务完成后由用户触发）

```
任务完成，用户敲 /archive
   │
   ▼
[command: /archive] → 调用 [subagent: archiver]
   │
   ▼
archiver 扫描会话产物，按 5 种知识类型 (decision/pitfall/guideline/model/process)
判断有没有"对未来项目有价值"的内容
   │
   ├── 有 → 生成 draft 条目 → 写到 contributions/pending/
   │         主对话里输出 review checklist + 提 PR 命令
   │
   └── 没有 → 输出"本次会话未发现可沉淀内容"，不硬凑

（archiver 永远不直接 commit 主分支）
```

**核心约束**：新条目永远 `maturity: draft`；`contributions/pending/` 是唯一允许的写入目标；进主库必须经过 maintainer 的 PR review。这道闸防止 AI 自动产出污染共享数据。

### 回路 C：维护（maintainer 周期性触发）

```
maintainer 敲 /knowledge-lint
   │
   ▼
[command: /knowledge-lint] →
   cd $TEAM_KNOWLEDGE_REPO
   python3 scripts/lint.py        ← schema 一致性、孤儿、衰减、重复
   python3 scripts/promote.py     ← 评估 draft→verified→proven 候选
   │
   ▼
Claude 解读输出，给 maintainer 优先级建议
（脚本本体在知识库 repo 内，不在 plugin 内 —— 因为它们 schema-bound）
```

回路 C 还有一个隐式分支：每次新会话启动时，hook 会自动 `git pull` 知识库，让团队成员的本地副本始终最新。

---

## 3. 组件详解

Plugin 的目录布局严格遵循 Claude Code Plugin 规范。每个文件都映射到 Claude Code 的一个原语（primitive）。

```
team-knowledge-plugin/
├── .claude-plugin/
│   └── plugin.json              ← 元数据（name/version/description）
├── skills/team-knowledge/
│   └── SKILL.md                 ← 查询协议（auto-invoked）
├── agents/
│   ├── archiver.md              ← 沉淀流程（sonnet）
│   └── knowledge-explorer.md    ← 大范围检索（haiku）
├── commands/
│   ├── archive.md               ← /archive
│   ├── knowledge-add.md         ← /knowledge-add
│   ├── knowledge-lint.md        ← /knowledge-lint
│   └── import-knowledge.md      ← /import-knowledge
├── hooks/
│   └── hooks.json               ← SessionStart + Stop
└── CLAUDE.md.template           ← 业务项目接入片段
```

### 3.1 Skill：`skills/team-knowledge/SKILL.md`

**类型**：Skill（Claude 根据 description 自动激活）
**触发**：用户提问涉及架构决策、技术选型、调试已知问题、业务规则、领域模型等场景
**职责**：把 3 级渐进式查询协议作为系统级指令注入 Claude 的对话

包含的硬约束：
- Step 1 永远先读 `knowledge-catalog.md`，零成本
- Step 2 用 tags + maturity 过滤，优先 `proven` > `verified` > `draft`
- Step 3 只读真正相关的条目，不确定时读到第一个 `## ` 二级标题就停
- Step 4（可选）沿 `source_references` 追溯原始 PR
- 大范围查询必须委托 `@knowledge-explorer`
- 任何使用知识的产出必须附 `knowledgeReferences` JSON 字段（驱动 `last_referenced` 更新和后续 promotion）

**不要做的事**（写在 SKILL 里，是运行时 gate）：
- 不要把整个 catalog.md 全读完（catalog 是给 lint 用的）
- 不要直接读 entry 文件（必须经 catalog 过滤）
- 不要主动写知识条目（用 `/archive`）
- 不要在主上下文里 grep 整个知识库（用 `@knowledge-explorer`）
- 不要 commit 到主分支（`contributions/pending/` 是唯一允许的写入位置）

### 3.2 Subagent：`agents/archiver.md`

**类型**：Subagent（model: sonnet，工具: Read/Write/Bash/Grep/Glob）
**触发**：`/archive` 命令调用，或 archiver 的 description 匹配（feature 交付、bug 修复、研究完成）
**职责**：从已结束的会话中提取可复用知识，生成 draft 条目到 `contributions/pending/`

工作流程：
1. 扫描会话产物（用户需求、Claude 输出、用户反馈/修正）
2. 按 5 种 MECE 知识类型识别可沉淀内容
3. 去重检查（`grep ~/.team-knowledge/` 确认不重复）
4. 判断归属：Layer 1（tech-wiki）/ Layer 2（biz-wiki/{domain}）/ Layer 3（项目内，不入团队库）
5. 按类型模板生成 frontmatter + body，写入 `contributions/pending/`
6. 在主对话输出条目摘要 + review checklist + 提 PR 的命令清单

**核心纪律**：宁缺毋滥；初始 maturity 一律 `draft`；不直接 commit 主分支。如果本次会话没有可沉淀内容，明确返回"未发现"而不硬凑。

### 3.3 Subagent：`agents/knowledge-explorer.md`

**类型**：Subagent（model: haiku，工具: Read/Grep/Glob）
**触发**：主 Claude 在需要做大范围知识检索时主动调用
**职责**：在知识库里多角度搜索，只回传 Top 3-5 条结构化摘要给主 Claude

为什么单独跑一个 subagent：
- 大范围 grep 可能命中几十个文件，全文返给主 Claude 会爆 token
- haiku 模型成本低，专门做"读 + 总结"
- 主 Claude 拿到的是经过排序和摘要的 Top 候选，不是原始 grep 结果

搜索策略（必须用至少 3 种）：
1. grep 标题行
2. grep tags 字段
3. grep 全文找隐性提及

排序优先级：标题命中 > tags 命中 > 其他 frontmatter 命中 > 正文命中。pitfall 类型 + bug/error/故障 关键词时优先返回。

输出格式固定：每条只回 ID / 标题 / maturity / 50 字摘要 / 完整路径，并标注是否 `[强烈建议读完整]`。**绝不返回文件全文。**

### 3.4 Commands

四个 slash command，都是薄封装层 —— 不做复杂逻辑，只做 UX 包装。

| 命令 | 入口 | 调用谁 | 何时用 |
|---|---|---|---|
| `/archive` | 触发知识沉淀 | archiver subagent | 任务完成时（Stop hook 会提示） |
| `/knowledge-add` | 手动添加单条知识 | 主 Claude 用 6 步交互式问答 | archiver 漏掉了某条；从外部资料总结 |
| `/knowledge-lint` | 知识库健康检查 | `cd $TEAM_KNOWLEDGE_REPO && python3 scripts/lint.py` + `promote.py` | maintainer 月度维护 |
| `/import-knowledge <path>` | 历史项目冷启动批量导入 | 三阶段管道 → archiver | 接入老项目时一次性 |

**为什么 `/knowledge-add` 标"少数情况使用"**：手动写绕过了 archiver 的"宁缺毋滥"判断和去重检查，容易产生低质量条目。多数情况让 `/archive` 从真实工作产物提取，质量自动更高。

**`/import-knowledge` 的产物会带 `IMPORT_<项目名>_` 前缀**：冷启动导入的条目质量参差不齐，前缀让 maintainer 在 review 时能区分对待，必要时整批拒绝。

### 3.5 Hooks：`hooks/hooks.json`

两个 hook：

**SessionStart**（每次进入 Claude Code 时跑一次）
```bash
REPO="${TEAM_KNOWLEDGE_REPO:-$HOME/.team-knowledge}"
if [ -d "$REPO" ]; then
  cd "$REPO" && git pull --quiet origin main 2>/dev/null \
    && echo '团队知识库已同步至最新版本' \
    || echo '知识库同步失败（可能离线）'
else
  echo "知识库目录不存在: $REPO"
fi
```

效果：每次开会话自动 `git pull`，团队成员永远在最新版上工作；目录不存在时给出清晰提示。

**Stop**（每次 Claude 回合结束）
```bash
echo '提示：如果本次任务有可沉淀的经验，运行 /archive 触发知识提取'
```

效果：把"沉淀"从用户记忆负担变成系统提醒，提升 archive 触发率。

> **路径解析**：hook 命令在运行时读 `${TEAM_KNOWLEDGE_REPO:-$HOME/.team-knowledge}`。环境变量在 `~/.claude/settings.json` 的 `env` 字段配置；不配则用默认值 `~/.team-knowledge/`。Skill / agent / command 文档里也用 `~/.team-knowledge/` 作为示例路径，SKILL.md 已显式说明"如果设了 env 就以 env 为准"。

### 3.6 `CLAUDE.md.template`

**不是自动加载的文件**。它是给业务项目用的"接入片段" —— 安装 plugin 后，把这段内容**手动追加**到业务项目的 `CLAUDE.md`：

```bash
cat /path/to/team-knowledge-plugin/CLAUDE.md.template >> /your/project/CLAUDE.md
```

这段内容告诉 Claude（在那个具体项目里）：
- 本项目接入了团队知识库
- 决策/选型/排查前必须查询
- 深度查询用 `@knowledge-explorer`
- 完成任务必须 `/archive`
- PR 必须含 `knowledgeReferences`
- 禁止直接 grep 知识库、禁止自动 commit 主分支

**为什么是模板而不是自动注入**：CLAUDE.md 是项目级强契约，团队不应该让 plugin 偷偷往里写东西。模板形式让接入者明确同意"我在我的项目里启用这套纪律"。

---

## 4. 安装

### 前置条件

```bash
# 1. clone 团队知识仓库（默认位置）
git clone <你们团队的 team-knowledge git URL> ~/.team-knowledge

# 2. 装 lint/promote 脚本依赖
pip3 install pyyaml
# 如遇 PEP 668 错误：
pip3 install --break-system-packages pyyaml
```

> 不想用默认路径？在 `~/.claude/settings.json` 顶层加：
> ```json
> { "env": { "TEAM_KNOWLEDGE_REPO": "/your/custom/path" } }
> ```

### 安装方式

**A. 从团队 marketplace 安装（生产推荐）**

```
> /plugin marketplace add <团队 marketplace 仓库 URL>
> /plugin install team-knowledge
```

**B. 从本地路径安装（测试 / 开发）**

```
> /plugin marketplace add /absolute/path/to/team-knowledge-plugin
> /plugin install team-knowledge
```

**C. 软链快速迭代（plugin 开发者）**

```bash
mkdir -p ~/.claude/plugins
ln -s /absolute/path/to/team-knowledge-plugin ~/.claude/plugins/team-knowledge
```

重启 Claude Code 生效。

### 业务项目接入

在每个想启用知识库的业务项目根目录跑一次：

```bash
cat /path/to/team-knowledge-plugin/CLAUDE.md.template >> ./CLAUDE.md
```

---

## 5. 验证

启动新会话，期望看到：

- SessionStart hook 输出 `团队知识库已同步至最新版本`
- 试问"团队知识库里有没有跟订单状态机相关的"，Claude 应该先读 `knowledge-catalog.md` 而不是直接 grep
- 跑 `/knowledge-lint`，能正常输出 lint 报告
- 任务结束时 Stop hook 提示 `运行 /archive`

如果以上任一不工作，参考下一节排错。

---

## 6. 常见问题

| 现象 | 原因 | 解决 |
|---|---|---|
| `知识库目录不存在` | 没 clone 或 env var 路径不对 | clone 到默认位置或修正 env |
| `/knowledge-lint` 报 `No module named 'yaml'` | 缺 pyyaml | `pip3 install pyyaml` |
| Hook 没触发（无任何提示） | 安装版 hooks.json schema 错误（0.1.1 已知 bug） | 升级到 ≥0.1.2，或手动覆盖 `~/.claude/plugins/cache/.../hooks/hooks.json` |
| Skill 没自动激活 | description 没匹配上当前问题 | 显式 `> 用 team-knowledge skill 查...` |
| 知识库 git pull 一直失败 | 本地副本不是 git repo / 网络问题 | 检查 `~/.team-knowledge/.git`；离线时忽略警告即可 |

---

## 7. 不变量（修改 plugin 时不要破坏）

这些是 plugin 的设计契约，散落在 SKILL.md / archiver.md / 模板里，是 Claude 运行时实际依赖的硬约束：

1. **知识库与 plugin 永远是两个独立 repo** —— 不要把知识塞进 plugin 内。
2. **新条目一律 `maturity: draft`** —— 提升靠 `promote.py` 基于真实引用证据，不靠作者自评。
3. **archiver 只写 `contributions/pending/`** —— 主库入库必须经过人类 review 的 PR。
4. **3 级渐进索引强制** —— 任何代码路径都不能批量读 entry 或在主上下文里全库 grep。
5. **每次复用必须记 `knowledgeReferences`** —— 这是驱动 `last_referenced` 和 promotion 的唯一信号源。

修改 SKILL.md / agent 文件 / CLAUDE.md.template 时，列举这些规则的中文段落是 **load-bearing prose**，Claude 在运行时会按字面意思 gate 行为，不要随意改写。

---

## 8. 卸载

```
> /plugin uninstall team-knowledge
```

或删软链 / 移除 cache 目录。卸载 plugin 不会动 `~/.team-knowledge/` 的内容（数据归数据，工具归工具）。
