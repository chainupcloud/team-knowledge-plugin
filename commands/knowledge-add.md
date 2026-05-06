---
description: 手动添加一条知识到团队知识库（少数情况使用，多数时候应该用 /archive）
---

# /knowledge-add — 手动添加知识

**优先使用 `/archive`**（让 archiver 从会话产物自动提取）。仅在以下情况手动添加：

- archiver 漏掉了某条重要知识
- 你想从外部资料（书、文章、其他人的经验）总结一条进来
- 修订一条已有条目（这种情况建议改成 PR 改原文件）

## 交互流程

向用户依次询问（每次一个问题）：

### Q1：知识类型

是哪种类型？
- (1) `decision` — 技术/架构决策
- (2) `pitfall` — 已知陷阱、踩过的坑
- (3) `guideline` — 推荐做法 (recommend) 或禁止做法 (avoid)
- (4) `model` — 实体定义、数据结构
- (5) `process` — 业务流程、状态机

### Q2：归属层级

跨项目通用还是特定业务领域？
- (1) Layer 1 (`tech-wiki/`) — 跨项目通用技术
- (2) Layer 2 (`biz-wiki/{domain}/`) — 业务领域知识
  - 如果选这个，问用户具体哪个 domain（参考 `~/.team-knowledge/.knowledge-config.yaml`）

### Q3：标题

用一句话概括这条知识。

### Q4：核心内容

让用户口述/粘贴核心内容。如果用户给的是零散信息，由你按对应类型的 body 模板（见 archiver subagent）整理。

### Q5：标签

3-5 个 tags，用于后续过滤。建议从已有 tags 中选（运行 `grep -h "^tags:" ~/.team-knowledge/**/*.md | sort -u`）。

### Q6：来源

source_references 是什么？（PR / commit / 文章 URL / 个人经验）

## 写入

按 archiver 的模板生成文件，写入：

```
~/.team-knowledge/contributions/pending/<生成的 ID>.md
```

**maturity 一律 `draft`，contributors 只列当前用户。**

## 完成后

输出：

```
✅ 已写入 ~/.team-knowledge/contributions/pending/<filename>

下一步：
  cd ~/.team-knowledge
  git add contributions/pending/<filename>
  git commit -m "knowledge: add <ID> <title>"
  git push 然后提 PR
```
