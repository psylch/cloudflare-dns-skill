# cloudflare-dns-skill

[中文文档](README.zh.md)

Manage Cloudflare DNS records via REST API — record CRUD, proxy settings, zone export, DNS verification, and Kubernetes External-DNS integration.

| Feature | Description |
|---------|-------------|
| Record CRUD | Create, list, delete A and CNAME records |
| Zone Management | List zones, export in BIND format |
| DNS Verification | Verify resolution with dig/nslookup |
| Proxy Control | Toggle Cloudflare proxy on/off |
| K8s Integration | External-DNS setup and troubleshooting |
| Azure Integration | Cloudflare as authoritative DNS for Azure apps |

## Installation

### Via skills.sh (recommended)

```bash
npx skills add psylch/cloudflare-dns-skill -g -y
```

### Via Plugin Marketplace

```
/plugin marketplace add psylch/cloudflare-dns-skill
/plugin install cloudflare-dns@psylch-cloudflare-dns-skill
```

### Manual Install

```bash
git clone https://github.com/psylch/cloudflare-dns-skill.git
# Copy skills/cloudflare-dns/ to your skills directory
```

Restart Claude Code after installation.

## Prerequisites

- **Cloudflare API Token** with `Zone:Read` + `DNS:Edit` permissions
- `curl` and `jq` installed
- Optional: `dig` or `nslookup` for DNS verification
- Optional: `kubectl` for Kubernetes External-DNS features

## Setup

Set your credentials in environment or `.env` file:

```bash
export CF_API_TOKEN="your-token-here"
export CF_ZONE_ID="your-zone-id"  # optional default zone
```

## Usage

- "List my Cloudflare DNS records"
- "Add an A record for api.example.com pointing to 1.2.3.4"
- "Delete the CNAME record for old.example.com"
- "Export my DNS zone"
- "Check if External-DNS is syncing properly"

## File Structure

```
cloudflare-dns-skill/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── skills/
│   └── cloudflare-dns/
│       ├── SKILL.md
│       ├── scripts/
│       │   └── cloudflare-dns.sh
│       └── references/
│           ├── api-reference.md
│           ├── azure-integration.md
│           ├── dns-operations.md
│           └── kubernetes-integration.md
├── README.md
├── README.zh.md
├── LICENSE
└── .gitignore
```

## License

MIT
