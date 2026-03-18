#!/bin/bash
# =============================================================================
# OpenClaw Quick Deploy
#
# Usage:
#   curl -sLO https://raw.githubusercontent.com/werdoe/openclawdeploy_raiyanasaral/main/deploy.sh && bash deploy.sh
#
# Works on: macOS, Linux (Ubuntu/Debian)
# Time: ~5 minutes
# =============================================================================

set -e

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

GATEWAY_PORT=18789
GATEWAY_BIND="loopback"

# =============================================================================
# 1. OS + Xcode
# =============================================================================
step "Pre-flight checks"

OS="$(uname -s)"
case "$OS" in
    Darwin) PLATFORM="macos"; log "macOS detected" ;;
    Linux)  PLATFORM="linux"; log "Linux detected" ;;
    *)      error "Unsupported OS: $OS" ;;
esac

if [ "$(id -u)" -eq 0 ]; then
    error "Don't run as root. Use your normal user account."
fi

if [ "$PLATFORM" = "macos" ]; then
    if ! xcode-select -p &> /dev/null; then
        info "Installing Xcode Command Line Tools..."
        xcode-select --install 2>/dev/null || true
        echo ""
        echo "  Waiting for installation to complete..."
        until xcode-select -p &> /dev/null; do
            sleep 5
        done
        log "Xcode Command Line Tools installed"
    else
        log "Xcode Command Line Tools found"
    fi
fi

# =============================================================================
# 2. Node.js (no nvm -- direct install)
# =============================================================================
step "Checking Node.js"

NEED_NODE=false

if command -v node &> /dev/null; then
    NODE_VER=$(node -v | sed 's/v//' | cut -d. -f1)
    if [ "$NODE_VER" -ge 20 ]; then
        log "Node.js $(node -v)"
    else
        warn "Node.js $(node -v) too old (need v20+)"
        NEED_NODE=true
    fi
else
    NEED_NODE=true
fi

if [ "$NEED_NODE" = true ]; then
    step "Installing Node.js"
    
    if [ "$PLATFORM" = "macos" ]; then
        # Use Homebrew if available, otherwise install it
        if ! command -v brew &> /dev/null; then
            info "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            
            # Add brew to PATH for Apple Silicon and Intel
            if [ -f "/opt/homebrew/bin/brew" ]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
                echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
            elif [ -f "/usr/local/bin/brew" ]; then
                eval "$(/usr/local/bin/brew shellenv)"
            fi
            log "Homebrew installed"
        else
            log "Homebrew found"
        fi
        
        info "Installing Node.js via Homebrew..."
        brew install node
        log "Node.js $(node -v) installed"
        
    elif [ "$PLATFORM" = "linux" ]; then
        info "Installing Node.js 22.x..."
        curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
        sudo apt-get install -y nodejs
        log "Node.js $(node -v) installed"
    fi
fi

if ! command -v node &> /dev/null; then
    error "Node.js installation failed. Install manually: https://nodejs.org"
fi

if ! command -v npm &> /dev/null; then
    error "npm not found. Something went wrong with Node.js installation."
fi

log "npm $(npm -v)"

# =============================================================================
# 3. Install OpenClaw
# =============================================================================
step "Installing OpenClaw"

if command -v openclaw &> /dev/null; then
    CURRENT=$(openclaw --version 2>/dev/null || echo "unknown")
    info "OpenClaw ${CURRENT} found. Updating..."
    npm update -g openclaw
else
    info "Installing OpenClaw..."
    npm install -g openclaw
fi

if ! command -v openclaw &> /dev/null; then
    error "OpenClaw not found after install. Check npm global path."
fi

log "OpenClaw $(openclaw --version 2>/dev/null || echo 'installed')"

# =============================================================================
# 4. Onboarding wizard
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
# 5. Security hardening
# =============================================================================
step "Security hardening"

CONFIG_DIR="$HOME/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"

if [ -f "$CONFIG_FILE" ]; then
    node -e "
        const fs = require('fs');
        const crypto = require('crypto');
        const cfg = JSON.parse(fs.readFileSync('$CONFIG_FILE', 'utf8'));
        
        cfg.gateway = cfg.gateway || {};
        cfg.gateway.bind = '${GATEWAY_BIND}';
        cfg.gateway.port = ${GATEWAY_PORT};
        
        if (!cfg.gateway.auth || !cfg.gateway.auth.token) {
            cfg.gateway.auth = {
                mode: 'token',
                token: crypto.randomBytes(24).toString('hex')
            };
        }
        
        cfg.gateway.tailscale = cfg.gateway.tailscale || {};
        cfg.gateway.tailscale.mode = 'off';
        
        fs.writeFileSync('$CONFIG_FILE', JSON.stringify(cfg, null, 2));
    "
    log "Gateway: loopback-only, token auth, tailscale off"
fi

if [ "$PLATFORM" = "macos" ]; then
    info "Tip: enable macOS firewall in System Settings > Network > Firewall"
fi

if [ "$PLATFORM" = "linux" ] && command -v ufw &> /dev/null; then
    sudo ufw deny "${GATEWAY_PORT}/tcp" 2>/dev/null && log "UFW: blocked port ${GATEWAY_PORT}" || true
fi

# =============================================================================
# 6. Workspace
# =============================================================================
step "Creating workspace"

WORKSPACE="$CONFIG_DIR/workspace"
mkdir -p "$WORKSPACE"/{memory,knowledge,learnings,archive,reports,skills}

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

if [ ! -f "$WORKSPACE/MEMORY.md" ]; then
    cat > "$WORKSPACE/MEMORY.md" << 'EOF'
# MEMORY.md

*Long-term curated memory. Updated during periodic reviews, not mid-task.*
EOF
    log "Created MEMORY.md"
fi

if [ ! -f "$WORKSPACE/learnings/LEARNINGS.md" ]; then
    cat > "$WORKSPACE/learnings/LEARNINGS.md" << 'EOF'
# LEARNINGS.md

*Every mistake becomes a one-line rule. These compound over time.*
EOF
    log "Created learnings/LEARNINGS.md"
fi

if [ ! -f "$WORKSPACE/TOOLS.md" ]; then
    cat > "$WORKSPACE/TOOLS.md" << 'EOF'
# TOOLS.md

*Environment-specific notes: device names, SSH hosts, API endpoints, etc.*
EOF
    log "Created TOOLS.md"
fi

# =============================================================================
# 7. Gateway service
# =============================================================================
step "Starting gateway"

openclaw gateway install 2>/dev/null || warn "Gateway service install -- may need manual setup"
openclaw gateway start 2>/dev/null || warn "Gateway may still be starting..."

sleep 3

# =============================================================================
# 8. Verify
# =============================================================================
step "Verification"

openclaw status 2>/dev/null || warn "Status check failed. Gateway may still be initializing."

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  OpenClaw is ready!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo "  Dashboard:   http://127.0.0.1:${GATEWAY_PORT}/"
echo "  Config:      ${CONFIG_FILE}"
echo "  Workspace:   ${WORKSPACE}"
echo ""
echo "  Commands:"
echo "    openclaw status              # health check"
echo "    openclaw security audit      # security scan"
echo "    openclaw gateway restart     # restart gateway"
echo ""
echo "  Docs: https://docs.openclaw.ai"
echo ""
