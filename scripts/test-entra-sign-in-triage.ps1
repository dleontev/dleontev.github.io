#Requires -Version 5.1
<#
AI-assisted code
Purpose: Verify the published synthetic cases and conservative error handling for the triage helper.
Prepared for review by: Dimitriy Leontev
Generated: 2026-11-06
#>
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$kit = Join-Path $root 'assets/projects/entra-sign-in'
$helper = Join-Path $kit 'Get-EntraSignInTriage.ps1'
$examples = Join-Path $kit 'examples'
$expected = [ordered] @{
    'device-compliance' = 'device-compliance'
    'mfa-incomplete'    = 'authentication'
    'account-disabled'  = 'account'
    'application-denied' = 'application'
    'no-matching-event' = 'match-event'
    'report-only'       = 'review-evidence'
    'missing-evidence'  = 'review-evidence'
    'policy-block'      = 'conditional-access'
    'verify-task'       = 'verify-task'
}

foreach ($caseName in $expected.Keys) {
    $result = & $helper -Path (Join-Path $examples "$caseName.json")
    if ($result.Route -ne $expected[$caseName] -or [string]::IsNullOrWhiteSpace($result.NextCheck)) {
        throw "Unexpected route or missing next check for $caseName."
    }
    if ($caseName -eq 'report-only' -and $result.Note -notmatch 'potential policy impact') {
        throw 'The report-only case must explain the result.'
    }
    if ($caseName -eq 'missing-evidence' -and $result.EvidenceGaps -ne 'signInResult') {
        throw 'The incomplete case must identify the missing sign-in result.'
    }
    Write-Host "PASS $caseName -> $($result.Route)"
}

$tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ("entra-triage-$([guid]::NewGuid()).json")
try {
    $conflict = '{"schemaVersion":1,"synthetic":true,"eventMatch":"matched","signInResult":"failed","accountState":"disabled","conditionalAccess":"enforcedFailure"}'
    Set-Content -LiteralPath $tempFile -Value $conflict -Encoding UTF8
    $result = & $helper -Path $tempFile
    if ($result.Route -ne 'review-evidence' -or $result.Note -notmatch 'reconciled') {
        throw 'Conflicting failure signals must be routed for review.'
    }

    $deviceUnknown = '{"schemaVersion":1,"synthetic":true,"eventMatch":"matched","signInResult":"failed","conditionalAccess":"enforcedFailure","failedControl":"compliantDevice"}'
    Set-Content -LiteralPath $tempFile -Value $deviceUnknown -Encoding UTF8
    $result = & $helper -Path $tempFile
    if ($result.Route -ne 'conditional-access' -or $result.EvidenceGaps -ne 'deviceCompliance') {
        throw 'A missing device observation must keep the route at policy review.'
    }
    Write-Host 'PASS conflicting signals and missing device evidence'

    $invalid = @(
        @{ Text = '{"eventMatch":"matched"}'; Error = 'synthetic set to true' }
        @{ Text = '{"schemaVersion":"1","synthetic":true}'; Error = 'numeric schemaVersion 1' }
        @{ Text = '{"schemaVersion":1,"synthetic":true,"eventMatch":"unexpected"}'; Error = 'unsupported value' }
        @{ Text = '{"schemaVersion":1,"synthetic":true,"eventMatch":["matched"]}'; Error = 'unsupported value' }
        @{ Text = '{"schemaVersion":1'; Error = 'invalid JSON' }
        @{ Text = '[{"schemaVersion":1,"synthetic":true}]'; Error = 'one version 1 synthetic case' }
    )
    foreach ($case in $invalid) {
        Set-Content -LiteralPath $tempFile -Value $case.Text -Encoding UTF8
        $failure = $null
        try { & $helper -Path $tempFile | Out-Null } catch { $failure = $_.Exception.Message }
        if ($null -eq $failure -or $failure -notlike "*$($case.Error)*") {
            throw "The helper must reject invalid input with an error containing '$($case.Error)'."
        }
    }
    Write-Host 'PASS invalid input rejection'
} finally {
    if (Test-Path -LiteralPath $tempFile) { Remove-Item -LiteralPath $tempFile }
}
