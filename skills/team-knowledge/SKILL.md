---
name: team-knowledge
description: "Auto-invoke whenever the user asks about architecture decisions, technical choices, debugging known issues, business rules, domain models, or any task where prior team experience could apply. Provides access to the team's accumulated knowledge base across tech-wiki (cross-project tech patterns and anti-patterns) and biz-wiki (per-domain business knowledge: entities, processes, pitfalls, decisions). Always consult before making non-trivial design decisions or when encountering unfamiliar bugs."
---

# Team Knowledge Base

知识库位于 `~/.team-knowledge/`（团队共享 Git 仓库）。如果用户在 `~/.claude/settings.json` 的 `env` 中设置了 `TEAM_KNOWLEDGE_REPO`，以该路径为准；下文所有 `~/.team-knowledge/` 都按相同规则替换。

## 严格的查询协议（按顺序，不要跳级）

### Step 1 — 读全景目录（永远先做这步，零成本）

读 `~/.team-knowledge/knowledge-catalog.md`（≤80 行）。

这个文件告诉你：
- 知识库有哪些分类
- 每类多少条目
- 当前任务阶段应该优先查哪个 catalog

### Step 2 — 读分类清单（按 Step 1 的指引）

根据 Step 1 中"按任务阶段推荐查阅路径"表，读对应的 `catalog.md`：
- `tech-wiki/catalog.md`
- `biz-wiki/{domain}/catalog.md`

每条知识在 catalog 里只有一行：`ID | 标题 | maturity | tags`

**用 tags 和 maturity 过滤** —— 优先选 `proven` > `verified` > `draft`。

### Step 3 — 读完整条目（仅当 catalog 过滤后命中相关条目）

读 `TK-*.md` 或 `BK-*.md` 完整文件，约 50-200 行。

**只读真正相关的**。如果不确定相关性，先读到第一个 `## ` 二级标题就停下，再决定是否继续。

### Step 4（可选）— 沿溯源链深入

每个条目有 `source_references` 字段，指向原始 PR / 复盘文档。仅在需要追溯具体推导过程时读取。

## 各任务阶段的查询焦点

| 当前任务 | 优先 catalog | 重点知识类型 |
|---|---|---|
| 业务理解 / 需求分析 | `biz-wiki/{domain}/catalog.md` | model, process, pitfall |
| 技术选型 | `tech-wiki/catalog.md` | decision, anti-patterns |
| 架构设计 | 两个都要 | decision, model, anti-patterns |
| 编码实现 | `tech-wiki/patterns/`, `team-conventions/` | guideline (recommend) |
| 排查 bug | **先 `*/pitfalls/`**, 再 `anti-patterns/` | pitfall, guideline (avoid) |
| 跨团队对接 | `biz-wiki/{domain}/processes/` | process |

## 引用追踪（强制要求）

任何使用了知识库条目的产出（架构方案、代码改动、排查报告），必须在 JSON 输出或 markdown 报告底部附 `knowledgeReferences`：

```json
{
  "knowledgeReferences": [
    {"id": "TK-PAT-001", "title": "分页查询延迟关联优化", "usedIn": "Step 2 性能优化"},
    {"id": "BK-ECO-PIT-001", "title": "高并发库存超扣", "usedIn": "并发控制设计"}
  ]
}
```

ARCHIVE 阶段会扫描这些引用，自动更新对应条目的 `last_referenced` 字段，触发成熟度提升。

## 深度查询

如果需要对某个主题做大范围查询（"找所有跟事务相关的知识"），**调用 `@knowledge-explorer` subagent**，不要在主上下文里 grep —— 会爆 token。

## 不要做的事

- ❌ 不要把整个 catalog.md 全部读完（那是给 lint 用的，不是给查询用）
- ❌ 不要直接读 `TK-*.md` / `BK-*.md`，先经过 catalog 过滤
- ❌ 不要主动写知识条目（用 `/archive` 让 archiver 提取）
- ❌ 不要在主上下文里 grep 整个知识库（用 `@knowledge-explorer`）
- ❌ 不要 commit 到知识库主分支（contributions/pending/ 是唯一允许的写入目标）

## 触发 archive 流程

任务完成后，提醒用户运行 `/archive`，让 archiver subagent 提取本次会话中产生的知识。
