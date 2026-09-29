---
title: Microsoft 365 Support Operations Toolkit
order: 4
status: In progress
tools: [Microsoft 365, PowerShell, Support Engineering]
description: A read-only Microsoft 365 incident triage collector with a walkthrough, synthetic examples, offline tests, and an escalation template.
article: 2026-09-15-building-a-microsoft-365-incident-triage-toolkit-with-powershell
permalink: /projects/microsoft-365-support-operations-toolkit/
---

# Microsoft 365 Support Operations Toolkit

**Status:** In progress — first toolkit available

This project collects reusable support-engineering resources for Microsoft 365 operations. The first release captures incident context and Microsoft Graph service-health data, then generates a consistent escalation report.

## Available now

- [Building a Microsoft 365 Incident Triage Toolkit with PowerShell]({% post_url 2026-09-15-building-a-microsoft-365-incident-triage-toolkit-with-powershell %})
- [Download the toolkit, synthetic examples, tests, and escalation template]({{ '/assets/downloads/microsoft-365-incident-triage-toolkit.zip' | relative_url }})
- [Browse the PowerShell source](https://github.com/dleontev/dleontev.github.io/tree/main/tools/microsoft-365-incident-triage-toolkit)

Version 1.0 uses read-only Graph requests and delegated authentication in the Global environment. Offline tests use synthetic data and a mocked Graph connection; live tenant integration has not been tested.

## Further work

- Workload-specific evidence collectors and runbooks
- Stakeholder update templates
- Troubleshooting runbook structure
- Safe PowerShell and Microsoft Graph examples
- Verification, rollback, and closure checklists

Published examples contain synthetic data. Real output should remain in an approved incident location and be reviewed before sharing. Future collectors will keep permissions and failure behavior explicit, with remediation handled through separate reviewed procedures.
