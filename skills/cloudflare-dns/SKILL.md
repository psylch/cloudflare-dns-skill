---
name: cloudflare-dns
description: Comprehensive guide for managing Cloudflare DNS with Azure integration. Use when configuring Cloudflare as authoritative DNS provider for Azure-hosted applications, managing DNS records via API, setting up API tokens, configuring proxy settings, troubleshooting DNS issues, implementing DNS security best practices, or integrating External-DNS with Cloudflare for Kubernetes workloads.
---

# Cloudflare DNS Skill

Manage Cloudflare DNS records via REST API. Covers record CRUD, proxy settings, troubleshooting, and Kubernetes External-DNS integration.

## Environment

Credentials are stored in `.env` at the skill root (`~/.claude/skills/cloudflare-dns/.env`). The helper script auto-loads this file. For inline `curl` commands, source it first:

```bash
set -a; source ~/.claude/skills/cloudflare-dns/.env; set +a
```

| Variable | Required | Description |
|----------|----------|-------------|
| `CF_API_TOKEN` | Yes | Cloudflare API Token (Zone:Read + DNS:Edit) |
| `CF_ZONE_ID` | No | Default zone ID (avoids passing it to every command) |

Create a token at: Cloudflare Dashboard > My Profile > API Tokens > Custom token with `Zone:Read` + `DNS:Edit` permissions, scoped to specific zones.

## Workflow

1. **Preflight** — Verify credentials and tools are ready:
   ```bash
   bash ~/.claude/skills/cloudflare-dns/scripts/cloudflare-dns.sh preflight
   ```
2. **List existing records** — Understand current state before making changes:
   ```bash
   bash ~/.claude/skills/cloudflare-dns/scripts/cloudflare-dns.sh list-records
   ```
3. **Create / update / delete** records as needed:
   ```bash
   bash ~/.claude/skills/cloudflare-dns/scripts/cloudflare-dns.sh create-cname $CF_ZONE_ID www target.example.com true
   bash ~/.claude/skills/cloudflare-dns/scripts/cloudflare-dns.sh create-a $CF_ZONE_ID app 1.2.3.4 true
   ```
4. **Verify DNS propagation**:
   ```bash
   bash ~/.claude/skills/cloudflare-dns/scripts/cloudflare-dns.sh verify-dns app.example.com
   ```

For raw `curl` commands, see `references/dns-operations.md`.

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

- `references/dns-operations.md` — Full curl examples for all record operations
- `references/kubernetes-integration.md` — External-DNS, cert-manager, AKS config
- `references/api-reference.md` — Complete Cloudflare DNS API docs
- `references/azure-integration.md` — Azure-specific patterns
- [Cloudflare API Docs](https://developers.cloudflare.com/api/)
