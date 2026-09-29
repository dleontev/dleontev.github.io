#requires -Version 7.5
[CmdletBinding()]
param([string]$OutputRoot = (Join-Path ([IO.Path]::GetTempPath()) ('triage-tests-' + [guid]::NewGuid().ToString('N'))))
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$kit = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $kit 'M365IncidentTriage.psm1') -Force
$null = [IO.Directory]::CreateDirectory($OutputRoot)
$passed = 0
function Assert($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Test([string]$Name, [scriptblock]$Body) {
    & $Body
    $script:passed++
    Write-Host "PASS $Name"
}
function Assert-Throws([scriptblock]$Body) {
    $threw = $false
    try { & $Body | Out-Null } catch { $threw = $true }
    Assert $threw 'Expected a terminating error.'
}
$fixturePath = Join-Path $kit 'demo-snapshot.json'
$fixture = Get-Content -LiteralPath $fixturePath -Raw | ConvertFrom-Json -AsHashtable -DateKind String
$healthRow = $fixture.collections.healthOverviews.value[0]
$baseUri = 'https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/healthOverviews'
$page2 = $baseUri + '?$skiptoken=synthetic'

Test 'Pagination follows an empty first page' {
    $healthRow = $healthRow; $page2 = $page2
    $calls = [Collections.Generic.List[string]]::new()
    $request = {
        param($uri)
        $calls.Add($uri)
        if ($uri -eq $page2) { return @{ value = @($healthRow) } }
        @{ value = @(); '@odata.nextLink' = $page2 }
    }.GetNewClosure()
    $r = Read-TriageCollection healthOverviews $request
    Assert ($r.Status -eq 'Complete' -and $r.Pages -eq 2 -and $r.Items.Count -eq 1) 'Lost a later page.'
    Assert ($calls[1] -ceq $page2) 'Continuation was rebuilt rather than followed.'
}
Test 'A later request failure retains earlier evidence and marks it incomplete' {
    $healthRow = $healthRow; $page2 = $page2
    $request = {
        param($uri)
        if ($uri -eq $page2) { throw 'Synthetic HTTP failure; do not export this body.' }
        @{ value = @($healthRow); '@odata.nextLink' = $page2 }
    }.GetNewClosure()
    $r = Read-TriageCollection healthOverviews $request
    Assert ($r.Status -eq 'Incomplete' -and $r.Items.Count -eq 1 -and $r.FailureReason -eq 'RequestFailed') 'Partial failure was hidden.'
}
Test 'A foreign continuation is rejected before a request' {
    $healthRow = $healthRow
    $calls = [Collections.Generic.List[string]]::new()
    $request = { param($uri); $calls.Add($uri); @{ value = @($healthRow); '@odata.nextLink' = 'https://example.org/collect' } }.GetNewClosure()
    $r = Read-TriageCollection healthOverviews $request
    Assert ($r.FailureReason -eq 'UnsafeContinuation' -and $calls.Count -eq 1) 'Requested a foreign host.'
}
Test 'Cross-resource, insecure, and credential-bearing continuations are rejected' {
    foreach ($bad in @('https://graph.microsoft.com/v1.0/users',
        'http://graph.microsoft.com/v1.0/admin/serviceAnnouncement/healthOverviews',
        'https://user@graph.microsoft.com/v1.0/admin/serviceAnnouncement/healthOverviews')) {
        $request = { param($uri); @{ value = @(); '@odata.nextLink' = $bad } }.GetNewClosure()
        $r = Read-TriageCollection healthOverviews $request
        Assert ($r.FailureReason -eq 'UnsafeContinuation') "Accepted $bad"
    }
}
Test 'Repeated pages and page limits stop collection' {
    $page2 = $page2
    $request = { param($uri); @{ value = @(); '@odata.nextLink' = $page2 } }.GetNewClosure()
    Assert ((Read-TriageCollection healthOverviews $request).FailureReason -eq 'RepeatedContinuation') 'Loop not detected.'
    Assert ((Read-TriageCollection healthOverviews $request -MaxPages 1).FailureReason -eq 'PageLimit') 'Page limit ignored.'
}
Test 'Malformed responses cannot look like empty success' {
    foreach ($badPage in @(@{}, @{value = $null}, @{value = 'invalid'}, @{value = @(@{id = 'x'})})) {
        $request = { param($uri); $badPage }.GetNewClosure()
        Assert ((Read-TriageCollection healthOverviews $request).Status -eq 'Incomplete') 'Malformed data treated as success.'
    }
}
Test 'Missing issue state or date is incomplete' {
    foreach ($property in @('isResolved', 'lastModifiedDateTime')) {
        $row = $fixture.collections.issues.value[0].Clone()
        $row.Remove($property)
        $request = { param($uri); @{value = @($row)} }.GetNewClosure()
        Assert ((Read-TriageCollection issues $request).FailureReason -eq 'InvalidItem') 'Invalid issue accepted.'
    }
}
Test 'Selection retains open issues and recently updated resolved issues' {
    $rows = @(Select-TriageIssue $fixture.collections.issues.value ([datetimeoffset]'2026-09-13T16:00:00Z'))
    Assert ($rows.Count -eq 2 -and $rows.id -contains 'DEMO-TM-002' -and $rows.id -notcontains 'DEMO-SP-003') 'Incorrect date selection.'
    $rows = @(Select-TriageIssue $fixture.collections.issues.value ([datetimeoffset]'2026-09-15T00:00:00Z'))
    Assert ($rows.Count -eq 1 -and $rows[0].id -eq 'DEMO-EX-001') 'Old unresolved issue was dropped.'
}
Test 'Tenant, delegated scope, and cloud checks fail closed' {
    $context = @{TenantId = '00000000-0000-0000-0000-000000000001'; AuthType = 'Delegated'; Environment = 'Global'; Scopes = @('ServiceHealth.Read.All')}
    Assert-TriageContext $context ([guid]$context.TenantId)
    Assert-Throws { Assert-TriageContext $null ([guid]$context.TenantId) }
    foreach ($change in @(@{TenantId = '00000000-0000-0000-0000-000000000002'}, @{AuthType = 'AppOnly'}, @{Environment = 'USGov'}, @{Scopes = @('User.Read')})) {
        $badContext = $context.Clone()
        foreach ($key in $change.Keys) { $badContext[$key] = $change[$key] }
        Assert-Throws { Assert-TriageContext $badContext ([guid]$context.TenantId) }
    }
}
$demoParams = @{
    Demo = $true; IncidentId = 'DEMO-INC-001'
    Symptom = 'Outlook on the web loads slowly for a fictional pilot group.'
    Impact = 'Six fictional users; email response work delayed.'
    FirstObservedUtc = '2026-09-14T16:00:00Z'; OutputRoot = $OutputRoot
}
Test 'Demo runs offline and produces a labeled, parseable bundle' {
    $run = & (Join-Path $kit 'Export-M365IncidentTriage.ps1') @demoParams
    $e = Get-Content -LiteralPath (Join-Path $run.OutputDirectory 'evidence.json') -Raw | ConvertFrom-Json -AsHashtable -DateKind String
    $report = Get-Content -LiteralPath (Join-Path $run.OutputDirectory 'report.md') -Raw
    Assert ($e.Mode -eq 'Demo' -and $e.CollectionStatus -eq 'Complete' -and $e.CandidateIssues.Count -eq 2) 'Demo output is wrong.'
    Assert ($report.Contains('SYNTHETIC DEMO') -and $report.Contains('DEMO-TM-002')) 'Missing synthetic label or candidate.'
    $script:firstRun = $run.OutputDirectory
}
Test 'Repeat runs preserve prior evidence and escape report text' {
    $before = (Get-FileHash -LiteralPath (Join-Path $firstRun 'evidence.json')).Hash
    $params = $demoParams.Clone()
    $params.Symptom = "<script>alert(1)</script> | [click](https://example.org)`n# forged heading"
    $run = & (Join-Path $kit 'Export-M365IncidentTriage.ps1') @params
    $report = Get-Content -LiteralPath (Join-Path $run.OutputDirectory 'report.md') -Raw
    Assert ($run.OutputDirectory -ne $firstRun -and $before -eq (Get-FileHash -LiteralPath (Join-Path $firstRun 'evidence.json')).Hash) 'Prior evidence overwritten.'
    Assert (-not $report.Contains('<script>') -and -not $report.Contains('[click]') -and -not $report.Contains("`n# forged")) 'Untrusted text became markup.'
}
Test 'Invalid timestamps fail before output is created' {
    foreach ($badDate in @('2026-09-14 16:00', '2026-09-14T16:00:00-07:00', '2026-09-15T16:00:00Z')) {
        $params = $demoParams.Clone(); $params.FirstObservedUtc = $badDate
        Assert-Throws { & (Join-Path $kit 'Export-M365IncidentTriage.ps1') @params }
    }
}

# Exercise the real Live entry point in child processes with a local fake authentication module.
# The fake has no HTTP capability and records every method; no tenant connection is attempted.
$mockRoot = Join-Path $OutputRoot 'mock-modules'
$mockModule = Join-Path $mockRoot 'Microsoft.Graph.Authentication'
$null = [IO.Directory]::CreateDirectory($mockModule)
@'
function Get-MgContext {
    @{ TenantId = '00000000-0000-0000-0000-000000000001'; AuthType = 'Delegated'; Environment = 'Global'; Scopes = @('ServiceHealth.Read.All') }
}
function Invoke-MgGraphRequest {
    [CmdletBinding()] param($Method, $Uri, $OutputType)
    Add-Content -LiteralPath $env:TRIAGE_TEST_CALLS -Value $Method
    if ($Method -ne 'GET') { throw 'Remote write attempted.' }
    $resource = ([uri]$Uri).Segments[-1]
    if ($env:TRIAGE_TEST_FAIL -eq '1' -and $resource -eq 'issues') { throw 'Synthetic issue collection failure.' }
    $data = Get-Content -LiteralPath $env:TRIAGE_TEST_FIXTURE -Raw | ConvertFrom-Json -AsHashtable -DateKind String
    $data.collections[$resource]
}
Export-ModuleMember -Function Get-MgContext, Invoke-MgGraphRequest
'@ | Set-Content -LiteralPath (Join-Path $mockModule 'Microsoft.Graph.Authentication.psm1') -Encoding utf8NoBOM
$savedPath = $env:PSModulePath
try {
    $env:PSModulePath = $mockRoot + [IO.Path]::PathSeparator + $savedPath
    $env:TRIAGE_TEST_CALLS = Join-Path $OutputRoot 'mock-methods.txt'
    $env:TRIAGE_TEST_FIXTURE = $fixturePath
    foreach ($fail in @('0', '1')) {
        $env:TRIAGE_TEST_FAIL = $fail
        Test "Live entry point with mocked Graph, failure=$fail" {
            $liveRoot = Join-Path $OutputRoot "mock-live-$fail"
            $log = & (Join-Path $PSHOME 'pwsh') -NoProfile -File (Join-Path $kit 'Export-M365IncidentTriage.ps1') -TenantId '00000000-0000-0000-0000-000000000001' -IncidentId 'MOCK-INC-001' -Symptom 'Synthetic test' -Impact 'No real users' -FirstObservedUtc '2026-09-14T16:00:00Z' -OutputRoot $liveRoot 2>&1
            $code = $LASTEXITCODE
            $files = @(Get-ChildItem -LiteralPath $liveRoot -Filter 'evidence.json' -Recurse)
            Assert ($files.Count -eq 1) "Missing evidence: $log"
            $e = Get-Content -LiteralPath $files[0].FullName -Raw | ConvertFrom-Json -AsHashtable -DateKind String
            if ($fail -eq '1') {
                Assert ($code -ne 0 -and $e.CollectionStatus -eq 'Incomplete' -and $e.Collections.HealthOverviews.Items.Count -eq 3) 'Failure lost evidence or returned success.'
            } else {
                Assert ($code -eq 0 -and $e.CollectionStatus -eq 'Complete') "Live mock failed: $log"
            }
        }
    }
    Test 'Live requests are exclusively GET' {
        $methods = @(Get-Content -LiteralPath $env:TRIAGE_TEST_CALLS)
        Assert ($methods.Count -eq 4 -and @($methods | Where-Object { $_ -ne 'GET' }).Count -eq 0) 'Unexpected HTTP methods.'
    }
} finally {
    $env:PSModulePath = $savedPath
    Remove-Item Env:TRIAGE_TEST_CALLS, Env:TRIAGE_TEST_FIXTURE, Env:TRIAGE_TEST_FAIL -ErrorAction SilentlyContinue
}
Write-Host "$passed tests passed. All API data and Graph connections were mocked. Outputs: $OutputRoot"
