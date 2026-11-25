# Fail if Ada/docs/scripts contain UTF-8 mojibake from gnatformat Latin-1
# round-trips of ellipsis / arrows / inequalities. Prefer ASCII in comments
# (...  ->  >=) so formatters cannot re-corrupt them.
#
# Usage (repo root):
#   pwsh scripts/check-encoding.ps1
#
# Exit: 0 ok, 1 mojibake found, 2 tool failure

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

# Build markers via string concat (bare [char]+[char] is numeric add in PowerShell).
function New-Marker {
    param([int[]] $CodePoints)
    $s = ''
    foreach ($cp in $CodePoints) {
        $s = $s + [char]$cp
    }
    return $s
}

# Substrings that only appear after UTF-8 was mis-decoded as Latin-1/Windows-1252
# (often more than once). Do not put literal mojibake in this file's comments —
# describe it in ASCII only (this script is scanned too).
$MojibakeMarkers = @(
    (New-Marker 0x00C3, 0x00A2),           # U+00C3 U+00A2 (double/triple-encoded ellipsis)
    (New-Marker 0x00E2, 0x20AC),           # U+00E2 U+20AC (single-encoded ellipsis / dash)
    (New-Marker 0x00C3, 0x0083),           # U+00C3 U+0083 (triple-encoded layer)
    (New-Marker 0x00E2, 0x0086),           # U+00E2 U+0086 (corrupted arrow)
    (New-Marker 0x00E2, 0x0089),           # U+00E2 U+0089 (corrupted inequality)
    (New-Marker 0x00C3, 0x00A2, 0x00C2), # common ellipsis corruption stem
    ([string][char]0xFFFD)                 # replacement character
)

$Extensions = @('.ads', '.adb', '.adc', '.md', '.mdc', '.ps1', '.toml')
$SkipDirNames = @(
    '.git', 'alire', '.coverage', '.metrics', 'bin', 'obj',
    'gnatcov-instr', 'node_modules'
)

$Hits = [System.Collections.Generic.List[string]]::new()

function Test-SkippedDirectory {
    param([string] $FullPath)
    $parts = $FullPath.Split(
        [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar),
        [System.StringSplitOptions]::RemoveEmptyEntries)
    foreach ($part in $parts) {
        if ($SkipDirNames -contains $part) { return $true }
    }
    return $false
}

Get-ChildItem -Path $RepoRoot -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
        $Extensions -contains $_.Extension -and
            -not (Test-SkippedDirectory -FullPath $_.DirectoryName)
    } |
    ForEach-Object {
        $path = $_.FullName
        $lineNo = 0
        try {
            $reader = [System.IO.StreamReader]::new($path, [System.Text.Encoding]::UTF8, $true)
            try {
                while ($null -ne ($line = $reader.ReadLine())) {
                    $lineNo++
                    foreach ($marker in $MojibakeMarkers) {
                        if ($line.Contains([string]$marker)) {
                            $rel = $path.Substring($RepoRoot.Length).TrimStart('\', '/')
                            $snippet = $line.Trim()
                            if ($snippet.Length -gt 100) {
                                $snippet = $snippet.Substring(0, 100) + '...'
                            }
                            $Hits.Add("${rel}:${lineNo}: $snippet")
                            break
                        }
                    }
                }
            } finally {
                $reader.Dispose()
            }
        } catch {
            Write-Error "Cannot read $path : $_"
            exit 2
        }
    }

if ($Hits.Count -gt 0) {
    Write-Host "check-encoding: $($Hits.Count) mojibake line(s) (UTF-8 corrupted by Latin-1 round-trip):" -ForegroundColor Red
    foreach ($h in $Hits) {
        Write-Host "  $h"
    }
    Write-Host ''
    Write-Host 'Replace with ASCII in comments (ellipsis -> ..., arrow -> ->, ge -> >=) and re-run.' -ForegroundColor Yellow
    Write-Host 'Avoid project-wide gnatformat; format only explicitly listed .ads/.adb files.' -ForegroundColor Yellow
    exit 1
}

Write-Host 'check-encoding: OK (no mojibake markers)'
exit 0
