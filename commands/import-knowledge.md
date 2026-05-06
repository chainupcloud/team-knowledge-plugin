---
description: 冷启动：从历史项目导入知识到团队知识库
argument-hint: <项目根路径>
---

# /import-knowledge — 历史项目冷启动导入

把已有项目（已积累代码和文档但没接入知识库）的知识批量导入到团队知识库。

参数：`$ARGUMENTS` = 项目根路径（默认当前目录）

## 三阶段管道

### Phase 1: 多源资料收集

扫描以下来源：
- `README.md`, `docs/`, `wiki/` 等文档目录
- Git commit message（grep "知识"/"决策"/"踩坑"等关键词）
- 项目内的 `CLAUDE.md` 子文件（已有的零散经验）
- ARCHITECTURE.md / DESIGN.md / DECISIONS.md
- 团队 wiki 链接（如果有，让用户提供）

输出：临时文件 `/tmp/knowledge-raw-collection.md`

### Phase 2: 代码库画像

代码扫描（最多 60 次工具调用，控制成本）：
- 技术栈：从 package.json / pom.xml / Cargo.toml 等推断
- 主要模块：扫描顶层目录结构
- 关键模式：grep 常见反模式（事务里调 RPC、未关闭的资源等）
- 依赖关系：粗略画出模块依赖

输出：`/tmp/codebase-profile.md`

### Phase 3: 知识标准化

让 archiver subagent 处理 Phase 1 + Phase 2 的产出：

- 提取 4 维基线（架构概览、核心实体、关键决策、已知约束）
- 提取 ≤13 条具体知识条目（不要贪多，宁缺毋滥）
- 所有条目初始 `maturity: draft`，`evidence.confidence: 0.5`

写入 `~/.team-knowledge/contributions/pending/`，**全部带前缀 `IMPORT_<项目名>_`** 便于识别。

## 状态持久化

把进度写入 `/tmp/import-state-<项目名>.json`：

```json
{
  "project": "...",
  "phase_completed": "phase_2",
  "files_scanned": 247,
  "raw_collection": "/tmp/knowledge-raw-collection.md",
  "codebase_profile": "/tmp/codebase-profile.md",
  "candidates_extracted": 8,
  "started_at": "...",
  "last_updated": "..."
}
```

如果中断，下次运行 `/import-knowledge --resume` 可以续跑。

## 完成后

输出：

```
✅ 冷启动导入完成

扫描覆盖：
  - 文档文件: N 个
  - 代码文件: N 个 (限制 60 个搜索预算)
  - Git commits: 最近 100 条

提取候选: K 条
  - decisions: X
  - pitfalls: Y
  - guidelines: Z
  - models: A
  - processes: B

⚠️ 冷启动导入的条目质量参差不齐，建议：

1. 让原项目核心成员逐条 review contributions/pending/IMPORT_*
2. 删掉低质量候选（不要 commit 了凑数）
3. 高质量的合入主分支
4. 后续通过实际工作流逐步把 maturity 从 draft 提升到 verified
```

## 不要做的事

- ❌ 不要追求一次性完美 —— draft 是正常状态
- ❌ 不要超出 60 次代码搜索预算 —— 否则成本失控
- ❌ 不要从 commit message 直接提取知识 —— 通过 archiver 二次加工
