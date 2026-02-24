# DNS Operations Reference

## List DNS Records

```bash
# All records
curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" | jq '.result[] | {name, type, content, proxied}'

# Filter by type
curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?type=A" \
  -H "Authorization: Bearer $CF_API_TOKEN" | jq '.result[]'

# Search by name
curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?name=app.example.com" \
  -H "Authorization: Bearer $CF_API_TOKEN" | jq '.result[]'
```

## Create DNS Records

```bash
# A Record (proxied)
curl -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "A",
    "name": "app",
    "content": "20.185.100.50",
    "ttl": 1,
    "proxied": true
  }'

# A Record (DNS-only)
curl -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "A",
    "name": "mail",
    "content": "20.185.100.51",
    "ttl": 3600,
    "proxied": false
  }'

# CNAME Record
curl -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "CNAME",
    "name": "www",
    "content": "app.example.com",
    "ttl": 1,
    "proxied": true
  }'

# TXT Record
curl -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "TXT",
    "name": "_dmarc",
    "content": "v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com",
    "ttl": 3600
  }'

# MX Record
curl -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "MX",
    "name": "@",
    "content": "mail.example.com",
    "priority": 10,
    "ttl": 3600
  }'
```

## Update DNS Records

```bash
# Get record ID first
RECORD_ID=$(curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?name=app.example.com&type=A" \
  -H "Authorization: Bearer $CF_API_TOKEN" | jq -r '.result[0].id')

# Update record
curl -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$RECORD_ID" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "A",
    "name": "app",
    "content": "20.185.100.60",
    "ttl": 1,
    "proxied": true
  }'

# Patch (partial update)
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$RECORD_ID" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"proxied": false}'
```

## Delete DNS Records

```bash
# Get record ID
RECORD_ID=$(curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?name=old.example.com" \
  -H "Authorization: Bearer $CF_API_TOKEN" | jq -r '.result[0].id')

# Delete
curl -X DELETE "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$RECORD_ID" \
  -H "Authorization: Bearer $CF_API_TOKEN"
```

## Proxy Settings (Orange/Gray Cloud)

### When to Enable Proxy (Orange Cloud)

| Use Case | Proxy | Reason |
|----------|-------|--------|
| Web applications | Yes | CDN, DDoS protection |
| REST APIs | Yes | Performance, security |
| Static websites | Yes | Caching, optimization |
| WebSockets | Yes | Supported with config |

### When to Disable Proxy (Gray Cloud)

| Use Case | Proxy | Reason |
|----------|-------|--------|
| Mail servers (MX) | No | SMTP not supported |
| SSH access | No | Non-HTTP protocol |
| FTP servers | No | Non-HTTP protocol |
| Custom TCP/UDP | No | Only HTTP/HTTPS proxied |
| VPN endpoints | No | Direct connection needed |

### Toggle Proxy via API

```bash
# Enable proxy
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$RECORD_ID" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"proxied": true}'

# Disable proxy
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$RECORD_ID" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"proxied": false}'
```

## Zone Management

### List Zones

```bash
curl -s "https://api.cloudflare.com/client/v4/zones" \
  -H "Authorization: Bearer $CF_API_TOKEN" | jq '.result[] | {name, id, status, plan: .plan.name}'
```

### Get Zone Details

```bash
curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID" \
  -H "Authorization: Bearer $CF_API_TOKEN" | jq '.result'
```

### Zone Settings

```bash
# Get all settings
curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/settings" \
  -H "Authorization: Bearer $CF_API_TOKEN" | jq '.result[] | {id, value}'

# Update SSL mode
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/settings/ssl" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"value": "full"}'
```

## Export/Import DNS Records

### Export (BIND Format)

```bash
curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/export" \
  -H "Authorization: Bearer $CF_API_TOKEN" > dns-backup-$(date +%Y%m%d).txt
```

### Import (BIND Format)

```bash
curl -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/import" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -F "file=@dns-backup.txt"
```
