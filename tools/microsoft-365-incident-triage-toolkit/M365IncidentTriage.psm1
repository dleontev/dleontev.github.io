#requires -Version 7.5
Set-StrictMode -Version Latest

function Assert-TriageContext {
    param($Context, [guid]$TenantId)
    if (-not $Context -or $Context.AuthType -ne 'Delegated' -or
        $Context.Environment -ne 'Global' -or
        [string]$Context.TenantId -ne $TenantId.ToString() -or
        @($Context.Scopes) -notcontains 'ServiceHealth.Read.All') {
        throw 'Connect to the requested tenant in Global with delegated ServiceHealth.Read.All first.'
    }
}

function Read-TriageCollection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('healthOverviews', 'issues')][string]$Resource,
        [Parameter(Mandatory)][scriptblock]$Request,
        [ValidateRange(1, 100)][int]$MaxPages = 100
    )
    $path = "/v1.0/admin/serviceAnnouncement/$Resource"
    $fields = if ($Resource -eq 'healthOverviews') {
        @('id', 'service', 'status')
    } else {
        @('id', 'title', 'service', 'status', 'classification', 'startDateTime',
            'endDateTime', 'lastModifiedDateTime', 'isResolved', 'impactDescription')
    }
    $next = 'https://graph.microsoft.com' + $path + '?$select=' + ($fields -join ',')
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $items = [System.Collections.Generic.List[object]]::new()
    $pages = 0
    $stage = 'RequestFailed'
    try {
        while ($next) {
            $stage = 'UnsafeContinuation'
            $uri = [uri]$next
            if (-not $uri.IsAbsoluteUri -or $uri.Scheme -ne 'https' -or
                $uri.Host -ne 'graph.microsoft.com' -or $uri.Port -ne 443 -or
                $uri.UserInfo -or $uri.Fragment -or $uri.AbsolutePath -cne $path) {
                throw 'Continuation must stay on the same Graph collection.'
            }
            $stage = 'RepeatedContinuation'
            if (-not $seen.Add($next)) { throw 'Repeated continuation.' }
            $stage = 'PageLimit'
            if ($pages -ge $MaxPages) { throw 'Page limit reached.' }
            $stage = 'RequestFailed'
            $page = & $Request $next
            $stage = 'InvalidResponse'
            if ($page -isnot [System.Collections.IDictionary] -or
                -not $page.Contains('value') -or $page.value -isnot [array]) {
                throw 'Expected an object containing a value array.'
            }
            # Validate a whole page before retaining it; never count a malformed page as complete.
            $pageItems = [System.Collections.Generic.List[object]]::new()
            foreach ($item in $page.value) {
                $stage = 'InvalidItem'
                if ($item -isnot [System.Collections.IDictionary]) { throw 'Expected an object.' }
                foreach ($required in @('id', 'service', 'status')) {
                    if ([string]::IsNullOrWhiteSpace([string]$item[$required])) {
                        throw 'Missing a required property.'
                    }
                }
                if ($Resource -eq 'issues') {
                    if ($item.isResolved -isnot [bool]) { throw 'Missing resolution state.' }
                    foreach ($dateField in @('startDateTime', 'lastModifiedDateTime')) {
                        if ([string]::IsNullOrWhiteSpace([string]$item[$dateField])) { throw 'Missing date.' }
                        $null = [datetimeoffset]::Parse([string]$item[$dateField], [cultureinfo]::InvariantCulture)
                    }
                }
                $selected = [ordered]@{}
                foreach ($field in $fields) { $selected[$field] = $item[$field] }
                $pageItems.Add($selected)
            }
            foreach ($item in $pageItems) { $items.Add($item) }
            $pages++
            $stage = 'InvalidResponse'
            $continuation = $page['@odata.nextLink']
            if ($null -ne $continuation -and
                ($continuation -isnot [string] -or [string]::IsNullOrWhiteSpace($continuation))) {
                throw 'Invalid continuation value.'
            }
            $next = [string]$continuation
        }
        return [ordered]@{ Status = 'Complete'; Pages = $pages; FailureReason = $null; Items = $items.ToArray() }
    } catch {
        # Do not copy HTTP response bodies, tokens, or request URLs into an escalation bundle.
        return [ordered]@{ Status = 'Incomplete'; Pages = $pages; FailureReason = $stage; Items = $items.ToArray() }
    }
}

function Select-TriageIssue {
    param([AllowEmptyCollection()][object[]]$Issues, [datetimeoffset]$SinceUtc)
    foreach ($issue in $Issues) {
        if (-not $issue.isResolved -or
            [datetimeoffset]::Parse([string]$issue.lastModifiedDateTime, [cultureinfo]::InvariantCulture) -ge $SinceUtc) {
            $issue
        }
    }
}

function ConvertTo-TriageText {
    param([AllowNull()][object]$Value)
    # Numeric entities prevent operator/API text from introducing Markdown or HTML structure.
    $text = ([string]$Value -replace '[\r\n\t]+', ' ').Trim()
    [regex]::Replace($text, '[&<>"''`*_|\[\]\\]', {
        param($match)
        '&#' + [int][char]$match.Value + ';'
    })
}

function ConvertTo-TriageReport {
    param([System.Collections.IDictionary]$Evidence)
    $e = $Evidence
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# Microsoft 365 incident triage')
    $lines.Add('')
    if ($e.Mode -eq 'Demo') { $lines.Add('**SYNTHETIC DEMO — no tenant data or live requests.**'); $lines.Add('') }
    $lines.Add('Collection: **' + $e.CollectionStatus + '**. This is collection status, not service health.')
    $lines.Add('')
    foreach ($field in @('IncidentId', 'Symptom', 'Impact', 'FirstObservedUtc')) {
        $lines.Add('- ' + $field + ': ' + (ConvertTo-TriageText $e.Incident[$field]))
    }
    $lines.Add('- Tenant: ' + (ConvertTo-TriageText $e.TenantId))
    $lines.Add('- Snapshot started (UTC): ' + $e.StartedAtUtc)
    $lines.Add('- Snapshot finished (UTC): ' + $e.FinishedAtUtc)
    $lines.Add('- Issue selection: unresolved OR last modified on/after ' + $e.IssuesSinceUtc)
    $lines.Add('')
    $lines.Add('## Collection results')
    $lines.Add('')
    $lines.Add('| Collection | Result | Pages | Retained items | Failure reason |')
    $lines.Add('| --- | --- | --- | --- | --- |')
    foreach ($name in @('HealthOverviews', 'Issues')) {
        $c = $e.Collections[$name]
        $lines.Add("| $name | $($c.Status) | $($c.Pages) | $(@($c.Items).Count) | $($c.FailureReason) |")
    }
    $lines.Add('')
    $lines.Add('## Service health snapshot')
    $lines.Add('')
    $lines.Add('| Service | Reported status |')
    $lines.Add('| --- | --- |')
    foreach ($health in $e.Collections.HealthOverviews.Items) {
        $lines.Add('| ' + (ConvertTo-TriageText $health.service) + ' | ' + (ConvertTo-TriageText $health.status) + ' |')
    }
    if (-not @($e.Collections.HealthOverviews.Items).Count) { $lines.Add('| No rows collected; check collection results | Unknown |') }
    $lines.Add('')
    $lines.Add('## Issues to review')
    $lines.Add('')
    $lines.Add('These are candidates for manual review. Their presence does not establish the cause of this incident.')
    $lines.Add('')
    foreach ($issue in $e.CandidateIssues) {
        $lines.Add('### ' + (ConvertTo-TriageText $issue.id) + ': ' + (ConvertTo-TriageText $issue.title))
        $lines.Add('')
        foreach ($field in @('service', 'status', 'classification', 'isResolved', 'startDateTime', 'endDateTime', 'lastModifiedDateTime', 'impactDescription')) {
            $lines.Add('- ' + $field + ': ' + (ConvertTo-TriageText $issue[$field]))
        }
        $lines.Add('')
    }
    if (-not @($e.CandidateIssues).Count) {
        $lines.Add('No candidate issues in the collected rows. This does not establish that the service is healthy.')
        $lines.Add('')
    }
    $lines.Add('## Handoff — complete before escalating')
    $lines.Add('')
    $lines.Add('- Confirmed observations and reproduction steps: [complete]')
    $lines.Add('- Affected and unaffected users, clients, locations, and networks: [complete]')
    $lines.Add('- Candidate Microsoft issue and symptom/time match: [complete; correlation unconfirmed]')
    $lines.Add('- Checks performed, evidence references, and results: [complete]')
    $lines.Add('- Changes made and verification/rollback status: [complete; this collector changes no tenant settings]')
    $lines.Add('- Workaround and business impact: [complete]')
    $lines.Add('- Escalation request, owner, and next update (UTC): [complete]')
    $lines.Add('')
    $lines.Add('Review and redact this report and evidence.json before sharing; neither is automatically anonymized.')
    $lines -join "`n"
}

Export-ModuleMember -Function Assert-TriageContext, Read-TriageCollection, Select-TriageIssue, ConvertTo-TriageReport
