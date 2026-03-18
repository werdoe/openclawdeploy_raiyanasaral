# OpenClaw Deploy

Production-ready OpenClaw setup in one command. Installs, configures, and hardens a fresh instance with battle-tested agent architecture.

## Why This Exists

The default OpenClaw install gives you a working agent with a blank workspace. That's fine for experimenting, but for real daily use you need more:

- **Memory architecture** -- daily logs, long-term memory curation, learning from mistakes
- **Task management** -- quality gates before starting work, WIP limits, working memory for complex tasks
- **Heartbeat system** -- morning briefs, nightly reflection loops, system health monitoring
- **Security hardening** -- loopback-only binding, token auth, firewall rules, tailscale disabled by default
- **Personality framework** -- template for defining your agent's behavior and communication style
- **Write discipline** -- if it matters, it goes to disk. Handovers between sessions so nothing gets lost

This script installs OpenClaw and applies these patterns automatically.

## What's Improved Over Default

| Area | Default Install | This Deploy |
|------|----------------|-------------|
| **Workspace** | Empty | Structured directories (memory/, knowledge/, learnings/, archive/, reports/) |
| **AGENTS.md** | None | Boot sequence, permissions model, quality gates, WIP limits, task classification, teaching mode, cost awareness |
| **Memory** | None | Daily logging system, long-term curation workflow, mistake-tracking rules |
| **Heartbeat** | Basic | Morning briefs, nightly reflection with pattern analysis, system health checks |
| **Personality** | Generic | Framework ready -- define your own via SOUL.md |
| **Security** | Varies by wizard | Enforced loopback binding, random token auth, tailscale off, firewall hints |
| **Task Handling** | Ad hoc | Quality gates (problem/plan/criteria before starting), WIP limits (max 3 concurrent), working memory for resumed tasks |
| **Self-Monitoring** | None | Blocked-3-times escalation, progress updates on long tasks, logging what worked AND what didn't |

## Quick Start

### macOS / Linux:
```bash
curl -sLO https://raw.githubusercontent.com/werdoe/openclawdeploy_raiyanasaral/main/deploy.sh && bash deploy.sh
```

### Windows (PowerShell):
```powershell
irm https://raw.githubusercontent.com/werdoe/openclawdeploy_raiyanasaral/main/deploy.ps1 | iex
```

## What You'll Need

- **macOS, Linux, or Windows 10/11**
- **Anthropic API key** ([get one here](https://console.anthropic.com/settings/keys))
- ~5 minutes

## What It Does

1. Installs Xcode CLI tools (macOS) if missing
2. Installs Homebrew + Node.js if missing
3. Installs OpenClaw globally via npm
4. Runs the onboarding wizard (API key, model, channel)
5. Hardens security (loopback binding, token auth, tailscale off)
6. Sets up workspace with production-tested agent config files
7. Registers and starts the gateway service
8. Runs verification

## What It Does NOT Include

- No API keys or credentials (you provide your own during setup)
- No sessions or conversation history
- No personal data (USER.md, bookmarks, etc.)
- No custom skills (add them later as needed)
- No cron jobs (configure per your needs)

This is a **blank slate** with a strong foundation. You get the architecture and patterns. Everything else you build yourself.


## After Install

```bash
openclaw status              # health check
openclaw security audit      # security scan
openclaw gateway restart     # restart gateway
open http://127.0.0.1:18789/ # open dashboard
```


## Security

The script enforces:
- **Loopback binding** -- gateway only accessible from localhost (127.0.0.1)
- **Token auth** -- random 48-character token generated per install
- **Tailscale off** -- no external network exposure by default
- **Firewall** -- Linux UFW rule added automatically; macOS reminder displayed

## License

MIT
