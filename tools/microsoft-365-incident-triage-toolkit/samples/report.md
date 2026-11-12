# Microsoft 365 incident triage

**SYNTHETIC DEMO — no tenant data or live requests.**

Collection: **Complete**. This is collection status, not service health.

- IncidentId: DEMO-INC-001
- Symptom: Outlook on the web loads slowly for a fictional pilot group.
- Impact: Six fictional users; email response work delayed.
- FirstObservedUtc: 2026-09-14T16:00:00.0000000+00:00
- Tenant: SYNTHETIC — no tenant
- Snapshot started (UTC): 2026-09-14T16:30:00.0000000+00:00
- Snapshot finished (UTC): 2026-09-14T16:30:00.0000000+00:00
- Issue selection: unresolved OR last modified on/after 2026-09-13T16:00:00.0000000+00:00

## Collection results

| Collection | Result | Pages | Retained items | Failure reason |
| --- | --- | --- | --- | --- |
| HealthOverviews | Complete | 1 | 3 |  |
| Issues | Complete | 1 | 3 |  |

## Service health snapshot

| Service | Reported status |
| --- | --- |
| Exchange Online | ServiceDegradation |
| Microsoft Teams | ServiceOperational |
| SharePoint Online | ServiceOperational |

## Issues to review

These are candidates for manual review. Their presence does not establish the cause of this incident.

### DEMO-EX-001: Synthetic example: delayed mailbox access

- service: Exchange Online
- status: ServiceDegradation
- classification: incident
- isResolved: False
- startDateTime: 2026-09-14T15:45:00Z
- endDateTime: Not reported
- lastModifiedDateTime: 2026-09-14T16:20:00Z
- impactDescription: Fictional users may experience delayed mailbox access. This is not a real Microsoft advisory.

### DEMO-TM-002: Synthetic example: resolved meeting join delays

- service: Microsoft Teams
- status: ServiceRestored
- classification: advisory
- isResolved: True
- startDateTime: 2026-09-13T17:00:00Z
- endDateTime: 2026-09-13T18:00:00Z
- lastModifiedDateTime: 2026-09-13T18:15:00Z
- impactDescription: Fictional meeting join delays have ended; included to demonstrate recently updated resolved issues.

## Handoff — complete before escalating

- Confirmed observations and reproduction steps: [complete]
- Affected and unaffected users, clients, locations, and networks: [complete]
- Candidate Microsoft issue and symptom/time match: [complete; correlation unconfirmed]
- Checks performed, evidence references, and results: [complete]
- Changes made and verification/rollback status: [complete; this collector changes no tenant settings]
- Workaround and business impact: [complete]
- Escalation request, owner, and next update (UTC): [complete]

Review and redact this report and evidence.json before sharing; neither is automatically anonymized.
