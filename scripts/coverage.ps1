# Host Ada coverage via gnatcov (roadmap 1.002 macro step 7 / #47).
#
# Instruments unit-test crates, runs them, consolidates traces, writes
# .coverage/ reports + summary JSON, and gates statement / decision /
# fun_call (subprogram+call aggregate) at >= 95% fully covered.
#
# Preconditions:
#   alr install gnatcov
#   Once per machine: gnatcov setup (this script runs it idempotently)
#   ~/.alire/bin on PATH (script prepends it)
#
# Usage (repo root):
#   pwsh scripts/coverage.ps1
#   pwsh scripts/coverage.ps1 -SkipGates
#
# Exit codes:
#   0 — success (gates passed, or -SkipGates)
#   1 — gate failure
#   2 — tool / parse failure

[CmdletBinding()]
param(
    # When set, print metrics but do not fail on thresholds (CI must not use this).
    [switch] $SkipGates
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$CoverageRoot = Join-Path $RepoRoot '.coverage'
$TracesDir = Join-Path $CoverageRoot 'traces'
$XmlDir = Join-Path $CoverageRoot 'xml'
$ReportPath = Join-Path $CoverageRoot 'report.txt'
$SummaryPath = Join-Path $CoverageRoot 'summary.json'
$AlireHome = Join-Path $HOME '.alire'
$GnatcovBin = Join-Path $AlireHome 'bin'
$GprShare = Join-Path $AlireHome 'share' 'gpr'
$LibDir = Join-Path $AlireHome 'lib'

$CoverageLevel = 'stmt+decision+fun_call'
$StatementMinimum = 95
$DecisionMinimum = 95
$FunCallMinimum = 95
$RtsProject = 'gnatcov_rts.gpr'

$UnitTestCrates = @(
    @{
        Path       = 'lovelace/common/tests'
        Executable = 'lovelace_common_tests'
        Projects   = @('lovelace_common.gpr')
    },
    @{
        Path       = 'lovelace/lir/tests'
        Executable = 'lovelace_lir_tests'
        Projects   = @('lovelace_lir.gpr')
    },
    @{
        Path       = 'lovelace/compiler/tests'
        Executable = 'lovelace_compiler_tests'
        Projects   = @('lovelace_compiler.gpr')
    },
    @{
        Path       = 'lovelace/lovelace/tests'
        Executable = 'lovelace_tests'
        Projects   = @('lovelace.gpr')
    }
)

# Project names resolved via alr GPR_PROJECT_PATH of lovelace/lovelace/tests.
$LibraryProjects = @(
    'lovelace_common.gpr',
    'lovelace_lir.gpr',
    'lovelace_compiler.gpr',
    'lovelace.gpr'
)
$AnalysisCrateRelative = 'lovelace/lovelace/tests'

function Write-Fail([string] $Message, [int] $Code) {
    Write-Error $Message
    exit $Code
}

function Ensure-PathPrefix([string] $Directory) {
    if (-not (Test-Path -LiteralPath $Directory)) {
        return
    }
    $Separator = [IO.Path]::PathSeparator
    $Parts = @($Directory) + @(
        ($env:PATH -split [regex]::Escape($Separator) |
            Where-Object { $_ -and ($_ -ne $Directory) })
    )
    $env:PATH = ($Parts -join $Separator)
}

function Ensure-GprProjectPath([string] $Directory) {
    $Separator = [IO.Path]::PathSeparator
    if ([string]::IsNullOrEmpty($env:GPR_PROJECT_PATH)) {
        $env:GPR_PROJECT_PATH = $Directory
        return
    }
    $Parts = @($Directory) + @(
        ($env:GPR_PROJECT_PATH -split [regex]::Escape($Separator) |
            Where-Object { $_ -and ($_ -ne $Directory) })
    )
    $env:GPR_PROJECT_PATH = ($Parts -join $Separator)
}

function Ensure-LibraryPath([string] $Directory) {
    $Separator = [IO.Path]::PathSeparator
    foreach ($Name in @('LD_LIBRARY_PATH', 'DYLD_LIBRARY_PATH')) {
        $Current = [Environment]::GetEnvironmentVariable($Name)
        if ([string]::IsNullOrEmpty($Current)) {
            [Environment]::SetEnvironmentVariable($Name, $Directory)
        }
        else {
            $Parts = @($Directory) + @(
                ($Current -split [regex]::Escape($Separator) |
                    Where-Object { $_ -and ($_ -ne $Directory) })
            )
            [Environment]::SetEnvironmentVariable($Name, ($Parts -join $Separator))
        }
    }
}

function Initialize-MacSdkEnvironment {
    if ($IsWindows) {
        return
    }
    try {
        $Sdk = (& xcrun --show-sdk-path 2>$null)
    }
    catch {
        $Sdk = $null
    }
    if ([string]::IsNullOrWhiteSpace($Sdk)) {
        return
    }
    $env:SDKROOT = $Sdk
    $Include = Join-Path $Sdk 'usr' 'include'
    $Lib = Join-Path $Sdk 'usr' 'lib'
    if (Test-Path -LiteralPath $Include) {
        if ([string]::IsNullOrEmpty($env:CPATH)) {
            $env:CPATH = $Include
        }
        elseif ($env:CPATH -notlike "*${Include}*") {
            $env:CPATH = "$Include$([IO.Path]::PathSeparator)$($env:CPATH)"
        }
    }
    if (Test-Path -LiteralPath $Lib) {
        # Required on recent macOS so the final link finds libSystem (.tbd).
        if ([string]::IsNullOrEmpty($env:LIBRARY_PATH)) {
            $env:LIBRARY_PATH = $Lib
        }
        elseif ($env:LIBRARY_PATH -notlike "*${Lib}*") {
            $env:LIBRARY_PATH = "$Lib$([IO.Path]::PathSeparator)$($env:LIBRARY_PATH)"
        }
    }
    if ([string]::IsNullOrEmpty($env:MACOSX_DEPLOYMENT_TARGET)) {
        $Major = (sw_vers -productVersion).Split('.')[0]
        $env:MACOSX_DEPLOYMENT_TARGET = "$Major.0"
    }
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory)]
        [string] $Label,
        [Parameter(Mandatory)]
        [scriptblock] $Action
    )
    & $Action
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Failed: $Label (exit $LASTEXITCODE)" 2
    }
}

Ensure-PathPrefix $GnatcovBin
Initialize-MacSdkEnvironment
Ensure-GprProjectPath $GprShare
Ensure-LibraryPath $LibDir

if (-not (Get-Command gnatcov -ErrorAction SilentlyContinue)) {
    Write-Fail 'gnatcov not found on PATH. Install with: alr install gnatcov (and ensure ~/.alire/bin is on PATH).' 2
}

if (-not (Test-Path -LiteralPath (Join-Path $GprShare $RtsProject))) {
    Write-Host 'Running gnatcov setup (coverage runtime missing)...'
    Push-Location (Join-Path $RepoRoot 'lovelace/common/tests')
    try {
        Invoke-Checked 'gnatcov setup' {
            & alr exec -- gnatcov setup --prefix=$AlireHome
        }
    }
    finally {
        Pop-Location
    }
}

if (Test-Path -LiteralPath $CoverageRoot) {
    Remove-Item -LiteralPath $CoverageRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $TracesDir -Force | Out-Null
New-Item -ItemType Directory -Path $XmlDir -Force | Out-Null

foreach ($Crate in $UnitTestCrates) {
    $CratePath = Join-Path $RepoRoot $Crate.Path
    Write-Host "Coverage: $($Crate.Path)"

    Push-Location $CratePath
    try {
        Get-ChildItem -Filter '*.srctrace' -ErrorAction SilentlyContinue |
            Remove-Item -Force

        Invoke-Checked "$($Crate.Path) build (baseline)" {
            & alr build
        }

        $InstrumentArgs = @(
            'gnatcov', 'instrument',
            "--level=$CoverageLevel",
            '--dump-trigger=atexit'
        )
        foreach ($Project in $Crate.Projects) {
            $InstrumentArgs += "--projects=$Project"
        }
        Invoke-Checked "$($Crate.Path) gnatcov instrument" {
            & alr @InstrumentArgs
        }

        Invoke-Checked "$($Crate.Path) build (instrumented)" {
            & alr build -- --src-subdirs=gnatcov-instr --implicit-with=$RtsProject
        }

        $Executable = Join-Path $CratePath 'bin' $Crate.Executable
        if (-not (Test-Path -LiteralPath $Executable)) {
            $Executable = "$Executable.exe"
        }
        if (-not (Test-Path -LiteralPath $Executable)) {
            Write-Fail "Test executable not found: $($Crate.Executable) under $($Crate.Path)/bin" 2
        }

        Invoke-Checked "$($Crate.Path) run $($Crate.Executable)" {
            & $Executable
        }

        $Traces = @(Get-ChildItem -Filter '*.srctrace' -ErrorAction SilentlyContinue)
        if ($Traces.Count -eq 0) {
            Write-Fail "No .srctrace produced under $($Crate.Path)" 2
        }
        foreach ($Trace in $Traces) {
            Move-Item -LiteralPath $Trace.FullName -Destination $TracesDir -Force
        }
    }
    finally {
        Pop-Location
    }
}

$AllTraces = @(Get-ChildItem -LiteralPath $TracesDir -Filter '*.srctrace')
if ($AllTraces.Count -eq 0) {
    Write-Fail 'No coverage traces collected.' 2
}

# Analyze from lovelace/tests — its Alire env sees all four host projects.
$AnalysisCrate = Join-Path $RepoRoot $AnalysisCrateRelative
Push-Location $AnalysisCrate
try {
    $CoverageArgs = @(
        'gnatcov', 'coverage',
        "--level=$CoverageLevel",
        '--annotate=report,xcov,xml',
        "--output-dir=$CoverageRoot"
    )
    foreach ($ProjectName in $LibraryProjects) {
        $CoverageArgs += "--projects=$ProjectName"
    }
    foreach ($Trace in $AllTraces) {
        $CoverageArgs += $Trace.FullName
    }

    $ReportLog = Join-Path $CoverageRoot 'gnatcov-coverage.log'
    & alr @CoverageArgs *> $ReportLog
    if ($LASTEXITCODE -ne 0) {
        Get-Content -LiteralPath $ReportLog | Write-Host
        Write-Fail 'gnatcov coverage failed' 2
    }

    Copy-Item -LiteralPath $ReportLog -Destination $ReportPath -Force

    $IndexXml = Join-Path $CoverageRoot 'index.xml'
    if (-not (Test-Path -LiteralPath $IndexXml)) {
        $NestedXml = Join-Path $CoverageRoot 'xml' 'index.xml'
        if (Test-Path -LiteralPath $NestedXml) {
            $IndexXml = $NestedXml
        }
        else {
            $Found = Get-ChildItem -LiteralPath $CoverageRoot -Filter 'index.xml' -Recurse |
                Select-Object -First 1
            if ($null -eq $Found) {
                Write-Fail 'gnatcov XML index.xml not found under .coverage/' 2
            }
            $IndexXml = $Found.FullName
        }
    }
}
finally {
    Pop-Location
}

try {
    [xml] $CoverageXml = Get-Content -LiteralPath $IndexXml -Raw
}
catch {
    Write-Fail "Failed to parse coverage XML: $($_.Exception.Message)" 2
}

# Prefer summary-level stats (first obligation_stats under coverage_summary).
$SummaryNode = $CoverageXml.document.coverage_report.coverage_summary
if ($null -eq $SummaryNode) {
    Write-Fail 'coverage_summary missing in index.xml' 2
}

function Get-SummaryObligation {
    param(
        [Parameter(Mandatory)] $Summary,
        [Parameter(Mandatory)] [string] $Kind
    )
    $Stats = @($Summary.obligation_stats) | Where-Object { $_.kind -eq $Kind } | Select-Object -First 1
    if ($null -eq $Stats) {
        Write-Fail "coverage_summary missing obligation_stats kind='$Kind'" 2
    }
    $Fully = @($Stats.metric) | Where-Object { $_.kind -eq 'fully_covered' } | Select-Object -First 1
    $Total = @($Stats.metric) | Where-Object { $_.kind -eq 'total_obligations_of_relevance' } | Select-Object -First 1
    $TotalCount = [int] $Total.count
    if ($TotalCount -eq 0) {
        return [pscustomobject]@{ Kind = $Kind; FullyCovered = 0; Total = 0; Percent = 100 }
    }
    $Percent = if ($Fully.PSObject.Properties['ratio'] -and $Fully.ratio -ne '') {
        [int] $Fully.ratio
    }
    else {
        [int] [math]::Round((100.0 * [int] $Fully.count) / $TotalCount)
    }
    return [pscustomobject]@{
        Kind         = $Kind
        FullyCovered = [int] $Fully.count
        Total        = $TotalCount
        Percent      = $Percent
    }
}

$Stmt = Get-SummaryObligation -Summary $SummaryNode -Kind 'Stmt'
$Decision = Get-SummaryObligation -Summary $SummaryNode -Kind 'Decision'
$FunCall = Get-SummaryObligation -Summary $SummaryNode -Kind 'Function and call'

# Report-only: count uncovered functions vs calls from the text report.
$FunctionUncovered = 0
$CallUncovered = 0
if (Test-Path -LiteralPath $ReportPath) {
    $ReportText = Get-Content -LiteralPath $ReportPath -Raw
    $FunctionUncovered = ([regex]::Matches($ReportText, 'function not executed')).Count
    $CallUncovered = ([regex]::Matches($ReportText, 'call not executed')).Count
}

$Summary = [ordered]@{
    level                 = $CoverageLevel
    statement_percent     = $Stmt.Percent
    decision_percent      = $Decision.Percent
    fun_call_percent      = $FunCall.Percent
    statement_fully       = $Stmt.FullyCovered
    statement_total       = $Stmt.Total
    decision_fully        = $Decision.FullyCovered
    decision_total        = $Decision.Total
    fun_call_fully        = $FunCall.FullyCovered
    fun_call_total        = $FunCall.Total
    function_uncovered    = $FunctionUncovered
    call_uncovered        = $CallUncovered
    statement_minimum     = $StatementMinimum
    decision_minimum      = $DecisionMinimum
    fun_call_minimum      = $FunCallMinimum
    gates_skipped         = [bool] $SkipGates
    note                  = 'fun_call_percent is gnatcov combined Function+call fully-covered ratio; function_uncovered/call_uncovered are report counts (call-site is report-only for sticky comment).'
}

($Summary | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath $SummaryPath -Encoding utf8

Write-Host ''
Write-Host 'Coverage summary'
Write-Host ("  Statement:  {0,3}%  (gate >= {1}%)  {2}/{3}" -f $Stmt.Percent, $StatementMinimum, $Stmt.FullyCovered, $Stmt.Total)
Write-Host ("  Decision:   {0,3}%  (gate >= {1}%)  {2}/{3}" -f $Decision.Percent, $DecisionMinimum, $Decision.FullyCovered, $Decision.Total)
Write-Host ("  Fun_call:   {0,3}%  (gate >= {1}%)  {2}/{3}" -f $FunCall.Percent, $FunCallMinimum, $FunCall.FullyCovered, $FunCall.Total)
Write-Host ("  Uncovered functions (report): {0}" -f $FunctionUncovered)
Write-Host ("  Uncovered calls (report):     {0}" -f $CallUncovered)
Write-Host "  Wrote $SummaryPath"

if ($SkipGates) {
    Write-Host 'SkipGates set — not enforcing thresholds.'
    exit 0
}

$Failures = @()
if ($Stmt.Percent -lt $StatementMinimum) {
    $Failures += "statement coverage $($Stmt.Percent)% < $StatementMinimum%"
}
if ($Decision.Percent -lt $DecisionMinimum) {
    $Failures += "decision coverage $($Decision.Percent)% < $DecisionMinimum%"
}
if ($FunCall.Percent -lt $FunCallMinimum) {
    $Failures += "fun_call coverage $($FunCall.Percent)% < $FunCallMinimum%"
}

if ($Failures.Count -gt 0) {
    Write-Host ''
    Write-Host 'Coverage gates FAILED:'
    foreach ($Failure in $Failures) {
        Write-Host "  - $Failure"
    }
    exit 1
}

Write-Host 'Coverage gates passed.'
exit 0
