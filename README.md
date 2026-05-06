# team-knowledge — Claude Code Plugin

Claude Code plugin。安装后，团队成员的 Claude Code 会按统一规则与团队知识库交互（3 级渐进式索引、archiver 自动沉淀、SessionStart 自动 pull）。

## 目录结构（plugin 规范布局）

```
team-knowledge-plugin/
├── .claude-plugin/
│   └── plugin.json              ← plugin 元数据
├── skills/team-knowledge/
│   └── SKILL.md                 ← 知识库查询入口（auto-invoked）
├── agents/
│   ├── archiver.md              ← /archive 调用的 subagent
│   └── knowledge-explorer.md    ← 深度查询，不污染主上下文
├── commands/
│   ├── archive.md               ← /archive
│   ├── knowledge-add.md         ← /knowledge-add
│   ├── knowledge-lint.md        ← /knowledge-lint
│   └── import-knowledge.md      ← /import-knowledge
├── hooks/
│   └── hooks.json               ← SessionStart 自动 git pull + Stop 提醒
└── CLAUDE.md.template           ← 项目级 CLAUDE.md 片段（手动追加）
```

## 前置条件

团队知识仓库必须 clone 到本地：

```bash
git clone <你们团队的 team-knowledge git URL> ~/.team-knowledge
```

如需自定义路径，在 `~/.claude/settings.json` 中设置环境变量：

```json
{
  "env": {
    "TEAM_KNOWLEDGE_REPO": "/your/custom/path"
  }
}
```

skill / agents / commands / hooks 全部按 `${TEAM_KNOWLEDGE_REPO:-~/.team-knowledge}` 解析。

## 安装方式

### 方式 A：本地 marketplace（推荐用于团队内部测试）

```bash
claude
```

进入会话后：

```
> /plugin marketplace add /path/to/team-knowledge-starter/team-knowledge-plugin
> /plugin install team-knowledge
```

### 方式 B：软链到 plugins 目录

```bash
mkdir -p ~/.claude/plugins
ln -s /path/to/team-knowledge-starter/team-knowledge-plugin ~/.claude/plugins/team-knowledge
```

重启 Claude Code 即生效。

### 方式 C：发布到团队 marketplace（生产部署）

把这个目录推到团队的 marketplace 仓库（参考 https://docs.claude.com/en/docs/claude-code/plugins）。团队成员：

```
> /plugin marketplace add <团队 marketplace 仓库 URL>
> /plugin install team-knowledge
```

## 项目级 CLAUDE.md 片段

plugin 不会自动改你项目的 `CLAUDE.md`。把 `CLAUDE.md.template` 的内容追加到你**业务项目**根目录的 `CLAUDE.md`：

```bash
cat /path/to/team-knowledge-starter/team-knowledge-plugin/CLAUDE.md.template \
    >> /path/to/your/project/CLAUDE.md
```

这段内容告诉 Claude：本项目接入了团队知识库，必须遵守查询纪律和引用追踪。

## 验证安装

```bash
claude
```

```
> /knowledge-lint
> 帮我查一下团队知识库里关于订单状态机的内容
```

期望看到：
- 启动时输出 `📚 团队知识库已同步至最新版本`（SessionStart hook）
- skill 自动触发，Claude 先读 `knowledge-catalog.md` 而不是直接 grep
- `/knowledge-lint` 跑通 `lint.py`

## 卸载

```
> /plugin uninstall team-knowledge
```

或删除软链 `rm ~/.claude/plugins/team-knowledge`。
