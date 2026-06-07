# Google Workspace CLI — Session Log

**Date:** 2026-06-07
**Goal:** Set up a single Google Workspace connection so Claude can manage Gmail,
Calendar, Contacts, etc. — and start replacing Superhuman.

## Outcome: ✅ Working

Google's official **gws** CLI (`@googleworkspace/cli`, Homebrew `googleworkspace-cli`
v0.22.5) is installed and authenticated on Nick's Mac, and **Claude Code on the Mac
drives it directly as a terminal tool** (no MCP server needed in this version).

Verified live:
- `gws calendar +agenda` → returned real calendar events
- `gws gmail +triage` → returned the real unread inbox
- Claude Code triaged 201 unread, categorized them, and summarized the top 3
  action items (signature request, commission confirm, failed payment)

## What was set up

- **Machine:** Nick's MacBook Pro (macOS), account `nick@buysellvtproperty.com` (Super Admin)
- **Tools installed:** `gws` (Homebrew), `gcloud` (Google Cloud SDK), Claude Code 2.1.153
- **Google Cloud project:** `bsvt-gws-1780803202` (created fresh; Nick is Owner)
- **OAuth:** Internal consent screen + Desktop OAuth client created in that project
- **Credentials:** encrypted in macOS Keychain at `~/.config/gws/credentials.enc`;
  client config at `~/.config/gws/client_secret.json`

## Scopes authorized (21)

Gmail (full incl. `gmail.send`, modify, labels, settings, compose, insert, addons),
Calendar, Contacts (People), Groups, Sheets, Tasks, cloud-platform, openid/email/profile.

## Problems hit & fixes (for future reference)

| Problem | Cause | Fix |
|---|---|---|
| `gcloud` couldn't enable APIs / read project | The old `gmail-notion-connection` project wasn't owned by Nick | Created a new project Nick owns |
| `Callers must accept Terms of Service` | Cloud ToS never accepted | Accepted at console.cloud.google.com |
| "You need additional access" in Console | Browser was on personal `nicsicard@gmail.com` | Switched browser to the business account |
| `Error 400: invalid_scope` | "All scopes" pulled in invalid `classroom.*` and `cloud-identity.*` | Deselected those groups |
| "Something went wrong" at consent | Too many scopes in one request (~64) | Used a smaller scope batch (21) — succeeded |
| `gws mcp` unknown | v0.22.5 has no built-in MCP server | Use gws as a direct CLI tool in Claude Code |

## Daily-driver commands

- Triage unread:   `gws gmail +triage`
- Read a message:  `gws gmail +read --id <id>`
- Reply / all:     `gws gmail +reply` | `gws gmail +reply-all`
- Forward:         `gws gmail +forward`
- Send:            `gws gmail +send --to … --subject … --body …`
- Calendar:        `gws calendar +agenda`
- Re-auth / add scopes: `gws auth login` (keep each batch small, ~<50 scopes)

## Pending / next steps

- [ ] Add a `~/.claude/CLAUDE.md` memory file (draft provided in chat) — needs Nick's
      email **signature** and **reply style** filled in (none provided yet).
- [ ] Add remaining scopes in small batches if/when needed (Drive, Docs, Slides, Chat,
      Admin) — re-run `gws auth login`, avoid `classroom.*` / `cloud-identity.*`.
- [ ] (Optional) **Path B — service account + domain-wide delegation** for full
      domain admin and headless use (no browser, no scope-count limit; can run in a
      cloud container). Not yet started.
- [ ] (Optional) Native MCP server when a newer gws build is available via Homebrew.
- [ ] **Cancel Superhuman subscription** once comfortable — Gmail read/triage/draft/
      send + Calendar + Contacts all work through Claude now.

## Safety rule established

Claude should **draft replies / save Gmail drafts** and never auto-send; only send when
Nick explicitly says "send." Use `--dry-run` to validate writes first.
