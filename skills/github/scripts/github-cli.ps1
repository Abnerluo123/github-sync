[CmdletBinding()]
param(
    [ValidateSet('status', 'setup', 'login', 'sync')]
    [string]$Action = 'status',

    [string]$RepoPath = (Get-Location).Path,

    [string]$CommitMessage = 'chore: update project',

    [string]$RepoName = '',

    [ValidateSet('private', 'public')]
    [string]$Visibility = 'private',

    [switch]$Force
)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -ge 5) {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
}

function Add-StandardToolPaths {
    $candidateList = New-Object System.Collections.Generic.List[string]
    foreach ($p in @(
        'C:\Program Files\Git\cmd',
        'C:\Program Files\Git\bin',
        'C:\Program Files (x86)\Git\cmd',
        (Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Git\bin'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'),
        'C:\Program Files\GitHub CLI',
        'C:\Program Files (x86)\GitHub CLI',
        (Join-Path $env:LOCALAPPDATA 'Programs\GitHub CLI')
    )) {
        $candidateList.Add($p)
    }

    $wingetPkgRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    if (Test-Path -LiteralPath $wingetPkgRoot) {
        Get-ChildItem -LiteralPath $wingetPkgRoot -Directory -Filter 'Git*' -ErrorAction SilentlyContinue | ForEach-Object {
            $candidateList.Add((Join-Path $_.FullName 'cmd'))
            $candidateList.Add((Join-Path $_.FullName 'bin'))
        }
        Get-ChildItem -LiteralPath $wingetPkgRoot -Directory -Filter 'GitHub.cli*' -ErrorAction SilentlyContinue | ForEach-Object {
            $candidateList.Add((Join-Path $_.FullName 'bin'))
        }
    }

    $existingParts = @($env:PATH -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $toPrepend = New-Object System.Collections.Generic.List[string]

    foreach ($dir in $candidateList) {
        if ((Test-Path -LiteralPath $dir) -and ($existingParts -notcontains $dir) -and (-not $toPrepend.Contains($dir))) {
            $toPrepend.Add($dir)
        }
    }

    if ($toPrepend.Count -gt 0) {
        $env:PATH = ($toPrepend -join ';') + ';' + $env:PATH
    }
}

function Get-ToolPath {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }
    return $null
}

function Test-GhAuthenticated {
    $ghPath = Get-ToolPath -Name 'gh'
    if (-not $ghPath) {
        return $false
    }
    $prevPref = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $null = & $ghPath auth status 2>&1
    $code = $LASTEXITCODE
    if ($code -eq 0) {
        $ErrorActionPreference = $prevPref
        return $true
    }
    $tokenOut = & $ghPath auth token -h github.com 2>$null
    $tokenCode = $LASTEXITCODE
    $ErrorActionPreference = $prevPref
    return ($tokenCode -eq 0 -and -not [string]::IsNullOrWhiteSpace(($tokenOut -join '')))
}

function Sync-GitIdentity {
    $gitPath = Get-ToolPath -Name 'git'
    $ghPath = Get-ToolPath -Name 'gh'
    if (-not $gitPath -or -not $ghPath) {
        return $null
    }

    $prevPref = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $userJson = & $ghPath api user 2>$null
    $apiExit = $LASTEXITCODE
    $ErrorActionPreference = $prevPref

    if ($apiExit -ne 0 -or [string]::IsNullOrWhiteSpace(($userJson -join ''))) {
        return $null
    }

    $user = ($userJson -join "`n") | ConvertFrom-Json
    $currentName = (& $gitPath config --global user.name 2>$null)
    $currentEmail = (& $gitPath config --global user.email 2>$null)

    if ([string]::IsNullOrWhiteSpace($currentName)) {
        $targetName = if (-not [string]::IsNullOrWhiteSpace($user.name)) { $user.name } else { $user.login }
        if (-not [string]::IsNullOrWhiteSpace($targetName)) {
            & $gitPath config --global user.name $targetName
        }
    }

    if ([string]::IsNullOrWhiteSpace($currentEmail)) {
        $targetEmail = if (-not [string]::IsNullOrWhiteSpace($user.email)) {
            $user.email
        } elseif ($user.id -and $user.login) {
            "$($user.id)+$($user.login)@users.noreply.github.com"
        } else {
            $null
        }
        if (-not [string]::IsNullOrWhiteSpace($targetEmail)) {
            & $gitPath config --global user.email $targetEmail
        }
    }

    return [PSCustomObject]@{
        login    = $user.login
        gitName  = (& $gitPath config --global user.name 2>$null)
        gitEmail = (& $gitPath config --global user.email 2>$null)
    }
}

function Invoke-Status {
    Add-StandardToolPaths

    $gitPath = Get-ToolPath -Name 'git'
    $ghPath = Get-ToolPath -Name 'gh'

    $gitVersion = $null
    if ($gitPath) {
        $gitVersion = ((& $gitPath --version 2>$null) -join ' ').Trim()
    }

    $ghVersion = $null
    $ghLoggedIn = $false
    $ghTokenPresent = $false
    $ghAccount = $null
    $ghAuthDetails = $null
    if ($ghPath) {
        $ghVersion = (((& $ghPath --version 2>$null) | Select-Object -First 1) -join ' ').Trim()
        $prevPref = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $authOutput = (& $ghPath auth status 2>&1) | ForEach-Object { $_.ToString() }
        $authExit = $LASTEXITCODE
        $tokenOut = & $ghPath auth token -h github.com 2>$null
        $tokenExit = $LASTEXITCODE
        $ErrorActionPreference = $prevPref

        $ghTokenPresent = ($tokenExit -eq 0 -and -not [string]::IsNullOrWhiteSpace(($tokenOut -join '')))
        $ghAuthDetails = ($authOutput -join "`n").Trim()
        $ghLoggedIn = ($authExit -eq 0 -or $ghTokenPresent)
        foreach ($line in $authOutput) {
            if ($line -match 'account\s+([^\s(]+)') {
                $ghAccount = $Matches[1]
                break
            }
        }
    }

    $gitUserName = $null
    $gitUserEmail = $null
    if ($gitPath) {
        $gitUserName = (& $gitPath config --global user.name 2>$null)
        $gitUserEmail = (& $gitPath config --global user.email 2>$null)
    }

    $resolvedRepoPath = $RepoPath
    if (Test-Path -LiteralPath $RepoPath) {
        $resolvedRepoPath = (Resolve-Path -LiteralPath $RepoPath).Path
    }

    $isGitRepo = $false
    $branch = $null
    $uncommittedCount = 0
    $originUrl = $null

    if ($gitPath -and (Test-Path -LiteralPath $resolvedRepoPath)) {
        $prevPref = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $inside = & $gitPath -C $resolvedRepoPath rev-parse --is-inside-work-tree 2>$null
        $insideExit = $LASTEXITCODE
        $ErrorActionPreference = $prevPref

        if ($insideExit -eq 0 -and ($inside -join '').Trim() -eq 'true') {
            $isGitRepo = $true
            $branchOut = (& $gitPath -C $resolvedRepoPath branch --show-current 2>$null)
            $branch = if (-not [string]::IsNullOrWhiteSpace(($branchOut -join ''))) { ($branchOut -join '').Trim() } else { 'HEAD' }
            $porcelain = @(& $gitPath -C $resolvedRepoPath status --porcelain 2>$null | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            $uncommittedCount = $porcelain.Count
            $remoteOut = (& $gitPath -C $resolvedRepoPath remote get-url origin 2>$null)
            if ($LASTEXITCODE -eq 0) {
                $originUrl = ($remoteOut -join '').Trim()
            }
        }
    }

    $result = [PSCustomObject]@{
        gitInstalled     = [bool]$gitPath
        gitPath          = $gitPath
        gitVersion       = $gitVersion
        ghInstalled      = [bool]$ghPath
        ghPath           = $ghPath
        ghVersion        = $ghVersion
        ghLoggedIn       = $ghLoggedIn
        ghTokenPresent   = $ghTokenPresent
        ghAccount        = $ghAccount
        ghAuthDetails    = $ghAuthDetails
        gitUserName      = $gitUserName
        gitUserEmail     = $gitUserEmail
        repoPath         = $resolvedRepoPath
        isGitRepo        = $isGitRepo
        branch           = $branch
        uncommittedCount = $uncommittedCount
        originUrl        = $originUrl
    }

    $result | ConvertTo-Json -Depth 4
}

function Invoke-Setup {
    Add-StandardToolPaths

    $gitPath = Get-ToolPath -Name 'git'
    $ghPath = Get-ToolPath -Name 'gh'

    if (-not $gitPath -or -not $ghPath) {
        $wingetPath = Get-ToolPath -Name 'winget'
        if (-not $wingetPath) {
            throw '未找到 winget，请手动安装 Git (https://git-scm.com/) 和 GitHub CLI (https://cli.github.com/)。'
        }

        if (-not $gitPath) {
            Write-Host '正在通过 winget 安装 Git (Git.Git)...'
            & $wingetPath install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -ne 0) {
                throw "安装 Git 失败，winget 退出码: $LASTEXITCODE"
            }
        }

        if (-not $ghPath) {
            Write-Host '正在通过 winget 安装 GitHub CLI (GitHub.cli)...'
            & $wingetPath install --id GitHub.cli -e --source winget --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -ne 0) {
                throw "安装 GitHub CLI 失败，winget 退出码: $LASTEXITCODE"
            }
        }

        Add-StandardToolPaths
        $gitPath = Get-ToolPath -Name 'git'
        $ghPath = Get-ToolPath -Name 'gh'
    }

    if (-not $gitPath) {
        throw 'Git 安装后仍未在标准路径中找到 git.exe，请重启终端或检查安装路径。'
    }
    if (-not $ghPath) {
        throw 'GitHub CLI 安装后仍未在标准路径中找到 gh.exe，请重启终端或检查安装路径。'
    }

    Write-Host "Git 已就绪: $(& $gitPath --version)"
    Write-Host "GitHub CLI 已就绪: $((& $ghPath --version | Select-Object -First 1))"
}

function Invoke-Login {
    Add-StandardToolPaths

    if (-not (Get-ToolPath -Name 'git') -or -not (Get-ToolPath -Name 'gh')) {
        Invoke-Setup
    }

    $ghPath = Get-ToolPath -Name 'gh'
    $alreadyLoggedIn = Test-GhAuthenticated

    if (-not $alreadyLoggedIn -or $Force) {
        Write-Host '正在打开交互窗口以启动浏览器完成 GitHub 一键授权登录...'
        $escapedGh = $ghPath.Replace("'", "''")
        $childCmd = "& '$escapedGh' auth login --hostname github.com --git-protocol https --web -s repo,workflow; if (`$LASTEXITCODE -ne 0) { Write-Host ''; Read-Host 'GitHub 登录未完成，按回车键关闭窗口' }"

        $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-Command', $childCmd) -Wait -PassThru
        if (-not (Test-GhAuthenticated)) {
            throw "GitHub 浏览器登录未完成（退出码: $($proc.ExitCode)）。请重试并完成浏览器授权。"
        }
    } else {
        Write-Host '检测到本地已登录 GitHub 账号。'
    }

    & $ghPath auth setup-git --hostname github.com
    if ($LASTEXITCODE -ne 0) {
        Write-Warning 'gh auth setup-git 返回非零状态，请确认 HTTPS Git 凭据是否已生效。'
    }

    $identity = Sync-GitIdentity
    if ($identity) {
        Write-Host "登录账号: $($identity.login)"
        Write-Host "Git user.name: $($identity.gitName)"
        Write-Host "Git user.email: $($identity.gitEmail)"
    }
}

function Invoke-Sync {
    Add-StandardToolPaths

    if (-not (Get-ToolPath -Name 'git') -or -not (Get-ToolPath -Name 'gh')) {
        Invoke-Setup
    }

    if (-not (Test-GhAuthenticated)) {
        Invoke-Login
    }

    $gitPath = Get-ToolPath -Name 'git'
    $ghPath = Get-ToolPath -Name 'gh'

    & $ghPath auth setup-git --hostname github.com
    if ($LASTEXITCODE -ne 0) {
        Write-Warning 'gh auth setup-git 返回非零状态，请确认 HTTPS Git 凭据是否已生效。'
    }

    $null = Sync-GitIdentity
    $gitName = (& $gitPath config --global user.name 2>$null)
    $gitEmail = (& $gitPath config --global user.email 2>$null)
    if ([string]::IsNullOrWhiteSpace($gitName) -or [string]::IsNullOrWhiteSpace($gitEmail)) {
        throw 'Git 全局身份 (user.name / user.email) 未设置，请先运行登录或手动设置。'
    }

    if (-not (Test-Path -LiteralPath $RepoPath)) {
        throw "目标项目路径不存在: $RepoPath"
    }
    $resolvedRepoPath = (Resolve-Path -LiteralPath $RepoPath).Path

    Push-Location -LiteralPath $resolvedRepoPath
    try {
        $prevPref = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $inside = & $gitPath rev-parse --is-inside-work-tree 2>$null
        $insideExit = $LASTEXITCODE
        $ErrorActionPreference = $prevPref

        if ($insideExit -ne 0 -or ($inside -join '').Trim() -ne 'true') {
            Write-Host "正在初始化 Git 仓库 (main 分支): $resolvedRepoPath"
            & $gitPath init -b main
            if ($LASTEXITCODE -ne 0) {
                throw "git init 失败，退出码: $LASTEXITCODE"
            }
        }

        $changes = @(& $gitPath status --porcelain 2>$null | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($changes.Count -gt 0) {
            Write-Host "检测到 $($changes.Count) 项变更，正在暂存并提交..."
            & $gitPath add -A
            if ($LASTEXITCODE -ne 0) {
                throw "git add 失败，退出码: $LASTEXITCODE"
            }
            & $gitPath commit -m $CommitMessage
            if ($LASTEXITCODE -ne 0) {
                throw "git commit 失败，退出码: $LASTEXITCODE"
            }
        } else {
            Write-Host '工作区没有新的未提交变更。'
        }

        $prevPref = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $null = & $gitPath rev-parse --verify HEAD 2>$null
        $hasHead = ($LASTEXITCODE -eq 0)
        $ErrorActionPreference = $prevPref

        if (-not $hasHead) {
            throw '当前目录没有任何可提交的文件或 Commit，无法推送空仓库。请先添加至少一个文件。'
        }

        $prevPref = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $originUrl = & $gitPath remote get-url origin 2>$null
        $hasOrigin = ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace(($originUrl -join '')))
        $ErrorActionPreference = $prevPref

        if (-not $hasOrigin) {
            $targetRepoName = if (-not [string]::IsNullOrWhiteSpace($RepoName)) {
                $RepoName
            } else {
                Split-Path -Path $resolvedRepoPath -Leaf
            }

            Write-Host "未检测到 origin 远程仓库，正在创建 GitHub 仓库 ($targetRepoName, $Visibility) 并推送..."
            $visibilityFlag = "--$Visibility"
            & $ghPath repo create $targetRepoName $visibilityFlag --source=. --remote=origin --push
            if ($LASTEXITCODE -ne 0) {
                throw "创建并推送 GitHub 仓库失败，退出码: $LASTEXITCODE"
            }
        } else {
            Write-Host '正在推送到 GitHub 远程仓库 origin...'
            & $gitPath push -u origin HEAD
            if ($LASTEXITCODE -ne 0) {
                throw "git push 失败，退出码: $LASTEXITCODE"
            }
        }

        $finalOrigin = ((& $gitPath remote get-url origin 2>$null) -join '').Trim()
        $latestCommit = ((& $gitPath log -1 --format="%h %s" 2>$null) -join '').Trim()
        $currentBranch = ((& $gitPath branch --show-current 2>$null) -join '').Trim()

        [PSCustomObject]@{
            repoPath     = $resolvedRepoPath
            originUrl    = $finalOrigin
            branch       = $currentBranch
            latestCommit = $latestCommit
        } | ConvertTo-Json -Depth 3
    } finally {
        Pop-Location
    }
}

switch ($Action) {
    'status' { Invoke-Status }
    'setup'  { Invoke-Setup }
    'login'  { Invoke-Login }
    'sync'   { Invoke-Sync }
}
