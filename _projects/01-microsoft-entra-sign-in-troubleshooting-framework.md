---
title: Microsoft Entra Sign-In Troubleshooting Framework
order: 1
status: Published
tools: [Microsoft Entra, Conditional Access, PowerShell]
article: /blog/entra-sign-in-troubleshooting-framework
description: A troubleshooting toolkit for interactive Microsoft Entra sign-ins, with a triage checklist, decision tree, handoff forms, and an offline PowerShell helper.
permalink: /projects/entra-sign-in-troubleshooting-framework/
---

# Microsoft Entra Sign-In Troubleshooting Framework

**Published · v1.0**

Use this toolkit to take an interactive sign-in report from the first user conversation to an evidence-based next check, a handoff, or a verified recovery. The examples are synthetic. Validation for v1 uses the included sample records and runs offline.

{% assign kit_path = '/assets/projects/entra-sign-in/' | relative_url %}

<details class="article-toc" markdown="1">
<summary>On this page</summary>
<nav aria-label="On this page" markdown="1">

- [Triage checklist](#triage-checklist)
- [Decision tree](#decision-tree)
- [Worked device case](#worked-case--a-device-requirement-blocks-access)
- [Run the PowerShell helper](#run-the-offline-powershell-helper)
- [More synthetic cases](#more-synthetic-cases)

</nav>
</details>

## Triage checklist

1. Ask what the user tried to do, who is affected, and when it happened. Capture the app or resource, client, visible error, and any request or correlation ID. Record the time zone and convert the time to UTC for the handoff.
2. In the Microsoft Entra admin center, open **Entra ID → Monitoring & health → Sign-in logs**. Microsoft lists Reports Reader as the least privileged role for activity logs. Work within the access assigned for the investigation. [Microsoft sign-in troubleshooting](https://learn.microsoft.com/en-us/entra/identity/monitoring-health/howto-troubleshoot-sign-in-errors)
3. Match the interactive event to the user, time, app and resource, and identifiers when available. A correlation ID can group activity from a session. Confirm the other details before choosing the event. [Microsoft sign-in log details](https://learn.microsoft.com/en-us/entra/identity/monitoring-health/concept-sign-in-log-activity-details)
4. Read the sign-in result, authentication steps, Conditional Access policy results, and relevant device information together. Use the decision tree to identify the next check and record who owns it.
5. After any approved remediation, confirm the original task in the affected context and record the new event and user outcome.

<a href="{{ kit_path }}triage-forms.txt" download>Download the checklist, Conditional Access worksheet, and escalation form (text)</a>.

## Decision tree

1. **Can you match the report to an event?** If the match is missing or uncertain, [match the event](#match-event).
2. **Did Entra record a successful sign-in for the requested resource?** If the app still denies access, [check the application](#application). If the app outcome is unclear, [verify the original task](#verify-task).
3. **Which evidence explains a failure or interruption?** Check [account state](#account), [authentication steps](#authentication), and [enforced policy results](#conditional-access). Follow [device compliance](#device-compliance) when an enforced control requires compliance and the matched event shows the device was noncompliant.
4. **Is the evidence incomplete or contradictory?** [Review the evidence](#review-evidence) before assigning a cause.

### Match event

Check the tenant, the UTC window, the sign-in type, and the requested resource. If the match remains unclear, capture a fresh attempt and ask for the error details. Keep the diagnosis open until you can connect the report to an event.

### Account

Confirm the account state and intended access with the identity owner. Record the evidence that connects the account state to the reported failure. Route any access change through the owner's approved process.

### Authentication

Read the authentication steps and result details to identify what was incomplete. Guide the user through the approved authentication recovery path and match the next attempt. An existing token claim can satisfy an MFA requirement. [Microsoft sign-in log details](https://learn.microsoft.com/en-us/entra/identity/monitoring-health/concept-sign-in-log-activity-details)

### Conditional Access

Use the worksheet to record each relevant policy, its mode and result, the required grant control, and the evidence used to evaluate it. Confirm whether the policy requires one or all selected controls and why it applied to the requested resource. A report-only failure shows potential impact. Base an enforcement finding on the enforced policy results. [Microsoft Conditional Access troubleshooting](https://learn.microsoft.com/en-us/entra/identity/conditional-access/troubleshoot-conditional-access) · [Report-only policy results](https://learn.microsoft.com/en-us/entra/identity/conditional-access/concept-conditional-access-report-only)

### Device compliance

Send the matched device evidence and failed requirement to endpoint support. Ask them to verify the affected device's compliance and identify the approved remediation. For recovery, capture a new sign-in and confirm the original task from the affected device after remediation.

### Application

Confirm the successful event covers the resource the user needed. Give the application owner the time, expected operation, and denial observed so they can check application authorization and logs.

### Verify task

Ask the user to repeat the operation that failed in the same context. Record the result and the related sign-in evidence before closing the ticket.

### Review evidence

Compare the sign-in result, authentication details, and enforced policy outcomes. Record missing or conflicting fields and ask the appropriate owner for evidence you cannot see. Include the unresolved question in the escalation.

## Worked case · A device requirement blocks access

**Synthetic ticket.** A user trying to open a report in Example Portal at 14:10 UTC received `AADSTS53000` after satisfying MFA. The matched interactive event shows that an enforced policy required a compliant device and that the device was noncompliant. [Microsoft Conditional Access error codes](https://learn.microsoft.com/en-us/entra/identity/conditional-access/troubleshoot-conditional-access#common-conditional-access-error-codes)

**Completed worksheet.** The requested resource is Example Portal. The example policy is enforced, its result is failure, and the failed control requires a compliant device. The authentication details show MFA was satisfied. The device evidence supports the next check with endpoint support. The underlying reason for the device's compliance state still needs investigation.

**Escalation.** One user cannot open the report from the affected device. Endpoint support owns the compliance check. The ticket records the matched event, time, failure code, and unmet control. After any approved remediation, the original reporter should retry opening the report from that device. The ticket remains open until the result is recorded.

> The sign-in reached the device check, and I’ve routed that result to endpoint support. Once they finish the check, I’ll ask you to retry opening the report from the same device.

## Run the offline PowerShell helper

Download the script and device example to the same directory. Review the script, then run the command from that directory in Windows PowerShell 5.1 or PowerShell 7 with your normal script approval process.

<a href="{{ kit_path }}Get-EntraSignInTriage.ps1" download>Download the PowerShell helper</a> · <a href="{{ kit_path }}examples/device-compliance.json" download>Download the synthetic device example</a>

```powershell
./Get-EntraSignInTriage.ps1 -Path ./device-compliance.json | Format-List
```

The device example returns `Route = device-compliance`. The helper summarizes the recorded evidence and gives a suggested next check, relevant gaps, and notes about ambiguous signals. The route points to a heading in the decision tree. The helper reads one local synthetic JSON case and performs analysis offline.

<details markdown="1">
<summary>Sample format and accepted values</summary>

Each JSON object requires numeric `schemaVersion` equal to `1` and Boolean `synthetic` equal to `true`. The samples are compact summaries based on observations. Omit a field or use `null` when the evidence is unavailable.

- `eventMatch` · `matched`, `none`, `uncertain`
- `signInResult` · `failed`, `interrupted`, `succeeded`
- `accountState` · `enabled`, `disabled`
- `authentication` · `mfaIncomplete`, `mfaSatisfied`, `other`
- `conditionalAccess` · `enforcedFailure`, `enforcedSuccess`, `reportOnlyFailure`, `notApplied`
- `failedControl` · `compliantDevice`, `other`
- `deviceCompliance` · `compliant`, `noncompliant`
- `applicationOutcome` · `denied`, `verified`

Record an enforced failure when the matched event shows one. Use `reportOnlyFailure` when that is the policy evidence available and no enforced result has been established. The helper refers cases with competing failure signals back to evidence review.

</details>

## More synthetic cases

Run these files with the same command, substituting the downloaded filename. The expected route is listed next to each case.

- <a href="{{ kit_path }}examples/mfa-incomplete.json" download>MFA interruption</a> → [authentication](#authentication)
- <a href="{{ kit_path }}examples/account-disabled.json" download>Disabled account</a> → [account](#account)
- <a href="{{ kit_path }}examples/application-denied.json" download>Application denial after a successful sign-in</a> → [application](#application)
- <a href="{{ kit_path }}examples/no-matching-event.json" download>No matching event</a> → [match event](#match-event)
- <a href="{{ kit_path }}examples/report-only.json" download>Report-only failure</a> → [review evidence](#review-evidence)
- <a href="{{ kit_path }}examples/missing-evidence.json" download>Missing sign-in result</a> → [review evidence](#review-evidence)
- <a href="{{ kit_path }}examples/policy-block.json" download>Enforced policy block</a> → [Conditional Access](#conditional-access)
- <a href="{{ kit_path }}examples/verify-task.json" download>Successful sign-in with no task outcome</a> → [verify task](#verify-task)

<p class="text-center">
<a class="btn btn-primary" href="{% post_url 2026-08-01-entra-sign-in-troubleshooting-framework %}">Read the companion article</a>
</p>
