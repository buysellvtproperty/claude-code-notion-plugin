# Google Workspace CLI (`gws`) — Setup Guide

A single, authenticated connection that lets **Claude** (and you, from the terminal)
operate across **all** your Google apps — Gmail, Calendar, Drive, Docs, Sheets, Chat, and
**Admin** — replacing the patchwork of separate Google connections.

This uses the **official Google Workspace CLI**, `gws`
([github.com/googleworkspace/cli](https://github.com/googleworkspace/cli),
npm: `@googleworkspace/cli`). It's "one command-line tool for Drive, Gmail, Calendar,
Sheets, Docs, Chat, Admin, and more," dynamically built from Google's Discovery Service,
with a **built-in MCP server** (`gws mcp`) so any MCP client — including Claude Code —
connects through one stdio server.

---

## What you can and can't automate

| Step | Who | Why |
|------|-----|-----|
| Install `gws`, wire up `.mcp.json`, run the helper script | scriptable | committed to this repo |
| Create Cloud project, OAuth consent, browser sign-in | **you (interactive)** | needs a browser + your Google login |
| Enable **Admin SDK** / admin scopes | **you, as Super Admin** | admin features are high-privilege |

> **Ephemeral environments (Claude Code on the web):** credentials stored in a container's
> keyring vanish when the session ends. For a durable headless connection, use a
> **service account** or **exported credentials** via
> `GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE` (see [Headless / web](#headless--web-durability)).

---

## Prerequisites

- **Node.js 18+** (this repo's environment has Node 22 ✓)
- A **Google Cloud project** in the same Workspace org
- A Google account with Workspace access; **Super Admin** for admin features

---

## Phase A — Google Cloud + OAuth foundation *(one-time, interactive)*

The fastest path is to let `gws auth setup` do this for you in Phase B (it can create the
project, enable APIs, and create the OAuth client via `gcloud`). To do it manually instead:

1. Create / pick a Cloud project (Console or `gcloud projects create`). Note the **Project ID**.
2. Configure the **OAuth consent screen** — choose **Internal** if everyone using it is in
   your org (no test-user management needed).
3. Create an **OAuth client → Desktop app**, download the JSON, and save it to:
   ```
   ~/.config/gws/client_secret.json
   ```

## Phase B — Install & authenticate

```bash
# Install (npm is simplest; prebuilt binary / brew / cargo / nix also supported)
npm install -g @googleworkspace/cli

# Automated: creates the GCP project if needed, enables APIs, makes the OAuth client
gws auth setup

# …or, if you placed client_secret.json manually:
gws auth login          # opens a browser for consent; tokens encrypted into the OS keyring

gws auth status         # confirm who you are
```

Or just run the helper in this repo, which installs `gws` if missing and authenticates:

```bash
bash scripts/setup-gws.sh
```

## Phase C — Enable services & admin scopes

- `gws auth setup` enables the required APIs automatically. If a later command returns
  `accessNotConfigured`, click the `enable_url` it prints → **Enable** → wait ~10s → retry.
- For **Admin** features: enable the **Admin SDK API** and authorize admin scopes
  (e.g. `admin.directory.*`) on the consent screen — **you must be a Super Admin**.

**Sanity-check coverage:**

```bash
gws gmail +send --to you@buysellvtproperty.com --subject test --body hi --dry-run
gws calendar +agenda
gws drive files list --params '{"pageSize": 5}'
gws admin users list --params '{"customer":"my_customer","maxResults":5}'   # admin check
```

## Phase D — Connect to Claude as a single MCP connection

```bash
claude mcp add google-workspace -- gws mcp -s gmail,calendar,drive,docs,sheets,chat,admin
```

This repo's **`.mcp.json`** already declares the equivalent project-scoped server:

```json
"google-workspace": {
  "type": "stdio",
  "command": "gws",
  "args": ["mcp", "-s", "gmail,calendar,drive,docs,sheets,chat,admin"]
}
```

Restart Claude Code, confirm the `google-workspace` tools appear, and run a read call
(e.g. today's calendar or recent Drive files).

> Trim the `-s` service list to only what you need — fewer services = smaller attack surface.

## Headless / web durability

For environments without a browser (CI, Claude Code on the web):

1. On an authenticated machine, export credentials **or** use a service account:
   ```bash
   gws auth export --unmasked > credentials.json   # user creds
   # or download a service-account JSON (with domain-wide delegation for admin/impersonation)
   ```
2. Store that JSON as an **environment secret** — **never commit it** (`.gitignore` already
   blocks `credentials.json`, `client_secret.json`, `*.sa.json`, `.env`, …).
3. Point the CLI at it in the environment's config:
   ```bash
   export GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE=/path/to/credentials.json
   ```
   `scripts/setup-gws.sh` detects this var and authenticates non-interactively.

**Admin + per-user impersonation** across the domain requires a **service account with
domain-wide delegation** authorized in the Admin Console (Security → API controls →
Domain-wide delegation), with the needed OAuth scopes.

## Phase F — Retire redundant connections

Once `google-workspace` works, remove the now-duplicative individual Google MCP servers
(separate Gmail / Calendar / Drive connections) so `gws` is the single source:

```bash
claude mcp remove <old-google-server-name>     # for locally-registered ones
```

Managed/hosted ones are removed from the environment's MCP config.

---

## Key environment variables

| Variable | Purpose |
|----------|---------|
| `GOOGLE_WORKSPACE_CLI_TOKEN` | Pre-obtained OAuth2 access token (highest precedence) |
| `GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE` | Path to credentials / service-account JSON |
| `GOOGLE_WORKSPACE_CLI_CLIENT_ID` / `_CLIENT_SECRET` | OAuth client override |
| `GOOGLE_WORKSPACE_CLI_CONFIG_DIR` | Override config dir (default `~/.config/gws`) |
| `GOOGLE_WORKSPACE_PROJECT_ID` | GCP project override |
| `GWS_SERVICES` | (this repo's script) services passed to `gws mcp -s` |

Credential precedence: `TOKEN` → `CREDENTIALS_FILE` → keyring (`gws auth login`) → plaintext file.

## Security

- Admin + domain-wide delegation is **high-privilege** — prefer least-privilege scopes and
  scope `gws mcp -s …` to only what you use.
- Credentials live in the OS keyring (AES-256-GCM) on interactive machines; headless uses a
  secret, never a committed file.
- Use `--dry-run` (supported by write / `+` helper commands) when first wiring workflows.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `accessNotConfigured` | Click the printed `enable_url`, Enable, wait ~10s, retry — or re-run `gws auth setup` |
| Admin commands 403 | Confirm Super Admin + Admin SDK API enabled + admin scopes authorized |
| Headless "not authenticated" | Set `GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE` to a valid creds/service-account JSON |
| MCP server not appearing in Claude | Ensure `gws` is on `PATH`; restart Claude Code; check `gws auth status` |

## Sources

- [github.com/googleworkspace/cli](https://github.com/googleworkspace/cli)
- [InfoQ: Google Workspace CLI for humans and AI agents](https://www.infoq.com/news/2026/06/google-workspace-cli/)
- [Google: Configure Workspace MCP servers](https://developers.google.com/workspace/guides/configure-mcp-servers)
