# AgentMeter

A native macOS menu-bar indicator showing your **Claude Code** and **Codex**
usage limits (5-hour / 7-day windows) at a glance — so you can keep an eye on
your account consumption no matter which machine you're running sessions on.

The menu-bar title looks like:

<img width="361" height="370" alt="agent-bar" src="https://github.com/user-attachments/assets/9feaad37-4c23-4590-b0b2-e41f5a4be8bc" />

`CC` = Claude Code, `CX` = Codex, each showing the *peak* utilization across its
windows. The dot turns 🟡 above 50% and 🔴 above 80%. Click it for the full
breakdown — every window with its reset countdown, your plan, and a progress bar.

<p align="center"><em>5-hour · 7-day · 7-day Opus · 7-day Sonnet (Claude) — 5-hour · 7-day (Codex)</em></p>

## How it works

It reads usage from the same OAuth endpoints the CLIs themselves use:

| Provider | Endpoint | Auth source |
|----------|----------|-------------|
| Claude Code | `GET api.anthropic.com/api/oauth/usage` | macOS keychain item `Claude Code-credentials` → `claudeAiOauth.accessToken` (sent with the required `User-Agent: claude-code/<ver>` header) |
| Codex | `GET chatgpt.com/backend-api/wham/usage` | `~/.codex/auth.json` → `tokens.access_token` + `chatgpt-account-id` |

Usage figures are **account-global**, so the numbers are identical on every
machine signed into the same account — exactly what you want when you bounce
between several Macs.

> AgentMeter only ever **reads** your local credentials. It never writes or
> refreshes them, so it can't disturb an active CLI session. If a token has
> lapsed it simply shows a "run `claude` / `codex` to refresh" hint — running the
> CLI on that machine refreshes the local token and the meter recovers.

Polling defaults to every 3 minutes (Anthropic's endpoint rate-limits aggressive
polling); 1/3/5/10-minute options are in the popover. It also refreshes on wake
from sleep.

## Build & install

Requires macOS 13+ and a Swift toolchain (Xcode or Command Line Tools).

```sh
make install      # build .app, copy to /Applications, launch
# or
make run          # debug build, run in foreground (Ctrl-C to stop)
make bundle       # just produce ./AgentMeter.app
```

To launch automatically at login: System Settings → General → Login Items → add
`AgentMeter.app`.

## Notes

- `claudeCodeVersion` in `Sources/AgentMeter/Providers.swift` is the User-Agent
  version string sent to Anthropic. Any recent value works; bump it if the
  endpoint ever gets picky.
- Inspired by menu-bar trackers like
  [Usage4Claude](https://github.com/f-is-h/Usage4Claude) and
  [AgentLimits](https://github.com/Nihondo/AgentLimits), built from scratch here.
