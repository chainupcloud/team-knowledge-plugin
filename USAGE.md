# team-knowledge — 日常使用指南

面向**普通使用者**（不是 plugin 维护者）。装好之后每天怎么用、按哪几个键。

如果你想了解 plugin 是怎么实现的（三个运行时回路、组件设计、不变量），看 [README.md](README.md)。

---

## 一、装一次（每个团队成员，5 分钟）

### 1. 装环境

```bash
curl -fsSL https://raw.githubusercontent.com/chainupcloud/team-knowledge-plugin/main/bootstrap.sh | bash
```

这一条命令会：clone 知识库到 `~/.team-knowledge/` → 装 pyyaml（自动处理 PEP 668）→ 跑 lint 验证。

> 自定义知识库 URL：在命令后追加 `bash -s -- git@github.com:your-org/your-kb.git`

### 2. 装 plugin

进 Claude Code（任意目录都行）：

```
> /plugin marketplace add chainupcloud/team-knowledge-plugin
> /plugin install team-knowledge
```

### 3. 给每个业务项目接入

在你想用知识库的项目根目录跑一次：

```bash
cat ~/.claude/plugins/cache/*/team-knowledge/*/CLAUDE.md.template >> ./CLAUDE.md
```

可选：把 `templates/business-project-pr-template.md` 复制到项目的 `.github/pull_request_template.md`，让 PR 自动提示作者标 `knowledgeReferences`。

**装完了。从此什么都不用手动做。**

---

## 二、每天用（什么都不用做 + 一个习惯）

### 自动发生的事（不用记，不用按键）

每次进 Claude Code，**SessionStart hook 自动 `git pull` 知识库**——你永远在最新版上工作，会看到这条提示：

```
团队知识库已同步至最新版本
```

每次你跟 Claude 聊代码相关的事（架构选型、查 bug、读已有模块、写新功能），**team-knowledge skill 会自动激活**——Claude 先读 `knowledge-catalog.md`，按 tags 过滤到相关条目，最后只读真正相关的几条。完全自动，不用你下指令。

如果 Claude 用了某条知识做参考，它会在回答里附 `knowledgeReferences`：

```json
"knowledgeReferences": [
  {"id": "TK-AP-001", "title": "在数据库事务中调用外部 RPC", "usedIn": "架构选型理由"}
]
```

### 唯一一个习惯：任务完成后敲 `/archive`

每次 Claude 一个回合结束，**Stop hook 会提醒你**：

```
提示：如果本次任务有可沉淀的经验，运行 /archive 触发知识提取
```

这时候敲一下：

```
> /archive
```

archiver 会扫描整个会话，判断有没有"对未来项目有价值"的内容：

- **有** → 生成 draft 条目写到 `~/.team-knowledge/contributions/pending/`，告诉你下一步：
  ```
  cd ~/.team-knowledge
  git checkout -b knowledge/$(date +%Y-%m-%d)
  git add contributions/pending/
  git commit -m "knowledge: archive from <项目> $(date +%Y-%m-%d)"
  git push 然后开 PR
  ```
- **没有** → 明确告诉你"本次会话未发现可沉淀内容"，你直接关 Claude 就行，archiver 不会硬凑。

### 什么时候**不用**跑 /archive

Stop hook 是提醒不是强制。下面这些场景跑了也是空跑：

- 改配置、改环境变量、跑脚本
- 查别人的代码、读文档
- 简单 bug 修复（已经在已知 pitfall 里）
- 项目特有配置变更（不具跨项目复用价值）

**判断标准**：如果你做完后能跟队友说"哎我学到一个东西"——值得 archive；如果没有——别跑。

### 主动查知识库的玩法

你也可以直接问：

```
> 团队知识库里有没有踩过 Redis 重启相关的坑？
> 我要做订单状态机，先看一下知识库里有没有相关的决策和陷阱
> 帮我查一下事务相关的 anti-pattern
> 用 knowledge-explorer 查一下分布式锁相关的所有知识
```

Claude 会自动用 skill 走三级索引；如果命中很多，它会调用 `@knowledge-explorer` subagent 在后台搜，只返摘要给你，不会把全文塞进对话浪费 token。

---

## 三、偶尔用（特定场景的 slash 命令）

### 场景 A：archiver 漏了一条重要的，你想手动加

```
> /knowledge-add
```

Claude 会问你 6 个问题（类型 / 归属层 / 标题 / 内容 / 标签 / 来源），按答案生成条目存到 `contributions/pending/`，让你提 PR。

**适用场景**：
- archiver 没识别出某条重要决策
- 从外部资料（书、文章、其他人的经验）总结进来
- 修订一条已有条目的具体字段

> 多数情况优先用 `/archive`——让 archiver 从真实工作产物自动提取，质量比手动写更高。

### 场景 B：把老项目的经验批量导进知识库

新项目刚开始，知识库是空的，Claude 查不到东西。让 archiver 把老项目里的经验灌一批进来：

```
> /import-knowledge /path/to/your/old-project
```

它会扫描 README / docs / commit message / 代码模式，提取候选条目，全部带 `IMPORT_*` 前缀写到 `contributions/pending/`，让你 review 后选择性合入。

**用一次就够**：每个老项目接入时跑一次冷启动。后续靠日常 `/archive` 增量增长。

### 场景 C：作为 maintainer 做月度健康检查

```
> /knowledge-lint
```

Claude 会跑 `lint.py` + `promote.py`，输出：

```
索引一致性: ✅
孤儿条目: 0
待衰减: 2 条（TK-PAT-005 已 8 个月未引用）
maturity 提升候选:
  - TK-PAT-002 (draft → verified): 满足 1 次引用 + 1 个项目
  - TK-AP-001 (verified → proven): 满足 4 次引用 + 2 个项目
```

按 Claude 给的优先级处理：
- 衰减条目：决定降级 / 归档 / 还是补强证据
- 提升候选：跟 maintainer review 后批准（脚本加 `--apply` 应用）

**触发频率**：月度即可，或者 30 天没跑时下次 `/knowledge-lint` 会有提醒。

---

## 四、典型一天长什么样

```
早上开 Claude Code
  → "团队知识库已同步至最新版本"     [SessionStart 自动]
  → 开始干活

写支付重试模块
  → 你: "我要加重试，要不要做幂等？"
  → Claude 自动激活 skill，读知识库，返回:
    "找到 TK-PAT-003《幂等键设计》(verified) 推荐用业务 ID + 版本号..."
    + 给出方案，附 knowledgeReferences

调试一个奇怪的 bug
  → 你: "为啥这里会死锁？"
  → Claude 自动查 anti-patterns，命中 TK-AP-001
    "这是已知反模式：你在 @Transactional 里调了 RPC..."

任务完成
  → "提示：如果本次任务有可沉淀的经验，运行 /archive..."  [Stop 自动]
  → 你: "/archive"
  → archiver: "提取了 1 条 pitfall（支付幂等键冲突排查路径）和 1 条 guideline
              （重试间隔 jitter 配置），写到 pending/，提 PR 命令如下..."
  → 你 review → push → 开 PR → 队友 review → 合入

(下班，没了)
```

---

## 五、PR 里怎么写 knowledgeReferences

业务项目的 PR 描述里加这一段（推荐用 `templates/business-project-pr-template.md` 自动提示）：

```markdown
## Knowledge references

- TK-AP-001: 避免事务里调 RPC（用于 — 架构选型理由）
- BK-PAY-PIT-002: 幂等键冲突排查（用于 — 重试模块设计）
```

**作用**：未来工具会扫这些字段更新对应条目的 `last_referenced` 字段，驱动 maturity 自动提升。**写了就有用，不写不报错**——但写多了你贡献的条目会越来越快升到 verified / proven。

---

## 六、常见问题快查

| 现象 | 原因 | 解决 |
|---|---|---|
| 没看到 `团队知识库已同步至最新版本` | hook 没跑 / 知识库目录不存在 | 重装 plugin（v0.1.2 修过 hook bug）；跑 bootstrap.sh |
| `/knowledge-lint` 报 `No module named 'yaml'` | 缺 pyyaml | `pip3 install --break-system-packages pyyaml` |
| Claude 没主动查知识库就直接回答 | skill description 没匹配上你的问题 | 显式说："用 team-knowledge skill 查一下..." |
| `/archive` 提取的内容质量差 | 会话信息不够 / 太琐碎 | 先 review pending/ 里的草稿，差的直接删，不是必须全提 PR |
| 知识库 git pull 一直失败 | 网络或权限问题 | 检查 `~/.team-knowledge/.git` 的 remote；离线时忽略警告即可 |

更多问题看 [README.md §6](README.md#6-常见问题)。

---

## TL;DR：你要记的就两件

1. **干活前**装一次环境（一行命令）+ 给业务项目 cat 一次 CLAUDE.md.template
2. **干活后**敲 `/archive`（Stop hook 会提醒，没忘的事）

剩下查询、同步、subagent 调度、引用追踪——全是自动的。
