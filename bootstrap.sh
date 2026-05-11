#!/usr/bin/env bash
# team-knowledge bootstrap — 一键安装环境
#
# 用法:
#   bash bootstrap.sh                                       # 用默认知识库 URL
#   bash bootstrap.sh git@github.com:your-org/your-kb.git   # 用自定义知识库
#
# 也可以远程跑:
#   curl -fsSL https://raw.githubusercontent.com/chainupcloud/team-knowledge-plugin/main/bootstrap.sh | bash

set -euo pipefail

DEFAULT_REPO_URL="git@github.com:chainupcloud/team-knowledge.git"
KNOWLEDGE_REPO_URL="${1:-$DEFAULT_REPO_URL}"
KNOWLEDGE_REPO_DIR="${TEAM_KNOWLEDGE_REPO:-$HOME/.team-knowledge}"

print_header() {
  echo ""
  echo "=================================================="
  echo "  team-knowledge bootstrap"
  echo "=================================================="
  echo "  Knowledge repo: $KNOWLEDGE_REPO_URL"
  echo "  Local path:     $KNOWLEDGE_REPO_DIR"
  echo ""
}

step() { echo "[$1/$2] $3"; }

# ------------------------------------------------------------------
# Step 1/4: 前置检查
# ------------------------------------------------------------------
check_prereqs() {
  step 1 4 "检查依赖 (git, python3, pip3)..."
  for cmd in git python3 pip3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "      ERROR: 缺少 $cmd，请先安装"
      exit 1
    fi
  done
  echo "      OK"
}

# ------------------------------------------------------------------
# Step 2/4: clone 或 pull 知识库
# ------------------------------------------------------------------
sync_knowledge_repo() {
  if [ -d "$KNOWLEDGE_REPO_DIR/.git" ]; then
    step 2 4 "知识库已存在，拉取最新..."
    (cd "$KNOWLEDGE_REPO_DIR" && git pull --quiet origin main) && echo "      OK"
  else
    step 2 4 "Clone 知识库到 $KNOWLEDGE_REPO_DIR..."
    git clone --quiet "$KNOWLEDGE_REPO_URL" "$KNOWLEDGE_REPO_DIR"
    echo "      OK"
  fi
}

# ------------------------------------------------------------------
# Step 3/4: Python 依赖
# ------------------------------------------------------------------
install_python_deps() {
  step 3 4 "安装 Python 依赖 (pyyaml)..."
  if python3 -c "import yaml" >/dev/null 2>&1; then
    echo "      已安装"
    return
  fi

  if pip3 install --quiet pyyaml 2>/dev/null; then
    echo "      OK"
  elif pip3 install --quiet --break-system-packages pyyaml 2>/dev/null; then
    echo "      OK (用了 --break-system-packages 绕过 PEP 668)"
  else
    echo "      WARNING: pyyaml 装失败，请手动:"
    echo "         pip3 install --break-system-packages pyyaml"
  fi
}

# ------------------------------------------------------------------
# Step 4/4: 验证
# ------------------------------------------------------------------
verify() {
  step 4 4 "验证安装..."
  if python3 "$KNOWLEDGE_REPO_DIR/scripts/lint.py" >/dev/null 2>&1; then
    echo "      lint.py 跑通"
  else
    echo "      WARNING: lint.py 失败，可能 pyyaml 没装好"
  fi
}

# ------------------------------------------------------------------
# 收尾提示
# ------------------------------------------------------------------
print_next_steps() {
  cat <<EOF

==================================================
  下一步 (在 Claude Code 里执行)
==================================================

  > /plugin marketplace add chainupcloud/team-knowledge-plugin
  > /plugin install team-knowledge

每个想接入知识库的业务项目，根目录跑一次:

  cat ~/.claude/plugins/cache/*/team-knowledge/*/CLAUDE.md.template >> ./CLAUDE.md

(如果未来你需要自定义知识库路径，编辑 ~/.claude/settings.json 顶层加:
  "env": { "TEAM_KNOWLEDGE_REPO": "/your/path" })

完成。
EOF
}

print_header
check_prereqs
sync_knowledge_repo
install_python_deps
verify
print_next_steps
