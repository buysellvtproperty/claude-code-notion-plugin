#!/usr/bin/env bash
#
# setup-gws.sh — install & authenticate the official Google Workspace CLI (gws)
# so Claude (and you) can drive Gmail, Calendar, Drive, Docs, Sheets, Chat, and
# Admin through a single connection.
#
# Two modes (auto-detected):
#   1. Interactive  — opens a browser for Google OAuth consent (use on your own machine).
#   2. Non-interactive / headless / CI / Claude Code web — supply credentials via
#      GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE (exported user creds or a service account).
#
# This script NEVER writes credentials into the repo. See docs/google-workspace-cli-setup.md.
#
# Usage:
#   bash scripts/setup-gws.sh
#   GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE=/path/to/creds.json bash scripts/setup-gws.sh
#
set -euo pipefail

SERVICES="${GWS_SERVICES:-gmail,calendar,drive,docs,sheets,chat,admin}"

log()  { printf '\033[1;34m[gws-setup]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[gws-setup]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[gws-setup]\033[0m %s\n' "$*" >&2; exit 1; }

# 1. Prerequisites ----------------------------------------------------------
command -v node >/dev/null 2>&1 || die "Node.js 18+ is required but not found."
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
[ "${NODE_MAJOR}" -ge 18 ] || die "Node.js 18+ required; found $(node --version)."

# 2. Install gws if missing -------------------------------------------------
if command -v gws >/dev/null 2>&1; then
  log "gws already installed: $(gws --version 2>/dev/null || echo '?')"
else
  command -v npm >/dev/null 2>&1 || die "npm not found; install Node/npm or use a prebuilt gws binary."
  log "Installing @googleworkspace/cli globally via npm…"
  npm install -g @googleworkspace/cli
  command -v gws >/dev/null 2>&1 || die "gws not on PATH after install; check your npm global bin dir."
  log "Installed gws: $(gws --version 2>/dev/null || echo '?')"
fi

# 3. Authenticate -----------------------------------------------------------
if [ -n "${GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE:-}" ]; then
  # Non-interactive path: credentials provided via env var (user export or service account).
  [ -f "${GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE}" ] \
    || die "GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE is set but file not found: ${GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE}"
  log "Using credentials from GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE (non-interactive)."
elif gws auth status >/dev/null 2>&1; then
  log "Already authenticated:"
  gws auth status || true
else
  if [ -t 0 ] && [ -t 1 ]; then
    log "No credentials found — starting interactive auth (a browser window will open)."
    log "If this is a brand-new project, 'gws auth setup' can also create the Cloud"
    log "project, enable APIs, and make the OAuth client for you."
    gws auth login
  else
    die "Not authenticated and no TTY for interactive login.
    Provide credentials non-interactively, e.g.:
      export GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE=/path/to/creds.json
    Generate that file on an authenticated machine with:
      gws auth export --unmasked > creds.json   # or use a service-account JSON
    See docs/google-workspace-cli-setup.md."
  fi
fi

# 4. Verify -----------------------------------------------------------------
log "Verifying authentication…"
gws auth status || warn "Could not confirm auth status; check output above."

log "Done. To expose Workspace to Claude as a single MCP connection, run:"
echo "    claude mcp add google-workspace -- gws mcp -s ${SERVICES}"
log "(This repo's .mcp.json already declares the same 'google-workspace' server.)"
