---
layout: post
title: 'Where Did the Email Go? Troubleshooting Exchange Online with Message Trace'
description: 'Investigate a missing email with Exchange Online message trace, interpret delivery events, and follow the evidence into the mailbox or the next mail system.'
tags: [Microsoft 365, Exchange Online, Troubleshooting, PowerShell]
date: 2026-09-27
permalink: /blog/where-did-the-email-go-troubleshooting-exchange-online-with-message-trace
related_posts:
  - /2026/08/27/microsoft-365-service-ownership-framework
---

“The supplier sent it, but I never received it.”

The message might have failed before reaching Microsoft 365, been quarantined, reached another recipient, or landed in an unexpected folder.

Exchange Online message trace shows what happened as the message passed through the service. Start with that history, then follow the result into the mailbox or the next mail system.

Let's work through a sample case: Alex is waiting for a supplier's delivery schedule.

<details class="article-toc" markdown="1">
<summary>On this page</summary>
<nav aria-label="On this page" markdown="1">

* Contents
{:toc}
</nav>
</details>

## Start with one specific message

Start with enough detail to find the right message:

- The sender's email address and the exact intended recipient address.
- The approximate send time, including the time zone.
- The subject and whether the message was a new email, reply, or forward.
- The original Message-ID from the headers, if available.
- Any nondelivery report, including its diagnostic text.
- Whether other recipients received the same message.

Ask the sender for the original message's headers and copy the `Message-ID` value. If the headers aren't available, start with the sender, recipient, time, and subject.

For this example, the ticket contains:

| Field | Example value |
| --- | --- |
| Sender | `dispatch@example.net` |
| Recipient | `alex@example.com` |
| Subject | Updated delivery schedule |
| Reported send time | 24 September 2026, 09:14 PDT / 16:14 UTC |
| Message-ID | `<training-20260924-0914@example.net>` |
| User's observation | Message is not visible in the Inbox |

## Run a focused trace

In the [Exchange admin center](https://admin.exchange.microsoft.com), open **Mail flow → Message trace → Start a trace**.

1. Set **Senders** to `dispatch@example.net` and **Recipients** to `alex@example.com`.
2. Switch **Time range** to **Custom time range**. Select UTC and enter 24 September 2026, **16:00–16:30**.
3. Leave **Delivery status** at **All**. Under **Detailed search options**, enter the original **Message ID** if you have it, including its angle brackets.
4. Choose **Summary report** and select **Search**.

Open the row matching the recipient, subject, and time. Expand **More information** to check the Message ID, then **Message events** to read the delivery history. Each recipient has a separate result, so follow Alex's row for this investigation.

## Use the result to choose the next check

Read the status alongside the recipient's event details to decide where to look next.

| Trace result | Next check |
| --- | --- |
| Delivered | Confirm the destination and delivery details, then investigate mailbox visibility. |
| Failed | Capture the failure event and diagnostic response; compare them with the sender's nondelivery report. |
| Pending | Inspect the latest event and the reason delivery is being retried. |
| Getting status | Allow time for the trace to update, then refresh. |
| Quarantined | Review the matching item and detection reason in quarantine. |
| Expanded | Open the group members' results and follow the intended recipient's delivery events. |
| No matching result | Recheck the addresses, time window, and search filters. |

For a **Delivered** result, inspect the events and then search the destination mailbox. Rules and filtering can place mail outside the Inbox.

For external recipients, follow the handoff to the receiving system. Its logs are needed to investigate what happened after it accepted the message.

## Worked example: Delivered, but missing from the Inbox

Two events give us the starting point:

| Time, UTC | Event | What happened |
| --- | --- | --- |
| 16:14:08 | Receive | Microsoft 365 received the message. |
| 16:14:11 | Deliver | Delivery to Alex's mailbox was recorded. |

With delivery to Alex's mailbox recorded, the next checks happen in the mailbox:

1. **Open the destination mailbox in Outlook on the web with the user.** Confirm which mailbox receives mail for that address, including aliases or shared mailboxes. Compare what appears there with the desktop client.
2. **Search across folders.** Use the sender, subject, and date. Check Junk Email, Deleted Items, Archive, and user-created folders; remove view filters that could hide the result.
3. **Inspect Inbox rules under Settings → Mail → Rules.** Open an enabled rule matching the sender or subject. Check its action, destination folder, and exceptions.
4. **Test a likely rule.** Ask the sender for a new message that matches the rule's conditions, adding a unique subject marker such as `[trace-test-01]`. Check whether it arrives in the folder named by the rule.

In this scenario, Alex finds the original email in **Supplier updates**. An enabled rule moves mail from `dispatch@example.net` into that folder, and a test message from the same sender follows the same route.

Alex can now open the missing message. The trace led us to the mailbox; the search and test supplied the explanation. If Alex wants this sorting rule turned off, disable it in **Settings → Mail → Rules** and repeat the test. The expected result is a new message in the Inbox that Alex can open.

### Following up on a missing message

If the message appears on the web but not in desktop Outlook, investigate the desktop view and synchronization. If neither shows it after a folder search, use the recipient, Message-ID, and delivery time to investigate mailbox audit records or security events for a later move or removal. For example, zero-hour auto purge can act on a message after delivery.

## If the trace finds nothing

Before moving to another system's logs, check the search itself:

1. Recheck the tenant, recipient spelling, aliases, and time-zone conversion.
2. Widen the time window. Use the original send time, which may differ from the time the message was forwarded to the help desk.
3. Remove one uncertain filter at a time. Try the exact recipient and time window without the sender or subject constraint.
4. Allow for trace ingestion delay. Microsoft documents approximately five to ten minutes before a newly sent message appears.
5. Ask the sending administrator for the actual sending address and delivery evidence. Trace searches use the SMTP **MAIL FROM**, which can differ from the From address the user sees.

If the search is still empty, check the sending system or upstream gateway's logs. Ask its administrator for the recipient, timestamp with time zone, Message-ID, destination server, and SMTP response. Those logs can reveal a connection-stage rejection, such as an IP reputation block, that left no searchable trace.

## If the message was quarantined or failed

For a quarantined result, open [Microsoft Defender quarantine](https://security.microsoft.com/quarantine), filter by recipient and received date, and match the sender and subject. Open the item to check why it was held, which policy acted, and whether it has already been released. If reviewing the message confirms a false positive, release it, report the misclassification, and check that the recipient can find and open it.

For a failed result, compare the trace's diagnostic response with the sender's nondelivery report. Together, they help point to an address problem, policy action, or receiving-system error. Include both in the ticket so the next administrator can pick up the investigation.

## Optional: reproduce the investigation in PowerShell

Run these blocks in order in the same PowerShell window. Replace `admin@example.com` with your administrative sign-in, and the sample sender, recipient, dates, and Message-ID with the incident details.

If `ExchangeOnlineManagement` isn't installed, run `Install-Module ExchangeOnlineManagement -Scope CurrentUser` first. Then connect and check that both V2 commands are available:

```powershell
Import-Module ExchangeOnlineManagement -ErrorAction Stop
Connect-ExchangeOnline -UserPrincipalName 'admin@example.com' -ErrorAction Stop
Get-Command Get-MessageTraceV2, Get-MessageTraceDetailV2 -ErrorAction Stop
```

After sign-in, `Get-Command` should list both command names. If either is missing, update a current-user installation with `Update-Module ExchangeOnlineManagement -Scope CurrentUser`, then reconnect in a new PowerShell window.

Use explicit UTC values for the sample window:

```powershell
$query = @{
    SenderAddress    = 'dispatch@example.net'
    RecipientAddress = 'alex@example.com'
    StartDate = [DateTimeOffset]::Parse('2026-09-24T16:00:00Z').UtcDateTime
    EndDate   = [DateTimeOffset]::Parse('2026-09-24T16:30:00Z').UtcDateTime
    ResultSize = 1000
}

$traceRows = @(Get-MessageTraceV2 @query -ErrorAction Stop)
'Matching trace rows: {0}' -f $traceRows.Count
$traceRows | Format-List Received, SenderAddress, RecipientAddress,
    Subject, Status, MessageId, MessageTraceId
```

The output lists the matching rows and their status, Message-ID, and trace ID. A count of zero takes you back to **If the trace finds nothing** above. At 1,000 rows, shorten the time window and rerun the query to get below the result cap. `Get-MessageTraceV2` searches the previous 90 days, up to ten days per query, and returns UTC timestamps.

Select the message by its original Message-ID, then retrieve its event details. If you started without headers, copy `MessageId` from the row you've matched by recipient, subject, and time:

```powershell
$selected = @($traceRows | Where-Object {
    $_.MessageId -eq '<training-20260924-0914@example.net>'
})

if ($selected.Count -ne 1) {
    throw "Found $($selected.Count) rows. Recheck the Message-ID and narrow the query."
}

$detailQuery = @{
    MessageTraceId   = $selected[0].MessageTraceId
    RecipientAddress = $selected[0].RecipientAddress
    StartDate = $query.StartDate
    EndDate   = $query.EndDate
}

Get-MessageTraceDetailV2 @detailQuery -ErrorAction Stop | Format-List
```

The original Message-ID selects the message; Exchange's returned `MessageTraceId` retrieves its events for that recipient and date window. Read each event's time and detail. For Alex's example, the **Receive** and **Deliver** events lead to the mailbox checks described above.

When finished with the session:

```powershell
Disconnect-ExchangeOnline -Confirm:$false
```

## Record what solved the problem

The closing note can be brief:

> **Finding:** Delivery to Alex's mailbox was recorded at 16:14:11 UTC on 24 September. The original message was located in Supplier updates.
>
> **Supporting check:** An enabled sender-based rule targets that folder. A test message followed the same route.
>
> **User verification:** Alex opened the original message and confirmed access to the updated schedule.
>
> **Action:** Showed Alex where these supplier messages arrive.

For an open case, include the sender, recipient, UTC search window, Message-ID, last event or diagnostic response, and next check with its owner. This gives the next engineer enough detail to repeat the search and continue from the same point.

## References

- **Message trace:** Microsoft's [Exchange admin center guide](https://learn.microsoft.com/en-us/exchange/monitoring/trace-an-email-message/message-trace-modern-eac) and [FAQ](https://learn.microsoft.com/en-us/exchange/monitoring/trace-an-email-message/message-trace-faq) cover searches, statuses, timing, and limitations.
- **PowerShell:** [Module installation](https://learn.microsoft.com/en-us/powershell/exchange/exchange-online-powershell-v2#install-and-update-the-exchange-online-powershell-module), [connection setup](https://learn.microsoft.com/en-us/powershell/exchange/connect-to-exchange-online-powershell?view=exchange-ps), [Get-MessageTraceV2](https://learn.microsoft.com/en-us/powershell/module/exchangepowershell/get-messagetracev2?view=exchange-ps), and [Get-MessageTraceDetailV2](https://learn.microsoft.com/en-us/powershell/module/exchangepowershell/get-messagetracedetailv2?view=exchange-ps) cover setup, query limits, and event details.
- **Inbox rules:** [Manage email messages using rules in Outlook](https://support.microsoft.com/en-us/outlook/mail/manage-email-messages-by-using-rules-in-outlook).
- **Post-delivery actions:** [Zero-hour auto purge](https://learn.microsoft.com/en-us/defender-office-365/zero-hour-auto-purge).
- **Quarantine:** [Manage quarantined messages](https://learn.microsoft.com/en-us/defender-office-365/quarantine-admin-manage-messages-files), including permissions, review, and release.
