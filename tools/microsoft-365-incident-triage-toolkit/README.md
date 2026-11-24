# Microsoft 365 Incident Triage Toolkit

Version 1.0.0. A read-only, interactive service-health collector for the Microsoft Graph Global environment. Tested offline on PowerShell 7.6.5 with synthetic fixtures and a mocked Graph module. Live tenant integration has not been tested.

## Contents

- `Export-M365IncidentTriage.ps1`: command-line entry point.
- `M365IncidentTriage.psm1`: context checks, collection, selection, and report formatting.
- `demo-snapshot.json`: fixed synthetic API responses, dated 2026-09-14.
- `samples/report.md` and `samples/evidence.json`: generated synthetic output.
- `escalation-template.md`: editable handoff checklist.
- `tests/Test-M365IncidentTriage.ps1`: dependency-free offline regression tests.

## Try the offline demo

Use PowerShell 7.5 or later (`pwsh`), not Windows PowerShell 5.1. Extract the complete ZIP and open PowerShell in that directory. Review downloaded scripts before running them; follow your organization's script-signing/execution policy.

```powershell
$incident = @{
    IncidentId = 'DEMO-INC-001'
    Symptom = 'Outlook on the web loads slowly for a fictional pilot group.'
    Impact = 'Six fictional users; email response work delayed.'
    FirstObservedUtc = '2026-09-14T16:00:00Z'
}
./Export-M365IncidentTriage.ps1 -Demo @incident
```

Demo mode needs no Microsoft module, account, or network. It uses a fixed snapshot time of `2026-09-14T16:30:00Z`, so use the example timestamp. Every run creates a new directory under `$HOME/m365-triage`, even when the incident ID is reused. `-OutputRoot` overrides that location. Read `report.md`; use `evidence.json` for structured evidence. Neither file contains credentials. Real reports do contain your tenant ID, incident text, and selected service-health data and are not automatically anonymized.

## Connect and collect live data

The tenant must approve the delegated `ServiceHealth.Read.All` permission, which requires administrator consent. Use your organization's approved Graph application/account. The examples use the standard Graph PowerShell application; no app-only, scheduled, or sovereign-cloud mode is implemented.

If needed, install the authentication module from your approved source. For an organization that permits PowerShell Gallery:

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Repository PSGallery
```

Connect in a new PowerShell process and collect:

```powershell
Import-Module Microsoft.Graph.Authentication
$tenantId = Read-Host 'Tenant ID (GUID)'
$connection = @{
    TenantId = $tenantId
    Scopes = 'ServiceHealth.Read.All'
    ContextScope = 'Process'
}
Connect-MgGraph @connection -NoWelcome
Get-MgContext | Select-Object TenantId, AuthType, Environment, Scopes

$incident = @{
    IncidentId = Read-Host 'Incident ID (letters, digits, hyphens, underscores; up to 60 characters)'
    Symptom = Read-Host 'Observed symptom'
    Impact = Read-Host 'Confirmed business impact and affected scope'
    FirstObservedUtc = Read-Host 'First observed UTC (YYYY-MM-DDTHH:mm:ssZ)'
}
try {
    ./Export-M365IncidentTriage.ps1 -TenantId $tenantId @incident -LookBackHours 24
} finally {
    Disconnect-MgGraph
}
```

The collector itself does not connect or disconnect your session. It validates tenant ID, delegated authentication, Global environment, and the required scope before issuing GET requests. It does not require or enforce that the session has *only* that scope; use a fresh process and review the context. It neither installs modules nor changes tenant settings.

## Collection and failure behavior

Only these v1.0 collections are requested:

- `/admin/serviceAnnouncement/healthOverviews`: ID, service, status.
- `/admin/serviceAnnouncement/issues`: ID, title, service, status, classification, start/end/update times, resolution flag, impact description.

The collector follows `@odata.nextLink` unchanged, checks the scheme/host/port/path, rejects loops, and stops after 100 pages per collection. The SDK supplies its standard retry behavior; no additional retry loop is layered on top. A final request failure produces an incomplete collection.

JSON retains the selected properties from all successfully validated pages, including older resolved issues. Report candidates are unresolved issues **or** issues last modified on/after `FirstObservedUtc - LookBackHours`. This is a local selection rule, not a historical API query, root-cause match, or service filter. It cannot recover records the API no longer returns. No issue posts, sign-in logs, mailbox data, user inventory, or configuration are collected.

`CollectionStatus: Complete` means both collections finished. `Incomplete` means at least one did not; review each collection's `Status`, `Pages`, `FailureReason`, and retained items. Available evidence is written before a terminating error is raised. A `pwsh -File` invocation returns nonzero for incomplete collection. Invalid input, context, or local write failures also terminate and may produce no complete bundle.

Failure reasons: `RequestFailed` (check authentication, consent, connectivity, or throttling); `UnsafeContinuation`, `RepeatedContinuation`, `PageLimit` (collection stopped); `InvalidResponse`, `InvalidItem` (unexpected API data). Raw HTTP error bodies are deliberately excluded. Investigate a request failure in the approved administrative environment instead of pasting raw diagnostics into a public report.

Service status strings are retained as reported. A complete empty collection or zero candidates is not proof of health. Compare candidates against symptom, time, service, and affected scope; check the current admin-center advisory before citing it.

## Run the offline tests

```powershell
./tests/Test-M365IncidentTriage.ps1
```

The tests exercise pagination, partial failures, response validation, tenant/scope/cloud checks, selection, escaping, repeat-run preservation, and the live entry point using a local fake Graph module. Test files remain in the printed temporary directory for inspection. No real tenant is contacted. Real authentication, consent, tenant-specific permissions, and live SDK/API behavior require a separate tenant smoke test before operational adoption.

Article: https://dleontev.com/blog/building-a-microsoft-365-incident-triage-toolkit-with-powershell

API references: [health overviews](https://learn.microsoft.com/en-us/graph/api/serviceannouncement-list-healthoverviews?view=graph-rest-1.0), [issues](https://learn.microsoft.com/en-us/graph/api/serviceannouncement-list-issues?view=graph-rest-1.0), [authentication](https://learn.microsoft.com/en-us/powershell/microsoftgraph/authentication-commands?view=graph-powershell-1.0), [paging](https://learn.microsoft.com/en-us/graph/paging), [throttling](https://learn.microsoft.com/en-us/graph/throttling).
