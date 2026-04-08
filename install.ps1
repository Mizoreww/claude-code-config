#Requires -Version 5.1
<#
.SYNOPSIS
    Awesome Claude Code Configuration Installer (Windows)
.DESCRIPTION
    https://github.com/Mizoreww/awesome-claude-code-config
.EXAMPLE
    .\install.ps1                  # Interactive selector
    .\install.ps1 -All             # Install everything (non-interactive)
    .\install.ps1 -Uninstall       # Uninstall everything
    .\install.ps1 -DryRun          # Preview changes
    # Remote install:
    & ([scriptblock]::Create((irm https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/main/install.ps1)))
#>

# When piped via `irm URL | iex`, PowerShell cannot bind param() correctly —
# directory names from subcommands (e.g. "adversarial-review") leak as
# positional arguments. Wrapping in & { ... } isolates the parameter scope.
& {
param(
    [switch]$All,
    [switch]$Uninstall,
    [switch]$Version,
    [switch]$DryRun,
    [switch]$Force,
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$CLAUDE_DIR = Join-Path $env:USERPROFILE ".claude"
$REPO_URL = "https://github.com/Mizoreww/awesome-claude-code-config"
$VERSION_STAMP_FILE = Join-Path $CLAUDE_DIR ".awesome-claude-code-config-version"

# --- Colors ----------------------------------------------------------------

function Write-Info  { param([string]$Msg) Write-Host "[INFO] " -ForegroundColor Blue -NoNewline; Write-Host $Msg }
function Write-Ok    { param([string]$Msg) Write-Host "[OK] " -ForegroundColor Green -NoNewline; Write-Host $Msg }
function Write-Warn  { param([string]$Msg) Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline; Write-Host $Msg }
function Write-Err   { param([string]$Msg) Write-Host "[ERROR] " -ForegroundColor Red -NoNewline; Write-Host $Msg }

# --- Retry wrapper ---------------------------------------------------------

function Invoke-Retry {
    param(
        [int]$MaxAttempts,
        [int]$DelaySeconds,
        [string]$Description,
        [scriptblock]$Action
    )
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            & $Action
            return $true
        } catch {
            if ($attempt -lt $MaxAttempts) {
                Write-Warn "$Description failed (attempt $attempt/$MaxAttempts), retrying in ${DelaySeconds}s..."
                Start-Sleep -Seconds $DelaySeconds
            } else {
                Write-Warn "$Description failed after $MaxAttempts attempts, skipping."
            }
        }
    }
    return $false
}

# --- Remote install detection ----------------------------------------------

$script:SCRIPT_DIR = ""
$script:REMOTE_MODE = $false
$script:InstallWarnings = 0

function Initialize-ScriptDir {
    $script:SCRIPT_DIR = $PSScriptRoot

    if ($script:SCRIPT_DIR -and (Test-Path (Join-Path $script:SCRIPT_DIR "CLAUDE.md"))) {
        $script:REMOTE_MODE = $false
        return
    }

    # Remote mode: download zip to temp dir
    $script:REMOTE_MODE = $true
    $tmpdir = Join-Path ([System.IO.Path]::GetTempPath()) "claude-config-$(Get-Random)"
    New-Item -ItemType Directory -Path $tmpdir -Force | Out-Null

    $ver = if ($env:VERSION) { $env:VERSION } else { "main" }
    $zipUrl = "$REPO_URL/archive/refs/heads/$ver.zip"
    if ($ver -match '^v\d') {
        $zipUrl = "$REPO_URL/archive/refs/tags/$ver.zip"
    }

    Write-Info "Remote mode: downloading $ver..."
    $zipPath = Join-Path $tmpdir "source.zip"

    $ok = Invoke-Retry -MaxAttempts 5 -DelaySeconds 3 -Description "Download source zip" -Action {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
    }
    if (-not $ok) {
        Write-Err "Failed to download source after retries. Cannot continue in remote mode."
        exit 1
    }

    Expand-Archive -Path $zipPath -DestinationPath $tmpdir -Force
    $extracted = Get-ChildItem -Path $tmpdir -Directory | Where-Object { $_.Name -ne "source.zip" } | Select-Object -First 1
    $script:SCRIPT_DIR = $extracted.FullName
    Write-Ok "Source downloaded to temporary directory"
}

# --- Version management ----------------------------------------------------

function Get-SourceVersion {
    $vf = Join-Path $SCRIPT_DIR "VERSION"
    if (Test-Path $vf) { return (Get-Content $vf -Raw).Trim() }
    return "unknown"
}

function Get-InstalledVersion {
    if (Test-Path $VERSION_STAMP_FILE) { return (Get-Content $VERSION_STAMP_FILE -Raw).Trim() }
    return "not installed"
}

function Get-RemoteVersion {
    $url = "https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/main/VERSION"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $result = (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10).Content.Trim()
        if ($result) { return $result }
    } catch {}
    return "unavailable"
}

function Show-Version {
    $sv = Get-SourceVersion
    $iv = Get-InstalledVersion
    $rv = Get-RemoteVersion
    Write-Host "awesome-claude-code-config version info:"
    Write-Host "  Source:    $sv"
    Write-Host "  Installed: $iv"
    Write-Host "  Remote:    $rv"
    if ($iv -ne "not installed" -and $rv -ne "unavailable" -and $iv -ne $rv) {
        Write-Warn "Update available: $iv -> $rv"
    }
}

function Save-VersionStamp {
    $ver = Get-SourceVersion
    if ($ver -ne "unknown") {
        $ver | Set-Content -Path $VERSION_STAMP_FILE -NoNewline
    }
}

# --- Confirm prompt --------------------------------------------------------

function Confirm-Action {
    param([string]$Prompt = "Continue?")
    if ($Force) { return $true }
    $answer = Read-Host "$Prompt [y/N]"
    return ($answer -match '^[Yy]$')
}

# --- Plugin groups ---------------------------------------------------------

$PLUGINS_ESSENTIAL = @(
    "everything-claude-code@everything-claude-code"
    "superpowers@claude-plugins-official"
    "context7@claude-plugins-official"
    "commit-commands@claude-plugins-official"
    "document-skills@anthropic-agent-skills"
    "playwright@claude-plugins-official"
    "feature-dev@claude-plugins-official"
    "code-simplifier@claude-plugins-official"
    "ralph-loop@claude-plugins-official"
    "frontend-design@claude-plugins-official"
    "example-skills@anthropic-agent-skills"
    "github@claude-plugins-official"
)

$PLUGINS_CLAUDE_MEM = @(
    "claude-mem@thedotmack"
)

$PLUGINS_AI_RESEARCH = @(
    "tokenization@ai-research-skills"
    "fine-tuning@ai-research-skills"
    "post-training@ai-research-skills"
    "inference-serving@ai-research-skills"
    "distributed-training@ai-research-skills"
    "optimization@ai-research-skills"
)

$PLUGINS_HEALTH = @(
    "health@claude-health"
)

$PLUGINS_PUA = @(
    "pua@pua-skills"
)

$MARKETPLACE_LIST = @(
    @{ Name = "anthropic-agent-skills"; Repo = "anthropics/skills" }
    @{ Name = "everything-claude-code"; Repo = "affaan-m/everything-claude-code" }
    @{ Name = "ai-research-skills"; Repo = "zechenzhangAGI/AI-research-SKILLs" }
    @{ Name = "claude-plugins-official"; Repo = "anthropics/claude-plugins-official" }
    @{ Name = "thedotmack"; Repo = "thedotmack/claude-mem" }
    @{ Name = "claude-health"; Repo = "tw93/claude-health" }
    @{ Name = "pua-skills"; Repo = "tanweai/pua" }
    @{ Name = "openai-codex"; Repo = "openai/codex-plugin-cc" }
)

# --- Interactive menu ------------------------------------------------------

function Show-InteractiveMenu {
    # Two-level menu: groups contain items, Enter opens sub-menu
    $groups = @(
        @{ Label = "Core"; Hint = ""; Items = @(
            @{ Label = "CLAUDE.md";       Desc = "Global instructions template";      Default = $true;  Id = "claude-md" }
            @{ Label = "settings.json";   Desc = "Smart-merged Claude Code settings"; Default = $true;  Id = "settings" }
            @{ Label = "Common rules";    Desc = "Coding style, git, security, testing"; Default = $true; Id = "rules-common" }
            @{ Label = "StatusLine";      Desc = "Gradient progress bar & usage display"; Default = $true; Id = "hooks" }
            @{ Label = "Lessons";         Desc = "lessons.md template + SessionStart hook"; Default = $true; Id = "lessons" }
        )}
        @{ Label = "Language Rules"; Hint = "only install what your projects need"; Items = @(
            @{ Label = "Python rules";    Desc = "PEP 8, pytest, type hints, bandit"; Default = $false; Id = "rules-python" }
            @{ Label = "TypeScript rules"; Desc = "Zod, Playwright, immutability";    Default = $false; Id = "rules-ts" }
            @{ Label = "Go rules";        Desc = "gofmt, table-driven tests, gosec";  Default = $false; Id = "rules-go" }
        )}
        @{ Label = "Review"; Hint = "adversarial-review and Codex are mutually exclusive"; Items = @(
            @{ Label = "code-review plugin"; Desc = "PR code review (claude-plugins-official)"; Default = $true; Id = "review-code-review" }
            @{ Label = "adversarial-review"; Desc = "Cross-model adversarial review (poteto/noodle)"; Default = $true; Id = "review-adversarial" }
            @{ Label = "Codex CLI"; Desc = "Codex adversarial review (openai/codex)"; Default = $false; Id = "review-codex" }
        )}
        @{ Label = "Skills"; Hint = ""; Items = @(
            @{ Label = "paper-reading";   Desc = "Research paper summarization";      Default = $true;  Id = "skill-paper-reading" }
            @{ Label = "humanizer";       Desc = "Remove AI writing patterns (English, blader)"; Default = $true; Id = "skill-humanizer" }
            @{ Label = "humanizer-zh";    Desc = "Remove AI writing patterns (Chinese, op7418)"; Default = $false; Id = "skill-humanizer-zh" }
            @{ Label = "update-config";   Desc = "Configure Claude Code via settings.json"; Default = $true; Id = "skill-update-config" }
        )}
        @{ Label = "Plugins - Official"; Hint = ""; Items = @(
            @{ Label = "everything-claude-code"; Desc = "TDD, security, database, Go/Python/Spring Boot"; Default = $true; Id = "plug-everything-claude-code" }
            @{ Label = "superpowers";     Desc = "Planning, brainstorming, TDD, debugging"; Default = $true; Id = "plug-superpowers" }
            @{ Label = "context7";        Desc = "Real-time library documentation";   Default = $true;  Id = "plug-context7" }
            @{ Label = "commit-commands"; Desc = "git commit / push / PR workflow";   Default = $true;  Id = "plug-commit-commands" }
            @{ Label = "document-skills"; Desc = "Document processing (PDF, DOCX, PPTX, XLSX)"; Default = $true; Id = "plug-document-skills" }
            @{ Label = "playwright";      Desc = "Browser automation & E2E testing";  Default = $true;  Id = "plug-playwright" }
            @{ Label = "feature-dev";     Desc = "Guided feature development";        Default = $true;  Id = "plug-feature-dev" }
            @{ Label = "code-simplifier"; Desc = "Code simplification & cleanup";     Default = $true;  Id = "plug-code-simplifier" }
            @{ Label = "ralph-loop";      Desc = "Automated iteration loop";          Default = $true;  Id = "plug-ralph-loop" }
            @{ Label = "frontend-design"; Desc = "Frontend UI design";                Default = $true;  Id = "plug-frontend-design" }
            @{ Label = "example-skills";  Desc = "Example skills collection";         Default = $true;  Id = "plug-example-skills" }
            @{ Label = "github";          Desc = "GitHub integration";                Default = $true;  Id = "plug-github" }
        )}
        @{ Label = "Plugins - Community"; Hint = ""; Items = @(
            @{ Label = "claude-mem";      Desc = "Cross-session memory (~3k tokens/session)"; Default = $false; Id = "plug-claude-mem" }
            @{ Label = "claude-health";   Desc = "Health check & wellness dashboard"; Default = $false; Id = "plug-claude-health" }
            @{ Label = "PUA";             Desc = "AI agent productivity booster (pua, pua-en, pua-ja)"; Default = $false; Id = "plug-pua" }
        )}
        @{ Label = "Plugins - AI Research"; Hint = ""; Items = @(
            @{ Label = "tokenization";    Desc = "Tokenizer training & usage";        Default = $false; Id = "plug-tokenization" }
            @{ Label = "fine-tuning";     Desc = "Model fine-tuning";                 Default = $false; Id = "plug-fine-tuning" }
            @{ Label = "post-training";   Desc = "Post-training (RLHF, DPO, GRPO)";  Default = $false; Id = "plug-post-training" }
            @{ Label = "inference-serving"; Desc = "Inference serving (vLLM, SGLang, TensorRT)"; Default = $false; Id = "plug-inference-serving" }
            @{ Label = "distributed-training"; Desc = "Distributed training (DeepSpeed, FSDP, Megatron)"; Default = $false; Id = "plug-distributed-training" }
            @{ Label = "optimization";    Desc = "Quantization & optimization (GPTQ, AWQ, Flash Attn)"; Default = $false; Id = "plug-optimization" }
        )}
        @{ Label = "MCP Servers"; Hint = ""; Items = @(
            @{ Label = "Lark MCP server"; Desc = "Feishu/Lark integration";           Default = $false; Id = "mcp" }
        )}
    )

    # Flatten groups into parallel arrays
    $allItems = @()
    $groupStart = @()
    $groupEnd = @()
    foreach ($g in $groups) {
        $groupStart += $allItems.Count
        $allItems += $g.Items
        $groupEnd += ($allItems.Count - 1)
    }
    $n = $allItems.Count
    $numGroups = $groups.Count

    # Initialize selections from defaults
    $selected = @()
    for ($i = 0; $i -lt $n; $i++) { $selected += $allItems[$i].Default }

    $cursor = 0
    $submitIndex = $numGroups

    # Helper: enforce review mutual exclusion
    function Enforce-ReviewMutex($idx) {
        if ($selected[$idx]) {
            $id = $allItems[$idx].Id
            $reviewStart = $groupStart[2]; $reviewEnd = $groupEnd[2]
            if ($id -eq "review-adversarial") {
                for ($j = $reviewStart; $j -le $reviewEnd; $j++) {
                    if ($allItems[$j].Id -eq "review-codex") { $selected[$j] = $false }
                }
            } elseif ($id -eq "review-codex") {
                for ($j = $reviewStart; $j -le $reviewEnd; $j++) {
                    if ($allItems[$j].Id -eq "review-adversarial") { $selected[$j] = $false }
                }
            }
        }
    }

    $savedCursorVisible = [Console]::CursorVisible
    [Console]::CursorVisible = $false

    try {
        # --- Main menu loop ---
        while ($true) {
            [Console]::Clear()
            Write-Host ""
            Write-Host "  =========================================" -ForegroundColor White
            Write-Host "  Awesome Claude Code Config Installer" -ForegroundColor White
            Write-Host "  $(Get-SourceVersion)" -ForegroundColor White
            Write-Host "  =========================================" -ForegroundColor White
            Write-Host ""
            Write-Host "  " -NoNewline; Write-Host "Up/Down move  Enter open  a=all n=none d=defaults q=quit" -ForegroundColor DarkGray
            Write-Host ""

            for ($g = 0; $g -lt $numGroups; $g++) {
                $cnt = 0
                for ($j = $groupStart[$g]; $j -le $groupEnd[$g]; $j++) {
                    if ($selected[$j]) { $cnt++ }
                }
                $tot = $groupEnd[$g] - $groupStart[$g] + 1
                $countStr = "[$cnt/$tot]".PadRight(7)
                $label = $groups[$g].Label.PadRight(24)
                $isCursor = ($g -eq $cursor)

                if ($isCursor) {
                    Write-Host "  " -NoNewline
                    Write-Host "> " -ForegroundColor Green -NoNewline
                    Write-Host "$countStr " -NoNewline
                    Write-Host $label -ForegroundColor White -NoNewline
                } else {
                    Write-Host "    $countStr $label" -NoNewline
                }
                if ($groups[$g].Hint) {
                    Write-Host " ($($groups[$g].Hint))" -ForegroundColor DarkGray
                } else {
                    Write-Host ""
                }
            }
            Write-Host ""

            if ($cursor -eq $submitIndex) {
                Write-Host "  " -NoNewline
                Write-Host "> " -ForegroundColor Green -NoNewline
                Write-Host "[ Submit ]" -ForegroundColor Green
            } else {
                Write-Host "     " -NoNewline
                Write-Host "[ Submit ]" -ForegroundColor DarkGray
            }
            Write-Host ""

            $key = [Console]::ReadKey($true)

            # Check submit first
            if ($cursor -eq $submitIndex -and ($key.Key -eq [ConsoleKey]::Enter -or $key.Key -eq [ConsoleKey]::Spacebar)) { break }

            switch ($key.Key) {
                ([ConsoleKey]::UpArrow)   { if ($cursor -gt 0) { $cursor-- } }
                ([ConsoleKey]::DownArrow) { if ($cursor -lt $submitIndex) { $cursor++ } }
                ([ConsoleKey]::Enter) {
                    if ($cursor -lt $numGroups) {
                        # Enter sub-menu
                        $subG = $cursor
                        $subItems = $groups[$subG].Items
                        $subN = $subItems.Count
                        $subCursor = 0
                        $inSub = $true
                        while ($inSub) {
                            [Console]::Clear()
                            Write-Host ""
                            Write-Host "  =========================================" -ForegroundColor White
                            Write-Host "  $($groups[$subG].Label)" -ForegroundColor Cyan -NoNewline
                            if ($groups[$subG].Hint) { Write-Host "  ($($groups[$subG].Hint))" -ForegroundColor DarkGray } else { Write-Host "" }
                            Write-Host "  =========================================" -ForegroundColor White
                            Write-Host ""
                            Write-Host "  " -NoNewline; Write-Host "Up/Down move  Space toggle  Enter/Esc back" -ForegroundColor DarkGray
                            Write-Host ""

                            for ($j = 0; $j -lt $subN; $j++) {
                                $absIdx = $groupStart[$subG] + $j
                                $isCur = ($j -eq $subCursor)
                                if ($isCur) { Write-Host "  " -NoNewline; Write-Host "> " -ForegroundColor Green -NoNewline } else { Write-Host "    " -NoNewline }
                                Write-Host "[" -NoNewline
                                if ($selected[$absIdx]) { Write-Host "x" -ForegroundColor Green -NoNewline } else { Write-Host " " -NoNewline }
                                Write-Host "] " -NoNewline
                                $lbl = $allItems[$absIdx].Label.PadRight(28)
                                if ($isCur) { Write-Host $lbl -ForegroundColor White -NoNewline } else { Write-Host $lbl -NoNewline }
                                Write-Host " $($allItems[$absIdx].Desc)" -ForegroundColor DarkGray
                            }
                            Write-Host ""
                            if ($subCursor -eq $subN) {
                                Write-Host "  " -NoNewline; Write-Host "> " -ForegroundColor Green -NoNewline; Write-Host "[ Back ]" -ForegroundColor Yellow
                            } else {
                                Write-Host "     " -NoNewline; Write-Host "[ Back ]" -ForegroundColor DarkGray
                            }
                            Write-Host ""

                            $subKey = [Console]::ReadKey($true)
                            switch ($subKey.Key) {
                                ([ConsoleKey]::UpArrow)   { if ($subCursor -gt 0) { $subCursor-- } }
                                ([ConsoleKey]::DownArrow) { if ($subCursor -lt $subN) { $subCursor++ } }
                                ([ConsoleKey]::Spacebar) {
                                    if ($subCursor -lt $subN) {
                                        $absIdx = $groupStart[$subG] + $subCursor
                                        $selected[$absIdx] = -not $selected[$absIdx]
                                        Enforce-ReviewMutex $absIdx
                                    }
                                }
                                ([ConsoleKey]::Enter) {
                                    if ($subCursor -eq $subN) { $inSub = $false }
                                    else {
                                        $absIdx = $groupStart[$subG] + $subCursor
                                        $selected[$absIdx] = -not $selected[$absIdx]
                                        Enforce-ReviewMutex $absIdx
                                    }
                                }
                                ([ConsoleKey]::Escape) { $inSub = $false }
                                default {
                                    switch ($subKey.KeyChar) {
                                        'a' { for ($j = $groupStart[$subG]; $j -le $groupEnd[$subG]; $j++) { $selected[$j] = $true }; if ($subG -eq 2) { for ($j = $groupStart[2]; $j -le $groupEnd[2]; $j++) { if ($allItems[$j].Id -eq "review-codex") { $selected[$j] = $false } } } }
                                        'n' { for ($j = $groupStart[$subG]; $j -le $groupEnd[$subG]; $j++) { $selected[$j] = $false } }
                                        'd' { for ($j = $groupStart[$subG]; $j -le $groupEnd[$subG]; $j++) { $selected[$j] = $allItems[$j].Default } }
                                        'q' { $inSub = $false }
                                        'j' { if ($subCursor -lt $subN) { $subCursor++ } }
                                        'k' { if ($subCursor -gt 0) { $subCursor-- } }
                                    }
                                }
                            }
                        }
                    }
                }
                default {
                    switch ($key.KeyChar) {
                        'a' { for ($i = 0; $i -lt $n; $i++) { $selected[$i] = $true }; for ($j = $groupStart[2]; $j -le $groupEnd[2]; $j++) { if ($allItems[$j].Id -eq "review-codex") { $selected[$j] = $false } } }
                        'n' { for ($i = 0; $i -lt $n; $i++) { $selected[$i] = $false } }
                        'd' { for ($i = 0; $i -lt $n; $i++) { $selected[$i] = $allItems[$i].Default } }
                        'q' { [Console]::CursorVisible = $savedCursorVisible; Write-Host ""; Write-Info "Cancelled."; exit 0 }
                        'j' { if ($cursor -lt $submitIndex) { $cursor++ } }
                        'k' { if ($cursor -gt 0) { $cursor-- } }
                    }
                }
            }
        }
    } finally {
        [Console]::CursorVisible = $savedCursorVisible
    }

    # Plugin ID -> package mapping
    $pluginMap = @{
        "plug-everything-claude-code" = "everything-claude-code@everything-claude-code"
        "plug-superpowers" = "superpowers@claude-plugins-official"
        "plug-context7" = "context7@claude-plugins-official"
        "plug-commit-commands" = "commit-commands@claude-plugins-official"
        "plug-document-skills" = "document-skills@anthropic-agent-skills"
        "plug-playwright" = "playwright@claude-plugins-official"
        "plug-feature-dev" = "feature-dev@claude-plugins-official"
        "plug-code-simplifier" = "code-simplifier@claude-plugins-official"
        "plug-ralph-loop" = "ralph-loop@claude-plugins-official"
        "plug-frontend-design" = "frontend-design@claude-plugins-official"
        "plug-example-skills" = "example-skills@anthropic-agent-skills"
        "plug-github" = "github@claude-plugins-official"
        "plug-claude-mem" = "claude-mem@thedotmack"
        "plug-claude-health" = "health@claude-health"
        "plug-pua" = "pua@pua-skills"
        "plug-tokenization" = "tokenization@ai-research-skills"
        "plug-fine-tuning" = "fine-tuning@ai-research-skills"
        "plug-post-training" = "post-training@ai-research-skills"
        "plug-inference-serving" = "inference-serving@ai-research-skills"
        "plug-distributed-training" = "distributed-training@ai-research-skills"
        "plug-optimization" = "optimization@ai-research-skills"
        "review-code-review" = "code-review@claude-plugins-official"
    }

    # Map selections to return value
    $result = @{
        ClaudeMd           = $false
        Settings           = $false
        Rules              = $false
        RuleLangs          = @()
        RuleLangsExplicit  = $true
        Hooks              = $false
        Lessons            = $false
        Skills             = $false
        SelectedSkills     = @()
        Plugins            = $false
        SelectedPlugins    = @()
        PluginGroups       = @()
        Mcp                = $false
        ReviewAdversarial  = $false
        ReviewCodex        = $false
        ReviewCodeReview   = $false
    }

    for ($i = 0; $i -lt $n; $i++) {
        if (-not $selected[$i]) { continue }
        $id = $allItems[$i].Id

        switch -Wildcard ($id) {
            "claude-md"          { $result.ClaudeMd = $true }
            "settings"           { $result.Settings = $true }
            "rules-common"       { $result.Rules = $true }
            "hooks"              { $result.Hooks = $true }
            "lessons"            { $result.Lessons = $true }
            "rules-python"       { $result.Rules = $true; $result.RuleLangs += "python" }
            "rules-ts"           { $result.Rules = $true; $result.RuleLangs += "typescript" }
            "rules-go"           { $result.Rules = $true; $result.RuleLangs += "golang" }
            "review-code-review" { $result.ReviewCodeReview = $true; $result.Plugins = $true; $result.SelectedPlugins += "code-review@claude-plugins-official" }
            "review-adversarial" { $result.ReviewAdversarial = $true; $result.Skills = $true; $result.SelectedSkills += "adversarial-review" }
            "review-codex"       { $result.ReviewCodex = $true; $result.Plugins = $true; $result.SelectedPlugins += "codex@openai-codex" }
            "skill-paper-reading"  { $result.Skills = $true; $result.SelectedSkills += "paper-reading" }
            "skill-humanizer"      { $result.Skills = $true; $result.SelectedSkills += "humanizer" }
            "skill-humanizer-zh"   { $result.Skills = $true; $result.SelectedSkills += "humanizer-zh" }
            "skill-update-config"  { $result.Skills = $true; $result.SelectedSkills += "update-config" }
            "mcp"                { $result.Mcp = $true }
            "plug-*"             {
                $result.Plugins = $true
                if ($pluginMap.ContainsKey($id)) { $result.SelectedPlugins += $pluginMap[$id] }
            }
        }
    }

    return $result
}

# --- Install functions -----------------------------------------------------

function Install-ClaudeMd {
    param([bool]$ReviewAdversarial = $false, [bool]$ReviewCodex = $false)
    Write-Info "Installing CLAUDE.md..."
    if ($DryRun) {
        Write-Info "Would copy: CLAUDE.md -> $CLAUDE_DIR\CLAUDE.md"
        Write-Info "  Code Review: adversarial=$ReviewAdversarial codex=$ReviewCodex"
    } else {
        $target = Join-Path $CLAUDE_DIR "CLAUDE.md"
        Copy-Item (Join-Path $SCRIPT_DIR "CLAUDE.md") $target -Force

        # Dynamic Code Review section
        if ($ReviewAdversarial) {
            $reviewLine = 'Whenever a code review is needed — whether explicitly requested by the user or triggered by a skill (e.g., `code-reviewer`, `simplify`) — always invoke the `adversarial-review` skill to perform it. If the adversarial-review skill is unavailable (e.g., `codex` CLI not installed), fall back to using the `code-reviewer` agent for the review. Never substitute the actual review call with a text-only description.'
        } elseif ($ReviewCodex) {
            $reviewLine = 'Whenever a code review is needed — whether explicitly requested by the user or triggered by a skill (e.g., `code-reviewer`, `simplify`) — first check if the Codex plugin is available by running `/codex:setup`. If Codex is ready (`ready: true`), invoke `/codex:adversarial-review` to perform the review. If Codex is unavailable or not authenticated, fall back to using the `code-reviewer` agent for the review. Never substitute the actual review call with a text-only description.'
        } else {
            $reviewLine = 'Whenever a code review is needed — whether explicitly requested by the user or triggered by a skill (e.g., `code-reviewer`, `simplify`) — use the `code-reviewer` agent to perform it. Never substitute the actual review call with a text-only description.'
        }
        $content = Get-Content $target -Raw
        $content = $content -replace '(?m)^Whenever a code review is needed.*$', $reviewLine
        Set-Content $target $content -NoNewline
        Write-Ok "CLAUDE.md installed"
    }
}

function Install-Settings {
    Write-Info "Installing settings.json..."
    $target = Join-Path $CLAUDE_DIR "settings.json"
    $source = Join-Path $SCRIPT_DIR "settings.json"

    if (-not (Test-Path $target)) {
        if ($DryRun) {
            Write-Info "Would copy: settings.json -> $target"
        } else {
            Copy-Item $source $target -Force
            Write-Ok "settings.json installed (new)"
        }
        return
    }

    # Smart merge using PowerShell JSON
    if ($DryRun) {
        Write-Info "Would smart-merge settings.json"
        Write-Info "  - env: incoming as defaults, existing overrides"
        Write-Info "  - permissions.allow: union of arrays"
        Write-Info "  - enabledPlugins: union (new plugins added, existing preserved)"
        Write-Info "  - hooks.SessionStart: deduplicated by matcher"
        Write-Info "  - statusLine: incoming takes priority"
        return
    }

    try {
        # Relax strict mode for dynamic JSON property access
        Set-StrictMode -Off

        $existing = Get-Content $target -Raw | ConvertFrom-Json
        $incoming = Get-Content $source -Raw | ConvertFrom-Json

        # Helper: convert PSCustomObject to ordered hashtable
        $toHt = {
            param($obj)
            if ($null -eq $obj) { return [ordered]@{} }
            if ($obj -is [System.Collections.IDictionary]) { return $obj }
            $ht = [ordered]@{}
            $obj.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
            return $ht
        }

        # Helper: merge two objects as hashtables (second wins on conflict)
        $mergeHt = {
            param($base, $over)
            $result = [ordered]@{}
            $b = & $toHt $base
            $o = & $toHt $over
            foreach ($key in $b.Keys) { $result[$key] = $b[$key] }
            foreach ($key in $o.Keys) { $result[$key] = $o[$key] }
            return $result
        }

        # env: incoming as defaults, existing overrides
        $mergedEnv = & $mergeHt $incoming.env $existing.env

        # permissions.allow: union
        $baseAllow = if ($incoming.permissions -and $incoming.permissions.allow) { @($incoming.permissions.allow) } else { @() }
        $overAllow = if ($existing.permissions -and $existing.permissions.allow) { @($existing.permissions.allow) } else { @() }
        $mergedAllow = @($baseAllow + $overAllow | Select-Object -Unique)

        # enabledPlugins: union (new plugins added, existing preserved)
        $mergedPlugins = & $mergeHt $existing.enabledPlugins $incoming.enabledPlugins

        # hooks.SessionStart: deduplicate by matcher (last wins)
        $sessionHooks = [ordered]@{}
        if ($incoming.hooks -and $incoming.hooks.SessionStart) {
            foreach ($h in @($incoming.hooks.SessionStart)) { if ($h.matcher) { $sessionHooks[$h.matcher] = $h } }
        }
        if ($existing.hooks -and $existing.hooks.SessionStart) {
            foreach ($h in @($existing.hooks.SessionStart)) { if ($h.matcher) { $sessionHooks[$h.matcher] = $h } }
        }
        $mergedSessionHooks = @($sessionHooks.Values)

        # Build merged result as hashtable (avoids PSCustomObject assignment issues)
        $merged = & $mergeHt $incoming $existing

        # Override with merged fields
        $merged["env"] = [PSCustomObject]$mergedEnv
        $merged["enabledPlugins"] = [PSCustomObject]$mergedPlugins
        $merged["statusLine"] = $incoming.statusLine
        $mergedPerms = & $mergeHt $incoming.permissions $existing.permissions
        $mergedPerms["allow"] = $mergedAllow
        $merged["permissions"] = [PSCustomObject]$mergedPerms
        $mergedHooks = & $mergeHt $incoming.hooks $existing.hooks
        $mergedHooks["SessionStart"] = $mergedSessionHooks
        $merged["hooks"] = [PSCustomObject]$mergedHooks

        [PSCustomObject]$merged | ConvertTo-Json -Depth 10 | Set-Content $target -Encoding UTF8

        Set-StrictMode -Version Latest
        Write-Ok "settings.json smart-merged"
    } catch {
        Set-StrictMode -Version Latest
        Write-Err "Merge failed: $_"
        Write-Warn "Please merge manually: $source -> $target"
        $script:InstallWarnings++
    }
}

function Install-Rules {
    param(
        [string[]]$Langs = @(),
        [bool]$LangsExplicit = $false
    )

    Write-Info "Installing rules..."
    $rulesDir = Join-Path $CLAUDE_DIR "rules"
    New-Item -ItemType Directory -Path $rulesDir -Force | Out-Null

    # Always install common rules
    $commonSrc = Join-Path $SCRIPT_DIR "rules\common"
    $commonDst = Join-Path $rulesDir "common"
    if ($DryRun) {
        Write-Info "Would copy: rules\common\ -> $commonDst"
    } else {
        if (Test-Path $commonDst) { Remove-Item $commonDst -Recurse -Force }
        Copy-Item $commonSrc $commonDst -Recurse -Force
        Write-Ok "Common rules installed"
    }

    # Determine languages
    $installLangs = @()
    if ($Langs.Count -gt 0) {
        $installLangs = $Langs
    } elseif (-not $LangsExplicit) {
        # Auto-detect: install all available languages (--all mode)
        Get-ChildItem (Join-Path $SCRIPT_DIR "rules") -Directory | ForEach-Object {
            if ($_.Name -ne "common") { $installLangs += $_.Name }
        }
    }
    # If LangsExplicit=true and Langs is empty, skip language rules

    foreach ($lang in $installLangs) {
        $langSrc = Join-Path $SCRIPT_DIR "rules\$lang"
        if (Test-Path $langSrc) {
            $langDst = Join-Path $rulesDir $lang
            if ($DryRun) {
                Write-Info "Would copy: rules\$lang\ -> $langDst"
            } else {
                if (Test-Path $langDst) { Remove-Item $langDst -Recurse -Force }
                Copy-Item $langSrc $langDst -Recurse -Force
                Write-Ok "$lang rules installed"
            }
        } else {
            Write-Err "Language rules not found: $lang"
        }
    }

    # Clean up known language rule dirs that were NOT selected (from previous installs)
    # Only removes languages this installer knows about; preserves user-created dirs
    if ($LangsExplicit) {
        $knownLangs = @("python", "typescript", "golang")
        foreach ($known in $knownLangs) {
            if ($installLangs -notcontains $known) {
                $langDir = Join-Path $rulesDir $known
                if (Test-Path $langDir) {
                    if ($DryRun) {
                        Write-Info "Would remove unselected: $langDir"
                    } else {
                        Remove-Item $langDir -Recurse -Force
                        Write-Ok "Removed unselected rules: $known"
                    }
                }
            }
        }
    }

    $readmeSrc = Join-Path $SCRIPT_DIR "rules\README.md"
    if (Test-Path $readmeSrc) {
        if ($DryRun) {
            Write-Info "Would copy: rules\README.md -> $rulesDir\README.md"
        } else {
            Copy-Item $readmeSrc (Join-Path $rulesDir "README.md") -Force
        }
    }
}

function Install-Skills {
    param([string[]]$SelectedSkills = @())
    Write-Info "Installing custom skills..."
    $skillsDir = Join-Path $CLAUDE_DIR "skills"
    New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null

    # Migration: remove renamed/deleted skills from previous installs
    foreach ($oldSkill in @("update")) {
        $oldPath = Join-Path $skillsDir $oldSkill
        if (Test-Path $oldPath) {
            Remove-Item $oldPath -Recurse -Force
            Write-Ok "Removed legacy skill: $oldSkill"
        }
    }

    if ($SelectedSkills.Count -gt 0) {
        # Install only selected skills
        foreach ($skill in $SelectedSkills) {
            $src = Join-Path $SCRIPT_DIR "skills" $skill
            $dst = Join-Path $skillsDir $skill
            if (Test-Path $src) {
                if ($DryRun) {
                    Write-Info "Would copy: skills\$skill\ -> $dst"
                } else {
                    if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
                    Copy-Item $src $dst -Recurse -Force
                    Write-Ok "Skill installed: $skill"
                }
            } else {
                Write-Warn "Skill not found: $skill"
            }
        }
    } else {
        # --All mode: install everything
        Get-ChildItem (Join-Path $SCRIPT_DIR "skills") -Directory | ForEach-Object {
            $skill = $_.Name
            $dst = Join-Path $skillsDir $skill
            if ($DryRun) {
                Write-Info "Would copy: skills\$skill\ -> $dst"
            } else {
                if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
                Copy-Item $_.FullName $dst -Recurse -Force
                Write-Ok "Skill installed: $skill"
            }
        }
    }
}

function Install-Lessons {
    Write-Info "Installing lessons.md template..."
    $target = Join-Path $CLAUDE_DIR "lessons.md"
    if (Test-Path $target) {
        Write-Warn "lessons.md already exists -- skipping"
    } else {
        if ($DryRun) {
            Write-Info "Would copy: lessons.md -> $target"
        } else {
            Copy-Item (Join-Path $SCRIPT_DIR "lessons.md") $target -Force
            Write-Ok "lessons.md template installed to $target"
        }
    }
}

function Install-Hooks {
    Write-Info "Installing hooks..."
    $hooksDir = Join-Path $CLAUDE_DIR "hooks"
    New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null

    Get-ChildItem (Join-Path $SCRIPT_DIR "hooks") -File | ForEach-Object {
        $fname = $_.Name
        $dst = Join-Path $hooksDir $fname
        if ($DryRun) {
            Write-Info "Would copy: hooks\$fname -> $dst"
        } else {
            Copy-Item $_.FullName $dst -Force
            Write-Ok "Hook installed: $fname"
        }
    }

    # Ensure jq is available (required by statusline.sh)
    Install-Jq

    # Install Nerd Font for statusline icons
    Install-NerdFont

    # Check bash availability (required by statusline and SessionStart hooks)
    if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
        Write-Warn "bash not found in PATH. Statusline and SessionStart hooks require bash."
        Write-Warn "  Install Git for Windows (includes Git Bash): https://git-scm.com/download/win"
        Write-Warn "  Or install WSL: wsl --install"
        $script:InstallWarnings++
    }
}

function Install-Jq {
    if (Get-Command jq -ErrorAction SilentlyContinue) {
        Write-Ok "jq already available in PATH"
        return
    }

    $binDir = Join-Path $CLAUDE_DIR "bin"
    $jqPath = Join-Path $binDir "jq.exe"
    if (Test-Path $jqPath) {
        Write-Ok "jq already installed at $jqPath"
        return
    }

    if ($DryRun) {
        Write-Info "Would download jq.exe -> $jqPath"
        return
    }

    Write-Info "Downloading jq (required by statusline)..."
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null

    $arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "i386" }
    $jqUrl = "https://github.com/jqlang/jq/releases/latest/download/jq-windows-$arch.exe"

    $ok = Invoke-Retry -MaxAttempts 3 -DelaySeconds 2 -Description "Download jq" -Action {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $jqUrl -OutFile $jqPath -UseBasicParsing
    }
    if ($ok) {
        Write-Ok "jq installed to $jqPath"
    } else {
        Write-Warn "Could not download jq. Install it manually: https://jqlang.github.io/jq/download/"
        Write-Warn "Or run: winget install jqlang.jq"
    }
}

function Install-NerdFont {
    # Check if already installed
    $fontDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
    if ((Test-Path $fontDir) -and (Get-ChildItem $fontDir -Filter "*MesloLGS NF*" -ErrorAction SilentlyContinue)) {
        return
    }

    if ($DryRun) {
        Write-Info "Would install MesloLGS NF font"
        return
    }

    Write-Info "Installing MesloLGS NF font for statusline icons..."

    # Copy bundled fonts from repository
    $srcDir = Join-Path $SCRIPT_DIR "fonts"
    $ttfFiles = Get-ChildItem $srcDir -Filter "*.ttf" -ErrorAction SilentlyContinue
    if (-not $ttfFiles) {
        Write-Warn "Bundled fonts not found in $srcDir - statusline will use text fallback"
        return
    }

    try {
        # Install to user fonts directory
        if (-not (Test-Path $fontDir)) {
            New-Item -ItemType Directory -Path $fontDir -Force | Out-Null
        }

        $regPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
        $ttfFiles | ForEach-Object {
            $dst = Join-Path $fontDir $_.Name
            Copy-Item $_.FullName $dst -Force
            # Register font in user registry
            $fontName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name) + " (TrueType)"
            New-ItemProperty -Path $regPath -Name $fontName -Value $dst -PropertyType String -Force | Out-Null
        }

        Write-Ok "MesloLGS NF font installed"
        Write-Warn "Set your terminal font to 'MesloLGS NF' for best icon display"
    } catch {
        Write-Warn "Could not install Nerd Font: $_"
    }
}

function Install-Mcp {
    Write-Info "Installing MCP servers..."
    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claudeCmd) {
        Write-Err "Claude Code CLI not found. Install it first: https://claude.com/claude-code"
        return
    }

    if ($DryRun) {
        Write-Info "Would add MCP server: lark-mcp (stdio)"
    } else {
        $ok = Invoke-Retry -MaxAttempts 5 -DelaySeconds 3 -Description "Add MCP server lark-mcp" -Action {
            & claude mcp add --scope user --transport stdio lark-mcp -- npx -y "@larksuiteoapi/lark-mcp" mcp -a YOUR_APP_ID -s YOUR_APP_SECRET 2>$null
        }
        if ($ok) { Write-Ok "MCP server added: lark-mcp" }
        else { Write-Warn "MCP server lark-mcp may already exist or could not be added, skipping" }
        Write-Warn "Replace YOUR_APP_ID and YOUR_APP_SECRET with your Feishu credentials"
    }
}

function Install-Plugins {
    param(
        [string[]]$Groups = @("essential"),
        [string[]]$SelectedPluginsList = @()
    )

    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claudeCmd) {
        Write-Err "Claude Code CLI not found. Install it first: https://claude.com/claude-code"
        return
    }

    # Collect plugins from individually selected + group-based
    $plugins = @()
    if ($SelectedPluginsList.Count -gt 0) { $plugins += $SelectedPluginsList }
    foreach ($group in $Groups) {
        switch ($group) {
            "essential" { $plugins += $PLUGINS_ESSENTIAL }
            "claude-mem" { $plugins += $PLUGINS_CLAUDE_MEM }
            "ai-research" { $plugins += $PLUGINS_AI_RESEARCH }
            "health" { $plugins += $PLUGINS_HEALTH }
            "pua" { $plugins += $PLUGINS_PUA }
            "all" { $plugins += $PLUGINS_ESSENTIAL + $PLUGINS_CLAUDE_MEM + $PLUGINS_AI_RESEARCH + $PLUGINS_HEALTH + $PLUGINS_PUA }
        }
    }

    # Deduplicate
    $plugins = $plugins | Select-Object -Unique

    $groupNames = $Groups -join ","
    Write-Info "Installing plugins (groups: $groupNames)..."

    # Collect needed marketplaces
    $neededMarketplaces = @{}
    foreach ($entry in $plugins) {
        $marketplace = ($entry -split '@')[-1]
        $neededMarketplaces[$marketplace] = $true
    }

    # Step 1: Add required marketplaces
    Write-Info "Adding marketplaces..."
    foreach ($mp in $MARKETPLACE_LIST) {
        if (-not $neededMarketplaces.ContainsKey($mp.Name)) { continue }

        # Skip if already installed
        $mpDir = Join-Path $env:USERPROFILE ".claude\plugins\marketplaces\$($mp.Name)"
        if (Test-Path $mpDir) {
            Write-Ok "Marketplace already exists: $($mp.Name)"
            continue
        }

        if ($DryRun) {
            Write-Info "Would add marketplace: $($mp.Name) (github.com/$($mp.Repo))"
        } else {
            $ok = Invoke-Retry -MaxAttempts 5 -DelaySeconds 3 -Description "Add marketplace $($mp.Name)" -Action {
                & claude plugin marketplace add "https://github.com/$($mp.Repo)" 2>$null
            }
            if ($ok) { Write-Ok "Marketplace added: $($mp.Name)" }
            else { Write-Warn "Marketplace $($mp.Name) may already exist or could not be added" }
        }
    }

    # Step 2: Install plugins
    Write-Info "Installing $($plugins.Count) plugins..."
    foreach ($entry in $plugins) {
        $parts = $entry -split '@'
        $pluginName = $parts[0]
        if ($DryRun) {
            Write-Info "Would install plugin: $pluginName from $($parts[1])"
        } else {
            $ok = Invoke-Retry -MaxAttempts 5 -DelaySeconds 3 -Description "Install plugin $pluginName" -Action {
                & claude plugin install "$entry" 2>$null
            }
            if ($ok) { Write-Ok "Plugin installed: $pluginName" }
            else { Write-Warn "Plugin $pluginName could not be installed, skipping"; $script:InstallWarnings++ }
        }
    }
}

# --- Uninstall -------------------------------------------------------------

function Invoke-Uninstall {
    Write-Host ""
    Write-Warn "The following will be removed:"
    Write-Host "  - $CLAUDE_DIR\CLAUDE.md"
    Write-Host "  - $CLAUDE_DIR\settings.json (backed up first)"
    Write-Host "  - $CLAUDE_DIR\rules\"
    Write-Host "  - $CLAUDE_DIR\skills\ (installer-managed only)"
    Write-Host "  - $CLAUDE_DIR\lessons.md"
    Write-Host "  - $CLAUDE_DIR\hooks\ (installer-managed only)"
    Write-Host "  - Installed plugins (requires claude CLI)"
    Write-Host "  - MCP server: lark-mcp (requires claude CLI)"
    if (Test-Path $VERSION_STAMP_FILE) {
        Write-Host "  - $VERSION_STAMP_FILE"
    }
    Write-Host ""

    if ($DryRun) {
        Write-Warn "DRY RUN -- nothing will be removed"
        return
    }

    if (-not (Confirm-Action "Proceed with uninstall?")) {
        Write-Info "Cancelled."
        exit 0
    }

    $p = Join-Path $CLAUDE_DIR "CLAUDE.md"
    if (Test-Path $p) { Remove-Item $p -Force; Write-Ok "Removed CLAUDE.md" }

    $p = Join-Path $CLAUDE_DIR "settings.json"
    if (Test-Path $p) {
        Copy-Item $p (Join-Path $CLAUDE_DIR "settings.json.bak") -Force
        Write-Ok "Backed up settings.json -> settings.json.bak"
        Remove-Item $p -Force; Write-Ok "Removed settings.json"
    }

    $p = Join-Path $CLAUDE_DIR "rules"
    if (Test-Path $p) { Remove-Item $p -Recurse -Force; Write-Ok "Removed rules/" }

    # Only remove skills that ship with this repo
    $skillsSrc = Join-Path $SCRIPT_DIR "skills"
    if (Test-Path $skillsSrc) {
        Get-ChildItem $skillsSrc -Directory | ForEach-Object {
            $sp = Join-Path $CLAUDE_DIR "skills\$($_.Name)"
            if (Test-Path $sp) { Remove-Item $sp -Recurse -Force; Write-Ok "Removed skill: $($_.Name)" }
        }
    } else {
        $p = Join-Path $CLAUDE_DIR "skills"
        if (Test-Path $p) { Remove-Item $p -Recurse -Force; Write-Ok "Removed skills/" }
    }

    $p = Join-Path $CLAUDE_DIR "lessons.md"
    if (Test-Path $p) { Remove-Item $p -Force; Write-Ok "Removed lessons.md" }

    # Only remove hooks that ship with this repo
    $hooksSrc = Join-Path $SCRIPT_DIR "hooks"
    if (Test-Path $hooksSrc) {
        Get-ChildItem $hooksSrc -File | ForEach-Object {
            $hp = Join-Path $CLAUDE_DIR "hooks\$($_.Name)"
            if (Test-Path $hp) { Remove-Item $hp -Force; Write-Ok "Removed hook: $($_.Name)" }
        }
    } else {
        $p = Join-Path $CLAUDE_DIR "hooks"
        if (Test-Path $p) { Remove-Item $p -Recurse -Force; Write-Ok "Removed hooks/" }
    }

    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($claudeCmd) {
        $allPlugins = $PLUGINS_ESSENTIAL + $PLUGINS_CLAUDE_MEM + $PLUGINS_AI_RESEARCH + $PLUGINS_HEALTH + $PLUGINS_PUA
        foreach ($entry in $allPlugins) {
            $pluginName = ($entry -split '@')[0]
            & claude plugin uninstall $entry 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "Uninstalled plugin: $pluginName"
            } else {
                Write-Warn "Could not uninstall: $pluginName"
            }
        }
        & claude mcp remove lark-mcp 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Removed MCP server: lark-mcp"
        } else {
            Write-Warn "Could not remove lark-mcp"
        }
    } else {
        Write-Warn "Claude CLI not found - cannot uninstall plugins or MCP servers"
    }

    if (Test-Path $VERSION_STAMP_FILE) { Remove-Item $VERSION_STAMP_FILE -Force }
    Write-Host ""
    Write-Ok "Uninstall complete."
}

# --- Help ------------------------------------------------------------------

function Show-Help {
    Write-Host @"

Usage: .\install.ps1 [OPTIONS]

Install Claude Code configuration files.

Running without options launches an interactive component selector.
Works with both local and remote installs (irm | iex).

Options:
    -All                Install everything (non-interactive)
    -Uninstall          Remove all installed files
    -Version            Show version info
    -DryRun             Show what would be installed without doing it
    -Force              Skip confirmation prompts
    -Help               Show this help

Examples:
    .\install.ps1                  # Interactive selector
    .\install.ps1 -All             # Install everything
    .\install.ps1 -Uninstall       # Uninstall everything
    .\install.ps1 -DryRun -All     # Preview full install
    & ([scriptblock]::Create((irm $REPO_URL/raw/main/install.ps1)))  # Remote install

"@
}

# --- Main ------------------------------------------------------------------

function Main {
    Initialize-ScriptDir

    if ($Help) { Show-Help; return }
    if ($Version) { Show-Version; return }
    if ($Uninstall) {
        Write-Host ""
        Write-Host "========================================="
        Write-Host "  Claude Code Config - Uninstaller"
        Write-Host "========================================="
        Invoke-Uninstall
        return
    }

    # Determine mode
    $doClaudeMd = $false
    $doSettings = $false
    $doRules = $false
    $doSkills = $false
    $doLessons = $false
    $doHooks = $false
    $doPlugins = $false
    $doMcp = $false
    $ruleLangs = @()
    $ruleLangsExplicit = $false
    $pluginGroups = @()
    $selectedSkills = @()
    $selectedPlugins = @()
    $reviewAdversarial = $false
    $reviewCodex = $false

    if ($All) {
        # Explicit -All: install everything including MCP
        $doClaudeMd = $true
        $doSettings = $true
        $doRules = $true
        $doSkills = $true
        $doLessons = $true
        $doHooks = $true
        $doPlugins = $true
        $doMcp = $true
        $pluginGroups = @("all")
        $reviewAdversarial = $true
        $reviewCodex = $false
        $selectedPlugins = @("code-review@claude-plugins-official")
        $selectedSkills = @()
    } elseif ([Environment]::UserInteractive -and $Host.Name -eq "ConsoleHost") {
        # Interactive mode: show menu (with fallback if console APIs fail)
        $menuResult = $null
        try {
            $menuResult = Show-InteractiveMenu
        } catch {
            Write-Warn "Interactive menu unavailable: $_"
            Write-Info "Falling back to default install (essential plugins, no MCP)"
        }
        if ($null -ne $menuResult) {
            $doClaudeMd = $menuResult.ClaudeMd
            $doSettings = $menuResult.Settings
            $doRules = $menuResult.Rules
            $doSkills = $menuResult.Skills
            $doLessons = $menuResult.Lessons
            $doHooks = $menuResult.Hooks
            $doPlugins = $menuResult.Plugins
            $doMcp = $menuResult.Mcp
            $ruleLangs = $menuResult.RuleLangs
            $ruleLangsExplicit = $menuResult.RuleLangsExplicit
            $pluginGroups = $menuResult.PluginGroups
            $selectedSkills = $menuResult.SelectedSkills
            $selectedPlugins = $menuResult.SelectedPlugins
            $reviewAdversarial = $menuResult.ReviewAdversarial
            $reviewCodex = $menuResult.ReviewCodex
        } else {
            # Fallback when interactive menu failed
            $doClaudeMd = $true
            $doSettings = $true
            $doRules = $true
            $doSkills = $true
            $doLessons = $true
            $doHooks = $true
            $doPlugins = $true
            $pluginGroups = @("essential")
        }
    } else {
        # Non-interactive fallback: essential plugins, no MCP
        $doClaudeMd = $true
        $doSettings = $true
        $doRules = $true
        $doSkills = $true
        $doLessons = $true
        $doHooks = $true
        $doPlugins = $true
        $pluginGroups = @("essential")
    }

    # Check if anything was selected
    if (-not $doClaudeMd -and -not $doSettings -and -not $doRules -and
        -not $doSkills -and -not $doLessons -and -not $doHooks -and
        -not $doPlugins -and -not $doMcp) {
        Write-Warn "Nothing selected to install."
        return
    }

    $sourceVer = Get-SourceVersion
    Write-Host ""
    Write-Host "========================================="
    Write-Host "  Awesome Claude Code Config Installer"
    Write-Host "  $sourceVer"
    Write-Host "========================================="
    Write-Host ""

    if ($DryRun) {
        Write-Warn "DRY RUN MODE -- no changes will be made"
        Write-Host ""
    }

    $installedVer = Get-InstalledVersion
    if ($installedVer -ne "not installed") {
        Write-Info "Upgrading from $installedVer -> $sourceVer"
    }

    if (-not (Test-Path $CLAUDE_DIR)) {
        New-Item -ItemType Directory -Path $CLAUDE_DIR -Force | Out-Null
    }

    if ($doClaudeMd) { Install-ClaudeMd -ReviewAdversarial $reviewAdversarial -ReviewCodex $reviewCodex }
    if ($doSettings) { Install-Settings }
    if ($doRules) { Install-Rules -Langs $ruleLangs -LangsExplicit $ruleLangsExplicit }
    if ($doSkills) { Install-Skills -SelectedSkills $selectedSkills }
    if ($doLessons) { Install-Lessons }
    if ($doHooks) { Install-Hooks }
    if ($doMcp) { Install-Mcp }
    if ($doPlugins) { Install-Plugins -Groups $pluginGroups -SelectedPluginsList $selectedPlugins }

    if (-not $DryRun) {
        if ($InstallWarnings -eq 0) {
            Save-VersionStamp
        } else {
            Write-Warn "Skipping version stamp due to $InstallWarnings warning(s)"
        }
    }

    Write-Host ""
    if ($InstallWarnings -gt 0) {
        Write-Warn "Installation completed with $InstallWarnings warning(s) - review messages above"
    } else {
        Write-Ok "Installation complete! ($sourceVer)"
    }
    Write-Host ""
    Write-Info "Next steps:"
    Write-Host "  1. Restart Claude Code for changes to take effect"
    Write-Host "  2. Customize CLAUDE.md for your specific projects"
    if ($doMcp) {
        Write-Host "  3. Replace YOUR_APP_ID/YOUR_APP_SECRET in Lark MCP config"
    }
    Write-Host ""
}

Main
} @args
