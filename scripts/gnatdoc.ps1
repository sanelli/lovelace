# Generate host Ada API docs with GNATdoc 4 (leading comments).
# Requires `gnatdoc` on PATH (alr install gnatdoc) and crate config/
# GPRs from a prior alr build of each crate.

$ErrorActionPreference = 'Stop'

$Gnatdoc = Get-Command gnatdoc -ErrorAction SilentlyContinue
if (-not $Gnatdoc) {
    Write-Error @'
gnatdoc not found on PATH.
Install GNATdoc 4, then add its bin directory to PATH, for example:
  alr install --prefix $HOME/.local gnatdoc
See https://alire.ada.dev/crates/gnatdoc
'@
}

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

function Invoke-CrateGnatdoc {
    param(
        [string]$CrateDirectory,
        [string]$ProjectFile
    )
    Push-Location (Join-Path $RepoRoot $CrateDirectory)
    try {
        & alr exec -- gnatdoc `
            --style=leading --warnings -O gnatdoc -P $ProjectFile
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }
    finally {
        Pop-Location
    }
}

Invoke-CrateGnatdoc -CrateDirectory 'common' -ProjectFile 'lovelace_common.gpr'
Invoke-CrateGnatdoc -CrateDirectory 'lovelace' -ProjectFile 'lovelace.gpr'
