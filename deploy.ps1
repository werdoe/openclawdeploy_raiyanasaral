# =============================================================================
# OpenClaw Quick Deploy (Windows)
#
# Usage:
#   irm https://raw.githubusercontent.com/werdoe/openclawdeploy_raiyanasaral/main/deploy.ps1 | iex
#
#   With template:
#   $env:OPENCLAW_TEMPLATE="rai_asaral"; irm https://raw.githubusercontent.com/werdoe/openclawdeploy_raiyanasaral/main/deploy.ps1 | iex
#
# Works on: Windows 10/11, Windows Server 2019+
# Requires: PowerShell 5.1+
# Time: ~5 minutes
# =============================================================================

$ErrorActionPreference = "Stop"

$GATEWAY_PORT = 18789
$GATEWAY_BIND = "loopback"
$TEMPLATE = if ($env:OPENCLAW_TEMPLATE) { $env:OPENCLAW_TEMPLATE } elseif ($args -contains "--template") { $args[($args.IndexOf("--template") + 1)] } else { "" }
$REPO_RAW = "https://raw.githubusercontent.com/werdoe/openclawdeploy_raiyanasaral/main"

function Log($msg) { Write-Host "[OK] $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "[!!] $msg" -ForegroundColor Yellow }
function Err($msg) { Write-Host "[ERR] $msg" -ForegroundColor Red; exit 1 }
function Info($msg) { Write-Host "[..] $msg" -ForegroundColor Cyan }
function Step($msg) { Write-Host "`n--- $msg ---`n" -ForegroundColor Blue }

# =============================================================================
# 1. Pre-flight
# =============================================================================
Step "Pre-flight checks"

if (-not ([Environment]::OSVersion.Platform -eq "Win32NT")) {
    Err "This script is for Windows. Use deploy.sh for macOS/Linux."
}
Log "Windows $([Environment]::OSVersion.Version) detected"

# Check if running as admin (don't require it)
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) { Info "Running as administrator" }

# =============================================================================
# 2. Node.js
# =============================================================================
Step "Checking Node.js"

$needNode = $false

try {
    $nodeVer = (node -v 2>$null) -replace 'v','' -split '\.' | Select-Object -First 1
    if ([int]$nodeVer -ge 20) {
        Log "Node.js $(node -v)"
    } else {
        Warn "Node.js v$nodeVer too old (need v20+)"
        $needNode = $true
    }
} catch {
    Warn "Node.js not found"
    $needNode = $true
}

if ($needNode) {
    Step "Installing Node.js"

    # Check for winget
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Info "Installing Node.js via winget..."
        winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
        
        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        Log "Node.js installed via winget"
    } else {
        # Direct download
        Info "Downloading Node.js installer..."
        $nodeUrl = "https://nodejs.org/dist/v22.15.0/node-v22.15.0-x64.msi"
        $installer = "$env:TEMP\node-installer.msi"
        Invoke-WebRequest -Uri $nodeUrl -OutFile $installer -UseBasicParsing
        
        Info "Running installer (this may take a minute)..."
        Start-Process msiexec.exe -ArgumentList "/i `"$installer`" /qn" -Wait
        
        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        Remove-Item $installer -ErrorAction SilentlyContinue
        Log "Node.js installed"
    }
    
    # Verify
    try {
        $null = node -v
        Log "Node.js $(node -v)"
    } catch {
        Err "Node.js installation failed. Install manually from https://nodejs.org and re-run this script."
    }
}

try {
    $null = npm -v
    Log "npm $(npm -v)"
} catch {
    Err "npm not found. Something went wrong with Node.js installation."
}

# =============================================================================
# 3. Install OpenClaw
# =============================================================================
Step "Installing OpenClaw"

try {
    $currentVer = openclaw --version 2>$null
    Info "OpenClaw $currentVer found. Updating..."
    npm update -g openclaw
} catch {
    Info "Installing OpenClaw..."
    npm install -g openclaw
}

# Refresh PATH again
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")

try {
    $installedVer = openclaw --version 2>$null
    Log "OpenClaw $installedVer"
} catch {
    Err "OpenClaw not found after install. Check npm global path."
}

# =============================================================================
# 4. Onboarding
# =============================================================================
Step "OpenClaw Setup"

Write-Host ""
Write-Host "  The wizard will ask you a few things:" -ForegroundColor White
Write-Host ""
Write-Host "    API provider  ->  Anthropic (recommended)"
Write-Host "    Default model  ->  claude-sonnet-4-20250514"
Write-Host "    Gateway mode   ->  local"
Write-Host "    Channel        ->  Telegram (for mobile access)"
Write-Host ""
Write-Host "  You'll need your Anthropic API key ready."
Write-Host "  Get one at: https://console.anthropic.com/settings/keys"
Write-Host ""
Read-Host "  Press Enter to start the wizard"

openclaw onboard

# =============================================================================
# 5. Security hardening
# =============================================================================
Step "Security hardening"

$configDir = "$env:USERPROFILE\.openclaw"
$configFile = "$configDir\openclaw.json"

if (Test-Path $configFile) {
    node -e @"
        const fs = require('fs');
        const crypto = require('crypto');
        const cfg = JSON.parse(fs.readFileSync('$($configFile -replace '\\','/')', 'utf8'));
        
        cfg.gateway = cfg.gateway || {};
        cfg.gateway.bind = '$GATEWAY_BIND';
        cfg.gateway.port = $GATEWAY_PORT;
        
        if (!cfg.gateway.auth || !cfg.gateway.auth.token) {
            cfg.gateway.auth = {
                mode: 'token',
                token: crypto.randomBytes(24).toString('hex')
            };
        }
        
        cfg.gateway.tailscale = cfg.gateway.tailscale || {};
        cfg.gateway.tailscale.mode = 'off';
        
        fs.writeFileSync('$($configFile -replace '\\','/')', JSON.stringify(cfg, null, 2));
"@
    Log "Gateway: loopback-only, token auth, tailscale off"
}

# Windows Firewall rule
if ($isAdmin) {
    try {
        $existing = netsh advfirewall firewall show rule name="OpenClaw Block External" 2>$null
        if (-not $existing -or $existing -match "No rules match") {
            netsh advfirewall firewall add rule name="OpenClaw Block External" dir=in action=block protocol=TCP localport=$GATEWAY_PORT
            Log "Firewall rule added: blocking port $GATEWAY_PORT from external access"
        } else {
            Log "Firewall rule already exists"
        }
    } catch {
        Warn "Could not add firewall rule. Add manually or re-run as admin."
    }
} else {
    Info "Run as administrator to auto-add firewall rule, or add manually:"
    Write-Host "  netsh advfirewall firewall add rule name=`"OpenClaw Block External`" dir=in action=block protocol=TCP localport=$GATEWAY_PORT"
}

# =============================================================================
# 6. Workspace
# =============================================================================
Step "Creating workspace"

$workspace = "$configDir\workspace"
$dirs = @("memory", "knowledge", "learnings", "archive", "reports", "skills")
foreach ($d in $dirs) {
    New-Item -ItemType Directory -Path "$workspace\$d" -Force | Out-Null
}

if ($TEMPLATE) {
    Info "Applying template: $TEMPLATE"
    
    $templateFiles = @(
        "AGENTS.md",
        "SOUL.md",
        "HEARTBEAT.md",
        "IDENTITY.md",
        "MEMORY.md",
        "TOOLS.md",
        "learnings/LEARNINGS.md"
    )
    
    foreach ($file in $templateFiles) {
        $dest = "$workspace\$($file -replace '/', '\')"
        $destDir = Split-Path $dest -Parent
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        
        if (-not (Test-Path $dest)) {
            try {
                Invoke-WebRequest -Uri "$REPO_RAW/templates/$TEMPLATE/$file" -OutFile $dest -UseBasicParsing
                Log "Created $file"
            } catch {
                Warn "Failed to download $file"
            }
        } else {
            Info "Skipped $file (already exists)"
        }
    }
}

# Fallback defaults
if (-not (Test-Path "$workspace\AGENTS.md")) {
    @"
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
"@ | Set-Content -Path "$workspace\AGENTS.md"
    Log "Created AGENTS.md (default)"
}

if (-not (Test-Path "$workspace\MEMORY.md")) {
    "# MEMORY.md`n`n*Long-term curated memory. Updated during periodic reviews, not mid-task.*" | Set-Content -Path "$workspace\MEMORY.md"
    Log "Created MEMORY.md (default)"
}

if (-not (Test-Path "$workspace\learnings\LEARNINGS.md")) {
    "# LEARNINGS.md`n`n*Every mistake becomes a one-line rule. These compound over time.*" | Set-Content -Path "$workspace\learnings\LEARNINGS.md"
    Log "Created learnings/LEARNINGS.md (default)"
}

if (-not (Test-Path "$workspace\TOOLS.md")) {
    "# TOOLS.md`n`n*Environment-specific notes: device names, SSH hosts, API endpoints, etc.*" | Set-Content -Path "$workspace\TOOLS.md"
    Log "Created TOOLS.md (default)"
}

# =============================================================================
# 7. Gateway
# =============================================================================
Step "Starting gateway"

try { openclaw gateway install 2>$null } catch { Warn "Gateway service install -- may need manual setup" }
try { openclaw gateway start 2>$null } catch { Warn "Gateway may still be starting..." }

Start-Sleep -Seconds 3

# =============================================================================
# 8. Verify
# =============================================================================
Step "Verification"

try { openclaw status } catch { Warn "Status check failed. Gateway may still be initializing." }

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  OpenClaw is ready!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Dashboard:   http://127.0.0.1:$GATEWAY_PORT/"
Write-Host "  Config:      $configFile"
Write-Host "  Workspace:   $workspace"
Write-Host ""
Write-Host "  Commands:"
Write-Host "    openclaw status              # health check"
Write-Host "    openclaw security audit      # security scan"
Write-Host "    openclaw gateway restart     # restart gateway"
Write-Host ""
Write-Host "  Docs: https://docs.openclaw.ai"
Write-Host ""
