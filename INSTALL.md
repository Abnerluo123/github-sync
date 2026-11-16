# 安装指南（面向 AI Agent 自动探测与安装）

当你（AI Agent）收到用户要求“帮我安装这个仓库 / 安装 github-sync 技能”时，请按以下步骤**主动探测本机所有 Agent Harness 目录**并完成安装，不要假设所有用户的工具都装在默认路径。

---

## 第一步：自我探测（当前正在运行的 Harness）

先确认**你自己**当前运行环境的技能加载目录：
1. 检查自身系统上下文、配置或环境变量中声明的技能目录与工作目录。
2. 检查环境变量：`HOME`、`USERPROFILE`、`XDG_CONFIG_HOME`、`APPDATA`、`LOCALAPPDATA`，以及任何 Agent 专属环境变量（如指向自定义配置目录的变量）。
3. 如果你发现当前自己的技能目录不在常见默认位置（例如装在自定义盘符、便携目录或企业定制路径），记下该目录作为后续安装的自定义目标。

---

## 第二步：动态扫描本机其他 Harness 目录

在以下根目录及其直接子目录中，探测是否存在其他 AI 编程 Agent 的配置目录：
- 用户主目录：`$HOME` / `%USERPROFILE%`（重点检查隐藏点目录 `.*`，如 `.agents`、`.gemini/config` 等）
- XDG 配置目录：`$XDG_CONFIG_HOME` 或 `~/.config`
- Windows 应用数据目录：`%APPDATA%`、`%LOCALAPPDATA%`（若用户明确提到某工具装在其他盘符，也一并纳入扫描）

**Harness 判定特征**（满足其一即可视为有效的 Agent 配置目录）：
- 目录下已存在 `skills/` 子目录；
- 目录下存在 AI Agent 专属配置或规则标记：`mcp_config.json`、`mcp.json`、`AGENTS.md`、`CLAUDE.md`、`GEMINI.md`；
- 属于常见 AI 编程 Agent 配置目录名（如 `.agents`、`.antigravity`、`.dsh`、`.codex`、`.claude`、`.cursor`、`.windsurf`、`.cline`、`.roo`、`.qoder`、`.zcode`、`opencode` 等）。

---

## 第三步：执行安装与清理旧版

### Windows（PowerShell）
在仓库根目录运行安装脚本；如果第一步或第二步发现了非默认路径的 Harness，请通过 `-TargetDirs`（或 `-ExtraTargets`）参数传入：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

传入自定义探查到的目录示例：
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -TargetDirs "D:\PortableAgents\my-agent","E:\Tools\custom-harness\skills"
```

### macOS / Linux / Git Bash
```bash
bash ./install.sh
# 如需指定额外的自定义目录：
bash ./install.sh "path/to/custom-harness"
```

> **提示**：脚本会自动将 `skills/github-sync` 复制到每个探测到的 `<harness>/skills/github-sync` 目录，清理历史遗留的同名旧技能目录 `skills/github`，并在检测到原生插件目录（如 `~/.gemini/config/plugins`）时同步安装完整插件包。

---

## 第四步：初始化共享配置并验证

安装完成后，运行一次状态检查以初始化全机共享配置文件 `~/.agents/github-sync/config.json` 并验证环境（注意沙盒限制时请确认权限）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME/.agents/skills/github-sync/scripts/github-cli.ps1" -Action status
```

完成后向用户汇报：
1. 本次探测到并完成安装的 Harness 目录列表；
2. 当前 `git`、`gh` 与 GitHub 登录状态；
3. 共享配置文件 `~/.agents/github-sync/config.json` 是否已就绪。
