---
title: 'Building a Microsoft 365 Incident Triage Toolkit with PowerShell'
description: 'Build a read-only PowerShell toolkit that captures Microsoft 365 service health, records incident context, and generates a consistent escalation report.'
tags: [Microsoft 365, PowerShell, Microsoft Graph, IT Operations]
related_project: /projects/microsoft-365-support-operations-toolkit/
related_posts:
  - /2026/08/27/microsoft-365-service-ownership-framework
  - /2026/08/01/entra-sign-in-troubleshooting-framework
---

A user reports that Outlook is slow. A second ticket mentions Teams. Someone asks whether Microsoft has an incident open, while another person starts checking the network.

Before deciding what to change, the response needs a shared starting point: the observed problem, its business impact, the relevant service-health information, and the evidence already collected.

PowerShell can make that starting point repeatable.

This walkthrough builds a small toolkit that records incident details, reads Microsoft 365 service health through Microsoft Graph, and produces a Markdown handoff report with supporting JSON. The collector makes no tenant configuration changes.

The complete implementation includes an offline demo, synthetic sample output, an escalation template, and regression tests. **The code has been tested offline with synthetic data and mocked Graph requests; live tenant integration has not been tested.** Treat the first tenant run as a validation exercise before adopting it in an operational runbook.

[Download the complete toolkit ZIP]({{ '/assets/downloads/microsoft-365-incident-triage-toolkit.zip' | relative_url }}) · [Browse the source and tests](https://github.com/dleontev/dleontev.github.io/tree/main/tools/microsoft-365-incident-triage-toolkit)

<details class="article-toc" markdown="1">
<summary>On this page</summary>
<nav aria-label="On this page" markdown="1">

* Contents
{:toc}
</nav>
</details>

## Start with a useful triage boundary

The first version should answer a few specific questions:

- What action is failing, when was it first observed, and who is affected?
- What service-health information does Microsoft currently expose for this tenant?
- Which advisories deserve comparison with the reported symptoms?
- Did evidence collection finish, and what does the next responder still need?

That leads to a deliberately small data model.

| Input or collection | What it contributes |
| --- | --- |
| Incident ID, symptom, impact, first-observed time | Operator-supplied context |
| Service health overviews | Reported status for subscribed services |
| Service-health issues | Advisory IDs, descriptions, status, and timestamps |
| Collection results | Completion state, pages received, and failure reasons |
| Handoff fields | Reproduction, checks, owner, escalation request, next update |

Microsoft Graph exposes the overview through `GET /admin/serviceAnnouncement/healthOverviews` and issue details through `GET /admin/serviceAnnouncement/issues`. Both support the `ServiceHealth.Read.All` permission. This implementation uses their v1.0 endpoints. [Health overview API](https://learn.microsoft.com/en-us/graph/api/serviceannouncement-list-healthoverviews?view=graph-rest-1.0), [service-health issues API](https://learn.microsoft.com/en-us/graph/api/serviceannouncement-list-issues?view=graph-rest-1.0).

User inventories, sign-in logs, mailbox contents, and tenant configuration are outside this version's scope. Those collections have different permission and evidence-handling requirements. Keeping them separate also makes the first report easier to review.

## Try the toolkit without a tenant

Extract the ZIP and open **PowerShell 7.5 or later** in the extracted directory. The offline checks were run with PowerShell 7.6.5. Windows PowerShell 5.1 is not supported.

The package contains:

```text
Export-M365IncidentTriage.ps1
M365IncidentTriage.psm1
demo-snapshot.json
escalation-template.md
README.md
samples/
  evidence.json
  report.md
tests/
  Test-M365IncidentTriage.ps1
```

Review the scripts, then run the synthetic example:

```powershell
$incident = @{
    IncidentId = 'DEMO-INC-001'
    Symptom = 'Outlook on the web loads slowly for a fictional pilot group.'
    Impact = 'Six fictional users; email response work delayed.'
    FirstObservedUtc = '2026-09-14T16:00:00Z'
}

./Export-M365IncidentTriage.ps1 -Demo @incident
```

Demo mode makes no network requests and needs no Microsoft module or account. It uses a fixed snapshot from `2026-09-14T16:30:00Z`, so keep the example first-observed time when reproducing the sample.

The command returns its collection status and output directory. Each run creates a new folder under `$HOME/m365-triage`; use `-OutputRoot` to choose an approved location. Repeating the same incident ID preserves the earlier evidence.

Open `report.md` for the readable handoff and `evidence.json` for the structured snapshot. The packaged `samples` folder shows the same synthetic scenario without requiring execution.

## Establish the Graph connection explicitly

For live collection, use an organizational account and a tenant-approved delegated `ServiceHealth.Read.All` permission. Microsoft lists this permission as requiring administrator consent. Arrange that consent through the organization's normal process before an incident. [Microsoft Graph permissions reference](https://learn.microsoft.com/en-us/graph/permissions-reference#servicehealthreadall).

Only the authentication module is required. If your organization permits installation from PowerShell Gallery:

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Repository PSGallery
```

Use a fresh PowerShell process and connect to the intended tenant:

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
```

`ContextScope Process` confines the authentication context to the current PowerShell process. Review the returned tenant and scopes before collecting evidence. The collector checks for the required scope; it does not remove additional permissions from an existing session. [Graph PowerShell authentication](https://learn.microsoft.com/en-us/powershell/microsoftgraph/authentication-commands?view=graph-powershell-1.0).

This version supports delegated authentication in the **Global** Graph environment. It rejects a different tenant, app-only authentication, a different cloud environment, or a missing required scope before collection. Supporting another environment requires an explicit implementation and validation of its endpoints and connection settings.

The collector itself does not sign in, install modules, or disconnect a session someone else may be using. The operator controls that lifecycle.

## Collect service health through Microsoft Graph

The module starts with one request per collection and follows additional pages as needed. It requests selected properties to keep the output focused; issue discussion posts and their HTML content are excluded.

The transport is small enough to inspect directly:

```powershell
$request = {
    param($uri)
    Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType Hashtable -ErrorAction Stop
}

$health = Read-TriageCollection -Resource healthOverviews -Request $request
$issues = Read-TriageCollection -Resource issues -Request $request
```

These functions are provided by `M365IncidentTriage.psm1`, which the entry script imports. The explicit `GET` is the only HTTP method used by the collector. `Invoke-MgGraphRequest` supplies the authenticated Graph transport. [Command reference](https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.authentication/invoke-mggraphrequest?view=graph-powershell-1.0).

Pagination matters even when a test tenant returns only a few rows. Graph returns an `@odata.nextLink` when more results are available. Follow that URL until no continuation remains; an empty page alone does not end collection. [Microsoft Graph paging](https://learn.microsoft.com/en-us/graph/paging).

The implementation also checks that each continuation stays on HTTPS, the expected Graph host, and the same collection path. Repeated links or more than 100 pages stop that collection and mark it incomplete.

The Graph SDK provides retry handling for throttled requests. This toolkit adds no second retry loop; a request that still fails is recorded as a collection failure. Repeatedly launching new collectors during throttling would add traffic rather than resolve it. [Microsoft Graph throttling guidance](https://learn.microsoft.com/en-us/graph/throttling).

## Keep collection status separate from service status

A report containing no advisories can mean several things: the collection succeeded with no matching records, a request failed, the chosen time window excluded older updates, or Microsoft has not published a matching issue.

The output needs to preserve those differences.

Each collection records its completion state, successfully validated pages, retained rows, and a failure reason. A failure on a later page preserves the earlier pages. If either collection is incomplete, the script writes the available evidence and then raises a terminating error. Running it through `pwsh -File` therefore returns a nonzero exit code.

| Result | Interpretation |
| --- | --- |
| Complete collection | Both API collections finished successfully |
| Incomplete collection | At least one collection failed or stopped early |
| No candidate issues | No collected rows met the report's selection rule |
| Reported service degradation | Microsoft reported a status that needs investigation |

**Complete describes evidence collection, not service health.** Likewise, a reported advisory is a candidate for correlation; it does not establish the cause of a user's problem.

If collection fails, inspect `FailureReason`. `RequestFailed` calls for checking access, consent, connectivity, or throttling. `InvalidResponse` or `InvalidItem` means the returned data did not meet the collector's expectations. Continuation and page-limit failures mean the result set was deliberately left incomplete. Raw HTTP error bodies are excluded from the handoff bundle.

Invalid input or connection context fails before API collection. Local file-write errors also terminate; check that both output files exist before treating a run as usable evidence.

## Choose issues for review without claiming a match

The JSON retains the selected fields from every successfully collected issue. The report narrows that set to:

```text
Unresolved issues
OR
Issues last modified on/after FirstObservedUtc minus LookBackHours
```

The default look-back is 24 hours. An unresolved issue remains a candidate even if its last update is older. A recently resolved issue can also be useful when investigating something users experienced earlier.

This is a local selection rule over currently available API results. It is not a historical query, and it cannot recover issues the API no longer returns. It also does not filter by service or automatically compare symptoms.

In the synthetic example, the report includes `DEMO-EX-001`, an unresolved Exchange issue, and `DEMO-TM-002`, a recently updated resolved Teams issue. The older resolved `DEMO-SP-003` remains in JSON but falls outside the report window. These are invented identifiers, not real Microsoft incidents.

The sample's collection results look like this:

| Collection | Result | Pages | Retained items |
| --- | --- | --- | --- |
| HealthOverviews | Complete | 1 | 3 |
| Issues | Complete | 1 | 3 |

The report contains two candidate issues, while JSON retains all three collected issues. That difference follows the selection rule and does not indicate missing evidence.

For each candidate, compare the service, failing action, start time, affected population, and current advisory details. An unrelated Teams advisory should not explain an Outlook symptom merely because both appear in the report.

## Run a live collection and complete the handoff

After connecting, enter the actual incident details. Timestamps must use the explicit UTC form shown by the prompt:

```powershell
$incident = @{
    IncidentId = Read-Host 'Incident ID'
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

Use letters, digits, hyphens, and underscores for the incident ID, up to 60 characters. Record an observed first-failure time where possible; ticket creation time may be later.

The generated report already includes the incident context, snapshot timestamps, collection results, service statuses, and candidate issue details. Its final section leaves explicit fields for the work automation cannot establish:

- Reproduction steps and an unaffected comparison.
- Checks performed and their results.
- Whether an advisory actually matches the symptom and timeline.
- Workaround, changes made, and verification results.
- The requested escalation action, owner, and next update time.

The separate `escalation-template.md` provides more room for that handoff. A useful request might be: “Please investigate the mailbox-access failures reproduced at the recorded UTC times; confirm whether the candidate advisory's scope includes this behavior.” It should identify what the receiving team needs to decide or investigate.

Review both output files before attaching them. The real bundle includes the tenant ID, operator-entered incident details, and service-health text; it is not automatically anonymized. Prefer references to approved logs over copying personal information into free-text fields. The collector creates files locally and does not send an escalation message.

## Verify the toolkit and extend it deliberately

Run the included offline checks from the toolkit directory:

```powershell
./tests/Test-M365IncidentTriage.ps1
```

The 15 checks cover pagination through an empty page, partial failures, invalid continuations, loop limits, malformed responses, issue selection, context validation, report escaping, repeated runs, timestamp validation, and the live entry point with a fake Graph module. They also verify that the transport uses GET requests only.

Those tests validate the collector's local behavior. They do not validate real sign-in, administrator consent, tenant-specific access, or the live SDK/API combination. The JSON records the PowerShell and Graph authentication module versions to make a tenant smoke test reproducible.

Before operational adoption, run it with an approved account, compare the resulting snapshot with the Microsoft 365 admin center, and confirm that another responder can understand the report. A successful command is only part of that check.

Useful extensions include a separate Entra sign-in evidence collector, a workload-specific runbook, or a stakeholder-update template. Each should have its own permissions, evidence boundary, and failure behavior. Keep remediation behind a separate, reviewed procedure.

This is the first implementation in the [Microsoft 365 Support Operations Toolkit]({{ '/projects/microsoft-365-support-operations-toolkit/' | relative_url }}). It applies the repeatable support practices from [the service ownership framework]({% post_url 2026-08-27-microsoft-365-service-ownership-framework %}); when identity evidence points toward an access problem, [the Entra sign-in troubleshooting framework]({% post_url 2026-08-01-entra-sign-in-troubleshooting-framework %}) provides a next investigation path.

The useful outcome is a handoff another administrator can act on: what failed, what is affected, which evidence is available, what remains uncertain, and who owns the next step.
