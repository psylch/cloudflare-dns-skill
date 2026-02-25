---
name: cloudflare-dns
description: Comprehensive guide for managing Cloudflare DNS with Azure integration. Use when configuring Cloudflare as authoritative DNS provider for Azure-hosted applications, managing DNS records via API, setting up API tokens, configuring proxy settings, troubleshooting DNS issues, implementing DNS security best practices, or integrating External-DNS with Cloudflare for Kubernetes workloads.
---

# Cloudflare DNS Skill

## Language

**Match user's language**: Respond in the same language the user uses.

## Overview

Manage Cloudflare DNS records via REST API. Covers record CRUD, proxy settings, troubleshooting, and Kubernetes External-DNS integration.

## Script Directory

Determine this SKILL.md directory as `SKILL_DIR`, then use `${SKILL_DIR}/scripts/cloudflare-dns.sh`.

## Environment

Credentials are loaded automatically from `.env` files. The script checks in this order (highest priority first):
1. Environment variables (already set in shell — always win)
2. Project-level `<cwd>/.env` (auto-loaded by script)
3. Skill-level `${SKILL_DIR}/.env` (auto-loaded by script)

| Variable | Required | Description |
|----------|----------|-------------|
| `CF_API_TOKEN` | Yes | Cloudflare API Token (Zone:Read + DNS:Edit) |
| `CF_ZONE_ID` | No | Default zone ID (avoids passing it to every command) |

### First-time Setup

When running preflight and credentials are missing, guide the user:

```
Cloudflare API credentials not found.

How to obtain:
1. Visit https://dash.cloudflare.com/profile/api-tokens
2. Create Custom Token with permissions: Zone:Read + DNS:Edit
3. Scope to specific zones (recommended)
4. Copy the token

Where to save?
A) Project-level: <cwd>/.env (this project only)
B) User-level: ${SKILL_DIR}/.env (all projects using this skill)
```

After the user chooses, check if a `.env` already exists at the target location:
- If it exists: show the current contents, ask the user — **(A) Append** CF_* keys to existing file, **(B) Backup and replace** (`cp .env .env.backup.$(date +%s)`), or **(C) Skip**
- If it does not exist: copy `.env.example` to `.env`

Then fill in the values:
```
CF_API_TOKEN=<user_input>
CF_ZONE_ID=<user_input_optional>
```

## Preflight Check-Fix Table

When preflight reports `ready: false`, use this table to resolve each failure:

| Check | Status | Fix |
|-------|--------|-----|
| `curl` | missing | `brew install curl` (macOS) / `apt install curl` (Linux) |
| `jq` | missing | `brew install jq` (macOS) / `apt install jq` (Linux) |
| `dig` | missing | `brew install bind` (macOS) / `apt install dnsutils` (Linux) — optional, only for `verify-dns` |
| `kubectl` | missing | `brew install kubectl` — optional, only for External-DNS features |
| `CF_API_TOKEN` | not_configured | Follow First-time Setup above to create and save the token |
| `CF_API_TOKEN` | invalid | Token exists but live API check failed. Regenerate at https://dash.cloudflare.com/profile/api-tokens with Zone:Read + DNS:Edit permissions |
| `CF_ZONE_ID` | not_configured | Optional. Find in Cloudflare dashboard: select zone, copy Zone ID from right sidebar |

## Workflow

1. **Preflight** — Verify credentials and tools:
   ```bash
   bash ${SKILL_DIR}/scripts/cloudflare-dns.sh preflight
   ```
   If `ready: false`, consult the Check-Fix Table above for specific remediation.
2. **List existing records** — Understand current state before changes:
   ```bash
   bash ${SKILL_DIR}/scripts/cloudflare-dns.sh list-records
   ```
3. **Create / update / delete** records as needed:
   ```bash
   bash ${SKILL_DIR}/scripts/cloudflare-dns.sh create-cname $CF_ZONE_ID www target.example.com true
   bash ${SKILL_DIR}/scripts/cloudflare-dns.sh create-a $CF_ZONE_ID app 1.2.3.4 true
   ```
4. **Verify DNS propagation**:
   ```bash
   bash ${SKILL_DIR}/scripts/cloudflare-dns.sh verify-dns app.example.com
   ```

For raw `curl` commands, read `references/dns-operations.md`.

## Script Reference

Helper script: `scripts/cloudflare-dns.sh`

| Command | Description |
|---------|-------------|
| `preflight` | Check env vars, tools, and token validity |
| `verify-token` | Verify API token |
| `list-zones` | List all zones |
| `list-records [zone_id]` | List DNS records |
| `get-record <zone_id> <name>` | Get specific record |
| `create-a <zone_id> <name> <ip> [proxied]` | Create A record |
| `create-cname <zone_id> <name> <target> [proxied]` | Create CNAME record |
| `delete-record <zone_id> <record_id>` | Delete record |
| `export <zone_id>` | Export zone to BIND format |
| `verify-dns <hostname>` | Verify DNS resolution |

## Degradation

| Dependency | When missing | Behavior |
|------------|-------------|----------|
| `dig` | Not installed | Skip `verify-dns` command; suggest manual check with `nslookup` or online tools like https://dnschecker.org |
| `kubectl` | Not installed or no cluster access | Skip `check-external-dns`; Kubernetes integration features unavailable — user can still manage DNS records directly via API |

Core DNS record operations (list, create, update, delete) only require `curl` and `jq`.

## Completion Report

After any mutation operation (create, update, delete), present a structured report:

```
DNS Record Updated!

Zone: [zone name] ([zone_id])
Operation: [create | update | delete]
Record: [type] [name] → [content]
Proxied: [yes | no]
TTL: [value]

Verification:
✓ API returned success
✓ dig @1.1.1.1 [name] [type] → [resolved value]  (if dig available)

Next Steps:
→ Full propagation may take 1-5 minutes
→ Verify with: dig @1.1.1.1 [name] [type]
```

For delete operations, omit the content/proxied/TTL fields and adjust accordingly.

## Proxy Decision Guide

| Use Case | Proxy (orange cloud) | Reason |
|----------|---------------------|--------|
| Web apps, APIs, static sites | Yes | CDN, DDoS protection |
| Mail (MX), SSH, FTP, VPN | No | Non-HTTP protocols |

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| 401 Unauthorized | Invalid token | Regenerate API token |
| 403 Forbidden | Insufficient permissions | Add Zone:Read, DNS:Edit |
| 429 Rate Limited | Too many requests | Increase interval, use pagination |
| "Record exists" | Duplicate | Delete or update existing record |
| DNS not resolving | Propagation delay | Wait 1-5 min, verify with `dig @1.1.1.1` |

## Security

1. **Scope tokens** — Use specific zones, not "All zones"
2. **IP filtering** — Restrict to known IPs when possible
3. **Rotate regularly** — Every 90 days for production
4. **Store in `.env`** — Never hardcode tokens in scripts or SKILL.md

## References

Read these on demand when the user's request needs deeper context. Do not load all at once.

| Topic | File | When to read |
|-------|------|-------------|
| curl examples for all record ops | `references/dns-operations.md` | User wants raw curl instead of script |
| Kubernetes External-DNS setup | `references/kubernetes-integration.md` | User mentions k8s, External-DNS, AKS |
| Complete Cloudflare API docs | `references/api-reference.md` | User needs advanced API features not in script |
| Azure integration patterns | `references/azure-integration.md` | User mentions Azure, App Service, AKS |
