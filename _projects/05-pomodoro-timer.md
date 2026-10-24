---
title: "Pomodoro Timer: Controlled Releases on Azure"
order: 0
status: Deployed
tools: [Node.js 24 LTS, Express 5, GitHub Actions, Azure App Service, OIDC, Release verification]
description: "An Azure release case study: verified source artifacts, staging, owner approval, separate OIDC identities, slot promotion, and deployment troubleshooting."
permalink: /projects/pomodoro-timer/
demo_url: https://pomodoro.dleontev.com/
source_url: https://github.com/dleontev/pomodoro
last_modified_at: "2026-10-23"
---
# Pomodoro Timer: Controlled Releases on Azure

**Status:** Deployed · Personal project · Evidence reviewed October 23, 2026

A small timer became an opportunity to work through a larger operational question: how can I release a change, know what reached production, and recover an earlier version?

The first deployment connected a Node.js application to Azure App Service and a custom domain. The current release process adds staging, an explicit production approval, separate deployment identities, and checks that compare the served application with the prepared release.

## Project at a glance

| Area | What this project demonstrates |
| --- | --- |
| Problem | Release changes without sending an unverified package straight to the public app. |
| My contribution | Configured the hosting, repository connection, and custom DNS; approve production releases. Codex assisted with application implementation, release tooling, tests, and documentation. |
| Key decisions | Keep the app small; package a known commit; verify staging; approve and swap; verify production. |
| Recorded result | The reviewed release passed 70 Linux tests, completed staging checks, received owner approval, and passed production verification. |
| Current evidence | The public release marker matched commit `6f78f67` when checked on October 23. |

[Open the live timer](https://pomodoro.dleontev.com/) · [View the source](https://github.com/dleontev/pomodoro) · [Read the release guide](https://github.com/dleontev/pomodoro/blob/6f78f67ef67db690061a217ef31efd18bcecff30/docs/development-deployment.md)

<details class="article-toc" markdown="1">
<summary>On this page</summary>
<nav aria-label="On this page" markdown="1">

* Contents
{:toc}
</nav>
</details>

## Keep the application small

Node.js 24 LTS and Express 5 serve a vanilla HTML, CSS, and JavaScript frontend. Express is the only direct dependency. The browser owns the timer, preferences, and audio; the server serves public files and exposes `/health`. There is no database or account system.

The latest interface supports custom session lengths, optional session switching and automatic starts, separate ambient and notification audio, and recovery after a reload. The timer uses an absolute deadline to catch up after delayed callbacks. If a session is discovered more than five seconds late or expired on reload, it records completion once and waits for Start instead of racing through unseen cycles.

Timer state is per tab, while preferences persist in the browser. That keeps hosting straightforward and makes the application useful for testing deployment changes.

{% include elements/figure.html image="/assets/projects/pomodoro/pomodoro-desktop-2026-10-23.jpg" width="1425" height="1341" loading="eager" alt="The live Pomodoro timer with focus and break modes, optional session switching and automatic starts, separate ambient and notification sound controls, and session-length settings." caption="The live interface on October 23, 2026, shown with saved session and audio preferences." %}

## Promote a verified release through staging

The release workflow now owns the path from `main` to production. Development changes go through pull requests and CI; a change on `main` starts a release with three dependent jobs: **prepare**, **stage**, and **promote**.

The prepare job runs the locked dependency installation, syntax checks, Node tests, and a production-startup smoke check. It then packages only `server.js`, the package manifests, and `public/`. A generated manifest records the commit and SHA-256 checksum of each release file. Missing, changed, unlisted, and symbolic-link files are rejected.

The source artifact is retained for 90 days. App Service installs dependencies in staging, and promotion swaps the staged application into production without another application build.

{% include elements/figure.html image="/assets/projects/pomodoro/pomodoro-release-flow.svg" width="650" height="1020" alt="Release flow: validate main, package the commit and checksums, publish to the dev staging slot using the publisher identity, verify staging, obtain owner approval, swap using the promoter identity, and verify both production hostnames." caption="The current release path. The same release moves through staging, approval, and production verification." %}

[Open the release diagram at full size]({{ '/assets/projects/pomodoro/pomodoro-release-flow.svg' | relative_url }}).

The existing Azure slot named `dev` serves as release staging. It shares the application's App Service plan; its name does not connect it to a GitHub development branch. The workflow checks the target slot, shared plan, and disabled automatic swapping before publishing.

A concurrency lock covers staging, the approval wait, and promotion. Another workflow run cannot replace the candidate while it awaits approval. The promote job also rechecks staging immediately before the swap, covering changes that may have happened outside that workflow.

[Azure deployment slots](https://learn.microsoft.com/en-us/azure/app-service/deploy-staging-slots) provide the staging and swap mechanism; [GitHub environment protection](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/control-deployments) supplies the approval gate. Slots require a supported App Service plan tier.

## Separate publishing from production promotion

The staging and production jobs authenticate through OIDC with separate environment identities. The workflow uses client, tenant, and subscription identifiers from environment variables, with no stored client secret or publish profile.

The repository defines two custom Azure roles:

| Role | Intended scope and responsibility |
| --- | --- |
| Staging publisher | Publish to the `dev` slot, with Reader access on the parent app for metadata checks. |
| Production promoter | Read the app and slot metadata and perform the slot swap, without direct publishing or configuration-write operations in its role definition. |

The staging role includes configuration-list and publishing-profile reads required by the deployment action. Those permissions can expose staging settings and deployment credentials, so keeping the assignment at the staging slot matters. OIDC removes the need to store a long-lived Azure deployment credential in GitHub; it still needs appropriately scoped Azure authorization.

This is a solo-maintainer project. I approve the production deployment after the staging checks; that is a release decision rather than an independent code review. The [successful release's approval record](https://github.com/dleontev/pomodoro/actions/runs/39685922391) shows that the production gate was used.

## Find the boundary behind a staging deployment failure

The move to staging exposed a useful distinction: Azure login and resource-metadata access could succeed while application publication still failed.

An [earlier staging run](https://github.com/dleontev/pomodoro/actions/runs/39536921924) reached the deployment action and failed with **Forbidden, HTTP 403**. Its preflight had already confirmed the slot and shared plan. An unauthenticated SCM probe returned 401, while an authenticated SCM read failed.

The investigation separated three checks:

1. **Authentication:** Did the OIDC login complete?
2. **Resource management:** Could the identity read the intended app and slot?
3. **Publication:** Could it access SCM/Kudu and publish to that slot?

The staging-role definition was refined to include the dev publishing-profile read and the `Microsoft.Web/sites/publish/action` operation alongside slot-specific publication. Microsoft documents that operation in its [Kudu access guidance](https://learn.microsoft.com/en-us/azure/app-service/resources-kudu#rbac-permissions-required-to-access-kudu).

In the final reviewed run, authenticated SCM reads succeeded, staging publication completed, and the served frontend matched the release. This supplied a stronger recovery check than a successful Azure login alone.

## Connect the custom domain and identify the public release

The Namecheap `pomodoro` CNAME routes the custom hostname to App Service. The separate `asuid.pomodoro` TXT record supplies Azure's domain-verification value. The public application is served over HTTPS at `pomodoro.dleontev.com`.

The release workflow checks both the default production hostname and the custom domain after the swap. For each, it verifies:

- `/health` returns HTTP 200 and `{"status":"ok"}`.
- `/release.json` identifies the expected application commit.
- Every packaged frontend file, including the page at `/`, matches its manifest checksum.

This distinguishes an available endpoint from the expected frontend release. It also makes a pending release visible: `main` may advance while production continues serving the previously approved commit.

On October 23, the release verifier was rerun against the retained artifact. The public health endpoint returned 200, the version marker matched `6f78f67ef67db690061a217ef31efd18bcecff30`, and all nine packaged frontend files matched their checksums.

## Prepare two recovery paths

Immediately after a swap, the previous production application remains in `dev`. Swapping the same slots back can restore it, provided another staging deployment has not overwritten it. Check the versions before that decision and verify the public application afterward.

For an older release, the workflow accepts a `rollback_run_id`. It checks that the selected run is a successful release from this repository's `main` history, downloads its retained source artifact, and verifies the package. The normal staging, approval, swap, and production checks then follow.

Artifact recovery depends on the 90-day retention window. Redeploying retained source runs dependency installation in staging again. If the artifact has expired, a reviewed revert can produce a new release from Git history. A failed production check fails the workflow; it does not trigger an automatic rollback.

## Reproduce the local checks

With Node.js 24 LTS and npm installed, these commands reproduce the reviewed source revision without Azure access:

```powershell
git clone https://github.com/dleontev/pomodoro.git
cd pomodoro
git checkout 6f78f67ef67db690061a217ef31efd18bcecff30
npm ci --ignore-scripts
npm run check
npm test
npm run smoke
```

The syntax check should finish without errors. Tests cover application behavior, storage and audio lifecycles, HTTP responses, artifact integrity, and release verification. Platform-specific process tests can skip on Windows. The smoke check starts the actual production command on a temporary port and verifies `/` and `/health`.

For Azure setup, promotion, and recovery commands, use the repository's [release guide](https://github.com/dleontev/pomodoro/blob/6f78f67ef67db690061a217ef31efd18bcecff30/docs/development-deployment.md).

## Verification and remaining limits

The [October 21 release](https://github.com/dleontev/pomodoro/actions/runs/39685922391) records all three jobs succeeding for `6f78f67`, with **70 tests passed, zero failures, and zero skips** on Linux.

| Area | Evidence and boundary |
| --- | --- |
| Release execution | Staging publication, owner approval, slot swap, and both production-hostname checks passed in the recorded run. |
| Live application | Health, release identity, and all nine frontend files matched the retained artifact when rechecked on October 23. |
| Application behavior | Node tests use DOM, storage, and Web Audio test doubles. Automated browser end-to-end and accessibility audits remain future work. |
| Azure access | Custom-role definitions and successful scoped operations are documented; effective inherited role assignments are not independently audited here. |
| Recovery | Rollback selection and package checks have automated tests. The reviewed release did not exercise a live rollback. |
| Availability | An HTTP health route and successful release checks do not establish continuous monitoring, load capacity, or an availability guarantee. |

The main improvement is the connection between a source revision, a staged candidate, a deliberate release decision, and the application visitors receive. Browser tests and a controlled rollback drill are the next useful additions.
