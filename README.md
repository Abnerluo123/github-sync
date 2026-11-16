# GitHub 一键登录与同步（Antigravity 插件 & 多 Agent 通用技能包）

一个可用于 **Antigravity、DSH、OpenCode、Codex、Claude Code** 等主流 AI 编程 Agent 的通用 GitHub 技能包与 Antigravity 原生插件：支持像 Codex / 豆包一样一键跳转浏览器完成 GitHub OAuth 授权登录、自动配置本地 `Git` 与 `GitHub CLI (gh)`、同步 Git 提交身份，并一键完成项目建仓、提交与推送。

## 核心能力

- **环境检测 (`status`)**：自动发现标准路径与 WinGet 安装目录中的 `git` / `gh`，检查 GitHub 登录账号与本地凭据状态，以及目标目录的分支、未提交变更与远程仓库地址。
- **自动安装 (`setup`)**：若本机尚未安装 `git` 或 `gh`，自动通过 `winget` 安装并刷新当前会话路径，无需重启 IDE/终端即可使用。
- **浏览器一键 OAuth 登录 (`login`)**：弹出交互终端显示一次性授权码并自动拉起浏览器登录 GitHub，无需手动创建/粘贴 PAT；授权完成后自动运行 `gh auth setup-git` 并根据 GitHub 账号配置全局 `git config user.name` 与 `user.email`。
- **一键建仓与推送迭代 (`sync`)**：自动执行 `git init -b main`（若未初始化）、`git add -A`、`git commit`，首次推送自动通过 `gh repo create` 创建远程仓库（默认 `private`，可指定 `public`）并推送；后续修改直接增量提交并 `git push`。
- **多 Agent 通用包装**：提供 `SKILL.md`、`agents/openai.yaml`、PowerShell 脚本（`github-cli.ps1`）与 Bash 包装器（`github-cli.sh`）。

## 一键安装到所有本地 Agent

在仓库根目录运行安装脚本，即可自动将 `github` 技能同步安装到本机已有的 Agent 技能目录中（包括 `~/.agents/skills/github`、`~/.dsh/skills/github`、`~/.config/opencode/skills/github`、`~/.codex/skills/github`、`~/.claude/skills/github` 及 Antigravity 插件/技能目录）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

## 目录结构

```text
.
├── plugin.json                        # Antigravity 插件清单
├── install.ps1                        # 一键分发安装到多 Agent 技能目录
├── README.md
├── assets/
│   └── logo.svg                       # 插件图标
├── rules/
│   └── AGENTS.md                      # Antigravity 插件全局触发规范
└── skills/
    └── github/
        ├── SKILL.md                   # 跨 Agent 通用技能说明
        ├── agents/
        │   └── openai.yaml            # OpenCode / DSH / Codex 元数据配置
        └── scripts/
            ├── github-cli.ps1         # 核心 PowerShell 自动化脚本
            └── github-cli.sh          # Bash / Git Bash 兼容包装脚本
```

## 常见指令示例

直接对任意已安装该技能的 Agent 说：
- “登录我的 GitHub 账号”
- “查看我的 GitHub 登录状态和当前仓库同步情况”
- “把当前项目推送到我的 GitHub”
- “帮我提交这次代码迭代并推到 GitHub”
