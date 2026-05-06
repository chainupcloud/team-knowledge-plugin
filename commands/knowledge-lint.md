---
description: 对团队知识库执行健康检查（索引一致性、孤儿条目、衰减、重复检测）
---

# /knowledge-lint — 知识库健康检查

执行步骤：

## 1. 切换到知识库目录

```bash
cd ~/.team-knowledge
```

## 2. 拉取最新版本

```bash
git pull --quiet origin main
```

## 3. 运行 lint

```bash
python3 scripts/lint.py
```

## 4. 解读结果

如果 lint 报告了问题：

### 索引不一致
→ 运行 `python3 scripts/lint.py --rebuild-catalog` 输出建议表格，把它替换到对应 `catalog.md`

### 孤儿条目
→ 跟 maintainer 评估：是真的没用还是只是没人引用？
   - 如果确实过时 → 写到 `contributions/conflicts/` 让 maintainer 决定归档还是修订
   - 如果只是冷门 → 加引用记录（手动更新 last_referenced）

### 衰减建议
→ 运行 `python3 scripts/lint.py --apply` 应用衰减（注意先 git diff 检查）

### 疑似重复
→ 让用户 review，决定是否合并条目

## 5. 同步检查 maturity 提升

```bash
python3 scripts/promote.py
```

如果有提升候选，跟 maintainer 确认后：

```bash
python3 scripts/promote.py --apply
git diff  # 检查改动
git add -A && git commit -m "knowledge: maturity promotion review $(date +%Y-%m)"
```

## 6. 输出汇总报告

向用户输出：

```
📊 知识库健康检查报告 (date)

总体：
  - 总条目数: N
  - maturity 分布: { proven: N, verified: N, draft: N }

问题统计：
  - 索引不一致: N 处
  - 孤儿条目: N 个
  - 待衰减: N 个
  - 疑似重复: N 组

提升候选：
  - draft → verified: N 个
  - verified → proven: N 个

建议优先处理：
  1. {最重要的问题}
  2. {次重要的问题}
```

## 触发频率建议

- **每月初**由 maintainer 主动跑一次
- **每完成 10 个工作流**自动提醒（待开发的功能）
- **超过 30 天没跑** 在下次 `/flow-run` 启动时提醒
