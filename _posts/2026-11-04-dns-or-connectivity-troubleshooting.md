---
layout: post
title: "DNS or Connectivity? How to Triage an Unreachable Service"
description: "Follow two worked examples from a failed DNS lookup or TCP connection to a focused fix, then verify the service from the affected client."
date: 2026-11-04
permalink: /blog/dns-or-connectivity-troubleshooting
tags: [Networking, DNS, Troubleshooting, PowerShell, IT Operations]
related_posts:
  - /blog/where-did-the-email-go-troubleshooting-exchange-online-with-message-trace
  - /blog/ccna-ocg
  - /blog/entra-sign-in-troubleshooting-framework
---

“The application won't open.”

That report is a starting point. The client needs to resolve the right name, reach the service's port, establish a secure connection, and receive a usable application response. Checking those steps in order gives each result a clear purpose.

The two worked examples below follow the same HTTPS service through different failures. Each includes example output, the next check it supports, and the evidence needed to close the ticket.

<details class="article-toc" markdown="1">
<summary>On this page</summary>
<nav aria-label="On this page" markdown="1">

* Contents
{:toc}
</nav>
</details>

## Start with the request the user is making

Before running commands, establish the exact URL, the error, who is affected, and when it last worked. Ask whether the failure follows one device, one location, or everyone who uses the service. Record any recent change.

For these examples, the requested URL is `https://portal.example.com/`, the expected IPv4 address is `192.0.2.25`, and the service accepts HTTPS on TCP port `443`. The application exposes `/health` for a basic service check.

The names and addresses are documentation examples. Replace them with the hostname, expected address, and port from the ticket when using the checks. The commands use Windows PowerShell 5.1. [IANA example domains](https://www.iana.org/help/example-domains) · [Documentation address ranges](https://www.rfc-editor.org/rfc/rfc5737)

Keep three questions in view.

1. Does the name resolve to the expected destination?
2. Can the affected client establish a connection to the required port?
3. Does the service respond correctly through its normal hostname?

## First example — the name cannot be resolved

Start on the affected client.

<!--
AI-assisted code
Purpose: Provide read-only DNS, TCP, listener, and HTTP checks for a worked troubleshooting example.
Prepared for review by: Dimitriy Leontev
Generated: 2026-11-04
-->

```powershell
Resolve-DnsName -Name portal.example.com -Type A -DnsOnly -NoHostsFile
```

The lookup returns a name error.

```text
Resolve-DnsName : portal.example.com : DNS name does not exist
```

`-DnsOnly` limits the query to DNS, and `-NoHostsFile` skips the local hosts file. The response focuses the investigation on the requested name and the resolver's view of it. Record which DNS servers the client uses before comparing answers. [Resolve-DnsName documentation](https://learn.microsoft.com/en-us/powershell/module/dnsclient/resolve-dnsname)

If the application behaves differently from this DNS-only check, compare local hosts entries, cached answers, and the resolver the application uses.

Check the exact hostname against the intended DNS zone. If necessary, query the approved resolver directly. In this example, that resolver is `192.0.2.53`.

```powershell
Resolve-DnsName -Name portal.example.com -Server 192.0.2.53 -Type A -DnsOnly -NoHostsFile |
    Select-Object Name, Type, IPAddress
```

The resolver also returns a name error. Checking the zone identifies a missing host record. The service owner confirms the intended destination before the record is added through the normal change process.

After the record is available, repeat the lookup from the affected client, accounting for any cached negative answer. The example answer is now the expected address.

```text
Name                Type IPAddress
----                ---- ---------
portal.example.com  A    192.0.2.25
```

A resolver timeout would call for checking reachability and DNS service availability. A returned address that differs from the expected destination would call for checking the record, aliases, cache, and resolver selection. Let the actual response choose the next step.

These examples follow IPv4. For a service that publishes IPv6 records, also check its AAAA records and the address family the client uses.

Continue with the TCP and application checks before closing the ticket.

## Second example — DNS works, but the port is unreachable

In the second case, the lookup already returns `192.0.2.25`. Test the required port from the affected client using that address.

```powershell
Test-NetConnection -ComputerName 192.0.2.25 -Port 443 -InformationLevel Quiet
```

```text
False
```

This test checks whether a TCP connection can be established to that destination and port. A failed attempt leaves several possibilities, including the network path, filtering, a stopped service, or a listener on the wrong interface. [Test-NetConnection documentation](https://learn.microsoft.com/en-us/powershell/module/nettcpip/test-netconnection)

The next check depends on the service's expected access path. Identify the component that should accept the client's connection, including a reverse proxy or load balancer where one is used.

In this example, the application itself is supposed to accept HTTPS on the server's network interface. On that Windows server, inspect the listening socket.

```powershell
Get-NetTCPConnection -LocalPort 443 -State Listen |
    Select-Object LocalAddress, LocalPort, State
```

```text
LocalAddress LocalPort State
------------ --------- -----
127.0.0.1          443 Listen
```

The service is listening on loopback. That allows connections originating on the server through its loopback address. Remote clients need a listener on the intended network interface. The address explains why the service can appear healthy locally while the client connection fails. [Get-NetTCPConnection documentation](https://learn.microsoft.com/en-us/powershell/module/nettcpip/get-nettcpconnection)

The application configuration check identifies a loopback binding where the approved network interface was expected. Correct that binding through the application's documented settings and restart the affected service within the change window.

After the binding change, the listener is on the intended address.

```text
LocalAddress LocalPort State
------------ --------- -----
192.0.2.25         443 Listen
```

From the affected client, repeat the same TCP test.

```powershell
Test-NetConnection -ComputerName 192.0.2.25 -Port 443 -InformationLevel Quiet
```

```text
True
```

The evidence now covers the listening interface and the client's TCP path. Continue through the hostname to check HTTPS and the application response.

## Verify the service through its normal hostname

Run the request from the affected client using the URL people actually use. Keeping the hostname exercises name resolution and the certificate name as part of the request.

```powershell
Invoke-WebRequest -Uri 'https://portal.example.com/health' -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop |
    Select-Object StatusCode, Content
```

For this application's health endpoint, the expected response is shown below.

```text
StatusCode Content
---------- -------
       200 {"status":"ok"}
```

`Invoke-WebRequest` lets you inspect the HTTP response after reaching the endpoint. If the request encounters a certificate, authentication, or application error, follow that evidence into the next layer. [Invoke-WebRequest documentation](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/invoke-webrequest?view=powershell-5.1)

Finish by asking the affected user to repeat the task that failed, such as signing in and opening the required page. A health response checks one endpoint. The user's task checks the recovery that matters to them.

## Record the finding and the recovery evidence

The two examples reach different fixes through the same sequence.

- **DNS case.** The requested name was missing from the intended zone. After the record was added, the affected client resolved the expected address and could complete the service checks.
- **Connectivity case.** The name resolved correctly, but the application listened only on loopback. Correcting the binding allowed the client to establish a TCP connection and receive the expected HTTPS response.

A useful closure note records the affected scope, the relevant lookup or connection result, the confirmed cause, the approved change, and the checks performed afterward. Include who verified the original task and when.

Keep the user update short and understandable.

> The service is reachable again. The connection checks and application health request pass. Please retry the page you were using so we can confirm your task is working.

That leaves the next administrator with evidence they can follow and gives the person who reported the issue a clear next step.
