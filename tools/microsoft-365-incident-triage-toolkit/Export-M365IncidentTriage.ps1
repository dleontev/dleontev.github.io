#requires -Version 7.5
<#
.SYNOPSIS
Collect a read-only Microsoft 365 service-health snapshot and incident handoff.
.DESCRIPTION
Demo mode uses packaged synthetic data without Graph. Live mode requires an existing
delegated Graph connection to the explicit tenant in the Global environment.
Each run creates a new directory under OutputRoot. Incomplete collection writes the
available evidence, then throws; pwsh -File returns a nonzero exit code.
#>
[CmdletBinding(DefaultParameterSetName = 'Live')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Demo')][switch]$Demo,
    [Parameter(Mandatory, ParameterSetName = 'Live')][guid]$TenantId,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_-]{0,59}$')][string]$IncidentId,
    [Parameter(Mandatory)][ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })][ValidateLength(1, 2000)][string]$Symptom,
    [Parameter(Mandatory)][ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })][ValidateLength(1, 2000)][string]$Impact,
    [Parameter(Mandatory)][string]$FirstObservedUtc,
    [ValidateRange(0, 168)][int]$LookBackHours = 24,
    [ValidateNotNullOrEmpty()][string]$OutputRoot = (Join-Path ([Environment]::GetFolderPath('UserProfile')) 'm365-triage')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'M365IncidentTriage.psm1') -Force
$first = [datetimeoffset]::ParseExact($FirstObservedUtc, "yyyy-MM-dd'T'HH:mm:ss'Z'",
    [cultureinfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal)
$started = [datetimeoffset]::UtcNow
$mode = 'Live'
$graphVersion = $null
if ($PSCmdlet.ParameterSetName -eq 'Demo') {
    $mode = 'Demo'
    $fixture = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'demo-snapshot.json') -Raw |
        ConvertFrom-Json -AsHashtable -DateKind String
    $started = [datetimeoffset]::Parse($fixture.snapshotAtUtc, [cultureinfo]::InvariantCulture)
    $tenantLabel = 'SYNTHETIC — no tenant'
    $request = {
        param($uri)
        $resource = ([uri]$uri).Segments[-1]
        if (-not $fixture.collections.Contains($resource)) { throw 'Unknown demo collection.' }
        $fixture.collections[$resource]
    }.GetNewClosure()
} else {
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Assert-TriageContext -Context (Get-MgContext) -TenantId $TenantId
    $graphVersion = (Get-Module Microsoft.Graph.Authentication).Version.ToString()
    $tenantLabel = $TenantId.ToString()
    $request = {
        param($uri)
        Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType Hashtable -ErrorAction Stop
    }
}
if ($first -gt $started) { throw 'FirstObservedUtc must not be after the snapshot time (the demo uses 2026-09-14T16:30:00Z).' }
$since = $first.AddHours(-$LookBackHours)
$health = Read-TriageCollection -Resource healthOverviews -Request $request
$issues = Read-TriageCollection -Resource issues -Request $request
$status = if ($health.Status -eq 'Complete' -and $issues.Status -eq 'Complete') { 'Complete' } else { 'Incomplete' }
$finished = if ($mode -eq 'Demo') { $started } else { [datetimeoffset]::UtcNow }
$evidence = [ordered]@{
    SchemaVersion = '1.0'
    ToolkitVersion = '1.0.0'
    Mode = $mode
    TenantId = $tenantLabel
    PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    GraphAuthenticationVersion = $graphVersion
    StartedAtUtc = $started.ToUniversalTime().ToString('o')
    FinishedAtUtc = $finished.ToUniversalTime().ToString('o')
    Incident = [ordered]@{
        IncidentId = $IncidentId; Symptom = $Symptom; Impact = $Impact
        FirstObservedUtc = $first.ToUniversalTime().ToString('o')
    }
    IssuesSinceUtc = $since.ToUniversalTime().ToString('o')
    CollectionStatus = $status
    Collections = [ordered]@{ HealthOverviews = $health; Issues = $issues }
    CandidateIssues = @(Select-TriageIssue -Issues $issues.Items -SinceUtc $since)
}
# Unique directories preserve previous evidence, even for repeated runs of the same incident.
$root = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputRoot)
$null = [IO.Directory]::CreateDirectory($root)
$runName = $IncidentId + '-' + [datetimeoffset]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' + [guid]::NewGuid().ToString('N')
$runDirectory = Join-Path $root $runName
$null = New-Item -ItemType Directory -Path $runDirectory -ErrorAction Stop
$json = ($evidence | ConvertTo-Json -Depth 20) -replace "`r`n", "`n"
$report = ConvertTo-TriageReport -Evidence $evidence
Set-Content -LiteralPath (Join-Path $runDirectory 'evidence.json') -Value ($json + "`n") -Encoding utf8NoBOM -NoNewline
Set-Content -LiteralPath (Join-Path $runDirectory 'report.md') -Value ($report + "`n") -Encoding utf8NoBOM -NoNewline
[pscustomobject]@{ CollectionStatus = $status; Mode = $mode; OutputDirectory = $runDirectory }
if ($status -ne 'Complete') {
    throw "Collection is incomplete. Review collection results in $runDirectory before using this evidence."
}
