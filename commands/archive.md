---
description: 触发知识沉淀流程，从本次会话提取可复用的知识到团队知识库
---

# /archive — 知识沉淀

调用 @archiver subagent，让它扫描本次会话的所有产物，提取可复用的知识条目。

## 任务

1. 启动 @archiver subagent
2. 让 archiver 完成提取，写入 `~/.team-knowledge/contributions/pending/`
3. 列出所有提取条目的摘要给用户
4. **不要直接 git commit 主分支**
5. 提示用户 review 并手动提 PR

## archiver 完成后，输出 review checklist

```
📋 Review Checklist（提 PR 前确认）

对每个提取的条目：
- [ ] frontmatter 中的 `id` 没有跟现有条目冲突
  → 检查命令: ls ~/.team-knowledge/{tech-wiki,biz-wiki}/**/*.md | grep <id>
- [ ] tags 准确（这些 tags 决定后续搜索能不能命中）
- [ ] body 中的代码示例可运行
- [ ] source_references 指向真实的 PR 或 commit
- [ ] maturity 是 `draft`（不是更高）

如果都没问题：

  cd ~/.team-knowledge
  git add contributions/pending/
  git commit -m "knowledge: archive from <project> $(date +%Y-%m-%d)"
  # 然后推 feature branch + PR

如果有问题：
- 直接编辑 contributions/pending/ 下的文件
- 或者删除该文件（不入库）
```

## 何时不应触发 archive

如果用户的本次任务是：
- 纯粹的知识查询（没产生新知识）
- 简单 bug 修复（已经在已知 pitfall 中）
- 项目特有配置变更

提示用户："本次会话似乎没有可沉淀的新知识。如果你认为有，请运行 /knowledge-add 手动添加。"
