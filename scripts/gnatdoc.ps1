# Generate host Ada API HTML with GNATdoc 4 (leading comments).
# Requires `alr install gnatdoc` and `~/.alire/bin` on PATH.
# Build each crate once so Alire has written config/ GPRs before running.
#
# When adding a new host Alire crate (.gpr), append an entry to $Projects below.

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$Projects = @(
    @{ Name = 'common'; ProjectFile = 'lovelace/common/lovelace_common.gpr' },
    @{ Name = 'compiler'; ProjectFile = 'lovelace/compiler/lovelace_compiler.gpr' },
    @{ Name = 'lir'; ProjectFile = 'lovelace/lir/lovelace_lir.gpr' },
    @{ Name = 'lovelace'; ProjectFile = 'lovelace/lovelace/lovelace.gpr' }
)

foreach ($Project in $Projects) {
    $OutputDirectory = Join-Path $RepoRoot ('docs/.code/' + $Project.Name)
    Write-Host "GNATdoc: $($Project.ProjectFile) -> docs/.code/$($Project.Name)"

    & alr exec -- gnatdoc `
        --style=leading `
        --backend html `
        --output-dir $OutputDirectory `
        $Project.ProjectFile

    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
