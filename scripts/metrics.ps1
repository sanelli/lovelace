# Host Ada complexity / nesting / coupling via gnatmetric (roadmap 1.002 macro step 7 / #47).
#
# Writes .metrics/metrix-*.xml + .metrics/summary.json and gates:
#   cyclomatic complexity <= 10
#   essential complexity  <= 10
#   max loop nesting      <= 4
#
# Coupling and extra exit points are reported only (no gate).
#
# Preconditions: alr install libadalang_tools (gnatmetric on PATH / ~/.alire/bin)
#
# Usage (repo root):
#   pwsh scripts/metrics.ps1
#   pwsh scripts/metrics.ps1 -SkipGates
#
# Exit: 0 ok, 1 gate failure, 2 tool/parse failure

[CmdletBinding()]
param(
    [switch] $SkipGates
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$MetricsRoot = Join-Path $RepoRoot '.metrics'
$SummaryPath = Join-Path $MetricsRoot 'summary.json'
$UnitsPath = Join-Path $MetricsRoot 'units.json'
$AlireBin = Join-Path $HOME '.alire' 'bin'

$CyclomaticMaximum = 10
$EssentialMaximum = 10
$NestingMaximum = 4

$HostProjects = @(
    @{ Crate = 'lovelace/common'; Project = 'lovelace_common.gpr'; XmlName = 'metrix-common.xml' },
    @{ Crate = 'lovelace/lir'; Project = 'lovelace_lir.gpr'; XmlName = 'metrix-lir.xml' },
    @{ Crate = 'lovelace/compiler'; Project = 'lovelace_compiler.gpr'; XmlName = 'metrix-compiler.xml' },
    @{ Crate = 'lovelace/lovelace'; Project = 'lovelace.gpr'; XmlName = 'metrix-lovelace.xml' }
)

$BodyKinds = @(
    'function body',
    'procedure body',
    'expression function',
    'entry body',
    'task body'
)

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

Ensure-PathPrefix $AlireBin

if (-not (Get-Command gnatmetric -ErrorAction SilentlyContinue)) {
    Write-Fail 'gnatmetric not found. Install with: alr install libadalang_tools' 2
}

if (Test-Path -LiteralPath $MetricsRoot) {
    Remove-Item -LiteralPath $MetricsRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $MetricsRoot -Force | Out-Null

foreach ($Entry in $HostProjects) {
    $CratePath = Join-Path $RepoRoot $Entry.Crate
    $XmlPath = Join-Path $MetricsRoot $Entry.XmlName
    Write-Host "Metrics: $($Entry.Crate)"

    Push-Location $CratePath
    try {
        & alr build *> $null
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "alr build failed for $($Entry.Crate)" 2
        }

        & alr exec -- gnatmetric `
            -P $Entry.Project `
            -U `
            --no-subprojects `
            --complexity-all `
            --extra-exit-points `
            --coupling-all `
            --generate-xml-output `
            --no-text-output `
            --xml-file-name=$XmlPath
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "gnatmetric failed for $($Entry.Crate)" 2
        }
        if (-not (Test-Path -LiteralPath $XmlPath)) {
            Write-Fail "gnatmetric XML missing: $XmlPath" 2
        }
    }
    finally {
        Pop-Location
    }
}

function Get-MetricValue($UnitElement, [string] $Name) {
    $Node = @($UnitElement.metric) | Where-Object { $_.name -eq $Name } | Select-Object -First 1
    if ($null -eq $Node) {
        return $null
    }
    return $Node.'#text'
}

function Collect-Units {
    param(
        $UnitElement,
        [string] $FilePath,
        [string] $FileName,
        [string] $QualifiedPrefix,
        [System.Collections.Generic.List[object]] $Into
    )

    $Name = [string] $UnitElement.name
    $Kind = [string] $UnitElement.kind
    $Line = [string] $UnitElement.line
    $Qualified = if ([string]::IsNullOrEmpty($QualifiedPrefix)) { $Name } else { "$QualifiedPrefix.$Name" }

    if ($BodyKinds -contains $Kind) {
        $CcText = Get-MetricValue $UnitElement 'cyclomatic_complexity'
        if ($null -ne $CcText) {
            $EssText = Get-MetricValue $UnitElement 'essential_complexity'
            $NestText = Get-MetricValue $UnitElement 'max_loop_nesting'
            $ExitText = Get-MetricValue $UnitElement 'extra_exit_points'
            $Into.Add([pscustomobject]@{
                    file              = $FileName
                    file_path         = $FilePath
                    name              = $Name
                    qualified_name    = $Qualified
                    kind              = $Kind
                    line              = [int] $Line
                    cyclomatic        = [int] [double] $CcText
                    essential         = if ($null -eq $EssText) { 0 } else { [int] [double] $EssText }
                    max_loop_nesting  = if ($null -eq $NestText) { 0 } else { [int] [double] $NestText }
                    extra_exit_points = if ($null -eq $ExitText) { 0 } else { [int] [double] $ExitText }
                })
        }
    }

    $ChildNodes = $UnitElement.SelectNodes('./unit')
    if ($null -ne $ChildNodes) {
        foreach ($Child in $ChildNodes) {
            Collect-Units -UnitElement $Child -FilePath $FilePath -FileName $FileName `
                -QualifiedPrefix $Qualified -Into $Into
        }
    }
}

function Collect-Coupling {
    param(
        $GlobalElement,
        [System.Collections.Generic.List[object]] $Into
    )

    # Coupling block is under <global><coupling><file>…<unit>… (not under each source file).
    foreach ($Coupling in @($GlobalElement.SelectNodes('./coupling'))) {
        foreach ($FileElement in @($Coupling.SelectNodes('./file'))) {
            $FileName = [IO.Path]::GetFileName([string] $FileElement.name)
            foreach ($Unit in @($FileElement.SelectNodes('./unit'))) {
                $FanOut = Get-MetricValue $Unit 'unit_fan-out_coupling'
                $FanIn = Get-MetricValue $Unit 'unit_fan-in_coupling'
                if ($null -eq $FanOut -and $null -eq $FanIn) {
                    continue
                }
                $Into.Add([pscustomobject]@{
                        file    = $FileName
                        name    = [string] $Unit.name
                        kind    = [string] $Unit.kind
                        fan_out = if ($null -eq $FanOut) { 0 } else { [int] $FanOut }
                        fan_in  = if ($null -eq $FanIn) { 0 } else { [int] $FanIn }
                    })
            }
        }
    }
}

$AllUnits = [System.Collections.Generic.List[object]]::new()
$AllCoupling = [System.Collections.Generic.List[object]]::new()

foreach ($Entry in $HostProjects) {
    $XmlPath = Join-Path $MetricsRoot $Entry.XmlName
    try {
        [xml] $Doc = Get-Content -LiteralPath $XmlPath -Raw
    }
    catch {
        Write-Fail "Failed to parse $($Entry.XmlName): $($_.Exception.Message)" 2
    }

    if ($null -eq $Doc.global) {
        Write-Fail "Unexpected metrics XML root in $($Entry.XmlName)" 2
    }

    foreach ($FileElement in @($Doc.global.SelectNodes('./file'))) {
        $FilePath = [string] $FileElement.name
        $FileName = [IO.Path]::GetFileName($FilePath)
        foreach ($Unit in @($FileElement.SelectNodes('./unit'))) {
            Collect-Units -UnitElement $Unit -FilePath $FilePath -FileName $FileName `
                -QualifiedPrefix '' -Into $AllUnits
        }
    }
    Collect-Coupling -GlobalElement $Doc.global -Into $AllCoupling
}

if ($AllUnits.Count -eq 0) {
    Write-Fail 'No complexity units found in metrics XML' 2
}

$CcBreaches = @($AllUnits | Where-Object { $_.cyclomatic -gt $CyclomaticMaximum })
$EssBreaches = @($AllUnits | Where-Object { $_.essential -gt $EssentialMaximum })
$NestBreaches = @($AllUnits | Where-Object { $_.max_loop_nesting -gt $NestingMaximum })

$MaxCc = ($AllUnits | Measure-Object -Property cyclomatic -Maximum).Maximum
$MaxEss = ($AllUnits | Measure-Object -Property essential -Maximum).Maximum
$MaxNest = ($AllUnits | Measure-Object -Property max_loop_nesting -Maximum).Maximum
$MaxExits = ($AllUnits | Measure-Object -Property extra_exit_points -Maximum).Maximum

$Summary = [ordered]@{
    unit_count              = $AllUnits.Count
    max_cyclomatic          = [int] $MaxCc
    max_essential           = [int] $MaxEss
    max_loop_nesting        = [int] $MaxNest
    max_extra_exit_points   = [int] $MaxExits
    cyclomatic_maximum      = $CyclomaticMaximum
    essential_maximum       = $EssentialMaximum
    nesting_maximum         = $NestingMaximum
    cyclomatic_breaches     = $CcBreaches.Count
    essential_breaches      = $EssBreaches.Count
    nesting_breaches        = $NestBreaches.Count
    gates_skipped           = [bool] $SkipGates
    top_cyclomatic          = @(
        $AllUnits | Sort-Object cyclomatic -Descending | Select-Object -First 15 |
            ForEach-Object {
                [ordered]@{
                    cyclomatic = $_.cyclomatic
                    essential  = $_.essential
                    nesting    = $_.max_loop_nesting
                    exits      = $_.extra_exit_points
                    unit       = $_.qualified_name
                    file       = $_.file
                    line       = $_.line
                }
            }
    )
    top_fan_out             = @(
        $AllCoupling | Sort-Object fan_out -Descending | Select-Object -First 10 |
            ForEach-Object {
                [ordered]@{ fan_out = $_.fan_out; fan_in = $_.fan_in; name = $_.name; file = $_.file }
            }
    )
}

($Summary | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $SummaryPath -Encoding utf8
(@($AllUnits) | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath $UnitsPath -Encoding utf8

Write-Host ''
Write-Host 'Complexity summary'
Write-Host ("  Units measured:     {0}" -f $AllUnits.Count)
Write-Host ("  Max cyclomatic:     {0}  (gate <= {1})" -f $MaxCc, $CyclomaticMaximum)
Write-Host ("  Max essential:      {0}  (gate <= {1})" -f $MaxEss, $EssentialMaximum)
Write-Host ("  Max loop nesting:   {0}  (gate <= {1})" -f $MaxNest, $NestingMaximum)
Write-Host ("  Max extra exits:    {0}  (report only)" -f $MaxExits)
Write-Host '  Top cyclomatic:'
foreach ($Row in $Summary.top_cyclomatic | Select-Object -First 10) {
    Write-Host ("    CC={0,2} Ess={1,2} Nest={2}  {3}:{4}  {5}" -f `
            $Row.cyclomatic, $Row.essential, $Row.nesting, $Row.file, $Row.line, $Row.unit)
}
Write-Host '  Top unit fan-out (report only):'
foreach ($Row in $Summary.top_fan_out | Select-Object -First 5) {
    Write-Host ("    out={0,2} in={1,2}  {2}  ({3})" -f $Row.fan_out, $Row.fan_in, $Row.name, $Row.file)
}
Write-Host "  Wrote $SummaryPath"

if ($SkipGates) {
    Write-Host 'SkipGates set — not enforcing thresholds.'
    exit 0
}

$Failures = @()
if ($CcBreaches.Count -gt 0) {
    $Failures += "cyclomatic: $($CcBreaches.Count) unit(s) > $CyclomaticMaximum (max $MaxCc)"
}
if ($EssBreaches.Count -gt 0) {
    $Failures += "essential: $($EssBreaches.Count) unit(s) > $EssentialMaximum (max $MaxEss)"
}
if ($NestBreaches.Count -gt 0) {
    $Failures += "nesting: $($NestBreaches.Count) unit(s) > $NestingMaximum (max $MaxNest)"
}

if ($Failures.Count -gt 0) {
    Write-Host ''
    Write-Host 'Complexity gates FAILED:'
    foreach ($Failure in $Failures) {
        Write-Host "  - $Failure"
    }
    exit 1
}

Write-Host 'Complexity gates passed.'
exit 0
