# CRAP scores from gnatmetric complexity + gnatcov per-subprogram statement coverage
# (roadmap 1.002 macro step 7 / #47).
#
# CRAP(m) = CC(m)^2 * (1 - cov(m)/100)^3 + CC(m)
# Gate: every joined unit CRAP <= 30
#
# Join key: source basename + unit/scope name + start line
#   metrics: .metrics/units.json (from scripts/metrics.ps1)
#   coverage: .coverage/xml/*.xml scope_metric Stmt fully_covered ratio
#
# Unmatched metrics units get cov=0 (fail-closed for CRAP).
#
# Preconditions: run scripts/coverage.ps1 and scripts/metrics.ps1 first.
#
# Usage (repo root):
#   pwsh scripts/crap.ps1
#   pwsh scripts/crap.ps1 -SkipGates
#
# Exit: 0 ok, 1 gate failure, 2 tool/parse failure

[CmdletBinding()]
param(
    [switch] $SkipGates
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$MetricsUnitsPath = Join-Path $RepoRoot '.metrics' 'units.json'
$CoverageXmlDir = Join-Path $RepoRoot '.coverage' 'xml'
$SummaryPath = Join-Path $RepoRoot '.coverage' 'crap-summary.json'
$ScoresPath = Join-Path $RepoRoot '.coverage' 'crap-scores.json'

$CrapMaximum = 30

function Write-Fail([string] $Message, [int] $Code) {
    Write-Error $Message
    exit $Code
}

function Get-CrapScore([double] $Cyclomatic, [double] $CoveragePercent) {
    $Uncovered = 1.0 - ($CoveragePercent / 100.0)
    if ($Uncovered -lt 0) { $Uncovered = 0 }
    if ($Uncovered -gt 1) { $Uncovered = 1 }
    return ($Cyclomatic * $Cyclomatic * [math]::Pow($Uncovered, 3)) + $Cyclomatic
}

if (-not (Test-Path -LiteralPath $MetricsUnitsPath)) {
    Write-Fail 'Missing .metrics/units.json — run scripts/metrics.ps1 first.' 2
}
if (-not (Test-Path -LiteralPath $CoverageXmlDir)) {
    Write-Fail 'Missing .coverage/xml — run scripts/coverage.ps1 first.' 2
}

try {
    $Units = Get-Content -LiteralPath $MetricsUnitsPath -Raw | ConvertFrom-Json
}
catch {
    Write-Fail "Failed to parse units.json: $($_.Exception.Message)" 2
}
if ($null -eq $Units) {
    Write-Fail 'units.json is empty' 2
}
$UnitList = @($Units)

# Map: "basename|name|line" -> stmt coverage percent
$CoverageMap = @{}
$XmlFiles = @(Get-ChildItem -LiteralPath $CoverageXmlDir -Filter '*.adb.xml')
$XmlFiles += @(Get-ChildItem -LiteralPath $CoverageXmlDir -Filter '*.ads.xml')

function Add-ScopeCoverage {
    param($ScopeElement, [string] $FileBase)

    if ($null -eq $ScopeElement) {
        return
    }

    $ScopeName = [string] $ScopeElement.GetAttribute('scope_name')
    $ScopeLine = [string] $ScopeElement.GetAttribute('scope_line')
    if (-not [string]::IsNullOrEmpty($ScopeName) -and -not [string]::IsNullOrEmpty($ScopeLine)) {
        $StmtStats = $ScopeElement.SelectSingleNode("./obligation_stats[@kind='Stmt']")
        $Percent = $null
        if ($null -ne $StmtStats) {
            $Total = $StmtStats.SelectSingleNode("./metric[@kind='total_obligations_of_relevance']")
            $Fully = $StmtStats.SelectSingleNode("./metric[@kind='fully_covered']")
            $TotalCount = [int] $Total.GetAttribute('count')
            if ($TotalCount -eq 0) {
                $Percent = 100
            }
            elseif ($null -ne $Fully -and $Fully.GetAttribute('ratio') -ne '') {
                $Percent = [int] $Fully.GetAttribute('ratio')
            }
            else {
                $Percent = [int] [math]::Round((100.0 * [int] $Fully.GetAttribute('count')) / $TotalCount)
            }
        }
        else {
            $Fully = $ScopeElement.SelectSingleNode("./metric[@kind='fully_covered']")
            if ($null -ne $Fully -and $Fully.GetAttribute('ratio') -ne '') {
                $Percent = [int] $Fully.GetAttribute('ratio')
            }
        }

        if ($null -ne $Percent) {
            $Key = ('{0}|{1}|{2}' -f $FileBase.ToLowerInvariant(), $ScopeName, $ScopeLine)
            $CoverageMap[$Key] = $Percent
        }
    }

    $ChildScopes = $ScopeElement.SelectNodes('./scope_metric')
    if ($null -ne $ChildScopes) {
        foreach ($Child in $ChildScopes) {
            Add-ScopeCoverage -ScopeElement $Child -FileBase $FileBase
        }
    }
}

foreach ($XmlFile in $XmlFiles) {
    try {
        [xml] $Doc = Get-Content -LiteralPath $XmlFile.FullName -Raw
    }
    catch {
        Write-Fail "Failed to parse $($XmlFile.Name): $($_.Exception.Message)" 2
    }

    $Source = $Doc.SelectSingleNode('/source')
    if ($null -eq $Source) {
        continue
    }
    $FileAttr = [string] $Source.GetAttribute('file')
    $FileBase = [IO.Path]::GetFileName($FileAttr)
    if ([string]::IsNullOrEmpty($FileBase)) {
        $FileBase = $XmlFile.Name -replace '\.xml$', ''
    }

    foreach ($Scope in @($Source.SelectNodes('./scope_metric'))) {
        Add-ScopeCoverage -ScopeElement $Scope -FileBase $FileBase
    }
}

$Scores = [System.Collections.Generic.List[object]]::new()
$Unmatched = 0

foreach ($Unit in $UnitList) {
    $Key = ('{0}|{1}|{2}' -f $Unit.file.ToLowerInvariant(), $Unit.name, $Unit.line)
    $Matched = $CoverageMap.ContainsKey($Key)
    $Cov = if ($Matched) { [double] $CoverageMap[$Key] } else { 0.0 }
    if (-not $Matched) {
        $Unmatched++
    }
    $Cc = [double] $Unit.cyclomatic
    $Crap = Get-CrapScore -Cyclomatic $Cc -CoveragePercent $Cov
    $Scores.Add([pscustomobject]@{
            file             = $Unit.file
            qualified_name   = $Unit.qualified_name
            name             = $Unit.name
            line             = [int] $Unit.line
            cyclomatic       = [int] $Cc
            coverage_percent = [int] [math]::Round($Cov)
            crap             = [math]::Round($Crap, 2)
            coverage_matched = $Matched
        })
}

if ($Scores.Count -eq 0) {
    Write-Fail 'No CRAP scores computed' 2
}

$MaxCrap = ($Scores | Measure-Object -Property crap -Maximum).Maximum
$AvgCrap = ($Scores | Measure-Object -Property crap -Average).Average
$Breaches = @($Scores | Where-Object { $_.crap -gt $CrapMaximum })

$Summary = [ordered]@{
    unit_count       = $Scores.Count
    unmatched_count  = $Unmatched
    max_crap         = [math]::Round([double] $MaxCrap, 2)
    average_crap     = [math]::Round([double] $AvgCrap, 2)
    crap_maximum     = $CrapMaximum
    breach_count     = $Breaches.Count
    gates_skipped    = [bool] $SkipGates
    join_note        = 'Join key = lowercase(basename)|unit_name|line; Stmt fully_covered % from gnatcov scope_metric; unmatched → cov 0.'
    worst            = @(
        $Scores | Sort-Object crap -Descending | Select-Object -First 20 |
            ForEach-Object {
                [ordered]@{
                    crap     = $_.crap
                    cc       = $_.cyclomatic
                    cov      = $_.coverage_percent
                    matched  = $_.coverage_matched
                    unit     = $_.qualified_name
                    file     = $_.file
                    line     = $_.line
                }
            }
    )
}

if (-not (Test-Path -LiteralPath (Split-Path $SummaryPath))) {
    New-Item -ItemType Directory -Path (Split-Path $SummaryPath) -Force | Out-Null
}

($Summary | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $SummaryPath -Encoding utf8
(@($Scores) | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath $ScoresPath -Encoding utf8

Write-Host ''
Write-Host 'CRAP summary'
Write-Host ("  Units:          {0}  (unmatched coverage: {1})" -f $Scores.Count, $Unmatched)
Write-Host ("  Max CRAP:       {0}  (gate <= {1})" -f $Summary.max_crap, $CrapMaximum)
Write-Host ("  Average CRAP:   {0}" -f $Summary.average_crap)
Write-Host ("  Breaches:       {0}" -f $Breaches.Count)
Write-Host '  Worst CRAP:'
foreach ($Row in $Summary.worst | Select-Object -First 12) {
    $MatchMark = if ($Row.matched) { '' } else { ' [unmatched cov]' }
    Write-Host ("    CRAP={0,6:N2}  CC={1,2} cov={2,3}%  {3}:{4}  {5}{6}" -f `
            $Row.crap, $Row.cc, $Row.cov, $Row.file, $Row.line, $Row.unit, $MatchMark)
}
Write-Host "  Wrote $SummaryPath"

if ($SkipGates) {
    Write-Host 'SkipGates set — not enforcing thresholds.'
    exit 0
}

if ($Breaches.Count -gt 0) {
    Write-Host ''
    Write-Host 'CRAP gates FAILED:'
    Write-Host ("  - {0} unit(s) with CRAP > {1} (max {2})" -f $Breaches.Count, $CrapMaximum, $Summary.max_crap)
    exit 1
}

Write-Host 'CRAP gates passed.'
exit 0
