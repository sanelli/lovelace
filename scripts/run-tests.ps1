# Build the workspace and run nested AUnit crates.
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

function Invoke-Alire {
    param(
        [Parameter(Mandatory)]
        [string] $Label,

        [Parameter(Mandatory)]
        [string[]] $Arguments
    )

    Write-Host ""
    Write-Host "=== $Label ==="
    Write-Host ("alr " + ($Arguments -join ' '))

    & alr @Arguments
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed: $Label (exit $LASTEXITCODE)"
        exit $LASTEXITCODE
    }
}

$UnitTestCrates = @(
    'common/tests',
    'lir/tests',
    'compiler/tests',
    'lovelace/tests'
)

Invoke-Alire -Label 'workspace build' -Arguments @('build')

if ($SkipUnit) {
    Write-Host ''
    Write-Host 'Skipping unit tests (-SkipUnit).'
}
else {
    foreach ($CratePath in $UnitTestCrates) {
        Invoke-Alire -Label "$CratePath (unit)" -Arguments @('-C', $CratePath, 'run')
    }
}

if ($SkipIntegration) {
    Write-Host ''
    Write-Host 'Skipping integration tests (-SkipIntegration).'
}
else {
    Invoke-Alire `
        -Label 'lovelace/integration_tests' `
        -Arguments @('-C', 'lovelace/integration_tests', 'run')
}

Write-Host ''
Write-Host 'All requested tests passed.'
