#Requires -Version 5.1
<#
.SYNOPSIS
Suggests a next check for a synthetic interactive sign-in case.

.PARAMETER Path
Path to a local version 1 sample JSON file from the Entra troubleshooting toolkit.

AI-assisted code
Purpose: Route synthetic sign-in evidence to the corresponding runbook section.
Prepared for review by: Dimitriy Leontev
Generated: 2026-11-06
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Path
)

if ($Path -match '^[\\/]{2}' -or $Path.Contains('::')) {
    throw 'Provide a local JSON file path.'
}
$file = Get-Item -LiteralPath $Path -ErrorAction Stop
if ($file -isnot [System.IO.FileInfo] -or $file.Extension -ine '.json') {
    throw 'Provide a local JSON file.'
}

$json = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 -ErrorAction Stop
if ($json -notmatch '^\s*\{') {
    throw 'Provide one version 1 synthetic case as a JSON object.'
}
try {
    $sample = ConvertFrom-Json -InputObject $json -ErrorAction Stop
} catch {
    throw 'The sample file contains invalid JSON.'
}

$allowedValues = [ordered] @{
    eventMatch         = 'matched', 'none', 'uncertain'
    signInResult       = 'failed', 'interrupted', 'succeeded'
    accountState       = 'enabled', 'disabled'
    authentication     = 'mfaIncomplete', 'mfaSatisfied', 'other'
    conditionalAccess  = 'enforcedFailure', 'enforcedSuccess', 'reportOnlyFailure', 'notApplied'
    failedControl      = 'compliantDevice', 'other'
    deviceCompliance   = 'compliant', 'noncompliant'
    applicationOutcome = 'denied', 'verified'
}
$evidence = @{}
foreach ($field in @('schemaVersion', 'synthetic') + @($allowedValues.Keys)) {
    $property = $sample.PSObject.Properties[$field]
    $evidence[$field] = $null
    if ($null -ne $property) { $evidence[$field] = $property.Value }
}
if (($evidence.schemaVersion -isnot [int] -and $evidence.schemaVersion -isnot [long]) -or
    $evidence.schemaVersion -ne 1 -or $evidence.synthetic -isnot [bool] -or !$evidence.synthetic) {
    throw 'The sample must have numeric schemaVersion 1 and synthetic set to true.'
}

$observed = @(
    foreach ($field in $allowedValues.Keys) {
        $value = $evidence[$field]
        if ($null -ne $value) {
            if ($value -isnot [string] -or $allowedValues[$field] -cnotcontains $value) {
                throw "The sample field '$field' has an unsupported value."
            }
            "$field=$value"
        }
    }
)

$route = 'review-evidence'
$gaps = @()
$notes = @()
if ($evidence.conditionalAccess -ceq 'reportOnlyFailure') {
    $notes += 'The report-only result shows potential policy impact.'
}

if ($evidence.eventMatch -cne 'matched') {
    $route = 'match-event'
    if (!$evidence.eventMatch) { $gaps += 'eventMatch' }
} elseif (!$evidence.signInResult) {
    $gaps += 'signInResult'
} else {
    $failureSignals = @(
        if ($evidence.accountState -ceq 'disabled') { 'account' }
        if ($evidence.authentication -ceq 'mfaIncomplete') { 'authentication' }
        if ($evidence.conditionalAccess -ceq 'enforcedFailure') { 'conditional-access' }
    )

    if ($failureSignals.Count -gt 1 -or
        ($evidence.signInResult -ceq 'succeeded' -and $failureSignals.Count -gt 0)) {
        $notes += 'Several recorded signals need to be reconciled against the matched event.'
    } elseif ($evidence.signInResult -ceq 'succeeded') {
        if ($evidence.applicationOutcome -ceq 'denied') {
            $route = 'application'
        } else {
            $route = 'verify-task'
            if (!$evidence.applicationOutcome) { $gaps += 'applicationOutcome' }
        }
    } elseif ($failureSignals.Count -eq 1) {
        $route = $failureSignals[0]
        if ($route -eq 'conditional-access') {
            if (!$evidence.failedControl) { $gaps += 'failedControl' }
            if ($evidence.failedControl -ceq 'compliantDevice') {
                if (!$evidence.deviceCompliance) { $gaps += 'deviceCompliance' }
                if ($evidence.deviceCompliance -ceq 'noncompliant') { $route = 'device-compliance' }
            }
        }
    } else {
        $gaps += @('accountState', 'authentication', 'conditionalAccess') |
            Where-Object { $null -eq $evidence[$_] }
    }
}

$nextChecks = @{
    'match-event'        = 'Check the tenant, sign-in type, and UTC window. Capture a fresh attempt if needed.'
    'review-evidence'    = 'Compare the status, authentication steps, and enforced policy results for the matched event.'
    'account'            = 'Confirm the account state and intended access with the identity owner.'
    'authentication'     = 'Review the incomplete MFA step and guide the user through the approved recovery path.'
    'conditional-access' = 'Inspect the enforced policy, failed control, and sign-in context with the policy owner.'
    'device-compliance'  = 'Ask endpoint support to verify the failed compliance requirement on the affected device.'
    'application'        = 'Confirm the requested resource and check application authorization and logs with its owner.'
    'verify-task'        = 'Confirm the user can complete the original task in the affected context.'
}

[pscustomobject] @{
    Route        = $route
    NextCheck    = $nextChecks[$route]
    Observed     = $observed -join ', '
    EvidenceGaps = $gaps -join ', '
    Note         = $notes -join ' '
}
