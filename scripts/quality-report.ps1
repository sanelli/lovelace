# Build Markdown quality report from coverage / metrics / CRAP summaries
# (roadmap 1.002 macro step 7 / #47).
#
# Reads:
#   .coverage/summary.json
#   .metrics/summary.json
#   .coverage/crap-summary.json
#
# Writes .coverage/quality-report.md and prints it to stdout.
# Optional -PostPullRequestComment updates a sticky PR comment identified by
# <!-- lovelace-quality-metrics --> (CI only; local runs omit this).
#
# Usage (repo root, after coverage/metrics/crap):
#   pwsh scripts/quality-report.ps1
#   pwsh scripts/quality-report.ps1 -PostPullRequestComment
#
# Exit: 0 ok, 2 missing/parse/API failure
# (Does not enforce gates — gate scripts own exit 1.)

[CmdletBinding()]
param(
    # When set, create or update the sticky PR comment via gh.
    [switch] $PostPullRequestComment,

    # Optional PR number; default: current branch's PR via `gh pr view`.
    [int] $PullRequestNumber = 0
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$CoverageSummaryPath = Join-Path $RepoRoot '.coverage' 'summary.json'
$MetricsSummaryPath = Join-Path $RepoRoot '.metrics' 'summary.json'
$CrapSummaryPath = Join-Path $RepoRoot '.coverage' 'crap-summary.json'
$ReportPath = Join-Path $RepoRoot '.coverage' 'quality-report.md'

$Marker = '<!-- lovelace-quality-metrics -->'

function Write-Fail([string] $Message, [int] $Code) {
    Write-Error $Message
    exit $Code
}

function Clear-ProxyEnv {
    foreach ($Name in @(
            'ALL_PROXY', 'all_proxy', 'HTTP_PROXY', 'http_proxy',
            'HTTPS_PROXY', 'https_proxy', 'GIT_HTTP_PROXY', 'GIT_HTTPS_PROXY',
            'SOCKS_PROXY', 'socks_proxy', 'SOCKS5_PROXY', 'socks5_proxy'
        )) {
        Remove-Item -Path "Env:$Name" -ErrorAction SilentlyContinue
    }
}

function Read-JsonFile([string] $Path, [string] $Label) {
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Fail "Missing $Label ($Path). Run coverage/metrics/crap first." 2
    }
    try {
        return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
    }
    catch {
        Write-Fail ("Failed to parse {0}: {1}" -f $Label, $_.Exception.Message) 2
    }
}

function Get-StatusHigherIsBetter([double] $Value, [double] $Minimum) {
    if ($Value -ge $Minimum) { return '✅' }
    return '⛔️'
}

function Get-StatusLowerIsBetter([double] $Value, [double] $Maximum) {
    if ($Value -le $Maximum) { return '✅' }
    return '⛔️'
}

$Coverage = Read-JsonFile $CoverageSummaryPath 'coverage summary'
$Metrics = Read-JsonFile $MetricsSummaryPath 'metrics summary'
$Crap = Read-JsonFile $CrapSummaryPath 'CRAP summary'

$CallSiteValue = if ($null -ne $Coverage.call_uncovered) {
    "$($Coverage.call_uncovered) uncovered"
}
else {
    'n/a'
}

$Rows = @(
    [pscustomobject]@{
        Metric     = 'Statement coverage'
        Value      = '{0}%' -f $Coverage.statement_percent
        Threshold  = '≥ {0}%' -f $Coverage.statement_minimum
        Status     = (Get-StatusHigherIsBetter $Coverage.statement_percent $Coverage.statement_minimum)
        Gated      = $true
    },
    [pscustomobject]@{
        Metric     = 'Decision coverage'
        Value      = '{0}%' -f $Coverage.decision_percent
        Threshold  = '≥ {0}%' -f $Coverage.decision_minimum
        Status     = (Get-StatusHigherIsBetter $Coverage.decision_percent $Coverage.decision_minimum)
        Gated      = $true
    },
    [pscustomobject]@{
        Metric     = 'Subprogram coverage (fun_call)'
        Value      = '{0}%' -f $Coverage.fun_call_percent
        Threshold  = '≥ {0}%' -f $Coverage.fun_call_minimum
        Status     = (Get-StatusHigherIsBetter $Coverage.fun_call_percent $Coverage.fun_call_minimum)
        Gated      = $true
    },
    [pscustomobject]@{
        Metric     = 'Max cyclomatic complexity'
        Value      = '{0}' -f $Metrics.max_cyclomatic
        Threshold  = '≤ {0}' -f $Metrics.cyclomatic_maximum
        Status     = (Get-StatusLowerIsBetter $Metrics.max_cyclomatic $Metrics.cyclomatic_maximum)
        Gated      = $true
    },
    [pscustomobject]@{
        Metric     = 'Max essential complexity'
        Value      = '{0}' -f $Metrics.max_essential
        Threshold  = '≤ {0}' -f $Metrics.essential_maximum
        Status     = (Get-StatusLowerIsBetter $Metrics.max_essential $Metrics.essential_maximum)
        Gated      = $true
    },
    [pscustomobject]@{
        Metric     = 'Max loop nesting'
        Value      = '{0}' -f $Metrics.max_loop_nesting
        Threshold  = '≤ {0}' -f $Metrics.nesting_maximum
        Status     = (Get-StatusLowerIsBetter $Metrics.max_loop_nesting $Metrics.nesting_maximum)
        Gated      = $true
    },
    [pscustomobject]@{
        Metric     = 'Max CRAP'
        Value      = '{0}' -f $Crap.max_crap
        Threshold  = '≤ {0}' -f $Crap.crap_maximum
        Status     = (Get-StatusLowerIsBetter $Crap.max_crap $Crap.crap_maximum)
        Gated      = $true
    },
    [pscustomobject]@{
        Metric     = 'Average CRAP'
        Value      = '{0}' -f $Crap.average_crap
        Threshold  = '(info)'
        Status     = '—'
        Gated      = $false
    },
    [pscustomobject]@{
        Metric     = 'Call-site coverage'
        Value      = $CallSiteValue
        Threshold  = '(info)'
        Status     = '—'
        Gated      = $false
    }
)

$GateFails = @($Rows | Where-Object { $_.Gated -and $_.Status -eq '⛔️' }).Count
$Overall = if ($GateFails -eq 0) { 'all gated metrics within thresholds' } else { "$GateFails gated metric(s) outside thresholds" }

$Lines = [System.Collections.Generic.List[string]]::new()
$Lines.Add($Marker)
$Lines.Add('')
$Lines.Add('## Lovelace quality metrics')
$Lines.Add('')
$Lines.Add("_Auto-updated sticky comment. $Overall._")
$Lines.Add('')
$Lines.Add('| Metric | Value | Threshold | Status |')
$Lines.Add('| --- | ---: | --- | :---: |')
foreach ($Row in $Rows) {
    $Lines.Add(('| {0} | {1} | {2} | {3} |' -f $Row.Metric, $Row.Value, $Row.Threshold, $Row.Status))
}

# Worst offenders (complexity + CRAP)
$Lines.Add('')
$Lines.Add('### Worst cyclomatic')
$Lines.Add('')
$TopCc = @($Metrics.top_cyclomatic | Select-Object -First 8)
if ($TopCc.Count -eq 0) {
    $Lines.Add('_None listed._')
}
else {
    $Lines.Add('| CC | Ess | Nest | Unit |')
    $Lines.Add('| ---: | ---: | ---: | --- |')
    foreach ($Item in $TopCc) {
        $UnitCell = '`' + $Item.file + ':' + $Item.line + '` `' + $Item.unit + '`'
        $Lines.Add(('| {0} | {1} | {2} | {3} |' -f `
                $Item.cyclomatic, $Item.essential, $Item.nesting, $UnitCell))
    }
}

$Lines.Add('')
$Lines.Add('### Worst CRAP')
$Lines.Add('')
$TopCrap = @($Crap.worst | Select-Object -First 8)
if ($TopCrap.Count -eq 0) {
    $Lines.Add('_None listed._')
}
else {
    $Lines.Add('| CRAP | CC | Cov | Unit |')
    $Lines.Add('| ---: | ---: | ---: | --- |')
    foreach ($Item in $TopCrap) {
        $UnitCell = '`' + $Item.file + ':' + $Item.line + '` `' + $Item.unit + '`'
        $Lines.Add(('| {0} | {1} | {2}% | {3} |' -f `
                $Item.crap, $Item.cc, $Item.cov, $UnitCell))
    }
}

$Lines.Add('')
$Lines.Add('<sub>Generated by <code>scripts/quality-report.ps1</code>.</sub>')

$Markdown = ($Lines -join "`n") + "`n"

$CoverageDir = Split-Path -Parent $ReportPath
if (-not (Test-Path -LiteralPath $CoverageDir)) {
    New-Item -ItemType Directory -Path $CoverageDir -Force | Out-Null
}
Set-Content -LiteralPath $ReportPath -Value $Markdown -Encoding utf8

Write-Output $Markdown
Write-Host "Wrote $ReportPath"

if (-not $PostPullRequestComment) {
    exit 0
}

Clear-ProxyEnv

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Fail 'gh not found; cannot post sticky PR comment' 2
}

$PrNumber = $PullRequestNumber
if ($PrNumber -le 0) {
    if ($env:GITHUB_EVENT_NAME -eq 'pull_request' -and $env:GITHUB_REF -match 'refs/pull/(\d+)/') {
        $PrNumber = [int] $Matches[1]
    }
    elseif ($env:GITHUB_EVENT_PATH -and (Test-Path -LiteralPath $env:GITHUB_EVENT_PATH)) {
        try {
            $Event = Get-Content -LiteralPath $env:GITHUB_EVENT_PATH -Raw | ConvertFrom-Json
            if ($Event.pull_request.number) {
                $PrNumber = [int] $Event.pull_request.number
            }
        }
        catch {
            # fall through to gh pr view
        }
    }
}
if ($PrNumber -le 0) {
    $ViewJson = & gh pr view --json number 2>$null
    if ($LASTEXITCODE -eq 0 -and $ViewJson) {
        $PrNumber = [int] (($ViewJson | ConvertFrom-Json).number)
    }
}
if ($PrNumber -le 0) {
    Write-Fail 'No pull request number; pass -PullRequestNumber or run on a PR branch / Actions PR event.' 2
}

$RepoNameWithOwner = (& gh repo view --json nameWithOwner -q .nameWithOwner).Trim()
if ([string]::IsNullOrEmpty($RepoNameWithOwner)) {
    Write-Fail 'Could not resolve repository nameWithOwner via gh' 2
}

$CommentsJson = & gh api --paginate "repos/$RepoNameWithOwner/issues/$PrNumber/comments"
if ($LASTEXITCODE -ne 0) {
    Write-Fail "Failed to list PR comments for #$PrNumber" 2
}

$ExistingId = $null
$Comments = $CommentsJson | ConvertFrom-Json
foreach ($Comment in @($Comments)) {
    if ($Comment.body -and ($Comment.body -like "*$Marker*")) {
        $ExistingId = [string] $Comment.id
        break
    }
}

# gh api -f body= can mishandle multiline; use --input JSON
$Payload = @{ body = $Markdown } | ConvertTo-Json -Compress
$PayloadFile = [IO.Path]::GetTempFileName()
try {
    # PowerShell ConvertTo-Json escapes unicode; ensure UTF-8 file for gh
    [IO.File]::WriteAllText($PayloadFile, $Payload, [Text.UTF8Encoding]::new($false))

    if ($ExistingId) {
        & gh api -X PATCH "repos/$RepoNameWithOwner/issues/comments/$ExistingId" --input $PayloadFile
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "Failed to update sticky comment $ExistingId on PR #$PrNumber" 2
        }
        Write-Host "Updated sticky quality comment on PR #$PrNumber (id $ExistingId)"
    }
    else {
        & gh api -X POST "repos/$RepoNameWithOwner/issues/$PrNumber/comments" --input $PayloadFile
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "Failed to create sticky comment on PR #$PrNumber" 2
        }
        Write-Host "Created sticky quality comment on PR #$PrNumber"
    }
}
finally {
    Remove-Item -LiteralPath $PayloadFile -ErrorAction SilentlyContinue
}

exit 0
