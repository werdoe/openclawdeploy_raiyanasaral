# OpenClaw Deploy

One-command setup for a production-ready [OpenClaw](https://docs.openclaw.ai) instance.

## Quick Start

```bash
curl -sL https://raw.githubusercontent.com/werdoe/openclaw-deploy/main/deploy.sh | bash
```

Or clone and run:

```bash
git clone https://github.com/werdoe/openclaw-deploy.git
cd openclaw-deploy
chmod +x deploy.sh
./deploy.sh
```

## What You'll Need

- **macOS or Linux** (Ubuntu/Debian/WSL)
- **Anthropic API key** ([get one here](https://console.anthropic.com/settings/keys))
- ~5 minutes

## What It Does

1. Installs Node.js 20+ if missing (via nvm)
2. Installs OpenClaw globally via npm
3. Runs the onboarding wizard (API key, model, channel)
4. Hardens security (loopback-only binding, token auth)
5. Creates workspace directory structure
6. Registers and starts the gateway service
7. Verifies everything works

## What It Does NOT Do

- Install custom skills (add them later as needed)
- Configure Slack, Discord, or other channels beyond the wizard
- Set up cron jobs or automations
- Create personality files (SOUL.md, etc.)

## After Install

```bash
# Check status
openclaw status

# Run security audit
openclaw security audit --deep

# Connect Telegram
openclaw channel telegram setup

# Open dashboard
open http://127.0.0.1:18789/
```

## Adding Custom Skills Later

```bash
# Copy a skill folder into your workspace
cp -r /path/to/my-skill ~/.openclaw/workspace/skills/

# Install its dependencies
cd ~/.openclaw/workspace/skills/my-skill
npm install
```

## Security

The script configures:
- **Loopback binding** -- gateway only accessible from localhost
- **Token auth** -- random 48-char token generated on setup
- **Tailscale off** -- no external network exposure by default

On Linux with UFW, port 18789 is automatically blocked from external access.

## Requirements

| Dependency | Minimum | Installed automatically? |
|-----------|---------|------------------------|
| Node.js | v20+ | Yes (via nvm) |
| npm | v10+ | Yes (with Node.js) |
| OpenClaw | latest | Yes |

## License

MIT
