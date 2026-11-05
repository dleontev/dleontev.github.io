# Systems & Infrastructure Administrator

I'm Dimitriy, a Network Administrator in public-sector IT. I support networks, servers, cloud services, and the devices staff rely on. I trace problems across those systems, plan changes with security and reliability in mind, and automate repeatable tasks so colleagues can run them confidently.

<div class="page-actions">
  <a class="btn btn-primary" href="{% link pages/projects.html %}">View projects</a>
  <a class="btn btn-outline-primary" href="{% link pages/about.md %}">About my work</a>
</div>

{% include social.html %}

## Featured work

<div class="article-grid">
  <article class="article-card">
    <p class="project-status">Deployed personal project</p>
    <h3><a href="{% link _projects/05-pomodoro-timer.md %}">Controlled Azure releases</a></h3>
    <p>I configured Azure hosting for a small web app. See how the release passed staging checks, moved to production after approval, and was verified against the packaged build.</p>
    <p><a href="https://pomodoro.dleontev.com/">Open the live timer</a> · <a href="https://github.com/dleontev/pomodoro">View the timer source</a></p>
  </article>
  <article class="article-card">
    <p class="project-status">Troubleshooting guide</p>
    <h3><a href="{% post_url 2026-09-27-where-did-the-email-go-troubleshooting-exchange-online-with-message-trace %}">Exchange Online message tracing</a></h3>
    <p>A worked example uses message trace and PowerShell to follow a missing email into the mailbox and confirm the recipient can open it.</p>
  </article>
</div>

[CCNA lab practice and study notes]({% post_url 2025-07-01-ccna-ocg %}) · [All technical articles]({% link pages/blog.html %})

## Skills

{% include skills.html context='home' %}

## Certifications

Select a certification to view its verification.

{% include certifications.html %}
