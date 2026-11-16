# GitHub 插件使用规范

当用户提出以下任一需求时，请立即激活 `github` 技能（位于 `$HOME/.gemini/config/plugins/github/skills/github/SKILL.md` 或通用技能目录 `~/.agents/skills/github/SKILL.md`）并优先调用其脚本 `$HOME/.gemini/config/plugins/github/skills/github/scripts/github-cli.ps1`（或技能目录下的 `scripts/github-cli.ps1`）完成操作：
- 登录或绑定 GitHub 账号（如“登录 GitHub”、“连接我的 GitHub”）
- 查看 GitHub 登录状态或当前项目仓库同步状态
- 在 GitHub 创建远程仓库，或将本地项目初始化、提交并推送到 GitHub
- 在完成代码迭代后要求把修改提交并推到 GitHub

**交互原则**：
- 默认始终采用一键跳转浏览器 OAuth 登录流程（`-Action login`），**不要**要求用户手动到网页生成并粘贴 Personal Access Token（PAT），除非用户主动明确提出要使用 PAT 或配置 GitHub MCP Server。
- 对于需要联网、安装软件或弹出浏览器授权窗口的操作（`setup`、`login`、`sync`），必须使用 `BypassSandbox: true` 运行命令。
