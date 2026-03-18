# OpenClaw Deploy

One-command setup for a production-ready [OpenClaw](https://docs.openclaw.ai) instance.

## Quick Start

### Bare install (minimal):
```bash
curl -sLO https://raw.githubusercontent.com/werdoe/openclawdeploy_raiyanasaral/main/deploy.sh && bash deploy.sh
```

### With template (recommended):
```bash
git clone https://github.com/werdoe/openclawdeploy_raiyanasaral.git
cd openclawdeploy_raiyanasaral
chmod +x deploy.sh
./deploy.sh --template rai_asaral
```

## What You'll Need

- **macOS or Linux** (Ubuntu/Debian/WSL)
- **Anthropic API key** ([get one here](https://console.anthropic.com/settings/keys))
- ~5 minutes

## What It Does

1. Installs Xcode CLI tools (macOS) if missing
2. Installs Homebrew + Node.js if missing
3. Installs OpenClaw globally via npm
4. Runs the onboarding wizard (API key, model, channel)
5. Hardens security (loopback binding, token auth)
6. Creates workspace with template files (if specified)
7. Registers and starts the gateway service
8. Verifies everything works

## Templates

Templates provide pre-configured workspace files (AGENTS.md, SOUL.md, HEARTBEAT.md, etc.) with production-tested patterns.

| Template | Description |
|----------|-------------|
| `rai_asaral` | Full agent config: boot sequence, quality gates, memory system, heartbeat, personality |

**Without a template:** you get a minimal workspace with basic AGENTS.md and MEMORY.md.

**With `rai_asaral`:** you get battle-tested config including:
- AGENTS.md with quality gates, WIP limits, task classification, teaching mode
- HEARTBEAT.md with morning briefs, nightly reflection, system health checks
- SOUL.md with two-mode personality (focused work / warm casual)
- IDENTITY.md, MEMORY.md, TOOLS.md, LEARNINGS.md

## After Install

```bash
openclaw status              # health check
openclaw security audit      # security scan
openclaw gateway restart     # restart gateway
open http://127.0.0.1:18789/ # dashboard
```

## Adding Custom Skills

```bash
cp -r /path/to/my-skill ~/.openclaw/workspace/skills/
cd ~/.openclaw/workspace/skills/my-skill
npm install
```

## Security

The script configures:
- **Loopback binding** -- gateway only accessible from localhost
- **Token auth** -- random 48-char token generated on setup
- **Tailscale off** -- no external network exposure by default

## License

MIT
