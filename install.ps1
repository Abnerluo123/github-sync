[CmdletBinding()]
param(
    [switch]$SkipPluginInstall
)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -ge 5) {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
}

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillSource = Join-Path $RepoRoot 'skills\github'

if (-not (Test-Path -LiteralPath (Join-Path $SkillSource 'SKILL.md'))) {
    throw "未找到通用技能源文件: $SkillSource\SKILL.md"
}

function Copy-DirectoryClean {
    param(
        [string]$Source,
        [string]$Destination
    )

    $resolvedSrc = (Resolve-Path -LiteralPath $Source).Path.TrimEnd('\', '/')
    $destParent = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $destParent)) {
        New-Item -ItemType Directory -Path $destParent -Force | Out-Null
    }

    if (Test-Path -LiteralPath $Destination) {
        $resolvedDest = (Resolve-Path -LiteralPath $Destination).Path.TrimEnd('\', '/')
        if ($resolvedSrc.Equals($resolvedDest, [System.StringComparison]::OrdinalIgnoreCase)) {
            return 'Skipped (SamePath)'
        }
        Remove-Item -LiteralPath $Destination -Recurse -Force
    }

    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
    return 'Installed'
}

$results = New-Object System.Collections.Generic.List[object]

# 1. Always install to universal .agents skills directory
$universalTarget = Join-Path $env:USERPROFILE '.agents\skills\github'
$status = Copy-DirectoryClean -Source $SkillSource -Destination $universalTarget
$results.Add([PSCustomObject]@{
    Agent  = 'Universal (.agents)'
    Path   = $universalTarget
    Status = $status
})

# 2. Install to Antigravity standalone skills directory (when ~/.gemini/config exists)
$geminiConfigDir = Join-Path $env:USERPROFILE '.gemini\config'
if (Test-Path -LiteralPath $geminiConfigDir) {
    $agSkillTarget = Join-Path $geminiConfigDir 'skills\github'
    $status = Copy-DirectoryClean -Source $SkillSource -Destination $agSkillTarget
    $results.Add([PSCustomObject]@{
        Agent  = 'Antigravity (skills)'
        Path   = $agSkillTarget
        Status = $status
    })
}

# 3. Install to detected agent config directories
$agentTargets = @(
    @{ Name = 'DSH (DeepSeek)'; Root = (Join-Path $env:USERPROFILE '.dsh'); Target = (Join-Path $env:USERPROFILE '.dsh\skills\github') },
    @{ Name = 'OpenCode'; Root = (Join-Path $env:USERPROFILE '.config\opencode'); Target = (Join-Path $env:USERPROFILE '.config\opencode\skills\github') },
    @{ Name = 'OpenCode2DSH'; Root = (Join-Path $env:USERPROFILE '.opencode2dsh'); Target = (Join-Path $env:USERPROFILE '.opencode2dsh\skills\github') },
    @{ Name = 'Codex CLI'; Root = (Join-Path $env:USERPROFILE '.codex'); Target = (Join-Path $env:USERPROFILE '.codex\skills\github') },
    @{ Name = 'Claude Code'; Root = (Join-Path $env:USERPROFILE '.claude'); Target = (Join-Path $env:USERPROFILE '.claude\skills\github') }
)

foreach ($entry in $agentTargets) {
    if (Test-Path -LiteralPath $entry.Root) {
        $status = Copy-DirectoryClean -Source $SkillSource -Destination $entry.Target
        $results.Add([PSCustomObject]@{
            Agent  = $entry.Name
            Path   = $entry.Target
            Status = $status
        })
    }
}

# 4. Also install/update the full Antigravity plugin if running outside ~/.gemini/config/plugins/github
if (-not $SkipPluginInstall) {
    $pluginTarget = Join-Path $env:USERPROFILE '.gemini\config\plugins\github'
    $resolvedRepo = (Resolve-Path -LiteralPath $RepoRoot).Path.TrimEnd('\', '/')
    $pluginAlreadyTarget = $false
    if (Test-Path -LiteralPath $pluginTarget) {
        $resolvedPlugin = (Resolve-Path -LiteralPath $pluginTarget).Path.TrimEnd('\', '/')
        if ($resolvedRepo.Equals($resolvedPlugin, [System.StringComparison]::OrdinalIgnoreCase)) {
            $pluginAlreadyTarget = $true
        }
    }

    if ($pluginAlreadyTarget) {
        $results.Add([PSCustomObject]@{
            Agent  = 'Antigravity (plugin)'
            Path   = $pluginTarget
            Status = 'Active (Source)'
        })
    } elseif (Test-Path -LiteralPath $geminiConfigDir) {
        New-Item -ItemType Directory -Path $pluginTarget -Force | Out-Null
        foreach ($item in @('plugin.json', 'README.md', '.gitignore', 'install.ps1', 'assets', 'rules', 'skills')) {
            $srcItem = Join-Path $RepoRoot $item
            if (Test-Path -LiteralPath $srcItem) {
                $dstItem = Join-Path $pluginTarget $item
                if (Test-Path -LiteralPath $dstItem) {
                    Remove-Item -LiteralPath $dstItem -Recurse -Force
                }
                Copy-Item -LiteralPath $srcItem -Destination $dstItem -Recurse -Force
            }
        }
        $results.Add([PSCustomObject]@{
            Agent  = 'Antigravity (plugin)'
            Path   = $pluginTarget
            Status = 'Installed'
        })
    }
}

$results | Format-Table -AutoSize
$results | ConvertTo-Json -Depth 3
