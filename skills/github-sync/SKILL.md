---
name: github-sync
description: >-
  一键跳转浏览器完成 GitHub OAuth 授权登录，自动配置本地 Git 工具、提交身份与 HTTPS 凭据，
  并支持自动初始化仓库、创建远程仓库、提交代码迭代与同步推送。
metadata:
  version: "1.2.0"
  date: "2026-11-16"
---

# GitHub Sync (`github-sync`)

本技能封装了 Git 与 GitHub CLI 环境探测与安装、浏览器 OAuth 一键登录、统一本地配置共享以及项目建仓、提交与同步推送流程，遵循通用 `SKILL.md` 规范，可在支持该规范的各类本地 AI 编程 Agent 中运行。

---

## 脚本与共享配置

- **PowerShell 脚本（Windows）**：`<skill-dir>/scripts/github-cli.ps1`
- **Bash 包装脚本（Git Bash / POSIX 环境）**：`<skill-dir>/scripts/github-cli.sh`
- **全局共享配置**：`~/.agents/github-sync/config.json`
  - 脚本在执行 `status`、`setup`、`login`、`sync` 时会自动维护这份共享配置，缓存已发现的 `gitPath`、`ghPath`，以及 `defaultVisibility`（默认 `"private"`）、`defaultBranch`（默认 `"main"`）、`ghAccount`、`gitUserName`、`gitUserEmail` 与 `updatedAt`。
  - 同一台机器上的所有 Agent 均复用同一套系统级 Git / GitHub CLI 凭据与 `~/.agents/github-sync/config.json`，只需登录一次即可跨 Agent 共享。

请**优先定位当前 `SKILL.md` 所在目录下的 `scripts/github-cli.ps1`（或 `scripts/github-cli.sh`）**；若需要回退路径，可按 `~/.agents/skills/github-sync/scripts/github-cli.ps1` 或当前环境配置目录下的 `skills/github-sync/scripts/github-cli.ps1` 查找。

---

## 执行权限与沙盒说明

若当前运行环境启用了命令沙盒：
- **`-Action status`**：仅做本地探测与状态输出，可在默认沙盒中执行。
- **`-Action setup` / `login` / `sync`**：需要联网、`winget` 安装软件、拉起交互窗口与浏览器完成 OAuth 授权，或向 GitHub 创建仓库与推送代码，**请在联网/宿主机权限下运行（若沙盒阻断，提请用户授权执行）**。

---

## 标准操作指令

以下示例以 `<SCRIPT>` 表示定位到的 `github-cli.ps1`（Bash 环境可替换为对应的 `github-cli.sh`）：

### 1. 检查当前状态 (`status`)
PowerShell：
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<SCRIPT>" -Action status -RepoPath "<项目路径>"
```
Bash：
```bash
bash "<SCRIPT_SH>" -Action status -RepoPath "<项目路径>"
```
返回 JSON，包含 `gitInstalled`、`ghInstalled`、`ghLoggedIn`、`ghTokenPresent`、`ghAccount`、`gitUserName`、`gitUserEmail`、`sharedConfigPath`、`isGitRepo`、`branch`、`uncommittedCount`、`originUrl`。

### 2. 自动安装 Git 与 GitHub CLI (`setup`)
当 `gitInstalled` 或 `ghInstalled` 为 `false` 时运行（需联网权限）：
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<SCRIPT>" -Action setup
```

### 3. 浏览器一键登录 GitHub (`login`)
若尚未安装工具会自动先安装，随后弹出交互窗口显示一次性授权码并自动拉起浏览器访问 `https://github.com/login/device` 完成 OAuth 授权；授权完成后自动执行 `gh auth setup-git` 并同步全局 `user.name`、`user.email` 与共享配置 `~/.agents/github-sync/config.json`。
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<SCRIPT>" -Action login
```
若需强制重新切换账号登录，追加 `-Force`。

### 4. 提交迭代并推送到 GitHub (`sync`)
适用于首次把项目推上新仓库，或修改代码后的增量提交与推送：
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<SCRIPT>" -Action sync -RepoPath "<项目路径>" -CommitMessage "<有意义的提交说明>" -RepoName "<可选仓库名>" -Visibility private
```
（若不传 `-Visibility`，则读取 `~/.agents/github-sync/config.json` 中的 `defaultVisibility`，默认 `private`。）

行为说明：
1. 若本机未安装工具或未登录，会自动补齐安装并拉起浏览器授权登录。
2. 每次同步都会自动执行 `gh auth setup-git` 确保 Git HTTPS 凭据已就绪。
3. 若目标目录尚未初始化 `.git`，自动执行 `git init -b <defaultBranch>`（默认 `main`）。
4. 若工作区存在变更，自动执行 `git add -A` 与 `git commit -m <CommitMessage>`。
5. 若尚未关联 `origin` 远程仓库，自动使用 `gh repo create` 创建远程仓库并推送；若已有 `origin`，直接执行 `git push -u origin HEAD`。

---

## 推荐协作流程

1. 当用户请求“登录 GitHub”或“连接 GitHub 账号”时：
   - 先执行 `-Action status` 检查现状。
   - 若未登录，告知用户即将打开授权窗口与浏览器完成登录，随后以联网权限执行 `-Action login`。
   - **不要**要求用户手动去网页生成并粘贴 Personal Access Token（PAT），除非用户明确要求使用 PAT 或 MCP。
2. 当用户请求“把项目推到 GitHub”或“提交这次修改并推送”时：
   - 先检查是否已有 `.gitignore` 或明显不应提交的敏感文件（如 `.env`、密钥文件），必要时先处理。
   - 根据本次实际改动生成清晰的 `-CommitMessage`，未指定可见性时沿用共享配置默认可见性（`private`），执行 `-Action sync`。
3. 完成后向用户反馈远程仓库 URL、分支名称与最新 Commit 信息。
