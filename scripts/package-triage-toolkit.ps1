#requires -Version 7.5
[CmdletBinding()]
param([switch]$Check)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$source = Join-Path $repo 'tools/microsoft-365-incident-triage-toolkit'
$destination = Join-Path $repo 'assets/downloads/microsoft-365-incident-triage-toolkit.zip'
$files = @('Export-M365IncidentTriage.ps1', 'M365IncidentTriage.psm1', 'README.md',
    'demo-snapshot.json', 'escalation-template.md', 'samples/evidence.json',
    'samples/report.md', 'tests/Test-M365IncidentTriage.ps1') | Sort-Object
$sample = Get-Content -LiteralPath (Join-Path $source 'samples/evidence.json') -Raw | ConvertFrom-Json -AsHashtable -DateKind String
if ($sample.Mode -ne 'Demo' -or $sample.TenantId -ne 'SYNTHETIC — no tenant') {
    throw 'Only the synthetic demo sample may be packaged.'
}
Add-Type -AssemblyName System.IO.Compression
if ($Check) {
    $zip = [IO.Compression.ZipFile]::OpenRead($destination)
    try {
        if ($zip.Entries.Count -ne $files.Count) { throw 'Unexpected archive entries.' }
        foreach ($file in $files) {
            $entry = $zip.GetEntry($file)
            if (-not $entry) { throw "Missing archive file: $file" }
            $stream = $entry.Open()
            $buffer = [IO.MemoryStream]::new()
            try {
                $stream.CopyTo($buffer)
                $expected = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $source $file)))
                if ([Convert]::ToBase64String($buffer.ToArray()) -cne $expected) { throw "Stale archive file: $file" }
            } finally { $stream.Dispose(); $buffer.Dispose() }
        }
    } finally { $zip.Dispose() }
    Write-Host 'Toolkit ZIP matches all eight source files; sample is synthetic.'
} else {
    $null = [IO.Directory]::CreateDirectory((Split-Path $destination -Parent))
    $stream = [IO.File]::Open($destination, [IO.FileMode]::Create)
    $zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in $files) {
            $entry = $zip.CreateEntry($file)
            $entry.LastWriteTime = [datetimeoffset]'2000-01-01T00:00:00Z'
            $entryStream = $entry.Open()
            try {
                $bytes = [IO.File]::ReadAllBytes((Join-Path $source $file))
                $entryStream.Write($bytes, 0, $bytes.Length)
            } finally { $entryStream.Dispose() }
        }
    } finally { $zip.Dispose(); $stream.Dispose() }
    Write-Host "Packaged $destination"
}
