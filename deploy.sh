#!/bin/bash
# =============================================================================
# OpenClaw Quick Deploy
# 
# One command to install and configure a production-ready OpenClaw instance.
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/werdoe/openclaw-deploy/main/deploy.sh | bash
#
# What it does:
#   1. Checks/installs Node.js 20+ (via nvm if needed)
#   2. Installs OpenClaw globally
#   3. Runs onboarding wizard (API key, model, channel setup)
#   4. Hardens security (loopback binding, token auth)
#   5. Creates workspace directory structure
#   6. Registers gateway as background service
#   7. Verifies everything works
#
# Works on: macOS, Linux (Ubuntu/Debian), WSL
# Time: ~5 minutes
# =============================================================================

set -e

# -- Colors -------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!!]${NC} $1"; }
error() { echo -e "${RED}[ERR]${NC} $1"; exit 1; }
info()  { echo -e "${BLUE}[..]${NC} $1"; }
step()  { echo -e "\n${BOLD}${BLUE}--- $1 ---${NC}\n"; }

# -- Configuration (edit if needed) -------------------------------------------
OPENCLAW_VERSION="latest"
GATEWAY_PORT=18789
GATEWAY_BIND="loopback"
MIN_NODE_VERSION=20

# =============================================================================
# 1. Pre-flight
# =============================================================================
step "Pre-flight checks"

OS="$(uname -s)"
case "$OS" in
    Darwin) PLATFORM="macos"; log "macOS detected" ;;
    Linux)  PLATFORM="linux"; log "Linux detected" ;;
    *)      error "Unsupported OS: $OS. This script supports macOS and Linux." ;;
esac

# macOS: ensure Xcode Command Line Tools are installed (git, curl, etc.)
if [ "$PLATFORM" = "macos" ]; then
    if ! xcode-select -p &> /dev/null; then
        info "Installing Xcode Command Line Tools (required for git, curl, etc.)..."
        xcode-select --install
        echo ""
        echo "  Waiting for Xcode CLI tools to finish installing..."
        echo "  If a dialog appeared, click Install and wait."
        echo ""
        # Wait for installation to complete
        until xcode-select -p &> /dev/null; do
            sleep 5
        done
        log "Xcode Command Line Tools installed"
    else
        log "Xcode Command Line Tools found"
    fi
fi

if [ "$(id -u)" -eq 0 ]; then
    error "Don't run as root. Use your normal user account."
fi

# -- Node.js ------------------------------------------------------------------
NEED_NODE=false

if command -v node &> /dev/null; then
    NODE_VER=$(node -v | sed 's/v//' | cut -d. -f1)
    if [ "$NODE_VER" -ge "$MIN_NODE_VERSION" ]; then
        log "Node.js $(node -v)"
    else
        warn "Node.js $(node -v) too old (need v${MIN_NODE_VERSION}+)"
        NEED_NODE=true
    fi
else
    warn "Node.js not found"
    NEED_NODE=true
fi

if [ "$NEED_NODE" = true ]; then
    step "Installing Node.js"
    
    if ! command -v nvm &> /dev/null; then
        info "Installing nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    fi
    
    nvm install --lts
    nvm use --lts
    log "Node.js $(node -v) installed"
fi

if ! command -v npm &> /dev/null; then
    error "npm not found after Node.js installation. Something went wrong."
fi

log "npm $(npm -v)"

# =============================================================================
# 2. Install OpenClaw
# =============================================================================
step "Installing OpenClaw"

if command -v openclaw &> /dev/null; then
    CURRENT=$(openclaw --version 2>/dev/null || echo "unknown")
    info "OpenClaw ${CURRENT} found. Updating..."
    npm update -g openclaw
else
    info "Installing openclaw@${OPENCLAW_VERSION}..."
    npm install -g "openclaw@${OPENCLAW_VERSION}"
fi

INSTALLED_VER=$(openclaw --version 2>/dev/null || echo "installed")
log "OpenClaw ${INSTALLED_VER}"

# =============================================================================
# 3. Onboarding
# =============================================================================
step "OpenClaw Setup"

echo ""
echo -e "  ${BOLD}The wizard will ask you a few things:${NC}"
echo ""
echo "    API provider  ->  Anthropic (recommended)"
echo "    Default model  ->  claude-sonnet-4-20250514"
echo "    Gateway mode   ->  local"
echo "    Channel        ->  Telegram (for mobile access)"
echo ""
echo "  You'll need your Anthropic API key ready."
echo "  Get one at: https://console.anthropic.com/settings/keys"
echo ""
read -p "  Press Enter to start the wizard..."

openclaw onboard

# =============================================================================
# 4. Security hardening
# =============================================================================
step "Security hardening"

CONFIG_DIR="$HOME/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"

if [ -f "$CONFIG_FILE" ]; then
    node -e "
        const fs = require('fs');
        const crypto = require('crypto');
        const cfg = JSON.parse(fs.readFileSync('$CONFIG_FILE', 'utf8'));
        
        // Force loopback binding
        cfg.gateway = cfg.gateway || {};
        cfg.gateway.bind = '${GATEWAY_BIND}';
        cfg.gateway.port = ${GATEWAY_PORT};
        
        // Ensure token auth exists
        if (!cfg.gateway.auth || !cfg.gateway.auth.token) {
            cfg.gateway.auth = {
                mode: 'token',
                token: crypto.randomBytes(24).toString('hex')
            };
        }
        
        // Disable tailscale by default
        cfg.gateway.tailscale = cfg.gateway.tailscale || {};
        cfg.gateway.tailscale.mode = 'off';
        
        fs.writeFileSync('$CONFIG_FILE', JSON.stringify(cfg, null, 2));
    "
    log "Gateway: loopback-only, token auth, tailscale off"
else
    warn "Config not found at $CONFIG_FILE -- run 'openclaw onboard' manually"
fi

# macOS: enable firewall reminder
if [ "$PLATFORM" = "macos" ]; then
    echo ""
    info "macOS firewall reminder:"
    echo "  System Settings > Network > Firewall > Turn On"
    echo "  (OpenClaw already binds to localhost, firewall is secondary defense)"
fi

# Linux: block port via ufw if available
if [ "$PLATFORM" = "linux" ] && command -v ufw &> /dev/null; then
    sudo ufw deny "${GATEWAY_PORT}/tcp" 2>/dev/null && log "UFW: blocked port ${GATEWAY_PORT}" || true
fi

# =============================================================================
# 5. Workspace structure
# =============================================================================
step "Creating workspace"

WORKSPACE="$CONFIG_DIR/workspace"
mkdir -p "$WORKSPACE"/{memory,knowledge,learnings,archive,reports,skills}

# -- AGENTS.md ----------------------------------------------------------------
if [ ! -f "$WORKSPACE/AGENTS.md" ]; then
    cat > "$WORKSPACE/AGENTS.md" << 'EOF'
# AGENTS.md

## Boot Sequence
1. Read SOUL.md (if exists)
2. Read USER.md (if exists)  
3. Read memory/YYYY-MM-DD.md (today's log)

## Permissions
**Do freely:** Read files, web search, write to memory/, analysis
**Ask first:** Sending messages, installing software, destructive commands, system changes

## Write Discipline
- After significant tasks: log to memory/YYYY-MM-DD.md
- After mistakes: append rule to learnings/LEARNINGS.md
- Before session end: write handover to memory/YYYY-MM-DD.md
EOF
    log "Created AGENTS.md"
fi

# -- MEMORY.md ----------------------------------------------------------------
if [ ! -f "$WORKSPACE/MEMORY.md" ]; then
    cat > "$WORKSPACE/MEMORY.md" << 'EOF'
# MEMORY.md

*Long-term curated memory. Updated during periodic reviews, not mid-task.*
EOF
    log "Created MEMORY.md"
fi

# -- LEARNINGS.md -------------------------------------------------------------
if [ ! -f "$WORKSPACE/learnings/LEARNINGS.md" ]; then
    cat > "$WORKSPACE/learnings/LEARNINGS.md" << 'EOF'
# LEARNINGS.md

*Every mistake becomes a one-line rule. These compound over time.*
EOF
    log "Created learnings/LEARNINGS.md"
fi

# -- TOOLS.md -----------------------------------------------------------------
if [ ! -f "$WORKSPACE/TOOLS.md" ]; then
    cat > "$WORKSPACE/TOOLS.md" << 'EOF'
# TOOLS.md

*Environment-specific notes: device names, SSH hosts, API endpoints, etc.*
*Skills are shared. Your setup is yours.*
EOF
    log "Created TOOLS.md"
fi

# =============================================================================
# 6. Gateway service
# =============================================================================
step "Starting gateway"

openclaw gateway install 2>/dev/null || warn "Gateway service install skipped (may need manual setup)"
openclaw gateway start 2>/dev/null || warn "Gateway may still be starting..."

# Give it a moment
sleep 3

# =============================================================================
# 7. Verify
# =============================================================================
step "Verification"

openclaw status 2>/dev/null || warn "Status check failed. Gateway may still be initializing."

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  OpenClaw is ready.${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo "  Dashboard:   http://127.0.0.1:${GATEWAY_PORT}/"
echo "  Config:      ${CONFIG_FILE}"
echo "  Workspace:   ${WORKSPACE}"
echo ""
echo "  Quick commands:"
echo "    openclaw status              # health check"
echo "    openclaw security audit      # security scan"
echo "    openclaw gateway restart     # restart gateway"
echo "    openclaw channel telegram setup  # connect Telegram"
echo ""
echo "  Docs: https://docs.openclaw.ai"
echo ""
