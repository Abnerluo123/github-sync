---
name: github
description: >-
  像 Codex/豆包一样一键跳转浏览器登录 GitHub，自动配置本地 Git 工具、身份与 HTTPS 凭证，
  并支持一键初始化仓库、创建 GitHub 远程仓库、提交代码迭代并推送上去。适用于 Antigravity、DSH、OpenCode、Codex 与 Claude Code 等通用 Agent。
metadata:
  version: "1.1.0"
  date: "2026-11-16"
---

# GitHub 一键登录与同步技能（通用多 Agent 版）

本技能通过统一的脚本封装了环境检测、工具安装、浏览器 OAuth 一键登录以及项目提交推送流程，适用于 **Antigravity、DSH、OpenCode、Codex、Claude Code** 等遵循 `SKILL.md` 规范的 AI Agent。

---

## 脚本定位方式（跨 Agent / 跨机器通用）

请**优先使用当前 `SKILL.md` 所在目录下的 `scripts/` 路径**（不要硬编码特定用户名路径）：
- **PowerShell（Windows 推荐）**：`<skill-dir>/scripts/github-cli.ps1`
- **Bash / Git Bash（兼容 OpenCode / DSH Bash 环境）**：`<skill-dir>/scripts/github-cli.sh`

若未记录当前 `SKILL.md` 路径，可按以下常见回退路径定位：
1. `~/.agents/skills/github/scripts/github-cli.ps1`
2. `~/.gemini/config/plugins/github/skills/github/scripts/github-cli.ps1`
3. `~/.dsh/skills/github/scripts/github-cli.ps1`
4. `~/.config/opencode/skills/github/scripts/github-cli.ps1`
5. `~/.codex/skills/github/scripts/github-cli.ps1`

---

## 沙盒与权限规范（重要）

如果当前 Agent 运行在沙盒环境中（例如 Antigravity）：
- **`-Action status`**：可在标准沙盒中运行（`BypassSandbox: false`），用于检查 `git` / `gh` 安装状态、本地账号缓存及项目仓库状态。
- **`-Action setup` / `login` / `sync`**：**必须以非沙盒权限运行（`BypassSandbox: true`）**。因为这些操作需要调用 `winget` 安装软件、访问 GitHub 网络接口、弹出交互窗口与浏览器完成 OAuth 授权，或执行 `gh repo create` / `git push`。

---

## 标准操作指令

以下示例以 `<SCRIPT>` 代表定位到的 `github-cli.ps1`（若在 Bash 环境下也可直接调用对应的 `github-cli.sh`）：

### 1. 检查当前状态 (`status`)
PowerShell:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<SCRIPT>" -Action status -RepoPath "<项目路径>"
```
Bash:
```bash
bash "<SCRIPT_SH>" -Action status -RepoPath "<项目路径>"
```
返回 JSON，包含 `gitInstalled`、`ghInstalled`、`ghLoggedIn`、`ghTokenPresent`、`ghAccount`、`gitUserName`、`gitUserEmail`、`isGitRepo`、`branch`、`uncommittedCount`、`originUrl`。

### 2. 自动安装 Git 与 GitHub CLI (`setup`)
当 `gitInstalled` 或 `ghInstalled` 为 `false` 时运行（需联网权限）：
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<SCRIPT>" -Action setup
```

### 3. 浏览器一键登录 GitHub (`login`)
若尚未安装工具会自动先安装，随后弹出交互式 PowerShell 窗口显示一次性验证码并自动拉起浏览器访问 `https://github.com/login/device` 完成授权；授权后会自动执行 `gh auth setup-git` 并同步全局 `user.name` 与 `user.email`。
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<SCRIPT>" -Action login
```
若需强制重新切换账号登录，追加 `-Force`。

### 4. 提交迭代并推送到 GitHub (`sync`)
适用于首次把项目推上新仓库，或日常修改完代码后的增量提交与推送：
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<SCRIPT>" -Action sync -RepoPath "<项目路径>" -CommitMessage "<有意义的提交说明>" -RepoName "<可选仓库名>" -Visibility private
```
行为说明：
1. 若本机未安装工具或未登录，会自动补齐安装并拉起浏览器登录。
2. 每次同步会自动确保 `gh auth setup-git` 已绑定当前 Git HTTPS 凭据。
3. 若目标目录尚未初始化 `.git`，自动执行 `git init -b main`。
4. 若工作区存在修改，自动执行 `git add -A` 与 `git commit -m <CommitMessage>`。
5. 若尚未关联 `origin` 远程仓库，自动使用 `gh repo create` 创建仓库（默认 `private`，可指定 `public`）并推送；若已有 `origin`，直接执行 `git push -u origin HEAD`。

---

## 推荐协作流程

1. 当用户说“登录 GitHub”或“绑定 GitHub”时：
   - 先运行 `-Action status` 了解现状。
   - 若未登录，告知用户即将拉起授权流程（如需安装工具一并说明），随后以联网权限执行 `-Action login`。
   - **不要**要求用户手动去网页生成并粘贴 Personal Access Token（PAT），除非用户明确要求使用 PAT 或 MCP。
2. 当用户说“把项目推到 GitHub”或“提交这次迭代并推送”时：
   - 先检查是否已有 `.gitignore` 或明显不应提交的敏感文件（如 `.env`、密钥文件），必要时提醒或处理。
   - 根据实际改动生成清晰的 `-CommitMessage`，若首次建仓且用户未指定可见性，默认使用 `private`（或按用户要求传 `public`），执行 `-Action sync`。
3. 推送完成后，再次反馈远程仓库 URL、分支名称与最新 Commit 信息。
