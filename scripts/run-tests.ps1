# Quietly build, then run nested AUnit crates (status lines only).
#
# Unit crates (default on):
#   common/tests, lir/tests, compiler/tests, lovelace/tests
#   — skip with -SkipUnit
#
# Integration (default on):
#   lovelace/integration_tests
#   — skip with -SkipIntegration
#
# Usage (from repo root):
#   pwsh scripts/run-tests.ps1
#   pwsh scripts/run-tests.ps1 -SkipIntegration
#   pwsh scripts/run-tests.ps1 -SkipUnit
#   pwsh scripts/run-tests.ps1 -SkipUnit -SkipIntegration

[CmdletBinding()]
param(
    # When set, do not run nested unit-test crates.
    [switch] $SkipUnit,

    # When set, do not build or run lovelace/integration_tests.
    [switch] $SkipIntegration
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

function Invoke-QuietAlireBuild {
    param(
        [Parameter(Mandatory)]
        [string] $Label,

        [Parameter(Mandatory)]
        [string[]] $Arguments
    )

    $LogPath = [System.IO.Path]::GetTempFileName()
    try {
        & alr @Arguments *> $LogPath
        if ($LASTEXITCODE -ne 0) {
            Get-Content -LiteralPath $LogPath | Write-Host
            Write-Error "Build failed: $Label (exit $LASTEXITCODE)"
            exit $LASTEXITCODE
        }
    }
    finally {
        Remove-Item -LiteralPath $LogPath -ErrorAction SilentlyContinue
    }
}

function Invoke-TestExecutable {
    param(
        [Parameter(Mandatory)]
        [string] $CratePath,

        [Parameter(Mandatory)]
        [string] $ExecutableName
    )

    Invoke-QuietAlireBuild -Label "$CratePath build" -Arguments @('-C', $CratePath, 'build')

    $Executable = Join-Path $RepoRoot $CratePath 'bin' $ExecutableName
    if (-not (Test-Path -LiteralPath $Executable)) {
        $Executable = "$Executable.exe"
    }
    if (-not (Test-Path -LiteralPath $Executable)) {
        Write-Error "Test executable not found: $ExecutableName under $CratePath/bin"
        exit 1
    }

    Push-Location (Join-Path $RepoRoot $CratePath)
    try {
        & $Executable
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed: $CratePath (exit $LASTEXITCODE)"
            exit $LASTEXITCODE
        }
    }
    finally {
        Pop-Location
    }
}

$UnitTestCrates = @(
    @{ Path = 'common/tests'; Executable = 'lovelace_common_tests' },
    @{ Path = 'lir/tests'; Executable = 'lovelace_lir_tests' },
    @{ Path = 'compiler/tests'; Executable = 'lovelace_compiler_tests' },
    @{ Path = 'lovelace/tests'; Executable = 'lovelace_tests' }
)

Invoke-QuietAlireBuild -Label 'workspace build' -Arguments @('build')

if ($SkipUnit) {
    Write-Host 'Skipping unit tests (-SkipUnit).'
}
else {
    foreach ($Crate in $UnitTestCrates) {
        Invoke-TestExecutable -CratePath $Crate.Path -ExecutableName $Crate.Executable
    }
}

if ($SkipIntegration) {
    Write-Host 'Skipping integration tests (-SkipIntegration).'
}
else {
    Invoke-TestExecutable `
        -CratePath 'lovelace/integration_tests' `
        -ExecutableName 'lovelace_integration_tests'
}
