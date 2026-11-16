# GitHub Sync (`github-sync`)

通用的多 Agent GitHub 登录与同步技能包：一键跳转浏览器完成 GitHub OAuth 授权登录，自动配置本地 Git 工具、提交身份与 HTTPS 凭据，并支持自动初始化仓库、创建远程仓库、提交代码迭代与同步推送。

## 核心功能

- **浏览器一键 OAuth 登录 (`login`)**：自动拉起交互终端显示授权码并跳转浏览器完成 GitHub OAuth 授权（无需手动生成/粘贴 PAT），自动执行 `gh auth setup-git` 绑定凭据并配置全局 `user.name` 与 `user.email`。
- **自动环境探测与安装 (`setup` / `status`)**：自动发现标准路径与 WinGet 包目录中的 `git` 与 `gh`，缺失时自动通过 `winget` 安装并立即生效；实时输出工具、登录账号与项目仓库状态。
- **一键建仓与迭代推送 (`sync`)**：自动完成 `git init`、暂存变更、提交 Commit，未关联远程仓库时自动通过 `gh repo create` 创建仓库并推送，已有远程仓库时直接 `git push`。
- **跨 Agent 共享配置**：统一读写系统级 Git / GitHub CLI 凭据与 `~/.agents/github-sync/config.json`，登录一次即可在当前电脑上的所有 Agent 之间共享。

---

## 安装方式

### 方式一：让 AI Agent 自动探查本机 Harness 目录并安装（推荐）

如果你的电脑里某些 Agent 安装在自定义路径或便携目录中，直接把本仓库地址或本地目录交给任意支持读文件的 Agent，并告诉它：

> “按 `INSTALL.md` 探测我电脑上的所有 Agent Harness 目录，并安装这个 `github-sync` 技能。”

Agent 会按照 [INSTALL.md](INSTALL.md) 主动识别自身加载目录并扫描本机所有 Harness 路径后完成安装。

### 方式二：运行启发式探测脚本安装

Windows（PowerShell）：
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```
如需额外指定自定义 Harness 路径或扫描根目录：
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -TargetDirs "D:\MyAgent" -SearchRoots "D:\Agents"
```

macOS / Linux / Git Bash：
```bash
bash ./install.sh
```

---

## 共享配置文件 (`~/.agents/github-sync/config.json`)

首次运行任意命令后，脚本会在 `~/.agents/github-sync/config.json` 自动生成并维护全局共享配置：

```json
{
  "gitPath": "...",
  "ghPath": "...",
  "defaultVisibility": "private",
  "defaultBranch": "main",
  "ghAccount": "...",
  "gitUserName": "...",
  "gitUserEmail": "...",
  "updatedAt": "..."
}
```

- `gitPath` / `ghPath`：缓存已探测到的 `git` 与 `gh` 可执行文件路径，加速所有 Agent 调用。
- `defaultVisibility`：首次自动建仓的默认可见性（`"private"` 或 `"public"`）。
- `defaultBranch`：初始化新仓库时的默认分支名（默认 `"main"`）。

---

## 目录结构

```text
.
├── plugin.json                        # 插件清单
├── INSTALL.md                         # AI Agent 自探查与安装指南
├── install.ps1                        # Windows 启发式探测与多 Harness 安装脚本
├── install.sh                         # POSIX / Git Bash 安装脚本
├── README.md
├── assets/
│   └── logo.svg                       # 图标资源
├── rules/
│   └── AGENTS.md                      # 插件触发规范
└── skills/
    └── github-sync/
        ├── SKILL.md                   # 通用技能说明
        ├── agents/
        │   └── openai.yaml            # 技能接口元数据
        └── scripts/
            ├── github-cli.ps1         # 核心 PowerShell 自动化脚本
            └── github-cli.sh          # Bash / Git Bash 兼容包装脚本
```

---

## 常用自然语言指令

- “登录我的 GitHub 账号”
- “查看我的 GitHub 登录状态和当前仓库同步情况”
- “把当前项目推送到我的 GitHub”
- “提交这次代码修改并同步到 GitHub”
