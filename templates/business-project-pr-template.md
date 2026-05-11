<!--
团队知识库 PR 模板（业务项目复制用）
=========================================

放置位置: <你的业务项目>/.github/pull_request_template.md

作用: 提示 PR 作者标注本次工作引用了哪些知识库条目，以及是否触发 /archive。
这些信息会被未来工具（promote.py 等）消费，驱动 maturity 提升。
-->

## What this PR does

<!-- 1-2 sentences -->

## Knowledge references

<!-- 引用了哪些团队知识库条目（如有）。格式:
- TK-AP-001: 避免事务里调 RPC (用于 — 架构选型理由)
- BK-XXX-PIT-002: 库存超扣陷阱 (用于 — 并发控制设计)

无引用就写 N/A。
-->

## Knowledge archive

<!-- 完成后是否运行了 /archive？ -->

- [ ] 已在 Claude Code 内运行 `/archive`
- [ ] 新增/修订的知识条目已列出（如有）:
  -

<!-- 如果未运行 /archive，简述原因（例：纯配置改动 / 已知陷阱无新内容）。 -->
