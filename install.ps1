[CmdletBinding()]
param(
    [Alias('ExtraTargets')]
    [string[]]$TargetDirs = @(),

    [string[]]$SearchRoots = @(),

    [switch]$SkipPluginInstall
)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -ge 5) {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
}

$HomeRoot = if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) { $env:USERPROFILE } else { $HOME }
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillSource = Join-Path $RepoRoot 'skills\github-sync'

if (-not (Test-Path -LiteralPath (Join-Path $SkillSource 'SKILL.md'))) {
    throw "未找到通用技能源文件: $SkillSource\SKILL.md"
}

function Resolve-SkillDestination {
    param([string]$InputPath)

    $trimmed = $InputPath.Trim().TrimEnd('\', '/')
    $leaf = Split-Path -Leaf $trimmed
    if ($leaf -ieq 'github-sync') {
        return $trimmed
    }
    if ($leaf -ieq 'skills') {
        return (Join-Path $trimmed 'github-sync')
    }
    return (Join-Path $trimmed 'skills\github-sync')
}

function Test-HarnessDirectory {
    param(
        [string]$DirPath,
        [bool]$StrictAppData = $false
    )

    if (-not (Test-Path -LiteralPath $DirPath -PathType Container)) {
        return $false
    }

    $name = Split-Path -Leaf $DirPath
    $noiseNames = @('Microsoft', 'Temp', 'Programs', 'Packages', 'Cache', 'Caches', 'CrashDumps', 'npm', 'npm-cache', 'pip', 'Yarn', 'Local', 'Roaming', 'Low', '.git', 'node_modules')
    if ($noiseNames -contains $name) {
        return $false
    }

    if (Test-Path -LiteralPath (Join-Path $DirPath 'skills') -PathType Container) {
        return $true
    }

    $strongMarkers = @('mcp_config.json', 'mcp.json', 'config.toml', 'AGENTS.md', 'CLAUDE.md', 'GEMINI.md', 'plugins')
    foreach ($marker in $strongMarkers) {
        if (Test-Path -LiteralPath (Join-Path $DirPath $marker)) {
            return $true
        }
    }

    if (-not $StrictAppData) {
        if (Test-Path -LiteralPath (Join-Path $DirPath 'settings.json')) {
            return $true
        }
        $knownNames = @('.agents', '.dsh', '.codex', '.claude', '.cursor', '.windsurf', '.cline', '.roo', '.qoder', '.qoder-cn', '.zcode', '.opencode', '.opencode2dsh', 'opencode')
        if ($knownNames -contains $name.ToLowerInvariant()) {
            return $true
        }
    }

    return $false
}

function Add-DiscoveredHarness {
    param(
        [System.Collections.Generic.Dictionary[string, string]]$TargetsMap,
        [string]$HarnessRoot,
        [string]$Label
    )

    $skillDest = Resolve-SkillDestination -InputPath $HarnessRoot
    $key = $skillDest.ToLowerInvariant()
    if (-not $TargetsMap.ContainsKey($key)) {
        $TargetsMap[$key] = "$Label|$skillDest"
    }
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

    # Remove legacy 'github' skill folder if present alongside target
    $legacyGithubSkill = Join-Path $destParent 'github'
    if ((Test-Path -LiteralPath $legacyGithubSkill) -and -not ($resolvedSrc.Equals((Resolve-Path -LiteralPath $legacyGithubSkill).Path.TrimEnd('\', '/'), [System.StringComparison]::OrdinalIgnoreCase))) {
        Remove-Item -LiteralPath $legacyGithubSkill -Recurse -Force -ErrorAction SilentlyContinue
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

$targetsMap = New-Object 'System.Collections.Generic.Dictionary[string, string]'

# 1. Always ensure universal ~/.agents/skills/github-sync is included
Add-DiscoveredHarness -TargetsMap $targetsMap -HarnessRoot (Join-Path $HomeRoot '.agents') -Label 'Universal (.agents)'

# 2. Explicitly passed custom harness directories
foreach ($custom in $TargetDirs) {
    if (-not [string]::IsNullOrWhiteSpace($custom)) {
        $label = "Custom ($(Split-Path -Leaf $custom.TrimEnd('\', '/')))"
        Add-DiscoveredHarness -TargetsMap $targetsMap -HarnessRoot $custom -Label $label
    }
}

# 3. Dynamic probing across standard and extra search roots
$probeRoots = New-Object System.Collections.Generic.List[hashtable]
$probeRoots.Add(@{ Path = $HomeRoot; DotOnly = $true; Strict = $false })

$xdgConfig = if (-not [string]::IsNullOrWhiteSpace($env:XDG_CONFIG_HOME)) { $env:XDG_CONFIG_HOME } else { Join-Path $HomeRoot '.config' }
if (Test-Path -LiteralPath $xdgConfig) {
    $probeRoots.Add(@{ Path = $xdgConfig; DotOnly = $false; Strict = $false })
}
if (-not [string]::IsNullOrWhiteSpace($env:APPDATA) -and (Test-Path -LiteralPath $env:APPDATA)) {
    $probeRoots.Add(@{ Path = $env:APPDATA; DotOnly = $false; Strict = $true })
}
if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA) -and (Test-Path -LiteralPath $env:LOCALAPPDATA)) {
    $probeRoots.Add(@{ Path = $env:LOCALAPPDATA; DotOnly = $false; Strict = $true })
}
foreach ($extraRoot in $SearchRoots) {
    if (-not [string]::IsNullOrWhiteSpace($extraRoot) -and (Test-Path -LiteralPath $extraRoot)) {
        $probeRoots.Add(@{ Path = $extraRoot; DotOnly = $false; Strict = $false })
    }
}

# Check nested ~/.gemini/config specifically
$geminiConfigDir = Join-Path $HomeRoot '.gemini\config'
if (Test-Path -LiteralPath $geminiConfigDir) {
    Add-DiscoveredHarness -TargetsMap $targetsMap -HarnessRoot $geminiConfigDir -Label 'Gemini/Antigravity (skills)'
}

foreach ($rootSpec in $probeRoots) {
    $rootPath = $rootSpec.Path
    if (-not (Test-Path -LiteralPath $rootPath)) { continue }

    $children = Get-ChildItem -LiteralPath $rootPath -Directory -Force -ErrorAction SilentlyContinue
    foreach ($child in $children) {
        if ($rootSpec.DotOnly -and -not $child.Name.StartsWith('.')) {
            continue
        }
        if ($child.Name -ieq '.gemini') {
            # Already checked ~/.gemini/config above
            continue
        }
        if (Test-HarnessDirectory -DirPath $child.FullName -StrictAppData $rootSpec.Strict) {
            Add-DiscoveredHarness -TargetsMap $targetsMap -HarnessRoot $child.FullName -Label "Probed ($($child.Name))"
        }
    }
}

$results = New-Object System.Collections.Generic.List[object]

foreach ($entry in $targetsMap.Values) {
    $parts = $entry -split '\|', 2
    $label = $parts[0]
    $dest = $parts[1]
    $status = Copy-DirectoryClean -Source $SkillSource -Destination $dest
    $results.Add([PSCustomObject]@{
        Harness = $label
        Path    = $dest
        Status  = $status
    })
}

# 4. Install/update native plugin bundle when ~/.gemini/config exists
if (-not $SkipPluginInstall -and (Test-Path -LiteralPath $geminiConfigDir)) {
    $pluginsRoot = Join-Path $geminiConfigDir 'plugins'
    $pluginTarget = Join-Path $pluginsRoot 'github-sync'
    $legacyPlugin = Join-Path $pluginsRoot 'github'

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
            Harness = 'Plugin Bundle (github-sync)'
            Path    = $pluginTarget
            Status  = 'Active (Source)'
        })
    } else {
        New-Item -ItemType Directory -Path $pluginTarget -Force | Out-Null
        foreach ($item in @('plugin.json', 'README.md', 'INSTALL.md', '.gitignore', 'install.ps1', 'install.sh', 'assets', 'rules', 'skills')) {
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
            Harness = 'Plugin Bundle (github-sync)'
            Path    = $pluginTarget
            Status  = 'Installed'
        })
    }

    if ((Test-Path -LiteralPath $legacyPlugin) -and -not ($resolvedRepo.Equals((Resolve-Path -LiteralPath $legacyPlugin).Path.TrimEnd('\', '/'), [System.StringComparison]::OrdinalIgnoreCase))) {
        Remove-Item -LiteralPath $legacyPlugin -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$results | Format-Table -AutoSize
$results | ConvertTo-Json -Depth 3
